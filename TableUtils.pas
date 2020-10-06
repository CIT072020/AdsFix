unit TableUtils;

interface

uses
  SysUtils,
  Classes, DB,
  AdsData, Ace, AdsTable, AdsCnnct,
  ServiceProc, AdsDAO;

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
  // “екущий статус таблицы
    State    : Integer;
  //  оды ошибок тестировани€
    ErrClass : Integer;
    NativeErr  : Integer;
    MsgErr   : string;
    //  од завершени€ "освобождени€ таблицы"
    PrepErr  : Integer;
    //  од завершени€ Fix таблицы
    FixErr   : Integer;
    //  од завершени€ INSERT таблицы
    InsErr   : Integer;

  end;

type
  // описание ADS-таблицы дл€ восстановлени€
  TTableInf = class
  private
    FSysPfx   : string;
  public
    // ќбъект TAdsTable
    AdsT      : TAdsTable;
    TableName : string;
    FileTmp   : string;
    // количество записей (теоретически)
    RecCount  : Integer;
    // количество записей (фактически)
    LastGood  : Integer;
    // количество уникальных индексов
    IndCount  : Integer;
    //
    IndexInf  : TList;
    //
    FieldsInf    : TList;
    FieldsInfAds : TACEFieldDefs;
    // пол€ с типом autoincrement
    FieldsAI  : TStringList;

    ErrInfo  : TErrInfo;

    DupRows   : TList;
    List4Del  : String;

    DmgdRIDs  : string;
    // список интервалов дл€ INSERT
    GoodSpans : TList;

    TotalDel  : Integer;
    RowsFixed : Integer;
    //property Owner : TObject read FOwner write FOwner;
    //constructor Create(TName : string; AT: TAdsTable; AnsiPfx : string);
    //constructor Create(TName : string; Conn: TAdsConnection; AnsiPfx : string);
    constructor Create(TName : string; TID : Integer; Conn: TAdsConnection; AnsiPfx : string);
    destructor Destroy; override;

    //class procedure FieldsInfBySQL(AdsTbl: TTableInf; QWork : TAdsQuery);
    procedure FieldsInfo;

    procedure IndexesInf(SrcTbl: TTableInf; QWork : TAdsQuery);
    function Test1Table(AdsTI : TTableInf; QWork : TAdsQuery; Check: TestMode): Integer;
  end;

procedure Read1Rec(Rec: TFields);
function Read1RecEx(Rec: TFields; FInf: TList): Integer;

implementation

uses
  FileUtil,
  StrUtils,
  DateUtils,
  Math,
  DBFunc;


function TableExists(Owner : TComponent; CName : string) : TAdsTable;
var
  i : Integer;
begin
  Result := nil;
  // ѕоиск таблицы в прежнем списке
  for i := 0 to Owner.ComponentCount -1 do
    if ( CName = Owner.Components[i].Name ) then begin
      Result := TAdsTable(Owner.Components[i]);
      Result.Close;
      Break;
    end;
end;

constructor TTableInf.Create(TName : string; TID : Integer; Conn: TAdsConnection; AnsiPfx : string);
var
  cName : string;
  T : TAdsTable;
begin
  inherited Create;

  cName := CMPNT_NAME + IntToStr(TID);
  Self.TableName := TName;
  T := TableExists(Conn.Owner, cName);
  if ( not Assigned(T) ) then begin
    Self.AdsT := TAdsTable.Create(Conn.Owner);
    Self.AdsT.Name := cName;
    Self.AdsT.AdsConnection := Conn;
  end
  else
    Self.AdsT := T;

  Self.AdsT.TableName := TName;

  Self.FSysPfx := AnsiPfx;

  ErrInfo   := TErrInfo.Create;
  IndexInf  := TList.Create;
  GoodSpans := TList.Create;
end;


destructor TTableInf.Destroy;
begin
  //if FField2 <> nil then FreeAndNil(FField2);
  inherited Destroy;
end;


