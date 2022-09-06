unit uTableUtils;

interface

uses
  SysUtils,
  Classes,
  Contnrs,
  DB,
  AdsData, Ace, AdsTable, AdsCnnct,
  uServiceProc;

type
  // �������� ����� �������
  TFieldsInf = class
    Name      : string;
    FieldType : integer;
    TypeSQL   : string;
  end;

  // �������� ������ �������, ��������������� ������ ����������
  TIndexInf = class
    Options : Integer;
    Fields  : TStringList;
    // ������� ��� ON-token ��� ������ ����������
    EquSet  : string;
    IndFieldsAdr: array of integer;

    destructor Destroy; override;
  end;

type
  // Info �� ������
  TErrInfo = class
  // ������� ������ �������
    State     : Integer;
  // ���� ������ ������������
    ErrClass  : Integer;
    NativeErr : Integer;
    MsgErr    : string;
    // ��� ���������� "������������ �������"
    PrepErr   : Integer;
    // ��� ���������� Fix �������
    FixErr    : Integer;
    // ��� ���������� INSERT �������
    InsErr    : Integer;
    // ���������� ������� ��� ��������� INSERT
    TotalIns  : Integer;
  end;

type
  TBadRec = class
  //info �� ������� ������
    RecNo     : Integer;
    BadFieldI : Integer;
    ErrCode   : Integer;
    //UseInSpan : Boolean;
    //InTOP     : Integer;
    //InSTART   : Integer;
    //RowID     : string;
  end;

  TSpan = class
  //info �� ��������� ������� �������
    InTOP     : Integer;
    InSTART   : Integer;
  end;


type
  // �������� ADS-������� ��� ��������������
  TTableInf = class(TInterfacedObject)
  private
    FTableID   : Integer;
    FPars      : TFixPars;
    procedure FieldsInfo(Q : TAdsQuery); virtual;
    procedure IndexesInfo(SrcTbl: TTableInf; QWork : TAdsQuery); virtual;
  public
    // ��� ������� � ������� ��� � ����� (Free table)
    TableName : string;
    // ��� ������� ��� ����������
    NameNoExt : string;
    // ��� ����� ����� ��� �����������
    FileTmp   : string;

    // ������ TAdsTable
    AdsT      : TAdsTable;

    // ���������� ������� (������������)
    RecCount  : Integer;
    // ���������� ������� (����������)
    LastGood  : Integer;
    // ���������� ���������� ��������
    IndCount  : Integer;

    // �������� ����� �������
    FieldsInf : TStringList;
    // �������� ��������
    IndexInf  : TObjectList;
    // ���� � ����� autoincrement
    FieldsAI  : TStringList;

    NeedBackUp : Boolean;

    // ������ ��������� �����
    BackUps   : TStringList;

    ErrInfo  : TErrInfo;


    DmgdRIDs  : string;
    // ������ ������ �������
    BadRecs   : TObjectList;
    // ������ ���������� ��� INSERT
    GoodSpans : TObjectList;

    TotalDel  : Integer;
    RowsFixed : Integer;

    property Pars : TFixPars read FPars write FPars;

    //function Test1Table(SrcTbl: TTableInf; Check: TestMode; SysAnsi: string): Integer; virtual;  overload;
    function Test1Table(QWork : TAdsQuery; Check: TestMode; SysAnsi: string): Integer; virtual;

    // ��������� ������� ����� � ������� ��������� �����������
    function SetWorkCopy(Path2TMP: string): Integer;

    constructor Create(TName : string; TID : Integer; Conn: TAdsConnection; AppPars : TFixPars);
    destructor Destroy; override;
  end;

  TDictTable = class(TTableInf)
  end;

  TFreeTable = class(TTableInf)
  private
    procedure FieldsInfo(Q : TAdsQuery);
    procedure IndexesInfo(SrcTbl: TTableInf; Q : TAdsQuery);
  public
    function Test1Table(QWork : TAdsQuery; Check: TestMode): Integer;

    //constructor Create(TName : string; TID : Integer; Conn: TAdsConnection; AppPars : TAppPars); overload;
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

destructor TIndexInf.Destroy;
begin
  FreeAndNil(Fields);
  inherited Destroy;
end;


