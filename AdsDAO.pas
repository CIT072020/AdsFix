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
    cnnTmp: TAdsConnection;
    qDst: TAdsQuery;
    qSrcFields: TAdsQuery;
    qSrcIndexes: TAdsQuery;
    qDupGroups: TAdsQuery;
    tblTmp: TAdsTable;
    dsPlan: TDataSource;
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
    FAdsConn : TAdsConnection;
    FWorkQuery : TAdsQuery;

    FTblList : TkbmMemTable;
    FTCount  : Integer;
    FFilled  : Boolean;

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

    // ������������ ����� ADS-�������
    function TestOneAds(TblPtr : Integer; TMode : TestMode; var ErrCode : Integer) : TTableInf; virtual; abstract;

    // ������������ ���� ��� ������ ����������
    procedure TestSelected(TMode : TestMode; ModeAll : Boolean = True);  virtual;

    constructor Create(APars : TFixPars; AllTables: TkbmMemTable; Cnct : TAdsConnection = nil);
    destructor Destroy; override;
  published

  end;

  // ������ ������ �� ���� ������� ADS
  TDictList = class(TAdsList)
  private
    function DictAvail : Boolean;
    function TablesListFromDict(QA: TAdsQuery): Integer;
  protected
  public
    // ������� ������ ������ �� ���� ������� ADS
    function FillList4Fix(TableName : string = '') : Integer; override;
    function TestOneAds(TblPtr : Integer; TMode : TestMode; var ErrCode : Integer) : TTableInf; override;
  published
  end;

  // ������ ��������� ������ � �����
  TFreeList = class(TAdsList)
  private
    function PathAvail : Boolean;
    function TablesListFromPath(QA: TAdsQuery): Integer;
  protected
  public
    // ������� ������ �������� ������
    function FillList4Fix(TableName : string = '') : Integer; override;
    function TestOneAds(TblPtr : Integer; TMode : TestMode; var ErrCode : Integer) : TTableInf; override;
  published
  end;

//---
// ���������� �������� /ANSI_ (������� � ������ 10)
function SetSysAlias(QV : TAdsQuery) : string;

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


constructor TAdsList.Create(APars : TFixPars; AllTables: TkbmMemTable; Cnct : TAdsConnection = nil);
begin
  inherited Create;
  Pars := APars;
  SrcList := AllTables;
  if (Assigned(Cnct)) then
    SrcConn := Cnct
  else
    SrcConn := dtmdlADS.cnnSrcAds;

  Filled  := False;
  FWorkQuery := TAdsQuery.Create(SrcConn.Owner);
  FWorkQuery.AdsConnection := SrcConn;

end;

destructor TAdsList.Destroy;
var
  pTInf: Integer;
  SrcTbl: TTableInf;
begin
  //FreeAndNil(SrcTbl);
  with SrcList do begin
    First;
    while not Eof do begin
      pTInf := FieldByName('TableInf').AsInteger;
      if (pTInf <> 0) then begin
        SrcTbl := TTableInf(Ptr(pTInf));
        FreeAndNil(SrcTbl);
      end;
      Next;
    end;
  end;
  SrcList.EmptyTable;
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
  FName, s: string;
  TblCapts: TStringList;
begin
  i := 0;
  SrcList.Close;
  SrcList.Active := True;
  with QA do begin
    First;
    while not Eof do begin
      FName := FieldByName('NAME').AsString;
      if (FileExists(Pars.Path2Src + FName + '.adt') = True) then begin
        i := i + 1;
        SrcList.Append;

        SrcList.FieldValues['Npp'] := i;
        SrcList.FieldValues['IsMark'] := False;
        SrcList.FieldValues['TableName'] := FName;
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
        SrcList.FieldValues['TableInf']     := Integer(TDictTable.Create(FieldByName('NAME').AsString, i, SrcConn, Pars));
        SrcList.FieldValues['FixLog']       := '';

        SrcList.Post;
      end;
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
    Pars.SysAdsPfx := SetSysAlias(FWorkQuery);
    if (TableName <> '') then
      TableName := Format(' WHERE (NAME=''%s'')', [TableName]);
    with FWorkQuery do begin
      Active := false;
      AdsCloseSQLStatement;
      SQL.Clear;
      SQL.Add('SELECT * FROM ' + Pars.SysAdsPfx + 'TABLES' + TableName);
      Active := true;
    end;
    TablesCount := TablesListFromDict(FWorkQuery);
    if (TablesCount = 0 ) then
      Result := UE_NO_ADS
    else begin
      Result := UE_OK;
      Filled := True;
    end;
    SrcConn.IsConnected := False;
  end else
    Result := UE_BAD_USER;
end;

// ������������ ����� (Dictionary)
function TDictList.TestOneAds(TblPtr : Integer; TMode : TestMode; var ErrCode : Integer) : TTableInf;
begin
  Result := TDictTable(Ptr(TblPtr));
  ErrCode := Result.Test1Table(FWorkQuery, TMode, FPars.SysAdsPfx);
end;

// ������������ ����� (Free)
function TFreeList.TestOneAds(TblPtr : Integer; TMode : TestMode; var ErrCode : Integer) : TTableInf;
var
  FT : TFreeTable;
begin
  FT := TFreeTable(Ptr(TblPtr));
  ErrCode := FT.Test1Table(FWorkQuery, TMode);
  Result := FT;
end;


// ������������ ���� ��� ������ ����������
procedure TAdsList.TestSelected(TMode : TestMode; ModeAll : Boolean = True);
var
  StateByTest,
  ErrCode, i: Integer;
  s: string;
  SrcTbl : TTableInf;
begin
  i := 0;
  if (Filled = True) then begin
    with SrcList do begin
      First;
      FPars.Logger.Add2Log('����� ������������ ��������� ������');
      ErrTested := 0;
      while not Eof do begin
        if ((FieldValues['State'] = TST_UNKNOWN) AND (ModeAll = True))
          OR ((FieldValues['IsMark'] = True) AND (ModeAll = False)) then begin
          // ��� ������������� ��� ����������
          i := i + 1;
          Edit;
          SrcTbl := TestOneAds(FieldValues['TableInf'], TMode, ErrCode);
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
  end;
  Tested := i;
  FPars.Logger.Add2Log(Format('����� ���������: %d, � ��������: %d',[Tested, ErrTested]));
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
    Pars.SysAdsPfx := SetSysAlias(FWorkQuery);
    //FWorkQuery.AdsCloseSQLStatement;
    FWorkQuery.SQL.Clear;
    FWorkQuery.SQL.Add('SELECT * FROM (EXECUTE PROCEDURE sp_GetTables(NULL,NULL,' + wich + ', ''TABLE'')) AS tmpAllT;');
    FWorkQuery.Active := True;

    TablesCount := TablesListFromPath(FWorkQuery);
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

end.