// сведени€ о пол€х одной таблицы (SQL)
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
    s := 'SELECT * FROM ' + FSysPfx + 'COLUMNS WHERE PARENT=''' + TableName + '''';
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

// ”брать из выражени€ индекса направлени€ сортировки
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

// сведени€ об индексах одной таблицы (SQL)
procedure TTableInf.IndexesInf(SrcTbl: TTableInf; QWork : TAdsQuery);
var
  i, j: Integer;
  CommaList: string;
  UInd : TIndexInf;
label
  QFor;
begin
  SrcTbl.IndexInf := TList.Create;
  with QWork do begin
    if Active then
      Close;
    // все уникальные индексы
    SQL.Text := 'SELECT INDEX_OPTIONS, INDEX_EXPRESSION, PARENT FROM ' +
      FSysPfx + 'INDEXES WHERE (PARENT = ''' + SrcTbl.TableName +
      ''') AND ((INDEX_OPTIONS & 1) = 1)';
    Active := True;
    SrcTbl.IndCount := RecordCount;
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
        for i := 0 to SrcTbl.FieldsInfAds.Count - 1 do
          if (SrcTbl.FieldsInfAds[i].FieldName = UInd.Fields[j]) then begin
            UInd.IndFieldsAdr[j] := i;
            goto QFor;
          end;
      end;
QFor:
      UInd.CommaSet := CommaList;

      SrcTbl.IndexInf.Add(UInd);
      Next;
    end;

  end;

end;

// подбор простейших полей дл€ ALTER
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
      if (t in [ADS_LOGICAL, ADS_INTEGER, ADS_SHORTINT, ADS_AUTOINC])
        or (t in ADS_DATES)
        or (t in ADS_BIN) then begin
        Result := k;
        Exit;
      end;
    end;
  end;

end;

// „тение всех полей записи
procedure Read1Rec(Rec: TFields);
var
  j: Integer;
  v: Variant;
begin
  for j := 0 to Rec.Count - 1 do begin
    v := Rec[j].Value;
  end;
end;

// „тение всех полей записи с обработкой ошибок
function Read1RecEx(Rec: TFields; FInf: TList): Integer;
var
  Ms, j: Integer;
  v: Variant;
  t: TDateTime;
  ts: TTimeStamp;
  Year: Word;
  FI: TFieldsInf;
begin
  Result := -1;
  for j := 0 to Rec.Count - 1 do begin
    try
      v := Rec[j].Value;
      if (Length(Rec[j].DisplayText) > 0) then begin
      // Ќе пусто или не NULL
        FI := TFieldsInf(FInf[j]);
        if (FI.FieldType in ADS_DATES) then begin
          t := v;
          Year := YearOf(t);
          if (Year <= 1) or (Year > 2100) then
            raise Exception.Create(EMSG_BAD_DATA);
          if (FI.FieldType = ADS_TIMESTAMP) then begin
            Ms := (DateTimeToTimeStamp(t)).Time;
            if (Ms < 0) or (Ms > MSEC_PER_DAY) then
              raise Exception.Create(EMSG_BAD_DATA);
          end
        end
        else if (FI.FieldType = ADS_AUTOINC) then begin
          Ms := v;
          if (Ms < 0) then
              raise Exception.Create(EMSG_BAD_DATA);
        end;
      end;

    except
      Result := j;
      Break;
    end;
  end;

end;

// ѕопытка позиционировани€ и чтени€ выборки записей таблицы
procedure PositionSomeRecs(AdsTbl: TAdsTable; FInf: TList; Check: TestMode);
var
  Step: Integer;
begin
  if (AdsTbl.RecordCount > 0) then begin
    AdsTbl.First;
    if (Read1RecEx(AdsTbl.Fields, FInf) >= 0) then
      raise EADSDatabaseError.create(AdsTbl, UE_BAD_DATA, EMSG_BAD_DATA);
    AdsTbl.Last;
    if (Read1RecEx(AdsTbl.Fields, FInf) >= 0) then
      raise EADSDatabaseError.create(AdsTbl, UE_BAD_DATA, EMSG_BAD_DATA);

    if (Check = Simple) then
        // Make EoF
      AdsTbl.Next
    else begin
      if (Check = Medium) then begin
        Step := Max(AdsTbl.RecordCount div 10, 1);
        if (Step > MAX_READ_MEDIUM) then
          // 10 процент записей превышает MAX_READ_MEDIUM
          Step := AdsTbl.RecordCount div MAX_READ_MEDIUM;
      end
      else
        Step := 1;
      AdsTbl.First;
    end;

    while (not AdsTbl.Eof) do begin
      AdsTbl.AdsSkip(Step);
      if (Read1RecEx(AdsTbl.Fields, FInf) >= 0) then
        raise EADSDatabaseError.create(AdsTbl, UE_BAD_DATA, EMSG_BAD_DATA);
    end;

  end;
end;


//  оличество записей в таблице (SQL)
function RecsBySQL(Q: TAdsQuery; TName: string): Integer;
begin
  Result := 0;
  Q.Close;
  Q.SQL.Clear;
  Q.SQL.Text := 'SELECT COUNT(*) FROM ' + TName;
  Q.Active := True;
  if (Q.RecordCount > 0) then
    Result := Q.Fields[0].Value;
  Q.Close;
  Q.AdsCloseSQLStatement;
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
    Conn := QWork.AdsConnection;
    FieldsInfo;
    IndexesInf(AdsTI, QWork);
    AdsTI.RecCount := RecsBySQL(QWork, AdsTI.TableName);
    AdsTI.ErrInfo.State := TST_UNKNOWN;

    // Easy Mode and others
    AdsTI.AdsT.Open;
    PositionSomeRecs(AdsTI.AdsT, AdsTI.FieldsInf, Check);
    AdsTI.AdsT.Close;

    if (Check = Medium)
      OR (Check = Slow) then begin
      s := 'EXECUTE PROCEDURE sp_Reindex(''' + AdsTI.TableName + '.adt'',0)';
      Conn.Execute(s);

      if (Check = Slow) then begin

          if (AdsTI.IndCount > 0) then begin
        // есть уникальные индексы
            iFld := Field4Alter(AdsTI);
            if (iFld >= 0) then begin
              s := AdsTI.FieldsInfAds[iFld].FieldName;
              TypeName := ArrSootv[AdsTI.FieldsInfAds[iFld].FieldType].Name;
              s := 'ALTER TABLE ' + AdsTI.TableName + ' ALTER COLUMN ' + s + ' ' + s + ' ' + TypeName;
              Conn.Execute(s);
              s := AppPars.Path2Src + AdsTI.TableName + '*.BAK';
              DeleteFiles(s);
            end;
          end;

        // Realy need?
        AdsTI.AdsT.PackTable;
      end;

    end;
    AdsTI.ErrInfo.State := TST_GOOD;

  except
    on E: EADSDatabaseError do begin
      Result := E.ACEErrorCode;
      AdsTI.ErrInfo.ErrClass  := E.ACEErrorCode;
      AdsTI.ErrInfo.NativeErr := E.SQLErrorCode;
      AdsTI.ErrInfo.MsgErr    := E.Message;
      AdsTI.ErrInfo.State     := TST_ERRORS;
    end;
  end;

end;


end.
