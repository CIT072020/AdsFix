unit MainF;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, CheckLst, Buttons, Mask, DBCtrlsEh, ExtCtrls, Grids,
  DBGridEh, Menus, DB,ComCtrls, FileCtrl, IniFiles, ShellAPI, TypInfo,
  kbmMemTable, DBCtrls;

type
  TFormMain = class(TForm)
    Panel1: TPanel;
    edtPath2Tmp: TDBEditEh;
    btnTblList: TBitBtn;
    OpenDialog: TOpenDialog;
    LtabK: TLabel;
    LvidK: TLabel;
    MainMenu1: TMainMenu;
    N1: TMenuItem;
    MemField: TkbmMemTable;
    MemIndex: TkbmMemTable;
    Label2: TLabel;
    Ln: TLabel;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    Panel5: TPanel;
    BoxProc: TGroupBox;
    TabN: TLabel;
    Prog: TProgressBar;
    chkAutoTest: TCheckBox;
    cbbPath2Src: TDBComboBoxEh;
    dbgAllT: TDBGridEh;
    lblPath2Tmp: TLabel;
    btnProcMark: TButton;
    btnGetFixed: TButton;
    btnDelOrig: TButton;
    rgTestMode: TRadioGroup;
    procedure ChangePath2TmpClick(Sender: TObject; var Handled: Boolean);
    procedure btnTblListClick(Sender: TObject);
    procedure btnDelOrigClick(Sender: TObject);

    procedure edtPath2TmpChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure cbbPath2SrcCloseUp(Sender: TObject; Accept: Boolean);
    procedure cbbPath2SrcDropDown(Sender: TObject);
    procedure btnProcMarkClick(Sender: TObject);
    procedure btnGetFixedClick(Sender: TObject);
    procedure cbbPath2SrcChange(Sender: TObject);
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
  UIHelper, AdsDAO, FixDups, ServiceProc;


{$R *.dfm}


procedure TFormMain.FormCreate(Sender: TObject);
var
  i : Integer;
  Ini: TIniFile;
begin
  cbbPath2Src.Items.Clear;
  cbbPath2Src.Items.Add(CONNECTIONTYPE_DDBROWSE);
  cbbPath2Src.Items.Add(CONNECTIONTYPE_DIRBROWSE);

  AppPars := TAppPars.Create;
  Ini := TIniFile.Create(ChangeFileExt(Application.ExeName, '.INI'));
  try
    AppPars.Src := Ini.ReadString('PARAM', 'SRCPath', '');
    cbbPath2Src.Text := AppPars.Src;
    AppPars.Path2Tmp := Ini.ReadString('PARAM', 'TMPPath', '');
    i := Ini.ReadInteger('PARAM', 'TestMode', 0);
    if (i > 0) then
      AppPars.TMode := TestMode(i)
    else
      AppPars.TMode := Simple;

  finally
    Ini.Free;
  end;
  if Length(cbbPath2Src.Text) > 0 then
    btnTblList.Enabled := True;

  if Length(AppPars.Path2Tmp) = 0 then
    AppPars.Path2Tmp := 'C:\TEMP\';
  edtPath2Tmp.Text := AppPars.Path2Tmp;

  // по умолчанию - простой режим тестирования
  rgTestMode.ItemIndex := i;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(ChangeFileExt(Application.ExeName, '.INI'));
  try
    if Length(cbbPath2Src.Text) > 0 then
      Ini.WriteString('PARAM', 'SRCPath', cbbPath2Src.Text);
    if Length(edtPath2Tmp.Text) > 0 then
      Ini.WriteSTring('PARAM', 'TMPPath', edtPath2Tmp.Text);
      Ini.WriteInteger('PARAM', 'TestMode', Ord(AppPars.TMode));
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
  //PathStart,
  PathNew: string;
begin
  PathNew   := '';
  //PathStart := AppPars.Src;
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
        PathNew := OpenDialog.FileName;
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
  Автор:    Alex
  Дата:  2020.08.27
  Входные параметры: Sender: TObject
  Результат:    Нет
-------------------------------------------------------------------------------}
procedure TFormMain.btnTblListClick(Sender: TObject);
var
  IsAdsDict : Boolean;
begin
  IsAdsDict := IsDictionary(cbbPath2Src.Text);
  if (IsCorrectSrc(cbbPath2Src.Text, IsAdsDict) = True) then begin
    AppPars.IsDict := IsAdsDict;
    AppPars.Src := cbbPath2Src.Text;
    if (IsAdsDict = True) then
      AppPars.Path2Src := ExtractFilePath(cbbPath2Src.Text)
    else
      AppPars.Path2Src := IncludeTrailingPathDelimiter(cbbPath2Src.Text);
    PrepareList(cbbPath2Src.Text);
    if (chkAutoTest.Checked) then
      TestSelected;
  end;
end;


procedure TFormMain.btnProcMarkClick(Sender: TObject);
var
  s : string;
begin
  s := IsCorrectTmp(AppPars.Path2Tmp);
  if (Length(s) > 0) then begin
    AppPars.Path2Tmp := s;
    FixAllMarked;
    if (dtmdlADS.conAdsBase.IsConnected = True) then
      dtmdlADS.conAdsBase.IsConnected := False;
  end;

end;

procedure TFormMain.btnGetFixedClick(Sender: TObject);
begin
  ChangeOriginal(TInfLast);
end;

procedure TFormMain.btnDelOrigClick(Sender: TObject);
begin
  DelOriginalTable(TInfLast);
end;

// Смена режима тестирования
procedure TFormMain.rgTestModeClick(Sender: TObject);
begin
  if (Assigned(AppPars) and (rgTestMode.ItemIndex >= 0)) then begin
    AppPars.TMode := TestMode(rgTestMode.ItemIndex);
  end;
end;


end.



