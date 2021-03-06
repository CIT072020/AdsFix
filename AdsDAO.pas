unit AdsDAO;

interface

uses
  SysUtils, Classes, adsset, adscnnct, DB,
  adsdata, adsfunc, adstable, ace,
  kbmMemTable,
  uTableUtils,
  uServiceProc;

type
  TdtmdlADS = class(TDataModule)
    cnnSrcAds: TAdsConnection;
    tblAds: TAdsTable;
    dsSrc: TDataSource;
    qTablesAll: TAdsQuery;
    qAny: TAdsQuery;

    mtSrc: TkbmMemTable;
    FSrcNpp: TIntegerField;
    FSrcMark: TBooleanField;
    FSrcTName: TStringField;
    FSrcTestCode: TIntegerField;
    FSrcTCaption: TStringField;
    FSrcState: TIntegerField;
    FSrcFixCode: TIntegerField;
    FSrcAIncs: TIntegerField;
    FSrcErrNative: TIntegerField;
    FSrcFixInf: TIntegerField;
    cnnTmp: TAdsConnection;
    qDst: TAdsQuery;
    qSrcFields: TAdsQuery;
    qSrcIndexes: TAdsQuery;
    qDupGroups: TAdsQuery;
    tblTmp: TAdsTable;
    dsPlan: TDataSource;
    FSrcFixLog: TMemoField;
    procedure DataModuleCreate(Sender: TObject);
  private
    FSysAlias : string;
  public
    property SYSTEM_ALIAS : string read FSysAlias write FSysAlias;
  end;

//------------------

const
  // ���������� ������ ������
  IDX_SRC     : String = 'OnState';

type

  // ������ �������� ADS-������ ��� �������� [� ��������������]
  TAdsList = class
  private
    FPars    : TFixPars;
    //FSrcPath : string;
    FAdsConn : TAdsConnection;
    FTblList : TkbmMemTable;
    FTCount  : Integer;
    FFilled  : Boolean;

    function TestOneAds(TblPtr : Integer; TMode : TestMode; var AdsTbl : TTableInf) : Integer; virtual; abstract;
  protected
  public
    Tested : Integer;
    // �� ������ ����
    ErrTested : Integer;
    property Pars : TFixPars read FPars write FPars;
    // MemTable �� �������
    property SrcList : TkbmMemTable read FTblList write FTblList;
    property SrcConn : TAdsConnection read FAdsConn write FAdsConn;
    property TablesCount : Integer read FTCount write FTCount;
    property Filled : Boolean read FFilled write FFilled;

    // ������� ������ ������ ADS
    function FillList4Fix(TableName : string = '') : Integer; virtual; abstract;

    // ������������ ���� ��� ������ ����������
    procedure TestSelected(ModeAll : Boolean; TMode : TestMode);  virtual;

    constructor Create(APars : TFixPars; Cnct : TAdsConnection = nil);
    destructor Destroy; override;
  published

  end;

  // ������ ������ �� ���� ������� ADS
  TDictList = class(TAdsList)
  private
    function DictAvail : Boolean;
    function TablesListFromDict(QA: TAdsQuery): Integer;
    function TestOneAds(TblPtr : Integer; TMode : TestMode; var AdsTbl : TTableInf) : Integer; override;
  protected
  public
    // ������� ������ ������ �� ���� ������� ADS
    function FillList4Fix(TableName : string = '') : Integer; override;
  published
  end;

  // ������ ��������� ������ � �����
  TFreeList = class(TAdsList)
  private
    function PathAvail : Boolean;
    function TablesListFromPath(QA: TAdsQuery): Integer;
    function TestOneAds(TblPtr : Integer; TMode : TestMode; var AdsTbl : TTableInf) : Integer; override;
  protected
  public
    // ������� ������ �������� ������
    function FillList4Fix(TableName : string = '') : Integer; override;
  published
  end;

//---
// ���������� �������� /ANSI_ (������� � ������ 10)
function SetSysAlias(QV : TAdsQuery) : string;
// ���������/����� ���������� ������ ������ �� �������
procedure SortByState(SetNow : Boolean);

var
  dtmdlADS: TdtmdlADS;

implementation

