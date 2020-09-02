unit UIHelper;

interface

uses
  Forms,
  Controls,
  Dialogs,
  kbmMemTable;

const
  CONNECTIONTYPE_DIRBROWSE = 'Выберите папку...';
  CONNECTIONTYPE_DDBROWSE  = 'Выберите файл словаря...';
  DATA_DICTIONARY_FILTER = 'Advantage Data Dictionaries (*.ADD)|*.ADD|All Files (*.*)|*.*';
  DATA_DIR_FILTER = 'Advantage Data Tables (*.ADT)|All Files (*.*)|*.*';
  DIR_4TMP_FILTER = 'Advantage Data Dictionaries (*.ADD)|*.ADD|All Files (*.*)|*.*';

function IsDictionary(s: string): Boolean;
function IsCorrectSrc(Path2Dic : string; IsDict : Boolean): Boolean;
procedure PrepareList(Path2Dic: string);
function IsCorrectTmp(Path2Tmp: string): string;

implementation

uses
  SysUtils, AdsDAO, AuthF, FixDups;

function IsDictionary(s: string): Boolean;
begin
  Result := False;
  if (Pos('.ADD', UpperCase(s)) > 0) then
    Result := True;
end;

function IsCorrectSrc(Path2Dic: string; IsDict: Boolean): Boolean;
var
  aPars: AParams;
begin
  Result := False;
  if (IsDict = True) then begin
    // Through dictionary
    FormAuth := TFormAuth.Create(nil);
    aPars[0] := dtmdlADS.conAdsBase.Username;
    aPars[1] := dtmdlADS.conAdsBase.Password;
    FormAuth.InitPars(aPars); //

    try
      if (FormAuth.ShowModal = mrOk) then begin
        aPars := FormAuth.SetResult();
        try
          dtmdlADS.AdsConnect(Path2Dic, aPars[0], aPars[1]);
          Result := True;
        except
          ShowMessage('Неправильное имя пользователя или пароль');
        end;
      end;
    finally
      FormAuth.Free;
      FormAuth := nil;
    end;

  end
  else begin
    // Свободные таблицы
    Result := True;
  end;
end;

procedure PrepareList(Path2Dic: string);
var
  aPars: AParams;
begin
  if (AppPars.IsDict = True) then begin
    // Through dictionary

    if (dtmdlADS.conAdsBase.IsConnected = False) then
      dtmdlADS.conAdsBase.IsConnected := True;
    dtmdlADS.SYSTEM_ALIAS := SetSysAlias(dtmdlADS.qAny);
    with dtmdlADS.qTablesAll do begin
      Active := false;
      SQL.Clear;
      SQL.Add('SELECT * FROM ' + dtmdlADS.SYSTEM_ALIAS + 'TABLES');
      Active := true;
    end;
    TablesListFromDic(dtmdlADS.qTablesAll);
  end
  else begin
    // Free tables

  end;

end;

function IsCorrectTmp(Path2Tmp: string): string;
begin
  Result := '';
  if (DirectoryExists(Path2Tmp)) then
    Result := IncludeTrailingPathDelimiter(Path2Tmp);
end;

end.
