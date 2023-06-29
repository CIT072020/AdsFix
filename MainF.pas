unit MainF;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, CheckLst, Buttons, Mask, DBCtrlsEh, ExtCtrls, Grids,
  DBGridEh, Menus, DB,ComCtrls, FileCtrl, IniFiles, ShellAPI, TypInfo,
  kbmMemTable, DBCtrls,
  SasaIniFile,
  FuncPr, XPMan, DBGrids;

type
  TFormMain = class(TForm)
    Panel1: TPanel;
    edtPath2Tmp: TDBEditEh;
    OpenDialog: TOpenDialog;
    LtabK: TLabel;
    LvidK: TLabel;
    MainMenu1: TMainMenu;
    N1: TMenuItem;
    Label2: TLabel;
    Ln: TLabel;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    Panel5: TPanel;
    cbbPath2Src: TDBComboBoxEh;
    dbgAllT: TDBGridEh;
    lblPath2Tmp: TLabel;
    btnProcMark: TButton;
    btnGetFixed: TButton;
    btnRestOrig: TButton;
    btnTest: TButton;
    rgDelDupMode: TRadioGroup;
    btnTblList: TBitBtn;
    rgTestMode: TRadioGroup;
    btnFixAll: TButton;
    grpBoxProc: TGroupBox;
    lblTabN: TLabel;
    pbProg: TProgressBar;
    btnFullFixOne: TButton;
    chkAutoTest: TCheckBox;
    dbgPlan: TDBGridEh;
    lblTotalIns: TLabel;
    lblResIns: TLabel;
    btnTestQ: TButton;
    chkUseWCopy: TCheckBox;
    chkRewriteCopy: TCheckBox;
    chkBackUp: TCheckBox;
    btnTTmp: TButton;
    xpmnfstMainForm1: TXPManifest;
    procedure ChangePath2TmpClick(Sender: TObject; var Handled: Boolean);
    procedure btnTblListClick(Sender: TObject);
    procedure btnRestOrigClick(Sender: TObject);
    procedure btnFixAllClick(Sender: TObject);
    procedure btnFullFixOneClick(Sender: TObject);

    procedure edtPath2TmpChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure cbbPath2SrcCloseUp(Sender: TObject; Accept: Boolean);
    procedure cbbPath2SrcDropDown(Sender: TObject);
    procedure btnProcMarkClick(Sender: TObject);
    procedure btnGetFixedClick(Sender: TObject);
    procedure btnTestClick(Sender: TObject);
    procedure btnTestQClick(Sender: TObject);
    procedure btnTTmpClick(Sender: TObject);
    procedure cbbPath2SrcChange(Sender: TObject);
    procedure chkAutoTestClick(Sender: TObject);
    procedure chkBackUpClick(Sender: TObject);
    procedure chkRewriteCopyClick(Sender: TObject);
    procedure chkUseWCopyClick(Sender: TObject);
    procedure rgDelDupModeClick(Sender: TObject);
    procedure rgTestModeClick(Sender: TObject);

  private
    FSavedComboText : string;
  public
    { Public declarations }
  end;

var
  FormMain : TFormMain;

implementation

uses
  adstable,
  adscnnct,
  adsdata,
  ace,
  AdsDAO,
  uFixTypes,
  uFixErrs,
  uServiceProc,
  uTableUtils;

{$R *.dfm}


procedure TFormMain.FormCreate(Sender: TObject);
begin
  cbbPath2Src.Items.Clear;
  cbbPath2Src.Items.Add(CONNECTIONTYPE_DDBROWSE);
  cbbPath2Src.Items.Add(CONNECTIONTYPE_DIRBROWSE);

  FixBaseUI := TFixADSTablesUI.Create(IncludeTrailingBackslash(ExtractFileDir(Application.ExeName)));
  AppFixPars := FixBaseUI.FixPars;
  dtmdlADS.dsSrc.DataSet := FixBaseUI.AllTables;

  cbbPath2Src.Text := AppFixPars.Src;
  btnTblList.Enabled := (Length(cbbPath2Src.Text) > 0);
  edtPath2Tmp.Text := AppFixPars.Tmp;

  chkAutoTest.Checked := AppFixPars.AutoTest;
  rgTestMode.ItemIndex := Integer(AppFixPars.TableTestMode);

  chkUseWCopy.Checked := AppFixPars.SafeFix.UseCopy4Work;
  chkRewriteCopy.Checked := AppFixPars.SafeFix.ReWriteWork;
  chkBackUp.Checked := AppFixPars.SafeFix.UseBackUp;

  rgDelDupMode.ItemIndex := Integer(AppFixPars.DelDupMode);

  AppFixPars.ShowForm := Self;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
var
  Ini: TSasaIniFile;
