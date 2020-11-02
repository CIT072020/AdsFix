unit AdsDAO;

interface

uses
  SysUtils, Classes, adsset, adscnnct, DB, adsdata, adsfunc, adstable, ace,
  kbmMemTable, ServiceProc;


  //FXDP_DEL_ALL : Integer = 1;
  //FXDP_1_ASIS  : Integer = 2;
  //FXDP_1_MRG   : Integer = 3;

  // ���� ����� ADS
type
 TAdsFTypes = set of 0..ADS_MAX_FIELD_TYPE;

const
  ADS_BOOL    : TAdsFTypes = [
    ADS_LOGICAL];
  ADS_STRINGS : TAdsFTypes = [
    ADS_STRING,
    ADS_VARCHAR,
    ADS_CISTRING,
    ADS_MEMO,
    ADS_NCHAR,
    ADS_NVARCHAR,
    ADS_NMEMO,
    ADS_VARCHAR_FOX];
  ADS_NUMBERS : TAdsFTypes = [
    ADS_NUMERIC,
    ADS_DOUBLE,
    ADS_INTEGER,
    ADS_SHORTINT,
    ADS_AUTOINC,
    ADS_CURDOUBLE,
    ADS_MONEY,
    ADS_LONGLONG,
    ADS_ROWVERSION];
  ADS_DATES : TAdsFTypes = [
    ADS_DATE,
    ADS_COMPACTDATE,
    ADS_TIME,
    ADS_TIMESTAMP,
    ADS_MODTIME];
  ADS_BIN : TAdsFTypes = [
    ADS_BINARY,
    ADS_IMAGE,
    ADS_RAW,
    ADS_VARBINARY_FOX,
    ADS_SYSTEM_FIELD];

type
  ITest = interface
  end;

type
  // ������ ������ ��� ��������������
  TSrcTableList = class
    IsDict : Boolean;
    Path2Src : String;
    Path2Tmp : String;
    AllT     : TkbmMemTable;
  end;

type
  // ������ ������ ��� �������������� �� ���� ADS-Dictionary
  TSrcDic = class(TSrcTableList)
  private
    FSrcDict : string;
    FUName : string;
    FPass : string;
  public
    property SrcDict : string read FSrcDict write FSrcDict;
  end;


type
  // �������� ������ � ������ ����������
  TDupRow = class
    RowID : string;
    FillPcnt : Integer;
    DelRow : Boolean;
  end;

  TFixAds = class
  end;

type
  TdtmdlADS = class(TDataModule)
    conAdsBase: TAdsConnection;
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

    cnABTmp: TAdsConnection;
    qDst: TAdsQuery;
    qSrcFields: TAdsQuery;
    qSrcIndexes: TAdsQuery;
    qDupGroups: TAdsQuery;
    tblTmp: TAdsTable;
    procedure DataModuleCreate(Sender: TObject);
  private
    { Private declarations }
    FSysAlias : string;
  public
    { Public declarations }
    property SYSTEM_ALIAS : string read FSysAlias write FSysAlias;

    procedure AdsConnect(Path2Dic, Login, Password: string);
  end;





type
  TAdsList = class
  private
    FPars    : TAppPars;
    FSrcPath : string;
    FAdsConn : TAdsConnection;
    FTblList : TkbmMemTable;
    FTCount  : Integer;
  protected
  public
    property Pars : TAppPars read FPars write FPars;
    property Path2Src : string read FSrcPath write FSrcPath;
    property SrcList : TkbmMemTable read FTblList write FTblList;
    property Conn : TAdsConnection read FAdsConn write FAdsConn;
    property TablesCount : Integer read FTCount write FTCount;

    function List4Fix(AppPars : TAppPars) : Integer; virtual; abstract;

    constructor Create(Cnct : TAdsConnection = nil);
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
    function List4Fix(AppPars : TAppPars) : Integer; override;
  published
  end;

  // ������ �������� ������ � �����
  TFreeList = class(TAdsList)
  private
    function PathAvail : Boolean;
    function TablesListFromPath(QA: TAdsQuery): Integer;
  protected
  public
    function List4Fix(AppPars : TAppPars) : Integer; override;
  published
  end;