(*
// ����� ����� ����������� ������������� � �������� ������
function TableExists(Owner : TComponent; CName : string) : TAdsTable;
var
  i : Integer;
begin
  Result := nil;
  // ����� ������� � ������� ������
  for i := 0 to Owner.ComponentCount -1 do
    if ( CName = Owner.Components[i].Name ) then begin
      Result := TAdsTable(Owner.Components[i]);
      Result.Close;
      Break;
    end;
end;
*)
constructor TTableInf.Create(TName : string; TID : Integer; Conn: TAdsConnection; AppPars : TFixPars);
var
  PosPoint: Integer;
  cName : string;
  //T : TAdsTable;
begin
  inherited Create;

  FTableID := TID;
  Pars := AppPars;
  TableName := TName;

  NameNoExt := TableName;
  PosPoint := LastDelimiter('.', TableName);
  if (PosPoint > 0) then
    NameNoExt := Copy(TableName, 1, PosPoint - 1);

  cName := CMPNT_NAME + IntToStr(TID);
(*
  T := TableExists(Conn.Owner, cName);
  if ( not Assigned(T) ) then begin
    AdsT := TAdsTable.Create(Conn.Owner);
    AdsT.Name := cName;
    AdsT.AdsConnection := Conn;
  end
  else
    AdsT := T;
*)
  AdsT := TAdsTable.Create(Conn.Owner);
  AdsT.Name := cName;
  AdsT.AdsConnection := Conn;
  AdsT.TableName := TName;

  FieldsInf  := TStringList.Create;
  FieldsAI   := TStringList.Create;
  IndexInf   := TObjectList.Create;
  BackUps    := TStringList.Create;
  //SafeFix    := Pars.SafeFix;

  NeedBackUp := True;

  ErrInfo       := TErrInfo.Create;
  ErrInfo.State := TST_UNKNOWN;

  BadRecs   := TObjectList.Create;
  //GoodSpans := TList.Create;
  GoodSpans := TObjectList.Create;
end;


destructor TTableInf.Destroy;
begin
  FreeAndNil(GoodSpans);
  FreeAndNil(BadRecs);
  FreeAndNil(ErrInfo);
  FreeAndNil(BackUps);
  FreeAndNil(IndexInf);
  FreeAndNil(FieldsAI);
  FreeAndNil(FieldsInf);
  FreeAndNil(AdsT);
  inherited Destroy;
end;
{
constructor TFreeTable.Create(TName : string; TID : Integer; Conn: TAdsConnection; AppPars : TAppPars);
begin
  inherited Create(TName, TID, Conn, AppPars);
  IsFree := True;
end;
}

// �������� � ����� ����� ������� (Select ��� dictionary)
procedure TTableInf.FieldsInfo(Q : TAdsQuery);
var
  OneField: TFieldsInf;
begin
  with Q do begin
    First;
    while not Eof do begin
      OneField := TFieldsInf.Create;
      OneField.Name      := FieldByName('Name').AsString;
      OneField.FieldType := FieldByName('Field_Type').AsInteger;
      OneField.TypeSQL   := ArrSootv[OneField.FieldType].Name;
      if (OneField.FieldType = ADS_AUTOINC) then
        FieldsAI.Add(OneField.Name);
      FieldsInf.AddObject(OneField.Name, OneField);
      Next;
    end;
    Close;
    AdsCloseSQLStatement;
    AdsConnection.CloseCachedTables;
  end;
end;

// �������� � ����� ����� ������� (EXEC sp_GetColumns)
procedure TFreeTable.FieldsInfo(Q : TAdsQuery);
var
  i : Integer;
  OneField: TFieldsInf;
begin
  with Q do begin
    SQL.Clear;
    SQL.Add( Format('SELECT * FROM (EXECUTE PROCEDURE sp_GetColumns(NULL,NULL,''%s'',''%s'')) AS Cols', [TableName, '%']) );

    Active := True;
    First;
    while not Eof do begin
      OneField := TFieldsInf.Create;
      OneField.Name      := FieldByName('COLUMN_NAME').AsString;
      OneField.TypeSQL   := FieldByName('TYPE_NAME').AsString;
      OneField.FieldType := SQLType2ADS(OneField.TypeSQL);
      if (OneField.FieldType = ADS_AUTOINC) then
        FieldsAI.Add(OneField.Name);
      FieldsInf.AddObject(OneField.Name, OneField);
      Next;
    end;

    Close;
    AdsCloseSQLStatement;
    AdsConnection.CloseCachedTables;
  end;