begin
  ProceedBackUps(0, FixBaseUI.FixList.SrcList);
  Ini := TSasaIniFile.Create(AppFixPars.IniName);
  try
    Ini.WriteString(INI_PATHS, 'SRCPath', AppFixPars.Src);
    Ini.WriteSTring(INI_PATHS, 'TMPPath', AppFixPars.Tmp);

    Ini.WriteBool(INI_CHECK, 'AutoTest', AppFixPars.AutoTest);
    Ini.WriteInteger(INI_CHECK, 'TestMode', Ord(AppFixPars.TableTestMode));

    Ini.WriteBool(INI_SAFETY, 'COPY4FIX', AppFixPars.SafeFix.UseCopy4Work);
    Ini.WriteBool(INI_SAFETY, 'RWRCOPY', AppFixPars.SafeFix.ReWriteWork);
    Ini.WriteBool(INI_SAFETY, 'BACKUP', AppFixPars.SafeFix.UseBackUp);

    Ini.WriteInteger(INI_FIX, 'DelDupMode', Ord(AppFixPars.DelDupMode));
    Ini.UpdateFile;
  finally
    FreeAndNil(Ini);
  end;
  FreeAndNil(FixBaseUI);
end;

procedure TFormMain.cbbPath2SrcDropDown(Sender: TObject);
begin
   FSavedComboText := AppFixPars.Src;
end;

procedure TFormMain.cbbPath2SrcCloseUp(Sender: TObject; Accept: Boolean);
var
  PathNew: string;
begin
  PathNew   := '';
  if (cbbPath2Src.Text = CONNECTIONTYPE_DIRBROWSE) then begin
    // свободные таблицы
    PathNew := AppFixPars.Src;
    if (NOT SelectDirectory(PathNew, [sdAllowCreate, sdPerformCreate, sdPrompt], 0)) then
      PathNew   := '';
  end
  else begin
    // словарные таблицы
    if (cbbPath2Src.Text = CONNECTIONTYPE_DDBROWSE) then begin
      OpenDialog.InitialDir := AppFixPars.Src;
      OpenDialog.Filter := DATA_DICTIONARY_FILTER;
      if OpenDialog.Execute then begin
        PathNew  := OpenDialog.FileName;
        AppFixPars.ULogin := USER_EMPTY;
      end
    end
  end;

  if (Length(PathNew) > 0) then begin
    AppFixPars.Src := PathNew;
    cbbPath2Src.Text := PathNew;
  end
  else
    cbbPath2Src.Text := FSavedComboText;
end;

procedure TFormMain.cbbPath2SrcChange(Sender: TObject);
begin
  if (Length(cbbPath2Src.Text) > 0) then
    btnTblList.Enabled := True
  else
    btnTblList.Enabled := False;
end;

procedure TFormMain.ChangePath2TmpClick(Sender: TObject; var Handled: Boolean);
var
  s : string;
begin
  s := AppFixPars.Tmp;
  if SelectDirectory(s, [sdAllowCreate, sdPerformCreate, sdPrompt], 0) then begin
    edtPath2Tmp.Text := IncludeTrailingPathDelimiter(s);
  end;
end;

procedure TFormMain.edtPath2TmpChange(Sender: TObject);
begin
    AppFixPars.Tmp := edtPath2Tmp.Text;
end;

procedure TFormMain.chkBackUpClick(Sender: TObject);
begin
AppFixPars.SafeFix.UseBackUp := TCheckBox(Sender).Checked;
end;

procedure TFormMain.chkRewriteCopyClick(Sender: TObject);
begin
AppFixPars.SafeFix.ReWriteWork := TCheckBox(Sender).Checked;
end;

procedure TFormMain.chkUseWCopyClick(Sender: TObject);
begin
AppFixPars.SafeFix.UseCopy4Work := TCheckBox(Sender).Checked;
end;