uses
  Controls,
  StrUtils,
  FileUtil,
  uFixDups,
  AuthF;
{$R *.dfm}

// ���������/����� ���������� ������ ������ �� �������
procedure SortByState(SetNow : Boolean);
begin
  if (SetNow = True) then
    dtmdlADS.mtSrc.IndexName := IDX_SRC
  else
    dtmdlADS.mtSrc.IndexName := '';
end;


// ���������� ���������� ������ ������ �� �������
procedure TdtmdlADS.DataModuleCreate(Sender: TObject);
begin
  dtmdlADS.mtSrc.AddIndex(IDX_SRC, 'State', [ixDescending]);
  SortByState(True);
end;

// ���������� �������� /ANSI_ (������� � ������ 10)
// ��� ��������� ������ ADS
function SetSysAlias(QV: TAdsQuery): string;
begin
  Result := 'SYSTEM.';
  try
    with QV do begin
      try
        Active := False;
        SQL.Text := 'EXECUTE PROCEDURE sp_mgGetInstallInfo()';
        Active := True;
        if (Pos('.', FieldByName('Version').AsString) >= 3) then
          Result := Result + 'ANSI_';
      except
      end;
    end;
  finally
    dtmdlADS.SYSTEM_ALIAS := Result;
  end;
end;


constructor TAdsList.Create(APars : TFixPars; Cnct : TAdsConnection = nil);
begin
  inherited Create;
  Pars := APars;
  if (Assigned(Cnct)) then
    SrcConn := Cnct
  else
    SrcConn := dtmdlADS.cnnSrcAds;
  SrcList := dtmdlADS.mtSrc;
  Filled  := False;
end;

destructor TAdsList.Destroy;
begin
  inherited Destroy;
end;


// �������� ������������ ����������� � ��������� ����
function TDictList.DictAvail : Boolean;
var
  aUser: AParams;
begin
  Result := False;
  if (Pars.ULogin = USER_EMPTY) then begin
    // ������������ ��� �� ��������, ����� USER/PASS
    FormAuth := TFormAuth.Create(nil);
    aUser[0] := USER_DFLT;
    aUser[1] := PASS_DFLT;
    FormAuth.InitPars(aUser); //
    try
      if (FormAuth.ShowModal = mrOk) then begin
        FormAuth.SetResult(Pars.ULogin, Pars.UPass);
      end;
    finally
      FormAuth.Free;
      FormAuth := nil;
    end;
  end;
  if (Pars.ULogin <> USER_EMPTY) then begin
    try
    //������������ � ����
      SrcConn.IsConnected := False;
      SrcConn.Username    := Pars.ULogin;
      SrcConn.Password    := Pars.UPass;
      SrcConn.ConnectPath := Pars.Src;
      SrcConn.Connect;
      Result := SrcConn.IsConnected;
    except
      Pars.ULogin := USER_EMPTY;
    end;
  end;
end;

// ������ ������ �� ������� - � MemTable
function TDictList.TablesListFromDict(QA: TAdsQuery): Integer;
var
  i: Integer;
  s: string;
  TblCapts: TStringList;
begin
  i := 0;
  SrcList.Close;
  SrcList.Active := True;
  with QA do begin
    First;
    while not Eof do begin
      i := i + 1;
      SrcList.Append;

      SrcList.FieldValues['Npp']       := i;
      SrcList.FieldValues['IsMark']    := False;
      SrcList.FieldValues['TableName'] := FieldByName('NAME').AsString;
      try
        TblCapts := Split('.', FieldByName('COMMENT').AsString);
        s := TblCapts[TblCapts.Count - 1];
      except
        s := '';
      end;
      if (Length(s) = 0) then
        s := '<' + FieldByName('NAME').AsString + '>';

      SrcList.FieldValues['TableCaption'] := s;
      SrcList.FieldValues['TestCode']     := 0;
      SrcList.FieldValues['ErrNative']    := 0;
      SrcList.FieldValues['AIncs']        := 0;
      SrcList.FieldValues['FixCode']      := 0;
      SrcList.FieldValues['State']        := TST_UNKNOWN;
      //SrcList.FieldValues['TableInf']     := 0;
      SrcList.FieldValues['TableInf']     := Integer(TDictTable.Create(FieldByName('NAME').AsString, i, SrcConn, Pars));
      SrcList.FieldValues['FixLog']       := '';

      SrcList.Post;
      Next;
    end;
  end;
  Result := i;