end;


// ������ �� ��������� ������� ����������� ����������
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

// �������� �� �������� ����� ������� (SQL)
procedure TTableInf.IndexesInfo(SrcTbl: TTableInf; QWork : TAdsQuery);
var
  i, j: Integer;
  OneInd : TIndexInf;
begin
  with QWork do begin
    Active := True;
    SrcTbl.IndCount := RecordCount;
    First;
    while not Eof do begin
      OneInd := TIndexInf.Create;
      OneInd.Options := FieldByName('INDEX_OPTIONS').AsInteger;
      OneInd.Fields := TStringList.Create;
      OneInd.Fields.Delimiter := ';';
      OneInd.Fields.DelimitedText := FieldByName('INDEX_EXPRESSION').AsString;
      ClearFieldInExp(OneInd.Fields);

      SetLength(OneInd.IndFieldsAdr, OneInd.Fields.Count);

      OneInd.EquSet := '';
      for j := 0 to OneInd.Fields.Count - 1 do begin
        if (j > 0) then
          OneInd.EquSet := OneInd.EquSet + ' AND ';
        OneInd.EquSet := OneInd.EquSet + '(' + AL_SRC + '.' + OneInd.Fields[j] + '=' + AL_DUP + '.' + OneInd.Fields[j] + ')';

        for i := 0 to SrcTbl.FieldsInf.Count - 1 do
          if (SrcTbl.FieldsInf[i] = OneInd.Fields[j]) then begin
            OneInd.IndFieldsAdr[j] := i;
            Break;
          end;
      end;

      SrcTbl.IndexInf.Add(OneInd);
      Next;
    end;
    Close;
    AdsCloseSQLStatement;
    AdsConnection.CloseCachedTables;
  end;
end;


// �������� �� �������� ����� ������� (SQL)
procedure TFreeTable.IndexesInfo(SrcTbl: TTableInf; Q: TAdsQuery);
var
  opt: TIndexOptions;
  j, k, i: Integer;
  OneInd: TIndexInf;
begin
  SrcTbl.IndCount := 0;
  try
    SrcTbl.AdsT.Active := True;
    with SrcTbl.AdsT do begin
    //SQL.Clear;
    //SQL.Add( Format('SELECT TOP 1 * FROM "%s" AS Indexes', [TableName]));
    //Active := True;
      for k := 0 to IndexDefs.Count - 1 do begin
        if (ixUnique in IndexDefs.Items[k].Options) then begin

          OneInd := TIndexInf.Create;
          OneInd.Options := 1;
          OneInd.Fields := TStringList.Create;
          OneInd.Fields.Delimiter := ';';
          OneInd.Fields.DelimitedText := IndexDefs.Items[k].Fields;
          ClearFieldInExp(OneInd.Fields);

          SetLength(OneInd.IndFieldsAdr, OneInd.Fields.Count);

          OneInd.EquSet := '';
          for j := 0 to OneInd.Fields.Count - 1 do begin
            if (j > 0) then
              OneInd.EquSet := OneInd.EquSet + ' AND ';
            OneInd.EquSet := OneInd.EquSet + '(' + AL_SRC + '.' + OneInd.Fields[j] + '=' + AL_DUP + '.' + OneInd.Fields[j] + ')';

            for i := 0 to SrcTbl.FieldsInf.Count - 1 do
              if (SrcTbl.FieldsInf[i] = OneInd.Fields[j]) then begin
                OneInd.IndFieldsAdr[j] := i;
                Break;
              end;
          end;
          SrcTbl.IndexInf.Add(OneInd);
        end;

      end;
      SrcTbl.IndCount := SrcTbl.IndexInf.Count;

    //AdsCloseSQLStatement;
    //AdsConnection.CloseCachedTables;
    end;
    SrcTbl.AdsT.Active := False;
  except
    SrcTbl.IndCount := 0;
  end;
end;


// ������ ���������� ����� ��� ALTER
function Field4Alter(AdsTI: TTableInf): integer;
var
  i, j, k, t: Integer;
  IndInf: TIndexInf;
