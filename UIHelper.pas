unit UIHelper;

interface

uses
  Forms,
  Controls,
  Dialogs,
  kbmMemTable,
  AdsDAO;

const
  CONNECTIONTYPE_DIRBROWSE = 'Выберите папку...';
  CONNECTIONTYPE_DDBROWSE  = 'Выберите файл словаря...';
  DATA_DICTIONARY_FILTER = 'Advantage Data Dictionaries (*.ADD)|*.ADD|All Files (*.*)|*.*';
  DATA_DIR_FILTER = 'Advantage Data Tables (*.ADT)|All Files (*.*)|*.*';
  DIR_4TMP_FILTER = 'Advantage Data Dictionaries (*.ADD)|*.ADD|All Files (*.*)|*.*';

//function IsCorrectSrc(Path2Dic : string; IsDict : Boolean): Boolean;
//function TablesListFromDic(QA: TAdsQuery): string;

//procedure PrepareList(Path2Dic: string);
function IsCorrectTmp(Path2Tmp: string): string;

implementation

uses
  SysUtils, AuthF, ServiceProc;

{
function IsCorrectSrc(Path2Dic: string; IsDict: Boolean): Boolean;
var
  NeedCnnct: Boolean;
  aPars: AParams;
begin
  Result := False;
  if (IsDict = True) then begin
    // Through dictionary
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
        dtmdlADS.AdsConnect(Path2Dic, AppPars.ULogin, AppPars.UPass);
        Result := True;
      except
        ShowMessage('Неправильное имя пользователя или пароль');
        AppPars.ULogin := USER_EMPTY;
      end;
    end;
  end
  else begin
    // Свободные таблицы
    Result := True;
  end;
end;
}


function IsCorrectTmp(Path2Tmp: string): string;
begin
  Result := '';
  if (DirectoryExists(Path2Tmp)) then
    Result := IncludeTrailingPathDelimiter(Path2Tmp);
end;

end.