//---
function SetSysAlias(QV : TAdsQuery) : string;
function PrepareList(Path2Dic: string) : Integer;
procedure SortByState(SetNow : Boolean);

var
  dtmdlADS: TdtmdlADS;
  //SrcList : TSrcTableList;

implementation

uses
  Controls,
  StrUtils,
  FileUtil,
  FixDups, AuthF;
{$R *.dfm}

// ���������� �������� /ANSI_ (������� � ������ 10)
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


constructor TAdsList.Create(Cnct : TAdsConnection = nil);
begin
  inherited Create;
  if (Assigned(Cnct)) then
    Conn := Cnct
  else
    Conn := dtmdlADS.conAdsBase;
  SrcList := dtmdlADS.mtSrc;
end;


destructor TAdsList.Destroy;
begin
  inherited Destroy;
end;


// �������� ������������ �����������
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
      Conn.IsConnected := False;
      Conn.Username := Pars.ULogin;
      Conn.Password := Pars.UPass;
      Conn.ConnectPath := Pars.Src;
      Conn.IsConnected := True;
      Result := True;
    except
      Pars.ULogin := USER_EMPTY;
    end;
  end;
end;

// ������ ������ - � MemTable
function TDictList.TablesListFromDict(QA: TAdsQuery): Integer;
var
  i: Integer;
  s: string;
  TblCapts: TStringList;
begin
  i := 0;
  with QA do begin
    //ClearTablesList(QA.Owner);
    dtmdlADS.mtSrc.Close;
    dtmdlADS.mtSrc.Active := True;

    First;
    while not Eof do begin
      i := i + 1;
      dtmdlADS.mtSrc.Append;

      dtmdlADS.FSrcNpp.AsInteger  := i;
      dtmdlADS.FSrcMark.AsBoolean := False;
      dtmdlADS.FSrcTName.AsString := FieldByName('NAME').AsString;
      try
        TblCapts := Split('.', FieldByName('COMMENT').AsString);
        s := TblCapts[TblCapts.Count - 1];
      except
        s := '';
      end;
      if (Length(s) = 0) then
        s := '<' + dtmdlADS.FSrcTName.AsString + '>';

      dtmdlADS.FSrcTCaption.AsString := s;
      dtmdlADS.FSrcTestCode.AsInteger := 0;
      dtmdlADS.FSrcState.AsInteger := TST_UNKNOWN;
      dtmdlADS.FSrcFixInf.AsInteger := 0;

      dtmdlADS.mtSrc.Post;
      Next;
    end;
  end;
  Result := i;
end;

// ���������� ������ ������ ��� ��������������
function TDictList.List4Fix(AppPars : TAppPars) : Integer;
begin
  Pars := AppPars;
  if (DictAvail = True) then begin
    Pars.SysAdsPfx := SetSysAlias(dtmdlADS.qAny);
    with dtmdlADS.qTablesAll do begin
      Active := false;
      AdsCloseSQLStatement;
      SQL.Clear;
      SQL.Add('SELECT * FROM ' + Pars.SysAdsPfx + 'TABLES');
      Active := true;
    end;
    TablesCount := TablesListFromDict(dtmdlADS.qTablesAll);
    Path2Src := ExtractFilePath(Pars.Src);
    Pars.Path2Src := Path2Src;

    Pars.TotTbls := TablesCount;
    if (TablesCount = 0 ) then
      Result := UE_NO_ADS
    else
      Result := 0;
  end
  else
    Result := UE_BAD_USER;
end;

function TFreeList.PathAvail : Boolean;
begin
  Result := True;
end;

function TFreeList.TablesListFromPath(QA: TAdsQuery): Integer;
begin
  Result := 0;