{-------------------------------------------------------------------------------
  Процедура: TFormMain.btnTblListClick(
  Построение списка таблиц для восстановления
-------------------------------------------------------------------------------}
procedure TFormMain.btnTblListClick(Sender: TObject);
begin
  TButtonControl(Sender).Enabled := False;
  try
  if (FixBaseUI.NewAdsList = True) then begin
    if (chkAutoTest.Checked = True) then
      FixBaseUI.FixList.TestSelected(AppFixPars.TableTestMode);
      FixBaseUI.FixList.SrcList.EnableControls;
  end else begin
    // No Ads tables OR ???
    if (FixBaseUI.FixPars.IsDict = True) then
      ShowMessage('Неправильное имя пользователя или пароль')
    else
      ShowMessage('Таблицы не найдены!')
  end;
  finally
    TButtonControl(Sender).Enabled := True;
  end;
end;

// Протестировать выбранные
procedure TFormMain.btnTestClick(Sender: TObject);
begin
  TButtonControl(Sender).Enabled := False;
  try
    if (Assigned(FixBaseUI.FixList)) then begin
      FixBaseUI.FixPars := AppFixPars;
      FixBaseUI.FixList.TestSelected(AppFixPars.TableTestMode, False);
    end;
  finally
    TButtonControl(Sender).Enabled := True;
  end;
end;


// Исправить помеченные
procedure TFormMain.btnProcMarkClick(Sender: TObject);
var
  s: string;
begin
  TButtonControl(Sender).Enabled := False;
  try
    s := AppFixPars.IsCorrectTmp(AppFixPars.Tmp);
    if (Length(s) > 0) and (Assigned(FixBaseUI.FixList)) then begin
      AppFixPars.Tmp := s;
      edtPath2Tmp.Text := s;
      dtmdlADS.cnnTmp.IsConnected := False;
      FixBaseUI.FixPars := AppFixPars;
      FixBaseUI.FixAllMarked;
      dtmdlADS.cnnSrcAds.IsConnected := False;
    end;
  finally
    TButtonControl(Sender).Enabled := True;
  end;
end;

// Заполнить оригинал исправленными данными
procedure TFormMain.btnGetFixedClick(Sender: TObject);
begin
  TButtonControl(Sender).Enabled := False;
  try
    FixBaseUI.FixPars := AppFixPars;
    FixBaseUI.ApplyFixMarked;
  finally
    TButtonControl(Sender).Enabled := True;
  end;
end;


// Восстановить оригинал
procedure TFormMain.btnRestOrigClick(Sender: TObject);
begin
  TButtonControl(Sender).Enabled := False;
  try
    ProceedBackUps(1, FixBaseUI.FixList.SrcList);
  finally
    TButtonControl(Sender).Enabled := True;
  end;
end;

// Установка/сброс режима автотестирования
procedure TFormMain.chkAutoTestClick(Sender: TObject);
begin
  AppFixPars.AutoTest := TCheckBox(Sender).Checked;
end;


// Смена режима тестирования
procedure TFormMain.rgTestModeClick(Sender: TObject);
begin
  if (Assigned(AppFixPars) and (rgTestMode.ItemIndex >= 0)) then begin
    AppFixPars.TableTestMode := TestMode(rgTestMode.ItemIndex);
  end;
end;


// Смена режима выбора записей для удаления
procedure TFormMain.rgDelDupModeClick(Sender: TObject);
begin
  if (Assigned(AppFixPars) and (rgDelDupMode.ItemIndex >= 0)) then begin
    AppFixPars.DelDupMode := TDelDupMode(rgDelDupMode.ItemIndex);
  end;
end;


// Full обработка отмеченных таблиц
procedure TFormMain.btnFullFixOneClick(Sender: TObject);
begin
  TButtonControl(Sender).Enabled := False;
  try
    FixBaseUI.FixPars := AppFixPars;
    FixBaseUI.RecoverMarked;
  finally
    TButtonControl(Sender).Enabled := True;
  end;
end;

// Проверить и исправить все
procedure TFormMain.btnFixAllClick(Sender: TObject);
begin
  TButtonControl(Sender).Enabled := False;
  try
    FixBaseUI.FixPars := AppFixPars;
    if (FixBaseUI.RecoverAll <> 0) then
      PutError('Таблицы не найдены!');
  finally
    TButtonControl(Sender).Enabled := True;
  end;
end;










procedure TFormMain.btnTestQClick(Sender: TObject);
var
  s : string;
begin
  s := 'НаселениеДвижение';
  FixBaseUI.RecoverAll(s);
  s := 'xxx';

end;

procedure TFormMain.btnTTmpClick(Sender: TObject);
var
  i,j : Integer;
  s : string;
  c : TAdsConnection;
  hCn,
  hTbl : ADSHANDLE;
begin
  try
  s := AppFixPars.IsCorrectTmp(AppFixPars.Tmp);
  c := dtmdlADS.cnnTmp;
  //c.ConnectPath := AppFixPars.Tmp;
  c.IsConnected := True;


  s := 'C:\Temp\3\SMDOPost.adt';
  //i := ACE.AdsOpenTable101(c.ConnectionHandle, PAnsiChar(s), @hTbl);
  i := ACE.AdsOpenTable(c.ConnectionHandle, PAnsiChar(s), 0, ADS_ADT, ADS_ANSI, ADS_COMPATIBLE_LOCKING, ADS_CHECKRIGHTS, ADS_DEFAULT, @hTbl);
  if (i = AE_SUCCESS) then begin
    i := AdsGetRecordCount(hTbl, ADS_IGNOREFILTERS, @j);
  end;
  except
    on E: EADSDatabaseError do begin
      i := E.ACEErrorCode;
      j := E.SQLErrorCode;
      s := E.Message;
    end;
  end;
  i := i + j;
end;


end.



