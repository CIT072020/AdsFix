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
  UIHelper,
  AdsDAO,
  FixTypes,
  FixDups,
  ServiceProc,
  TableUtils;

{$R *.dfm}


procedure TFormMain.FormCreate(Sender: TObject);
var
  Ini: TSasaIniFile;
begin
  cbbPath2Src.Items.Clear;
  cbbPath2Src.Items.Add(CONNECTIONTYPE_DDBROWSE);
  cbbPath2Src.Items.Add(CONNECTIONTYPE_DIRBROWSE);

  Ini := TSasaIniFile.Create(ChangeFileExt(Application.ExeName, '.INI'));

  AppPars := TAppPars.Create(Ini);
  cbbPath2Src.Text := AppPars.Src;
  if Length(cbbPath2Src.Text) > 0 then
    btnTblList.Enabled := True;

  edtPath2Tmp.Text := AppPars.Path2Tmp;

  rgTestMode.ItemIndex   := Integer(AppPars.TMode);
  rgDelDupMode.ItemIndex := Integer(AppPars.DelDupMode);
  chkAutoTest.Checked    := AppPars.AutoTest;

  AppPars.ShowForm := Self;
  FixBase := TFixBase.Create(AppPars);
end;

procedure TFormMain.FormDestroy(Sender: TObject);
var
  Ini: TSasaIniFile;
begin
  ProceedBackUps(0);
  Ini := AppPars.IniFile;
  try
    if Length(cbbPath2Src.Text) > 0 then
      Ini.WriteString(INI_PATHS, 'SRCPath', cbbPath2Src.Text);
    if Length(edtPath2Tmp.Text) > 0 then
      Ini.WriteSTring(INI_PATHS, 'TMPPath', edtPath2Tmp.Text);

    Ini.WriteBool(INI_CHECK, 'AutoTest', AppPars.AutoTest);
    Ini.WriteInteger(INI_CHECK, 'TestMode', Ord(AppPars.TMode));
    Ini.WriteInteger(INI_FIX, 'DelDupMode', Ord(AppPars.DelDupMode));
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
  AppPars.Free;
end;

procedure TFormMain.cbbPath2SrcDropDown(Sender: TObject);
begin
   FSavedComboText := AppPars.Src;
end;

procedure TFormMain.cbbPath2SrcCloseUp(Sender: TObject; Accept: Boolean);
var
  PathNew: string;
begin
  PathNew   := '';
  if (cbbPath2Src.Text = CONNECTIONTYPE_DIRBROWSE) then begin
    // свободные таблицы
    PathNew := AppPars.Src;
    if (NOT SelectDirectory(PathNew, [sdAllowCreate, sdPerformCreate, sdPrompt], 0)) then
      PathNew   := '';
  end
  else begin
    // словарные таблицы
    if (cbbPath2Src.Text = CONNECTIONTYPE_DDBROWSE) then begin
      OpenDialog.InitialDir := AppPars.Src;
      OpenDialog.Filter := DATA_DICTIONARY_FILTER;
      if OpenDialog.Execute then begin
        PathNew  := OpenDialog.FileName;
        AppPars.ULogin := USER_EMPTY;
      end
    end
  end;

  if (Length(PathNew) > 0) then begin
    AppPars.Src := PathNew;
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
  if SelectDirectory(AppPars.Path2Tmp, [sdAllowCreate, sdPerformCreate, sdPrompt], 0) then begin
    edtPath2Tmp.Text := IncludeTrailingPathDelimiter(AppPars.Path2Tmp);
  end;
end;

procedure TFormMain.edtPath2TmpChange(Sender: TObject);
begin
  if Length(edtPath2Tmp.Text) > 0 then
    AppPars.Path2Tmp := edtPath2Tmp.Text;
end;


{-------------------------------------------------------------------------------
  Процедура: TFormMain.btnTblListClick(
  Построение списка таблиц для восстановления
-------------------------------------------------------------------------------}
procedure TFormMain.btnTblListClick(Sender: TObject);
var
  i : Integer;
begin
  if (FixBase.FixPars.IsDict) then
    FixBase.FixList := TDictList.Create(FixBase.FixPars)
  else
    FixBase.FixList := TFreeList.Create(FixBase.FixPars);
  if (FixBase.FixList.FillList4Fix(AppPars) = 0) then begin
    if (chkAutoTest.Checked = True) then
      FixBase.FixList.TestSelected(True, AppPars.TMode);
  end
  else begin
    // No Ads tables OR ???
        ShowMessage('Неправильное имя пользователя или пароль');
  end;
end;

// Протестировать выбранные
procedure TFormMain.btnTestClick(Sender: TObject);
begin
  TButtonControl(Sender).Enabled := False;
  try
    FixBase.FixList.TestSelected(False, AppPars.TMode);
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
    s := IsCorrectTmp(AppPars.Path2Tmp);
    if (Length(s) > 0) then begin
      AppPars.Path2Tmp := s;
      dtmdlADS.cnnTmp.IsConnected := False;
      FixBase.FixAllMarked;
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
    FixBase.ChangeOriginalAllMarked;
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
  AppPars.AutoTest := TCheckBox(Sender).Checked;
end;


// Смена режима тестирования
procedure TFormMain.rgTestModeClick(Sender: TObject);
begin
  if (Assigned(AppPars) and (rgTestMode.ItemIndex >= 0)) then begin
    AppPars.TMode := TestMode(rgTestMode.ItemIndex);
  end;
end;


// Смена режима выбора записей для удаления
procedure TFormMain.rgDelDupModeClick(Sender: TObject);
begin
  if (Assigned(AppPars) and (rgDelDupMode.ItemIndex >= 0)) then begin
    AppPars.DelDupMode := TDelDupMode(rgDelDupMode.ItemIndex);
  end;
end;


// Full обработка отмеченных таблиц
procedure TFormMain.btnFullFixOneClick(Sender: TObject);
begin
  TButtonControl(Sender).Enabled := False;
  try
    FixBase.FullFixAllMarked(False);
  finally
    TButtonControl(Sender).Enabled := True;
  end;
end;

// Проверить и исправить все
procedure FullFix;
begin
  if (FixBase.FixList.FillList4Fix(AppPars) = 0) then begin
    FixBase.FixList.TestSelected(True, AppPars.TMode);
    FixBase.FullFixAllMarked(False);
  end
  else
  PutError('Таблицы не найдены!');

end;


// Проверить и исправить все
procedure TFormMain.btnFixAllClick(Sender: TObject);
begin
  TButtonControl(Sender).Enabled := False;
  try
    FixBase.FullFix;
  finally
    TButtonControl(Sender).Enabled := True;
  end;
end;










procedure TFormMain.btnTestQClick(Sender: TObject);
var
  Q : TAdsQuery;
begin
  Q := dtmdlADS.qDst;

end;


end.



