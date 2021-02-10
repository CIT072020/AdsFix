unit TableUtils;

interface

uses
  SysUtils,
  Classes, DB,
  AdsData, Ace, AdsTable, AdsCnnct,
  ServiceProc;

type
  // описание полей таблицы
  TFieldsInf = class
    Name      : string;
    FieldType : integer;
    TypeSQL   : string;
  end;

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

  // ќписание планируемой к удалению строки
  TRow4Del = class
    RowID : string;
    FillPcnt : Integer;
    DelRow : Boolean;
    Reason : Integer;
  end;

  // описание записи в наборе дубликатов
  TDupRow = class
    RowID : string;
    FillPcnt : Integer;
    DelRow : Boolean;
  end;


type
  // Info по ошибке
  TErrInfo = class
  // “екущий статус таблицы
    State     : Integer;
  //  оды ошибок тестировани€
    ErrClass  : Integer;
    NativeErr : Integer;
    MsgErr    : string;
    //  од завершени€ "освобождени€ таблицы"
    PrepErr   : Integer;
    //  од завершени€ Fix таблицы
    FixErr    : Integer;
    //  од завершени€ INSERT таблицы
    InsErr    : Integer;
    //  оличество записей как результат INSERT
    TotalIns  : Integer;

    Rows4Del : TStringList;
    Plan2Del : TAdsQuery;
  end;

type
  TBadRec = class
  //info по сбойной записи
    RecNo     : Integer;
    BadFieldI : Integer;
    ErrCode   : Integer;
    //UseInSpan : Boolean;
    //InTOP     : Integer;
    //InSTART   : Integer;
    //RowID     : string;
  end;

  TSpan = class
  //info по интервалу хороших записей
    InTOP     : Integer;
    InSTART   : Integer;
  end;


type
  // описание ADS-таблицы дл€ восстановлени€
  TTableInf = class(TInterfacedObject)
  private
    FSysPfx   : string;
    procedure FieldsInfo(Q : TAdsQuery);
    procedure IndexesInf(SrcTbl: TTableInf; QWork : TAdsQuery);
  public
    TableName : string;
    // ѕуть к словарю
    Path2Src  : string;
    // ќбъект TAdsTable
    AdsT      : TAdsTable;

    FileTmp   : string;

    // количество записей (теоретически)
    RecCount  : Integer;
    // количество записей (фактически)
    LastGood  : Integer;
    // количество уникальных индексов
    IndCount  : Integer;

    // описание полей таблицы
    FieldsInf : TStringList;
    // описание индексов
    IndexInf  : TList;
    // пол€ с типом autoincrement
    FieldsAI  : TStringList;

    NeedBackUp : Boolean;
    // —писок резервных копий
    BackUps   : TStringList;

    ErrInfo  : TErrInfo;

    //T_DupRows   : TList;
    //T_List4Del  : String;

    DmgdRIDs  : string;
    // список плохих записей
    BadRecs   : TList;
    // список интервалов дл€ INSERT
    GoodSpans : TList;

    TotalDel  : Integer;
    RowsFixed : Integer;

    constructor Create(TName : string; TID : Integer; Conn: TAdsConnection; AnsiPfx : string);
    destructor Destroy; override;

    function Test1Table(AdsTI : TTableInf; Check: TestMode): Integer;
  end;

procedure Read1Rec(Rec: TFields);
function Read1RecEx(Fields: TFields; FInf: TStringList) : TBadRec;

implementation

uses
  FileUtil,
  StrUtils,
  DateUtils,
  Math,
  DBFunc;

// ѕоиск среди компонентов существующего с заданным именем
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

  Self.TableName := TName;
  Self.Path2Src  := IncludeTrailingPathDelimiter(Conn.GetConnectionPath);

  cName := CMPNT_NAME + IntToStr(TID);
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

  FieldsInf  := TStringList.Create;
  FieldsAI   := TStringList.Create;
  IndexInf   := TList.Create;
  BackUps    := TStringList.Create;
  
  NeedBackUp := True;

  ErrInfo   := TErrInfo.Create;
  ErrInfo.Rows4Del := TStringList.Create; 
  BadRecs   := TList.Create;
  GoodSpans := TList.Create;