end;

// ���������� ���������� ������ ������ ��� ��������������
function TDictList.FillList4Fix(TableName : string = '') : Integer;
begin
  Filled  := False;
  if (DictAvail = True) then begin
    Pars.SysAdsPfx := SetSysAlias(dtmdlADS.qAny);
    if (TableName <> '') then
      TableName := Format(' WHERE (NAME=''%s'')', [TableName]);
    with dtmdlADS.qTablesAll do begin
      Active := false;
      AdsCloseSQLStatement;
      SQL.Clear;
      SQL.Add('SELECT * FROM ' + Pars.SysAdsPfx + 'TABLES' + TableName);
      Active := true;
    end;
    TablesCount := TablesListFromDict(dtmdlADS.qTablesAll);
    if (TablesCount = 0 ) then
      Result := UE_NO_ADS
    else begin
      Result := UE_OK;
      Filled := True;
    end;
    SrcConn.IsConnected := False;
  end
  else
    Result := UE_BAD_USER;
end;

// ������������ ����� (Dictionary)
function TDictList.TestOneAds(TblPtr : Integer; TMode : TestMode; var AdsTbl : TTableInf) : Integer;
var
  DT : TDictTable;
begin
  DT     := TDictTable(Ptr(TblPtr));
  AdsTbl := DT;
  Result := DT.Test1Table(DT, TMode, FPars.SysAdsPfx);
end;

// ������������ ����� (Free)
function TFreeList.TestOneAds(TblPtr : Integer; TMode : TestMode; var AdsTbl : TTableInf) : Integer;
var
  FT : TFreeTable;
begin
  FT := TFreeTable(Ptr(TblPtr));
  AdsTbl := FT;
  Result := FT.Test1Table(FT, TMode);
end;


// ������������ ���� ��� ������ ����������
procedure TAdsList.TestSelected(ModeAll : Boolean; TMode : TestMode);
var
  StateByTest,
  ErrCode, i: Integer;
  SrcTbl : TTableInf;
begin
    with SrcList do begin
      First;
      i := 0;
      ErrTested := 0;
      while not Eof do begin
        if ((FieldValues['State'] = TST_UNKNOWN) AND (ModeAll = True))
          OR ((FieldValues['IsMark'] = True) AND (ModeAll = False)) then begin
          // ��� ������������� ��� ����������
          i := i + 1;
          Edit;
          ErrCode := TestOneAds(FieldValues['TableInf'], TMode, SrcTbl);
          FieldValues['AIncs']    := SrcTbl.FieldsAI.Count;
          FieldValues['TestCode'] := ErrCode;
          if (ErrCode > 0) then begin
            FieldValues['IsMark']    := True;
            FieldValues['ErrNative'] := SrcTbl.ErrInfo.NativeErr;
            FieldValues['FixLog']    := FieldValues['FixLog'] + SrcTbl.ErrInfo.MsgErr;
            StateByTest := TST_ERRORS;
            ErrTested := ErrTested + 1;
          end
          else begin
            FieldValues['IsMark'] := False;
            StateByTest := TST_GOOD;
            end;
          FieldValues['State'] := StateByTest;
          Post;
        end;
        Next;
      end;
      First;
    end;
    Tested := i;
    SrcConn.IsConnected := False;
end;

// ����������� � ����� � Free tables
function TFreeList.PathAvail: Boolean;
begin
  SrcConn.IsConnected := False;
  SrcConn.ConnectPath := Pars.Path2Src;
  SrcConn.Connect;
  Result := SrcConn.IsConnected;
end;

function TFreeList.TablesListFromPath(QA: TAdsQuery): Integer;
var
  i: Integer;
  s: string;