begin
  Result := -1;

  for i := 0 to AdsTI.IndexInf.Count - 1 do begin

    IndInf := TIndexInf(AdsTI.IndexInf.Items[i]);

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

// ������ ���� ����� ������
procedure Read1Rec(Rec: TFields);
var
  j: Integer;
  v: Variant;
begin
  for j := 0 to Rec.Count - 1 do
    v := Rec[j].Value;
end;


// ������ ���� ����� ������ � ���������� ������
function Read1RecEx(Fields: TFields; FInf: TStringList) : TBadRec;
var
  Logic : Boolean;
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
      // �� ����� ��� �� NULL
        FI := TFieldsInf(FInf.Objects[j]);
        if (FI.FieldType in ADS_DATES) then begin
          t := v;
          Year := YearOf(t);
          if (Year <= 1) or (Year > 2100) then
            // !!! ���� �� �������� 04.11.21
            //raise EADSDatabaseError.create(nil, UE_BAD_YEAR, '');
            ;
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
        end
        else if (FI.FieldType = ADS_LOGICAL) then begin
          Ms    := 0;
          Logic := Fields[j].GetData(Addr(Ms));
          Logic := Fields[j].Value;
          if (Logic = True) then
            if (Ms <> $FFFF) then
              raise EADSDatabaseError.create(nil, UE_BAD_LOGIC, '')
          else
            if (Logic = False) then
              if (Ms <> $0) then
              raise EADSDatabaseError.create(nil, UE_BAD_LOGIC, '');
        end;
      end;

    except
    // �������� ��������� ������
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

// ������� ���������������� � ������ ������� ������� �������
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
          // 10 ������� ������� ��������� MAX_READ_MEDIUM
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


// ���������� ������� � ������� (SQL)
function RecsBySQL(Q: TAdsQuery; TName: string): Integer;
begin
  Result := 0;
  try
    Q.Close;
    Q.SQL.Clear;
    Q.SQL.Text := Format('SELECT COUNT(*) FROM "%s"', [TName]);
    Q.Active := True;
    if (Q.RecordCount > 0) then
      Result := Q.Fields[0].Value;
    Q.Close;
    Q.AdsCloseSQLStatement;
    Q.AdsConnection.CloseCachedTables;
  except
  end;
end;

(*
// ������������ ����� ������� �� ������ (Dictionary)
function TTableInf.Test1Table(SrcTbl: TTableInf; Check: TestMode; SysAnsi: string): Integer;
var
  iFld, ec: Integer;
  TypeName, s: string;
  ErrInf: TStringList;
  AdsFT: UNSIGNED16;
  Conn : TAdsConnection;
  QWork : TAdsQuery;
begin
  Result := 0;
  if (SrcTbl.AdsT.Active) then
    SrcTbl.AdsT.Close;

  try
    Conn := SrcTbl.AdsT.AdsConnection;
    QWork := TAdsQuery.Create(SrcTbl.AdsT.Owner);
    QWork.AdsConnection := Conn;
    QWork.SQL.Add( Format('SELECT * FROM %sCOLUMNS WHERE PARENT=''%s''' , [SysAnsi, TableName]) );

    FieldsInfo(QWork);
    // ��� ���������� �������
    QWork.SQL.Text := 'SELECT INDEX_OPTIONS, INDEX_EXPRESSION, PARENT FROM ' + SysAnsi + 'INDEXES WHERE (PARENT = ''' + TableName + ''') AND ((INDEX_OPTIONS & 1) = 1)';
    IndexesInfo(SrcTbl, QWork);
    SrcTbl.RecCount := RecsBySQL(QWork, SrcTbl.TableName);
    SrcTbl.ErrInfo.State := TST_UNKNOWN;

    // Easy Mode and others
    SrcTbl.AdsT.Open;
    PositionSomeRecs(SrcTbl.AdsT, SrcTbl.FieldsInf, Check);
    SrcTbl.AdsT.Close;

    if (Check = Medium)
      OR (Check = Slow) then begin
      s := 'EXECUTE PROCEDURE sp_Reindex(''' + SrcTbl.TableName + '.adt'',0)';
      Conn.Execute(s);

      if (Check = Slow) then begin

          if (SrcTbl.IndCount > 0) then begin
        // ���� ���������� �������
            iFld := Field4Alter(SrcTbl);
            if (iFld >= 0) then begin
              s := SrcTbl.FieldsInf[iFld];
              s := 'ALTER TABLE ' + SrcTbl.TableName + ' ALTER COLUMN ' + s + ' ' + s + ' ' + TFieldsInf(SrcTbl.FieldsInf.Objects[iFld]).TypeSQL;
              Conn.Execute(s);
              s := IncludeTrailingPathDelimiter(Conn.GetConnectionPath) + SrcTbl.TableName + '*.BAK';
              DeleteFiles(s);
            end;
          end;

        // Realy need?
        SrcTbl.AdsT.PackTable;
      end;

    end;
    SrcTbl.ErrInfo.State  := TST_GOOD;
    SrcTbl.ErrInfo.MsgErr := '';

  except
    on E: EADSDatabaseError do begin
      Result := E.ACEErrorCode;
      SrcTbl.ErrInfo.ErrClass  := E.ACEErrorCode;
      SrcTbl.ErrInfo.NativeErr := E.SQLErrorCode;
      SrcTbl.ErrInfo.MsgErr    := E.Message;
      SrcTbl.ErrInfo.State     := TST_ERRORS;
    end;
  end;

end;
*)

