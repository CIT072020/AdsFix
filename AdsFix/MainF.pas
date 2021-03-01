unit MainF;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, CheckLst, Buttons, Mask, DBCtrlsEh, ExtCtrls, Grids,
  DBGridEh, Menus, DB,ComCtrls, FileCtrl, IniFiles, ShellAPI, TypInfo,
  kbmMemTable, DBCtrls,
  SasaIniFile,
  FuncPr;

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
  AdsDAO,
  FixTypes,
  uFixDups,
  uServiceProc,
  uTableUtils;

{$R *.dfm}


procedure TFormMain.FormCreate(Sender: TObject);
var
  Ini: TSasaIniFile;
begin
  cbbPath2Src.Items.Clear;
  cbbPath2Src.Items.Add(CONNECTIONTYPE_DDBROWSE);
  cbbPath2Src.Items.Add(CONNECTIONTYPE_DIRBROWSE);

  Ini := TSasaIniFile.Create(ChangeFileExt(Application.ExeName, '.INI'));
  AppFixPars := TAppPars.Create(Ini);

  cbbPath2Src.Text := AppFixPars.Src;
  btnTblList.Enabled := (Length(cbbPath2Src.Text) > 0);
  edtPath2Tmp.Text := AppFixPars.Path2Tmp;

  chkAutoTest.Checked    := AppFixPars.AutoTest;
  rgTestMode.ItemIndex   := Integer(AppFixPars.TMode);

  chkUseWCopy.Checked := AppFixPars.SafeFix.UseCopy4Work;
  chkRewriteCopy.Checked := AppFixPars.SafeFix.ReWriteWork;
  chkBackUp.Checked := AppFixPars.SafeFix.UseBackUp;

  rgDelDupMode.ItemIndex := Integer(AppFixPars.DelDupMode);

  AppFixPars.ShowForm := Self;
  FixBaseUI := TFixBaseUI.Create(AppFixPars);
end;

procedure TFormMain.FormDestroy(Sender: TObject);
var
  Ini: TSasaIniFile;
begin
  ProceedBackUps(0);
  Ini := AppFixPars.IniFile;
  try
    if Length(cbbPath2Src.Text) > 0 then
      Ini.WriteString(INI_PATHS, 'SRCPath', cbbPath2Src.Text);
    if Length(edtPath2Tmp.Text) > 0 then
      Ini.WriteSTring(INI_PATHS, 'TMPPath', edtPath2Tmp.Text);

    Ini.WriteBool(INI_CHECK, 'AutoTest', AppFixPars.AutoTest);
    Ini.WriteInteger(INI_CHECK, 'TestMode', Ord(AppFixPars.TMode));

    Ini.WriteBool(INI_SAFETY, 'COPY4FIX', AppFixPars.SafeFix.UseCopy4Work);
    Ini.WriteBool(INI_SAFETY, 'RWRCOPY', AppFixPars.SafeFix.ReWriteWork);
    Ini.WriteBool(INI_SAFETY, 'BACKUP', AppFixPars.SafeFix.UseBackUp);

    Ini.WriteInteger(INI_FIX, 'DelDupMode', Ord(AppFixPars.DelDupMode));
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
  AppFixPars.Free;
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
begin
  if SelectDirectory(AppFixPars.Path2Tmp, [sdAllowCreate, sdPerformCreate, sdPrompt], 0) then begin
    edtPath2Tmp.Text := IncludeTrailingPathDelimiter(AppFixPars.Path2Tmp);
  end;
end;

procedure TFormMain.edtPath2TmpChange(Sender: TObject);
begin
  if Length(edtPath2Tmp.Text) > 0 then
    AppFixPars.Path2Tmp := edtPath2Tmp.Text;
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
  if (FixBaseUI.FixPars.IsDict) then
    FixBaseUI.FixList := TDictList.Create(FixBaseUI.FixPars)
  else
    FixBaseUI.FixList := TFreeList.Create(FixBaseUI.FixPars);
  // when progress bar be ready - actually
  //FixBase.FixList.SrcList.DisableControls;

  if (FixBaseUI.FixList.FillList4Fix = UE_OK) then begin
    if (chkAutoTest.Checked = True) then
      FixBaseUI.FixList.TestSelected(True, FixBaseUI.FixPars.TMode);
  end
  else begin
    // No Ads tables OR ???
        ShowMessage('Неправильное имя пользователя или пароль');
  end;
  FixBaseUI.FixList.SrcList.EnableControls;

end;

// Протестировать выбранные
procedure TFormMain.btnTestClick(Sender: TObject);
begin
  TButtonControl(Sender).Enabled := False;
  try
    FixBaseUI.FixPars := AppFixPars;
    FixBaseUI.FixList.TestSelected(False, AppFixPars.TMode);
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
    s := IsCorrectTmp(AppFixPars.Path2Tmp);
    if (Length(s) > 0) then begin
      AppFixPars.Path2Tmp := s;
      dtmdlADS.cnnTmp.IsConnected := False;
      FixBaseUI.FixAllMarked;
      //if (dtmdlADS.conAdsBase.IsConnected = True) then
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
    ProceedBackUps(1);
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
    AppFixPars.TMode := TestMode(rgTestMode.ItemIndex);
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
    FixBaseUI.RecoverAll;
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


end.



