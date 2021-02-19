unit AdsDAO;

interface

uses
  SysUtils, Classes, adsset, adscnnct, DB, adsdata, adsfunc, adstable, ace,
  kbmMemTable, ServiceProc;

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
    procedure DataModuleCreate(Sender: TObject);
  private
    FSysAlias : string;
  public
    property SYSTEM_ALIAS : string read FSysAlias write FSysAlias;
  end;

//------------------

const
  // сортировка списка таблиц
  IDX_SRC     : String = 'OnState';

type

  // Список исходных ADS-таблиц для проверки [и восстановления]
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
    // путь к словарю/таблице
    property Path2Src : string read FSrcPath write FSrcPath;
    // MemTable со списком
    property SrcList : TkbmMemTable read FTblList write FTblList;
    property Conn : TAdsConnection read FAdsConn write FAdsConn;
    property TablesCount : Integer read FTCount write FTCount;

    function List4Fix(AppPars : TAppPars) : Integer; virtual; abstract;
    // Тестирование всех или только отмеченных
    procedure TestSelected(ModeAll : Boolean; TMode : TestMode);  virtual; abstract;

    constructor Create(Cnct : TAdsConnection = nil);
    destructor Destroy; override;
  published

  end;

  // Список таблиц на базе словаря ADS
  TDictList = class(TAdsList)
  private
    FDictPath : string;

    function DictAvail : Boolean;
    function TablesListFromDict(QA: TAdsQuery): Integer;
  protected
  public
    property DictFullPath : string read FDictPath write FDictPath;

    // Создать список таблиц на базе словаря ADS
    function List4Fix(AppPars : TAppPars) : Integer; override;
    // Тестирование всех или только отмеченных
    procedure TestSelected(ModeAll : Boolean; TMode : TestMode);override;
  published
  end;

  // Список свободных таблиц в папке
  TFreeList = class(TAdsList)
  private
    function PathAvail : Boolean;
    function TablesListFromPath(QA: TAdsQuery): Integer;
  protected
  public
    // Создать список свбодных таблиц
    function List4Fix(AppPars : TAppPars) : Integer; override;
    // Тестирование всех или только отмеченных
    procedure TestSelected(ModeAll : Boolean; TMode : TestMode); override;
  published
  end;


//---
function SetSysAlias(QV : TAdsQuery) : string;
procedure SortByState(SetNow : Boolean);

var
  dtmdlADS: TdtmdlADS;

implementation

uses
  Controls,
  StrUtils,
  FileUtil,
  TableUtils,
  FixDups, AuthF;
{$R *.dfm}

// установка сортировки списка таблиц по статусу
procedure SortByState(SetNow : Boolean);
begin
  if (SetNow = True) then
    dtmdlADS.mtSrc.IndexName := IDX_SRC
  else
    dtmdlADS.mtSrc.IndexName := '';
end;


// установка сортировки списка таблиц по статусу
procedure TdtmdlADS.DataModuleCreate(Sender: TObject);
begin
  dtmdlADS.mtSrc.AddIndex(IDX_SRC, 'State', [ixDescending]);
  SortByState(True);
end;

// добавление префикса /ANSI_ (начиная с версия 10)
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
    Conn := dtmdlADS.cnnSrcAds;
  SrcList := dtmdlADS.mtSrc;
end;


destructor TAdsList.Destroy;
begin
  inherited Destroy;
end;

// Проверка корректности подключения к словарной базе
function TDictList.DictAvail : Boolean;
var
  aUser: AParams;
begin
  Result := False;
  if (Pars.ULogin = USER_EMPTY) then begin
    // Подключаться еще не пытались, нужна USER/PASS
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
    //подключаемся к базе
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

// Список таблиц из словаря - в MemTable
function TDictList.TablesListFromDict(QA: TAdsQuery): Integer;
var
  i: Integer;
  s: string;
  TblCapts: TStringList;
begin
  i := 0;
  with QA do begin
    SrcList.Close;
    SrcList.Active := True;

    First;
    while not Eof do begin
      i := i + 1;
      SrcList.Append;

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

      SrcList.Post;
      Next;
    end;
  end;
  Result := i;
end;

// Построение словарного списка таблиц для восстановления
function TDictList.List4Fix(AppPars : TAppPars) : Integer;
begin
  Pars := AppPars;
  DictFullPath := Pars.Src;
  if (DictAvail = True) then begin
    Pars.SysAdsPfx := SetSysAlias(dtmdlADS.qAny);
    with dtmdlADS.qTablesAll do begin
      Active := false;
      AdsCloseSQLStatement;
      SQL.Clear;
      SQL.Add('SELECT * FROM ' + dtmdlADS.SYSTEM_ALIAS + 'TABLES');
      Active := true;
    end;
    TablesCount := TablesListFromDict(dtmdlADS.qTablesAll);
    Path2Src := ExtractFilePath(Pars.Src);

    //Pars.TotTbls := TablesCount;
    if (TablesCount = 0 ) then
      Result := UE_NO_ADS
    else
      Result := 0;
    Conn.IsConnected := False;
  end
  else
    Result := UE_BAD_USER;
