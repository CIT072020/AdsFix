unit AdsDAO;

interface

uses
  SysUtils, Classes, adsset, adscnnct, DB, adsdata, adsfunc, adstable,
  kbmMemTable, ServiceProc;

const
  TST_UNKNOWN : Integer = 1;
  TST_GOOD    : Integer = 2;
  TST_RECVRD  : Integer = 4;
  TST_ERRORS  : Integer = 8;

  // сортировка списка таблиц
  IDX_SRC     : String = 'OnState';

  // код типа поля = autoinc
  FTYPE_AUTOINC : Integer = 15;

type
  ITest = interface
  end;

type
  // Режимы тестирования
  TestMode = (Simple, Medium, Slow);

type
  // Параметры для восстановления
  TAppPars = class
    Src      : String;
    IsDict   : Boolean;
    Path2Src : String;
    Path2Tmp : String;
    TMode : TestMode;
  end;

type
  // Список таблиц для восстановления
  TSrcTableList = class
    IsDict : Boolean;
    Path2Src : String;
    Path2Tmp : String;
    AllT     : TkbmMemTable;
  end;

type
  // Список таблиц для восстановления на базе ADS-Dictionary
  TSrcDic = class(TSrcTableList)
  private
    FSrcDict : string;
  public
    property SrcDict : string read FSrcDict write FSrcDict;
  end;

type
  // описание одного индекса
  TIndexInf = class
    Options: Integer;
    Expr: string;
    Fields: TStringList;
  end;

type
  // описание полей таблицы
  TFieldsInf = class
    Name      : String;
    FieldType : Integer;
  end;

type
  // описание ADS-таблицы для восстановления
  TTableInf = class
    TableName : string;
    IndCount  : Integer;
    IndexInf  : TList;
    FieldsInf : TList;
    // поля с типом autoincrement
    FieldsAI  : TStringList;
    RowsFixed : Integer;
  public
    //constructor Create(Owner: TComponent); override;
  end;

type
  TdtmdlADS = class(TDataModule)
    conAdsBase: TAdsConnection;
    qTablesAll: TAdsQuery;
    qAny: TAdsQuery;
    mtSrc: TkbmMemTable;
    FSrcNpp: TIntegerField;
    FSrcMark: TBooleanField;
    FSrcTName: TStringField;
    FSrcTestCode: TIntegerField;
    FSrcTCaption: TStringField;
    dsSrc: TDataSource;
    tblAds: TAdsTable;
    FSrcState: TIntegerField;
    FSrcFixCode: TIntegerField;
    cnABTmp: TAdsConnection;
    qDst: TAdsQuery;
    FSrcAIncs: TIntegerField;
    procedure DataModuleCreate(Sender: TObject);
  private
    { Private declarations }
    FSysAlias : string;
  public
    { Public declarations }
    property SYSTEM_ALIAS : string read FSysAlias write FSysAlias;

    procedure AdsConnect(Path2Dic, Login, Password: string);
  end;

function SetSysAlias(QV : TAdsQuery) : string;
function TablesListFromDic(QA: TAdsQuery): string;
procedure TestSelected;

var
  AppPars : TAppPars;
  dtmdlADS: TdtmdlADS;
  SrcList : TSrcTableList;

implementation

{$R *.dfm}

//constructor TTableInf.Create((Owner: TComponent);
//begin
//  inherited Create(Owner);
//  IndexInf := TList.Create;
//end;



function SetSysAlias(QV: TAdsQuery): string;
begin
  Result := 'SYSTEM.';
  with QV do begin
    Active := False;
    SQL.Text := 'EXECUTE PROCEDURE sp_mgGetInstallInfo()';
    Active := True;
    if (Pos('.', FieldByName('Version').AsString) >= 3) then
      Result := Result + 'ANSI_';
  end;
end;

procedure TdtmdlADS.DataModuleCreate(Sender: TObject);
begin
  dtmdlADS.mtSrc.AddIndex(IDX_SRC, 'State', [ixDescending]);
  dtmdlADS.mtSrc.IndexName := IDX_SRC;
end;

procedure TdtmdlADS.AdsConnect(Path2Dic, Login, Password: string);
begin
    //подключаемся к базе
  dtmdlADS.conAdsBase.IsConnected := False;
  dtmdlADS.conAdsBase.Username := Login;
  dtmdlADS.conAdsBase.Password := Password;
  dtmdlADS.conAdsBase.ConnectPath := Path2Dic;
  try
    dtmdlADS.conAdsBase.IsConnected := True;
  except
    RaiseLastOSError();
  end;
end;

function TablesListFromDic(QA: TAdsQuery): string;
var
  i: Integer;
  s: string;
  TblCapts: TStringList;
begin
  with QA do begin
    //TblCapts := TStringList.Create;
    //TblCapts.Delimiter := '.';
    dtmdlADS.mtSrc.Close;
    dtmdlADS.mtSrc.Active := True;

    First;
    i := 0;
    while not Eof do begin
      i := i + 1;
      dtmdlADS.mtSrc.Append;
      dtmdlADS.FSrcNpp.AsInteger := i;
      dtmdlADS.FSrcMark.AsBoolean := False;
      dtmdlADS.FSrcTName.AsString := FieldByName('NAME').AsString;
      s := FieldByName('COMMENT').AsString;
      if (Length(s) > 0) then begin
        TblCapts := Split('.', s);
        //TblCapts.Text := s;
        s := TblCapts[TblCapts.Count - 1];
      end
      else
        s := '???';

      dtmdlADS.FSrcTCaption.AsString := s;
      dtmdlADS.FSrcTestCode.AsInteger := 0;
      dtmdlADS.FSrcState.AsInteger := TST_UNKNOWN;

      dtmdlADS.mtSrc.Post;
      Next;
    end;
  end;



end;

function Test1Table(TName: string): Integer;
var
  ec : Integer;
  s  : string;
  ErrInf : TStringList;
begin
  Result := 0;
  try
    if (dtmdlADS.tblAds.Active) then
      dtmdlADS.tblAds.Close;
    dtmdlADS.tblAds.TableName := TName;
    dtmdlADS.tblAds.Open;
    dtmdlADS.tblAds.Close;
  except
    on E: EADSDatabaseError do
    begin
      Result := E.ACEErrorCode;
    end;
  end;

end;


procedure TestSelected;
var
  ec, i: Integer;
begin
  if (AppPars.IsDict = True) then begin
    with dtmdlADS.mtSrc do begin

    //Close;
    //Active := True;
      dtmdlADS.tblAds.AdsConnection := dtmdlADS.conAdsBase;
      dtmdlADS.tblAds.ReadOnly := True;

      First;
      i := 0;
      while not Eof do begin
        i := i + 1;
        if (dtmdlADS.FSrcState.AsInteger = TST_UNKNOWN) then begin
          dtmdlADS.mtSrc.Edit;
          ec := Test1Table(dtmdlADS.FSrcTName.AsString);
          if (ec > 0) then begin
            dtmdlADS.FSrcTestCode.AsInteger := ec;
            dtmdlADS.FSrcMark.AsBoolean := True;
            ec := TST_ERRORS;
          end
          else
            ec := TST_GOOD;
          dtmdlADS.FSrcState.AsInteger := ec;
          dtmdlADS.mtSrc.Post;
        end;
        Next;
      end;
      First;

    end;

  end;

end;


end.
