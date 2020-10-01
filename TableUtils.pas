unit TableUtils;

interface

uses
  SysUtils,
  Classes, DB,
  AdsData, Ace, AdsTable, AdsCnnct,
  ServiceProc, AdsDAO;

type
  // �������� ����� �������
  TFieldsInf = class
    Name      : string;
    FieldType : integer;
    TypeSQL   : string;
  end;

type
  // �������� ������ �������
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
  // Info �� ������
  TErrInfo = class
    ErrClass : Integer;
    NativeErr  : Integer;
    MsgErr   : string;
  end;

type
  // �������� ADS-������� ��� ��������������
  TTableInf = class
  private
    FSysPfx   : string;
  public
    // ������ TAdsTable
    AdsT      : TAdsTable;
    TableName : string;
    FileTmp   : string;
    // ���������� ������� (������������)
    RecCount  : Integer;
    // ���������� ���������� ��������
    IndCount  : Integer;
    //
    IndexInf  : TList;
    //
    FieldsInf    : TList;
    FieldsInfAds : TACEFieldDefs;
    // ���� � ����� autoincrement
    FieldsAI  : TStringList;

    ErrInfo  : TErrInfo;

    DupRows   : TList;
    List4Del  : String;

    DmgdRIDs  : string;
    // ���������� ������� (����������)
    LastGood  : Integer;
    // ������ ���������� ��� INSERT
    GoodSpans : TList;

    TotalDel  : Integer;
    RowsFixed : Integer;
    //property Owner : TObject read FOwner write FOwner;
    constructor Create(TName : string; AT: TAdsTable; AnsiPfx : string);
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

constructor TTableInf.Create(TName : string; AT: TAdsTable; AnsiPfx : string);
begin
  inherited Create;

  Self.TableName := TName;
  Self.AdsT := AT;
  Self.AdsT.TableName := TName;
  Self.FSysPfx := AnsiPfx;

  IndexInf  := TList.Create;
  ErrInfo   := TErrInfo.Create;
  GoodSpans := TList.Create;
end;


destructor TTableInf.Destroy;
begin
  //if FField2 <> nil then FreeAndNil(FField2);
  inherited Destroy;
end;


// �������� � ����� ����� ������� (SQL)
{
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
}




// �������� � ����� ����� ������� (SQL)
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
    // ��� ���������� �������
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

// ������ ���������� ����� ��� ALTER
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

// ������ ���� ����� ������
procedure Read1Rec(Rec: TFields);
var
  j: Integer;
  v: Variant;
begin
  for j := 0 to Rec.Count - 1 do begin
    v := Rec[j].Value;
  end;
end;

// ������ ���� ����� ������ � ���������� ������
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
      // �� ����� ��� �� NULL
        FI := TFieldsInf(FInf[j]);
        if (FI.FieldType in ADS_DATES) then begin
          //t := Rec[j].Value;
          t := v;
          Year := YearOf(t);
          if (Year <= 1) or (Year > 2100) then
            raise Exception.Create(EMSG_BAD_DATA);
          if (FI.FieldType = ADS_TIMESTAMP) then begin
            Ms := (DateTimeToTimeStamp(t)).Time;
            if (Ms < 0) or (Ms > MSEC_PER_DAY) then
              raise Exception.Create(EMSG_BAD_DATA);
          end
        end;
      end;

    except
      Result := j;
      Break;
    end;
  end;

end;

// ������� ���������������� � ������ ������� ������� �������
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
          // 10 ������� ������� ��������� MAX_READ_MEDIUM
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


// ���������� ������� � ������� (SQL)
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

// ������������ ����� ������� �� ������
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
        // ���� ���������� �������
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

  except
    on E: EADSDatabaseError do begin
      Result := E.ACEErrorCode;
      AdsTI.ErrInfo.ErrClass := E.ACEErrorCode;
      AdsTI.ErrInfo.NativeErr := E.SQLErrorCode;
      AdsTI.ErrInfo.MsgErr := E.Message;
    end;
  end;

end;


end.