begin
  i := 0;
  SrcList.Close;
  SrcList.Active := True;
  with QA do begin
    First;
    while not Eof do begin
      i := i + 1;
      SrcList.Append;
      SrcList.FieldValues['Npp']          := i;
      SrcList.FieldValues['IsMark']       := False;
      SrcList.FieldValues['TableName']    := FieldByName('TABLE_NAME').AsString;
      SrcList.FieldValues['TableCaption'] := '<' + FieldByName('TABLE_NAME').AsString + '>';
      SrcList.FieldValues['TestCode']     := 0;
      SrcList.FieldValues['ErrNative']    := 0;
      SrcList.FieldValues['AIncs']        := 0;
      SrcList.FieldValues['FixCode']      := 0;
      SrcList.FieldValues['State']        := TST_UNKNOWN;
      SrcList.FieldValues['TableInf']     := Integer(TFreeTable.Create(FieldByName('TABLE_NAME').AsString, i, SrcConn, Pars));
      SrcList.FieldValues['FixLog']       := '';
      SrcList.Post;
      Next;
    end;
  end;
  Result := i;
end;


// ���������� ������ �������� ������ ��� ��������������
function TFreeList.FillList4Fix(TableName : string = '') : Integer;
var
  wich : string;
begin
  Filled := False;
  if (PathAvail = True) then begin
    if (TableName = '') then
      wich := 'NULL'
    else
      wich := '''' + TableName + '''';
    Pars.SysAdsPfx := SetSysAlias(dtmdlADS.qAny);
    dtmdlADS.qTablesAll.AdsCloseSQLStatement;
    dtmdlADS.qTablesAll.SQL.Clear;
    dtmdlADS.qTablesAll.SQL.Add('SELECT * FROM (EXECUTE PROCEDURE sp_GetTables(NULL,NULL,' + wich + ', ''TABLE'')) AS tmpAllT;');
    dtmdlADS.qTablesAll.Active := True;

    TablesCount := TablesListFromPath(dtmdlADS.qTablesAll);
    if (TablesCount = 0 ) then
      Result := UE_NO_ADS
    else begin
      Result := UE_OK;
      Filled := True;
    end;
  end
  else
    Result := UE_BAD_PATH;
    SrcConn.IsConnected := False;
end;

// ������������ ���� ��� ������ ����������
{
procedure TFreeList.TestSelected(ModeAll : Boolean; TMode : TestMode);
var
  ec, i: Integer;
  TableInf : TFreeTable;
begin

    with SrcList do begin

      First;
      i := 0;
      while not Eof do begin
        i := i + 1;
        if ((dtmdlADS.FSrcState.AsInteger = TST_UNKNOWN) AND (ModeAll = True))
          OR ((dtmdlADS.FSrcMark.AsBoolean = True) AND (ModeAll = False)) then begin
          // ��� ������������� ��� ����������
          Edit;

          TableInf := TFreeTable.Create(dtmdlADS.FSrcTName.AsString, dtmdlADS.FSrcNpp.AsInteger, dtmdlADS.cnnSrcAds, Pars);
          dtmdlADS.FSrcFixInf.AsInteger := Integer(TableInf);

          ec := TableInf.Test1Table(TableInf, TMode);
          dtmdlADS.FSrcAIncs.AsInteger := TableInf.FieldsAI.Count;
          dtmdlADS.FSrcTestCode.AsInteger := ec;
          if (ec > 0) then begin
            dtmdlADS.FSrcMark.AsBoolean := True;
            dtmdlADS.FSrcErrNative.AsInteger := TableInf.ErrInfo.NativeErr;
            ec := TST_ERRORS;
          end
          else begin
            dtmdlADS.FSrcMark.AsBoolean := False;
            ec := TST_GOOD;
            end;
          dtmdlADS.FSrcState.AsInteger := ec;

          Post;
        end;
        Next;
      end;
      First;

    end;
    SrcList.EnableControls;
    SrcConn.IsConnected := False;
end;
}

{
procedure ClearTablesList(Owner : TComponent);
var
  iM,
  i : Integer;
begin
  iM := Owner.ComponentCount;
  // ������� ��� ������� �������� ������
  for i := 0 to Owner.ComponentCount -1 do
    if ( Pos(CMPNT_NAME, Owner.Components[i].Name) > 0 ) then begin
      TAdsTable(Owner.Components[i]).Close;
      Owner.Components[i].Free;
    end;
end;
}


end.
