unit TableUtils;

interface

uses
  Classes,
  AdsData, Ace, AdsTable, AdsCnnct,
  ServiceProc;

type
  // описание полей таблицы
  TFieldsInf = class
    Name      : string;
    FieldType : integer;
    TypeSQL   : string;
  end;
  
type
  // описание одного индекса
  TIndexInf = class
    Options: Integer;
    Expr: string;
    Fields: TStringList;
    CommaSet : string;
    AlsCommaSet : string;
    EquSet : string;
    IndFieldsAdr: array of integer;
  end;

type
  // Info по ошибке
  TErrInfo = class
    ErrClass : Integer;
    NativeErr  : Integer;
    MsgErr   : string;
  end;

type
  // описание ADS-таблицы для восстановления
  TTableInf = class
  private
    //FOwner : TObject;
  public
    AdsT      : TAdsTable;
    TableName : string;
    FileTmp   : string;
    // уникальных индексов
    IndCount  : Integer;
    IndexInf  : TList;
    FieldsInf    : TList;
    FieldsInfAds : TACEFieldDefs;
    // поля с типом autoincrement
    FieldsAI  : TStringList;
    ErrInfo  : TErrInfo;

    DupRows   : TList;
    List4Del  : String;
    TotalDel  : Integer;
    RowsFixed : Integer;
    //property Owner : TObject read FOwner write FOwner;
    constructor Create(TName : string; AT: TAdsTable);
    destructor Destroy; override;

    class procedure FieldsInfBySQL(AdsTbl: TTableInf; QWork : TAdsQuery);
    procedure FieldsInfo;

    procedure IndexesInf(AdsTbl: TTableInf; QWork : TAdsQuery);
    function Test1Table(AdsTI : TTableInf; QWork : TAdsQuery; Check: TestMode): Integer;
  end;

implementation

uses
  FileUtil,
  StrUtils,
  DBFunc;

constructor TTableInf.Create(TName : string; AT: TAdsTable);
begin
  inherited Create;

  Self.TableName := TName;
  Self.AdsT := AT;
  Self.AdsT.TableName := TName;

  IndexInf := TList.Create;
  ErrInfo  := TErrInfo.Create;
end;


destructor TTableInf.Destroy;
begin
  //if FField2 <> nil then FreeAndNil(FField2);
  inherited Destroy;
end;


// сведения о полях одной таблицы (SQL)
class procedure TTableInf.FieldsInfBySQL(AdsTbl: TTableInf; QWork : TAdsQuery);
var
  i: Integer;
  s: string;
  UFlds: TFieldsInf;
  ACEField: TACEFieldDef;