end;

// Тестирование всех или только отмеченных
procedure TDictList.TestSelected(ModeAll : Boolean; TMode : TestMode);
var
  ec, i: Integer;
  TableInf : TDictTable;
begin
    // when progress bar be ready - actually
    //SrcList.DisableControls;

    with SrcList do begin

      First;
      i := 0;
      while not Eof do begin
        i := i + 1;
        if ((dtmdlADS.FSrcState.AsInteger = TST_UNKNOWN) AND (ModeAll = True))
          OR ((dtmdlADS.FSrcMark.AsBoolean = True) AND (ModeAll = False)) then begin
          // все непроверенные или отмеченные
          Edit;

          TableInf := TDictTable.Create(dtmdlADS.FSrcTName.AsString, dtmdlADS.FSrcNpp.AsInteger, dtmdlADS.cnnSrcAds);
          dtmdlADS.FSrcFixInf.AsInteger := Integer(TableInf);

          ec := TableInf.Test1Table(TableInf, TMode, FPars.SysAdsPfx);
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
    Conn.IsConnected := False;
end;

// Подключение к папке с Free tables
function TFreeList.PathAvail: Boolean;
begin
  Path2Src := IncludeTrailingPathDelimiter(Pars.Src);
  Conn.ConnectPath := Path2Src;
  Conn.Connect;
  Result := Conn.IsConnected;
end;

function TFreeList.TablesListFromPath(QA: TAdsQuery): Integer;
var
  i: Integer;
  s: string;
  TblCapts: TStringList;
begin
  i := 0;
  with QA do begin
    SrcList.Close;
    SrcList.Active := True;

    First;
    while not Eof do begin
      i := i + 1;
      SrcList.Append;

      dtmdlADS.FSrcNpp.AsInteger  := i;
      dtmdlADS.FSrcMark.AsBoolean := False;
      dtmdlADS.FSrcTName.AsString := FieldByName('TABLE_NAME').AsString;

      dtmdlADS.FSrcTCaption.AsString := '<' + dtmdlADS.FSrcTName.AsString + '>';
      dtmdlADS.FSrcTestCode.AsInteger := 0;
      dtmdlADS.FSrcState.AsInteger := TST_UNKNOWN;
      dtmdlADS.FSrcFixInf.AsInteger := 0;

      SrcList.Post;
      Next;
    end;
  end;
  Result := i;
end;


// Построение списка свбодных таблиц для восстановления
function TFreeList.List4Fix(AppPars : TAppPars) : Integer;
begin
  Pars := AppPars;
  if (PathAvail = True) then begin
    Pars.SysAdsPfx := SetSysAlias(dtmdlADS.qAny);
    dtmdlADS.qTablesAll.AdsCloseSQLStatement;
    dtmdlADS.qTablesAll.SQL.Clear;
    dtmdlADS.qTablesAll.SQL.Add('SELECT * FROM (EXECUTE PROCEDURE sp_GetTables(NULL,NULL,NULL, ''TABLE'')) AS tmpAllT;');
    dtmdlADS.qTablesAll.Active := True;

    TablesCount := TablesListFromPath(dtmdlADS.qTablesAll);
    //Pars.TotTbls := TablesCount;
    if (TablesCount = 0 ) then
      Result := UE_NO_ADS
    else
      Result := 0;
  end
  else
    Result := UE_BAD_PATH;
    Conn.IsConnected := False;
end;

// Тестирование всех или только отмеченных
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
          // все непроверенные или отмеченные
          Edit;

          TableInf := TFreeTable.Create(dtmdlADS.FSrcTName.AsString, dtmdlADS.FSrcNpp.AsInteger, dtmdlADS.cnnSrcAds);
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
    Conn.IsConnected := False;
end;

{
procedure ClearTablesList(Owner : TComponent);
var
  iM,
  i : Integer;
begin
  iM := Owner.ComponentCount;
  // Удалить все таблицы прежнего списка
  for i := 0 to Owner.ComponentCount -1 do
    if ( Pos(CMPNT_NAME, Owner.Components[i].Name) > 0 ) then begin
      TAdsTable(Owner.Components[i]).Close;
      Owner.Components[i].Free;
    end;
end;
}

// Список таблиц - в MemTable
{
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
    //AppPars.TotTbls := TablesListFromDic(dtmdlADS.qTablesAll);
    Result := AppPars.TotTbls;
  end
  else begin
    // Free tables

  end;

end;
}
end.