end;


destructor TTableInf.Destroy;
begin
  //if FField2 <> nil then FreeAndNil(FField2);
  inherited Destroy;
end;

// сведени€ о пол€х одной таблицы (SQL)
procedure TTableInf.FieldsInfo(Q : TAdsQuery);
var
  OneField: TFieldsInf;
begin
  with Q do begin
    SQL.Add( Format('SELECT * FROM %sCOLUMNS WHERE PARENT=''%s''' , [FSysPfx, TableName]) );
    Active := True;
    First;
    while not Eof do begin
      OneField := TFieldsInf.Create;
      OneField.Name      := FieldByName('Name').AsString;
      OneField.FieldType := FieldByName('Field_Type').AsInteger;
      OneField.TypeSQL   := ArrSootv[OneField.FieldType].Name;
      if (OneField.FieldType = ADS_AUTOINC) then
        FieldsAI.Add(OneField.Name);
      FieldsInf.AddObject(FieldByName('Name').AsString, OneField);
      Next;
    end;
    Close;
    AdsCloseSQLStatement;
    AdsConnection.CloseCachedTables;
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
  OneInd : TIndexInf;
label
  QFor;
begin
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
      OneInd := TIndexInf.Create;
      OneInd.Options := FieldByName('INDEX_OPTIONS').AsInteger;
      //OneInd.Expr := FieldByName('INDEX_EXPRESSION').AsInteger;
      OneInd.Fields := TStringList.Create;
      OneInd.Fields.Delimiter := ';';
      OneInd.Fields.DelimitedText := FieldByName('INDEX_EXPRESSION').AsString;
      ClearFieldInExp(OneInd.Fields);

      SetLength(OneInd.IndFieldsAdr, OneInd.Fields.Count);

      CommaList := '';
      OneInd.AlsCommaSet := '';
      OneInd.EquSet := '';
      for j := 0 to OneInd.Fields.Count - 1 do begin
        if (j > 0) then begin
          CommaList := CommaList + ',';
          OneInd.AlsCommaSet := OneInd.AlsCommaSet + ',';
          OneInd.EquSet := OneInd.EquSet + ' AND ';
        end;

        CommaList := CommaList + OneInd.Fields[j];
        OneInd.AlsCommaSet := OneInd.AlsCommaSet + AL_SRC + '.' + OneInd.Fields[j];
        OneInd.EquSet := OneInd.EquSet + '(' + AL_SRC + '.' + OneInd.Fields[j] + '=' + AL_DUP + '.' + OneInd.Fields[j] + ')';
        for i := 0 to SrcTbl.FieldsInf.Count - 1 do
          //if (TFieldsInf(SrcTbl.FieldsInf[i]).Name = OneInd.Fields[j]) then begin
          if (SrcTbl.FieldsInf[i] = OneInd.Fields[j]) then begin
            OneInd.IndFieldsAdr[j] := i;
            //goto QFor;
            Break;
          end;
      end;
QFor:
      OneInd.CommaSet := CommaList;

      SrcTbl.IndexInf.Add(OneInd);
      Next;
    end;
    Close;
    AdsCloseSQLStatement;
    AdsConnection.CloseCachedTables;
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
      t := TFieldsInf(AdsTI.FieldsInf.Objects[k]).FieldType;
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
  for j := 0 to Rec.Count - 1 do
    v := Rec[j].Value;
end;


// „тение всех полей записи с обработкой ошибок
function Read1RecEx(Fields: TFields; FInf: TStringList) : TBadRec;
var
  Ms, j: Integer;
  v: Variant;
  t: TDateTime;
  ts: TTimeStamp;
  Year: Word;
  FI: TFieldsInf;
  BadFInRec: TBadRec;