// ������������ ����� ������� �� ������ (Dictionary)
function TTableInf.Test1Table(QWork : TAdsQuery; Check: TestMode; SysAnsi: string): Integer;
var
  iFld, ec: Integer;
  TypeName, s: string;
  ErrInf: TStringList;
  AdsFT: UNSIGNED16;
begin
  Result := 0;
  ErrInfo.State := TST_UNKNOWN;
  if (AdsT.Active) then
    AdsT.Close;

  try
    QWork.SQL.Clear;
    QWork.SQL.Add( Format('SELECT * FROM %sCOLUMNS WHERE PARENT=''%s''' , [SysAnsi, TableName]) );
    QWork.Active := True;

    FieldsInfo(QWork);
    // ��� ���������� �������
    QWork.SQL.Text := 'SELECT INDEX_OPTIONS, INDEX_EXPRESSION, PARENT FROM ' + SysAnsi + 'INDEXES WHERE (PARENT = ''' + TableName + ''') AND ((INDEX_OPTIONS & 1) = 1)';
    IndexesInfo(Self, QWork);
    RecCount := RecsBySQL(QWork, TableName);

    // Easy Mode and others
    AdsT.Open;
    PositionSomeRecs(AdsT, FieldsInf, Check);
    AdsT.Close;

    if (Check = Medium)
      OR (Check = Slow) then begin
      s := 'EXECUTE PROCEDURE sp_Reindex(''' + TableName + '.adt'',0)';
      QWork.AdsConnection.Execute(s);

      if (Check = Slow) then begin

          if (IndCount > 0) then begin
        // ���� ���������� �������
            iFld := Field4Alter(Self);
            if (iFld >= 0) then begin
              s := FieldsInf[iFld];
              s := 'ALTER TABLE ' + TableName + ' ALTER COLUMN ' + s + ' ' + s + ' ' + TFieldsInf(FieldsInf.Objects[iFld]).TypeSQL;
              QWork.AdsConnection.Execute(s);
              s := IncludeTrailingPathDelimiter(QWork.AdsConnection.GetConnectionPath) + TableName + '*.BAK';
              DeleteFiles(s);
            end;
          end;

        // Realy need?
        AdsT.PackTable;
      end;

    end;
    ErrInfo.State  := TST_GOOD;
    ErrInfo.MsgErr := '';

  except
    on E: EADSDatabaseError do begin
      Result := E.ACEErrorCode;
      ErrInfo.ErrClass  := E.ACEErrorCode;
      ErrInfo.NativeErr := E.SQLErrorCode;
      ErrInfo.MsgErr    := E.Message;
      ErrInfo.State     := TST_ERRORS;
    end;
  end;

end;



// ������������ ����� ������� �� ������ (Free Table)
function TFreeTable.Test1Table(QWork : TAdsQuery; Check: TestMode): Integer;
var
  iFld, ec: Integer;
  TypeName, s: string;
  ErrInf: TStringList;
  AdsFT: UNSIGNED16;
  Conn : TAdsConnection;
