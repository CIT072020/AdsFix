unit FixObject;

interface

uses
  SysUtils,
  //Classes,
  //adsset,
  adscnnct,
  //DB,
  adsdata,
  //adsfunc,
  //adstable,
  //ace,
  kbmMemTable,
  //EncdDecd,
  //ServiceProc, AdsDAO, TableUtils;
  ServiceProc,
  TableUtils;


type

  TAdsList = class
  private
    FSrcPath : string;
    FAdsConn : TAdsConnection;
    FTblList : TkbmMemTable;
  protected
    function List4Fix(Src : string) : Integer; virtual; abstract;
  public
    property SrcPath : string read FSrcPath write FSrcPath;
    property FixList : TkbmMemTable read FTblList write FTblList;
    property Conn : TAdsConnection read FAdsConn write FAdsConn;

    constructor Create(SrcDir : string; Cnct : TAdsConnection);
    destructor Destroy; override;
  published

  end;

  TDictList = class(TAdsList)
  private
  protected
    function List4Fix(Src : string) : Integer; override;
  public

    constructor Create(SrcDir : string);
    destructor Destroy; override;
  published

  end;


implementation

constructor TAdsList.Create(SrcDir : string; Cnct : TAdsConnection);
begin
  inherited Create;

end;


destructor TAdsList.Destroy;
begin
  inherited Destroy;

end;




function IsCorrectSrc(Path2Dic: string; IsDict: Boolean): Boolean;
var
  NeedCnnct: Boolean;
  aPars: AParams;
begin
  Result := False;
    if (AppPars.ULogin = USER_EMPTY) then begin
      FormAuth := TFormAuth.Create(nil);
      aPars[0] := USER_DFLT;
      aPars[1] := PASS_DFLT;
      FormAuth.InitPars(aPars); //

      try
        if (FormAuth.ShowModal = mrOk) then begin
          FormAuth.SetResult(AppPars.ULogin, AppPars.UPass);
        end;
      finally
        FormAuth.Free;
        FormAuth := nil;
      end;

    end;

    if (AppPars.ULogin <> USER_EMPTY) then begin
      try

    //подключаемся к базе
  Conn.IsConnected := False;
  Conn.Username    := Login;
  Conn.Password    := Password;
  Conn.ConnectPath := Path2Dic;
  Conn.IsConnected := True;

        Result := True;
      except
        ShowMessage('Неправильное имя пользователя или пароль');
        AppPars.ULogin := USER_EMPTY;
      end;
    end;
end;





// Список таблиц - в MemTable
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
    // Through dictionary
    if (dtmdlADS.conAdsBase.IsConnected = False) then
      dtmdlADS.conAdsBase.IsConnected := True;
    dtmdlADS.SYSTEM_ALIAS := SetSysAlias(dtmdlADS.qAny);
    AppPars.SysAdsPfx := dtmdlADS.SYSTEM_ALIAS;
    with dtmdlADS.qTablesAll do begin
      Active := false;
      AdsCloseSQLStatement;
      SQL.Clear;
      SQL.Add('SELECT * FROM ' + dtmdlADS.SYSTEM_ALIAS + 'TABLES');
      Active := true;
    end;
    AppPars.TotTbls := TablesListFromDic(dtmdlADS.qTablesAll);
    Result := AppPars.TotTbls;

end;





// Построение списка таблиц для восстановления
function TDictList.List4Fix(Src : string) : Integer;
var
  IsAdsDict : Boolean;
begin
  Result := 0;
  if (IsCorrectSrc(Src, IsAdsDict) = True) then begin
    if (PrepareList(Src) <= 0) then
      Result := UE_NO_ADS;
  end
  else
    Result := UE_NO_ADS;
end;

end.