begin
  Result := nil;
  for j := 0 to Fields.Count - 1 do begin
    try
      v := Fields[j].Value;
      if (Length(Fields[j].DisplayText) > 0) then begin
      // Ќе пусто или не NULL
        FI := TFieldsInf(FInf.Objects[j]);
        if (FI.FieldType in ADS_DATES) then begin
          t := v;
          Year := YearOf(t);
          if (Year <= 1) or (Year > 2100) then
            //raise Exception.Create(EMSG_BAD_DATA);
            raise EADSDatabaseError.create(nil, UE_BAD_YEAR, '');
          if (FI.FieldType = ADS_TIMESTAMP) then begin
            Ms := (DateTimeToTimeStamp(t)).Time;
            if (Ms < 0) or (Ms > MSEC_PER_DAY) then
              //raise Exception.Create(EMSG_BAD_DATA);
              raise EADSDatabaseError.create(nil, UE_BAD_TMSTMP, '');
          end
        end
        else if (FI.FieldType = ADS_AUTOINC) then begin
          Ms := v;
          if (Ms < 0) then
              //raise Exception.Create(EMSG_BAD_DATA);
              raise EADSDatabaseError.create(nil, UE_BAD_AINC, '');
        end;
      end;

    except
    // ќписание ошибочной записи
    on E: Exception do begin
      if (E is EADSDatabaseError) then
        Ms := EADSDatabaseError(E).ACEErrorCode
      else
        Ms := UE_BAD_DATA;
      Result := TBadRec.Create;
      Result.BadFieldI := j;
      Result.ErrCode := Ms;
      Break;
    end
    end;
  end;

end;

// ѕопытка позиционировани€ и чтени€ выборки записей таблицы
procedure PositionSomeRecs(AdsTbl: TAdsTable; FInf: TStringList; Check: TestMode);
var
  Step: Integer;
begin
  if (AdsTbl.RecordCount > 0) then begin
    AdsTbl.First;
    if ( Assigned(Read1RecEx(AdsTbl.Fields, FInf)) ) then
      raise EADSDatabaseError.create(AdsTbl, UE_BAD_DATA, EMSG_BAD_DATA);
    AdsTbl.Last;
    if ( Assigned(Read1RecEx(AdsTbl.Fields, FInf)) ) then
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
      if ( Assigned(Read1RecEx(AdsTbl.Fields, FInf)) ) then
        raise EADSDatabaseError.create(AdsTbl, UE_BAD_DATA, EMSG_BAD_DATA);
    end;

  end;
end;


//  оличество записей в таблице (SQL)
function RecsBySQL(Q: TAdsQuery; TName: string): Integer;
begin
  Result := 0;
  try
    Q.Close;
    Q.SQL.Clear;
    Q.SQL.Text := 'SELECT COUNT(*) FROM ' + TName;
    Q.Active := True;
    if (Q.RecordCount > 0) then
      Result := Q.Fields[0].Value;
    Q.Close;
    Q.AdsCloseSQLStatement;
    Q.AdsConnection.CloseCachedTables;
  except
  end;
end;




// тестирование одной таблицы на ошибки
function TTableInf.Test1Table(AdsTI : TTableInf; Check: TestMode): Integer;
var
  iFld, ec: Integer;
  TypeName, s: string;
  ErrInf: TStringList;
  AdsFT: UNSIGNED16;
  Conn : TAdsConnection;
  QWork : TAdsQuery;
begin
  Result := 0;
  if (AdsTI.AdsT.Active) then
    AdsTI.AdsT.Close;

  try
    Conn := AdsTI.AdsT.AdsConnection;
    QWork := TAdsQuery.Create(AdsTI.AdsT.Owner);
    QWork.AdsConnection := Conn;

    FieldsInfo(QWork);
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
              s := AdsTI.FieldsInf[iFld];
              s := 'ALTER TABLE ' + AdsTI.TableName + ' ALTER COLUMN ' + s + ' ' + s + ' ' + TFieldsInf(AdsTI.FieldsInf.Objects[iFld]).TypeSQL;
              Conn.Execute(s);
              s := IncludeTrailingPathDelimiter(Conn.GetConnectionPath) + AdsTI.TableName + '*.BAK';
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
