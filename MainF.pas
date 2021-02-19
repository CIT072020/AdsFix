unit MainF;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, CheckLst, Buttons, Mask, DBCtrlsEh, ExtCtrls, Grids,
  DBGridEh, Menus, DB,ComCtrls, FileCtrl, IniFiles, ShellAPI, TypInfo,
  kbmMemTable, DBCtrls, FuncPr;

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
  iDD,
  i : Integer;
  Ini: TIniFile;
begin
  cbbPath2Src.Items.Clear;
  cbbPath2Src.Items.Add(CONNECTIONTYPE_DDBROWSE);
  cbbPath2Src.Items.Add(CONNECTIONTYPE_DIRBROWSE);

  AppPars := TAppPars.Create;
  // Default values
  AppPars.Path2Tmp := 'C:\Temp\';
  AppPars.ULogin := USER_EMPTY;
  // по умолчанию - простой режим тестирования
  AppPars.TMode := Simple;
  // по умолчанию - удаление всех
  AppPars.DelDupMode := DDup_ALL;

  Ini := TIniFile.Create(ChangeFileExt(Application.ExeName, '.INI'));
  try
    AppPars.Src := Ini.ReadString('PARAM', 'SRCPath', '');
    cbbPath2Src.Text := AppPars.Src;
    AppPars.Path2Tmp := Ini.ReadString('PARAM', 'TMPPath', '');
    AppPars.AutoTest := Ini.ReadBool('PARAM', 'AutoTest', True);
    i := Ini.ReadInteger('PARAM', 'TestMode', 0);
    if (i > 0) then
      AppPars.TMode := TestMode(i);
    iDD := Ini.ReadInteger('PARAM', 'DelDupMode', 0);
    if (iDD > 0) then
      AppPars.DelDupMode := TDelDupMode(iDD)
  finally
    Ini.Free;
  end;
  if Length(cbbPath2Src.Text) > 0 then
    btnTblList.Enabled := True;

  edtPath2Tmp.Text := AppPars.Path2Tmp;

  rgTestMode.ItemIndex   := i;
  rgDelDupMode.ItemIndex := iDD;
  chkAutoTest.Checked    := AppPars.AutoTest;

  AppPars.IsDictionary;
  AppPars.ShowForm := Self;
  FixBase := TFixBase.Create(AppPars);
end;

procedure TFormMain.FormDestroy(Sender: TObject);
var
  Ini: TIniFile;
begin
  ProceedBackUps(0);
  Ini := TIniFile.Create(ChangeFileExt(Application.ExeName, '.INI'));
  try
    if Length(cbbPath2Src.Text) > 0 then
      Ini.WriteString('PARAM', 'SRCPath', cbbPath2Src.Text);
    if Length(edtPath2Tmp.Text) > 0 then
      Ini.WriteSTring('PARAM', 'TMPPath', edtPath2Tmp.Text);
    Ini.WriteInteger('PARAM', 'TestMode', Ord(AppPars.TMode));
    Ini.WriteInteger('PARAM', 'DelDupMode', Ord(AppPars.DelDupMode));
    Ini.WriteBool('PARAM', 'AutoTest', AppPars.AutoTest);
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
  DictPath : Boolean;
  PathNew: string;
begin
  DictPath  := False;
  PathNew   := '';
  if (cbbPath2Src.Text = CONNECTIONTYPE_DIRBROWSE) then begin
    // свободные таблицы
    if SelectDirectory(AppPars.Src, [sdAllowCreate, sdPerformCreate, sdPrompt], 0) then begin
      PathNew := AppPars.Src;
    end;
  end
  else begin
    // словарные таблицы
    if (cbbPath2Src.Text = CONNECTIONTYPE_DDBROWSE) then begin
      OpenDialog.InitialDir := AppPars.Src;
      OpenDialog.Filter := DATA_DICTIONARY_FILTER;
      if OpenDialog.Execute then begin
        PathNew  := OpenDialog.FileName;
        DictPath := True;
        AppPars.ULogin := USER_EMPTY;
      end
    end
  end;

  if (Length(PathNew) > 0) then begin
    AppPars.Src := PathNew;
    AppPars.IsDictionary;
    cbbPath2Src.Text := PathNew;
{
    if (AppPars.IsDict = True) then
      AppPars.Path2Src := ExtractFilePath(PathNew)
    else
      AppPars.Path2Src := IncludeTrailingPathDelimiter(PathNew);
}      
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
  if (FixBase.CreateFixList.List4Fix(AppPars) = 0) then begin
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
      FixAllMarked;
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
    ChangeOriginalAllMarked;
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
    FullFixAllMarked(False);
  finally
    TButtonControl(Sender).Enabled := True;
  end;
end;

// Проверить и исправить все
procedure FullFix;
begin
  if (FixBase.CreateFixList.List4Fix(AppPars) = 0) then begin
    FixBase.FixList.TestSelected(True, AppPars.TMode);
    FullFixAllMarked(False);
  end
  else
  PutError('Таблицы не найдены!');

end;


// Проверить и исправить все
procedure TFormMain.btnFixAllClick(Sender: TObject);
begin
  TButtonControl(Sender).Enabled := False;
  try
    FullFix;
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