end;

// ���������� ������ �������� ������ ��� ��������������
function TFreeList.List4Fix(AppPars : TAppPars) : Integer;
begin
  Pars := AppPars;
  if (PathAvail = True) then begin
    Pars.SysAdsPfx := SetSysAlias(dtmdlADS.qAny);
    TablesCount := TablesListFromPath(dtmdlADS.qTablesAll);
    Pars.TotTbls := TablesCount;
    if (TablesCount = 0 ) then
      Result := UE_NO_ADS
    else
      Result := 0;
  end
  else
    Result := UE_BAD_PATH;
end;

// ��������� ���������� ������ ������ �� �������
procedure SortByState(SetNow : Boolean);
begin
  if (SetNow = True) then
    dtmdlADS.mtSrc.IndexName := IDX_SRC
  else
    dtmdlADS.mtSrc.IndexName := '';
end;


// ��������� ���������� ������ ������ �� �������
procedure TdtmdlADS.DataModuleCreate(Sender: TObject);
begin
  dtmdlADS.mtSrc.AddIndex(IDX_SRC, 'State', [ixDescending]);
  SortByState(True);
end;

//
procedure TdtmdlADS.AdsConnect(Path2Dic, Login, Password: string);
begin
    //������������ � ����
  dtmdlADS.conAdsBase.IsConnected := False;
  dtmdlADS.conAdsBase.Username    := Login;
  dtmdlADS.conAdsBase.Password    := Password;
  dtmdlADS.conAdsBase.ConnectPath := Path2Dic;
  dtmdlADS.conAdsBase.IsConnected := True;
end;

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


// ������ ������ - � MemTable
function TablesListFromDic(QA: TAdsQuery): Integer;
var
  i: Integer;
  s: string;
  TblCapts: TStringList;
begin
  i := 0;
  with QA do begin
    //ClearTablesList(QA.Owner);
    dtmdlADS.mtSrc.Close;
    dtmdlADS.mtSrc.Active := True;

    First;
    while not Eof do begin
      i := i + 1;
      dtmdlADS.mtSrc.Append;

      dtmdlADS.FSrcNpp.AsInteger  := i;
      dtmdlADS.FSrcMark.AsBoolean := False;
      dtmdlADS.FSrcTName.AsString := FieldByName('NAME').AsString;
      try
        TblCapts := Split('.', FieldByName('COMMENT').AsString);
        s := TblCapts[TblCapts.Count - 1];
      except
        s := '';
      end;
      if (Length(s) = 0) then
        s := '<' + dtmdlADS.FSrcTName.AsString + '>';

      dtmdlADS.FSrcTCaption.AsString := s;
      dtmdlADS.FSrcTestCode.AsInteger := 0;
      dtmdlADS.FSrcState.AsInteger := TST_UNKNOWN;
      dtmdlADS.FSrcFixInf.AsInteger := 0;

      dtmdlADS.mtSrc.Post;
      Next;
    end;
  end;
  Result := i;
end;



function PrepareList(Path2Dic: string) : Integer;
//var
  //aPars: AParams;
begin
  Result := 0;
  if (AppPars.IsDict = True) then begin
    // Through dictionary
    if (dtmdlADS.conAdsBase.IsConnected = False) then
      dtmdlADS.conAdsBase.IsConnected := True;
    AppPars.SysAdsPfx := SetSysAlias(dtmdlADS.qAny);
    with dtmdlADS.qTablesAll do begin
      Active := false;
      AdsCloseSQLStatement;
      SQL.Clear;
      SQL.Add('SELECT * FROM ' + dtmdlADS.SYSTEM_ALIAS + 'TABLES');
      Active := true;
    end;
    AppPars.TotTbls := TablesListFromDic(dtmdlADS.qTablesAll);
    Result := AppPars.TotTbls;
  end
  else begin
    // Free tables

  end;

end;

end.