begin
  Result := 0;
  ErrInfo.State := TST_UNKNOWN;

  try
    try
      AdsT.Open;
    except
      on E: EADSDatabaseError do begin
        if (E.ACEErrorCode = 5159) AND (E.SQLErrorCode = 0) then begin
          if AdsDDFreeTable(PAnsiChar(Pars.Path2Src + TableName), nil) = AE_FREETABLEFAILED then
            // ��������� ������� ����������� �������������
            raise EADSDatabaseError.Create(AdsT, UE_BAD_PREP, '������ ������������ �������');
        end;
      end;
    end;

    FieldsInfo(QWork);
    IndexesInfo(Self, QWork);
    RecCount      := RecsBySQL(QWork, TableName);

    // Easy Mode and others
    AdsT.Open;
    PositionSomeRecs(AdsT, FieldsInf, Check);
    AdsT.Close;
    if (IndexInf.Count > 0) then begin
      s := Format('EXECUTE PROCEDURE sp_Reindex(''%s'',0)', [TableName]);
      QWork.AdsConnection.Execute(s);
    end;


    if (Check = Medium)
      OR (Check = Slow) then begin
      //s := 'EXECUTE PROCEDURE sp_Reindex(''' + AdsTI.TableName + '.adt'',0)';
      //Conn.Execute(s);

      if (Check = Slow) then begin

          if (IndexInf.Count > 0) then begin
        // ���� ���������� �������
{
            iFld := Field4Alter(AdsTI);
            if (iFld >= 0) then begin
              s := AdsTI.FieldsInf[iFld];
              s := 'ALTER TABLE ' + AdsTI.TableName + ' ALTER COLUMN ' + s + ' ' + s + ' ' + TFieldsInf(AdsTI.FieldsInf.Objects[iFld]).TypeSQL;
              Conn.Execute(s);
              s := IncludeTrailingPathDelimiter(Conn.GetConnectionPath) + AdsTI.TableName + '*.BAK';
              DeleteFiles(s);
            end;
}
          end;

        // Realy need?
        AdsT.PackTable;
      end;

    end;
    ErrInfo.State := TST_GOOD;

  except
    on E: EADSDatabaseError do begin
      Result := E.ACEErrorCode;
      ErrInfo.ErrClass  := E.ACEErrorCode;
      ErrInfo.NativeErr := E.SQLErrorCode;
      ErrInfo.MsgErr    := E.Message;
      ErrInfo.State     := TST_ERRORS;
    end;
  end;

end;


//-------------------------------------------------------------

// ����� ��������� � ������������ �������
function TTableInf.SetWorkCopy(Path2TMP: string): Integer;
var
  s, FileSrc, FileSrcNoExt, FileDst: string;
begin
  Result := UE_BAD_PREP;

  if (Pars.IsDict = True) OR (Pars.SafeFix.UseCopy4Work = True) then begin
    // ����������� ����������� � ����� �������
    // ��������������� ����������� �������� ����
    FileTmp := Path2TMP + NameNoExt;

    // ������ ������ � ���������
    FileSrc := Pars.Path2Src + NameNoExt;
    try
      s := FileSrc + ExtADT;
      if (not FileExists(FileTmp + ExtADT)) OR (Pars.SafeFix.ReWriteWork = True) then
        if (CopyOneFile(s, Path2TMP) <> 0) then
          raise Exception.Create('������ ����������� ' + s);

      s := FileSrc + ExtADM;
      if FileExists(s) then begin
        if (not FileExists(FileTmp + ExtADM)) OR (Pars.SafeFix.ReWriteWork = True) then
          if (CopyOneFile(s, Path2TMP) <> 0) then
            raise Exception.Create('������ ����������� ' + s);
      end;

      if AdsDDFreeTable(PAnsiChar(FileTmp + ExtADT), nil) = AE_FREETABLEFAILED then
        if ((Pars.IsDict = True) and (Pars.SafeFix.ReWriteWork = True)) then
        // ��������� ������� (������ ��� �����������!) ����������� �������������
          raise EADSDatabaseError.Create(AdsT, UE_BAD_PREP, '������ ������������ �������');

      ErrInfo.PrepErr := 0;
      Result := 0;
    except
      ErrInfo.State := FIX_ERRORS;
      ErrInfo.PrepErr := UE_BAD_PREP;
    end;

  end
  else begin

  end;
end;




end.