begin
  AdsTbl.FieldsInf := TList.Create;
  AdsTbl.FieldsAI := TStringList.Create;

  AdsTbl.FieldsInfAds := TACEFieldDefs.Create(AdsTbl.AdsT.Owner);

  with QWork do begin

    Active := false;
    SQL.Clear;
    s := 'SELECT * FROM ' + AppPars.SysAdsPfx + 'COLUMNS WHERE PARENT=''' +
      AdsTbl.TableName + '''';
    SQL.Add(s);
    Active := true;

    First;
    while not Eof do begin
      UFlds := TFieldsInf.Create;
      UFlds.Name := FieldByName('Name').AsString;
      UFlds.FieldType := FieldByName('Field_Type').AsInteger;
      UFlds.TypeSQL   := ArrSootv[UFlds.FieldType].Name;
      if (UFlds.FieldType = ADS_AUTOINC) then
        AdsTbl.FieldsAI.Add(UFlds.Name);
      AdsTbl.FieldsInf.Add(UFlds);

      ACEField := AdsTbl.FieldsInfAds.Add;
      ACEField.FieldName := FieldByName('Name').AsString;
      ACEField.FieldType := FieldByName('Field_Type').AsInteger;

      Next;
    end;

  end;

end;

// Убрать из выражения индекса направления сортировки
procedure ClearFieldInExp(Flds: TStringList);
var
  i, j, k: Integer;
begin
  for i := 0 to Flds.Count - 1 do begin
    j := Pos('(', Flds[i]);
    if (j > 0) then begin
      Flds[i] := RightStr(Flds[i], j + 1);
      k := Pos(')', Flds[i]);
      if (k > 0) then begin
        Flds[i] := LeftStr(Flds[i], k - 1);
      end;
    end;
  end;
end;

// сведения об индексах одной таблицы (SQL)
procedure TTableInf.IndexesInf(AdsTbl: TTableInf; QWork : TAdsQuery);
var
  i, j: Integer;
  CommaList: string;
  UInd : TIndexInf;
label
  QFor;
begin
  AdsTbl.IndexInf := TList.Create;
  with QWork do begin
    if Active then
      Close;
    // все уникальные индексы
    SQL.Text := 'SELECT INDEX_OPTIONS, INDEX_EXPRESSION, PARENT FROM ' +
      AppPars.SysAdsPfx + 'INDEXES WHERE (PARENT = ''' + AdsTbl.TableName +
      ''') AND ((INDEX_OPTIONS & 1) = 1)';
    Active := True;
    AdsTbl.IndCount := RecordCount;
    First;
    while not Eof do begin
      UInd := TIndexInf.Create;
      UInd.Options := FieldByName('INDEX_OPTIONS').AsInteger;
      //UInd.Expr := FieldByName('INDEX_EXPRESSION').AsInteger;
      UInd.Fields := TStringList.Create;
      UInd.Fields.Delimiter := ';';
      UInd.Fields.DelimitedText := FieldByName('INDEX_EXPRESSION').AsString;
      ClearFieldInExp(UInd.Fields);

      SetLength(UInd.IndFieldsAdr, UInd.Fields.Count);

      CommaList := '';
      UInd.AlsCommaSet := '';
      UInd.EquSet := '';
      for j := 0 to UInd.Fields.Count - 1 do begin
        if (j > 0) then begin
          CommaList := CommaList + ',';
          UInd.AlsCommaSet := UInd.AlsCommaSet + ',';
          UInd.EquSet := UInd.EquSet + ' AND ';
        end;

        CommaList := CommaList + Uind.Fields[j];
        UInd.AlsCommaSet := UInd.AlsCommaSet + AL_SRC + '.' + Uind.Fields[j];
        UInd.EquSet := UInd.EquSet + '(' + AL_SRC + '.' + Uind.Fields[j] + '=' + AL_DUP + '.' + Uind.Fields[j] + ')';
        for i := 0 to AdsTbl.FieldsInfAds.Count - 1 do
          if (AdsTbl.FieldsInfAds[i].FieldName = UInd.Fields[j]) then begin
            UInd.IndFieldsAdr[j] := i;
            goto QFor;
          end;
      end;
QFor:
      UInd.CommaSet := CommaList;

      AdsTbl.IndexInf.Add(UInd);
      Next;
    end;

  end;

end;

// подбор простейших полей для ALTER
function Field4Alter(AdsTI: TTableInf): integer;
var
  i, j, k, t: Integer;
  IndInf: TIndexInf;
begin
  Result := -1;

  for i := 0 to AdsTI.IndexInf.Count - 1 do begin

    IndInf := AdsTI.IndexInf.Items[i];

    for j := 0 to IndInf.Fields.Count - 1 do begin
      k := IndInf.IndFieldsAdr[j];
      t := AdsTI.FieldsInfAds[k].FieldType;
      if (t in [ADS_INTEGER, ADS_SHORTINT, ADS_AUTOINC]) then begin
        Result := k;
        Exit;
      end;
    end;
  end;

end;

// тестирование одной таблицы на ошибки
function TTableInf.Test1Table(AdsTI : TTableInf; QWork : TAdsQuery; Check: TestMode): Integer;
var
  iFld, ec: Integer;
  TypeName, s: string;
  ErrInf: TStringList;
  AdsFT: UNSIGNED16;
  Conn : TAdsConnection;
begin
  Result := 0;
  if (AdsTI.AdsT.Active) then
    AdsTI.AdsT.Close;

  try
    FieldsInfBySQL(AdsTI, QWork);
    IndexesInf(AdsTI, QWork);

    // Easy Mode and others
    AdsTI.AdsT.Open;
    AdsTI.AdsT.Close;

    if (Check = Medium)
      OR (Check = Slow) then begin
          if (AdsTI.IndCount > 0) then begin
        // есть уникальные индексы
            iFld := Field4Alter(AdsTI);
            if (iFld >= 0) then begin
              s := AdsTI.FieldsInfAds[iFld].FieldName;
              TypeName := ArrSootv[AdsTI.FieldsInfAds[iFld].FieldType].Name;
              s := 'ALTER TABLE ' + AdsTI.TableName + ' ALTER COLUMN ' + s + ' ' + s + ' ' + TypeName;
              Conn := QWork.AdsConnection;
              Conn.Execute(s);
              s := AppPars.Path2Src + AdsTI.TableName + '*.BAK';
              DeleteFiles(s);
            end;
          end;

      if (Check = Slow) then begin

      end;

    end;

  except
    on E: EADSDatabaseError do begin
      Result := E.ACEErrorCode;
      AdsTI.ErrInfo.ErrClass := E.ACEErrorCode;
      AdsTI.ErrInfo.NativeErr := E.SQLErrorCode;
      AdsTI.ErrInfo.MsgErr := E.Message;
    end;
  end;

end;



























// сведения о полях одной таблицы (SQL)
procedure TTableInf.FieldsInfo;
var
  i: Integer;
  s: string;
  Q : TAdsQuery;
  UFlds: TFieldsInf;
  ACEField: TACEFieldDef;
begin
  FieldsInf := TList.Create;
  FieldsAI := TStringList.Create;

  FieldsInfAds := TACEFieldDefs.Create(AdsT.Owner);
  Q := TAdsQuery.Create(AdsT.Owner);
  Q.AdsConnection := AdsT.AdsConnection;

  with Q do begin

    Active := False;
    SQL.Clear;
    s := 'SELECT * FROM ' + AppPars.SysAdsPfx + 'COLUMNS WHERE PARENT=''' + TableName + '''';
    SQL.Add(s);
    Active := True;

    First;
    while not Eof do begin
      UFlds := TFieldsInf.Create;
      UFlds.Name := FieldByName('Name').AsString;
      UFlds.FieldType := FieldByName('Field_Type').AsInteger;
      UFlds.TypeSQL   := ArrSootv[UFlds.FieldType].Name;
      if (UFlds.FieldType = ADS_AUTOINC) then
        FieldsAI.Add(UFlds.Name);

      FieldsInf.Add(UFlds);

      ACEField := FieldsInfAds.Add;
      ACEField.FieldName := FieldByName('Name').AsString;
      ACEField.FieldType := FieldByName('Field_Type').AsInteger;

      Next;
    end;

  end;

end;




end.
 