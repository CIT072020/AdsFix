unit HEADunit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, mRtf, StdCtrls, CheckLst, Buttons, Mask, DBCtrlsEh, ExtCtrls, Grids,
  DBGridEh, Menus, DB,ComCtrls, IniFiles, ShellAPI,BOBKFunct, kbmMemTable;

type
  THEADform = class(TForm)
    Panel1: TPanel;
    Adres: TDBEditEh;
    BitBtn1: TBitBtn;
    OpenFail: TOpenDialog;
    LtabK: TLabel;
    LvidK: TLabel;
    MainMenu1: TMainMenu;
    N1: TMenuItem;
    MemTab: TkbmMemTable;
    MemField: TkbmMemTable;
    MemIndex: TkbmMemTable;
    Label2: TLabel;
    RV: TSpeedButton;
    PV: TSpeedButton;
    PN: TSpeedButton;
    RN: TSpeedButton;
    Ln: TLabel;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    Panel5: TPanel;
    DBGridEh1: TDBGridEh;
    GroupBox1: TGroupBox;
    TabName: TCheckBox;
    TabType: TCheckBox;
    TabCreat: TCheckBox;
    TabPrKey: TCheckBox;
    TabInd: TCheckBox;
    TabKod: TCheckBox;
    TabPerliv: TCheckBox;
    TabMemo: TCheckBox;
    TabCom: TCheckBox;
    TabChekOll: TBitBtn;
    NotTabChekOll: TBitBtn;
    GroupBox4: TGroupBox;
    Label3: TLabel;
    Label4: TLabel;
    Tab_size: TDBNumberEditEh;
    Sh1: TRadioButton;
    Sh2: TRadioButton;
    Sh3: TRadioButton;
    GroupBox2: TGroupBox;
    FieldName: TCheckBox;
    FieldNum: TCheckBox;
    FieldType: TCheckBox;
    FieldLen: TCheckBox;
    FieldMin: TCheckBox;
    FieldMax: TCheckBox;
    FieldNull: TCheckBox;
    FieldDef: TCheckBox;
    FieldCom: TCheckBox;
    FieldChekOll: TBitBtn;
    NotFieldChekOl: TBitBtn;
    Label6: TLabel;
    Label7: TLabel;
    Field_size: TDBNumberEditEh;
    Shf1: TRadioButton;
    Shf2: TRadioButton;
    Shf3: TRadioButton;
    FieldFree: TCheckBox;
    FieldSCH: TCheckBox;
    GrInd: TGroupBox;
    IndexChekOll: TSpeedButton;
    NotIndexChekOll: TSpeedButton;
    IndexName: TCheckBox;
    IndexField: TCheckBox;
    IndexLen: TCheckBox;
    IndexMin: TCheckBox;
    IndexCom: TCheckBox;
    Label5: TLabel;
    Label8: TLabel;
    Index_size: TDBNumberEditEh;
    Shi1: TRadioButton;
    Shi2: TRadioButton;
    Shi3: TRadioButton;
    ChPrKey: TCheckBox;
    Label1: TLabel;
    VidK: TSpeedButton;
    VidA: TSpeedButton;
    ChAll: TBitBtn;
    ChnotAll: TBitBtn;
    Vigr: TButton;
    Put: TDBEditEh;
    BoxProc: TGroupBox;
    TabN: TLabel;
    Prog: TProgressBar;
    ChInd: TCheckBox;
    GAll: TSpeedButton;
    GNow: TSpeedButton;
    chkAutoTest: TCheckBox;
    procedure AdreEditButtons0Click(Sender: TObject; var Handled: Boolean);
    procedure BitBtn1Click(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure TabListClickCheck(Sender: TObject);
    procedure ChAllClick(Sender: TObject);
    procedure ChnotAllClick(Sender: TObject);
    procedure VigrClick(Sender: TObject);
    procedure TabChekOllClick(Sender: TObject);
    procedure NotTabChekOllClick(Sender: TObject);
    procedure NotFieldChekOlClick(Sender: TObject);
    procedure FieldChekOllClick(Sender: TObject);


    procedure AdresChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ChIndClick(Sender: TObject);
    procedure IndexChekOllClick(Sender: TObject);
    procedure NotIndexChekOllClick(Sender: TObject);
    procedure FieldLenClick(Sender: TObject);
    procedure RVClick(Sender: TObject);
    procedure PVClick(Sender: TObject);
    procedure PNClick(Sender: TObject);
    procedure DBGridEh1GetCellParams(Sender: TObject; Column: TColumnEh;
      AFont: TFont; var Background: TColor; State: TGridDrawState);
    procedure RNClick(Sender: TObject);
    procedure DBGridEh1CellClick(Column: TColumnEh);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure GAllClick(Sender: TObject);
    procedure GNowClick(Sender: TObject);






  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Col_Vid:integer;
  HEADform: THEADform;
  Tabs,Del_st:TstringList;
  STEP:integer;
  Red_flag:boolean;
  FileNames:string;
implementation

uses DTab, SoedUnit, ProcUnit;

{$R *.dfm}

//Функция орпеделяет количество РАЗДЕЛОВ
Function ColRazd:integer;
var R:integer;
s:string;
begin
s:=''; R:=0;
  With DatTab.kmTable do begin
  IndexName:='IndRazdel';
  First;
    While not Eof do begin
      if DatTab.kmTableRazdel.AsString<>s then begin
         s:=DatTab.kmTableRazdel.AsString;
         inc(R);
      end;
      Next;
    end;
  end;
result:=R;
end;

//Функция определяет количество ПОДРАЗДЕЛОВ
Function ColPodRazd(R:integer):integer;
var  P:integer;
begin
P:=0;
  With DatTab.kmTable do begin
    First;
    While not Eof do begin
      if DatTab.kmTableNR.AsInteger=R then
      inc(P);
      Next;
    end;
  end;
result:=P; 
end;

//Функция которая возвращает номер раздела
Function NRazd(s:string):integer;
var
R:integer;
begin
R:=0;
  With DatTab.kmTable do begin
    First;
    While not Eof do begin
    if DatTab.kmTableRazdel.AsString=s then
       R:=DatTab.kmTableNR.AsInteger;
    Next;
    end;
  end;
if R=0 then result:=ColRazd+1
else result:=R;
end;

//Функция которая определяет встречается ли такое имя таблицы в kmTable
Function NameTrue(s:string):boolean;
begin
result:=false;
  With DatTab.kmTable do begin
    First;
    While not Eof do begin
    if DatTab.kmTableName.AsString=s then result:=true;
    Next;
    end;
  end;
end;

//Процедура формирования таблицы
Procedure FormirovSL;
begin
//ФОРМИРОВАНИЕ листа таблиц
{     Tabs.Free;
     Tabs:=TStringList.Create;
     For STEP:=0 to HEADform.TabList.Items.Count-1 do
         IF HEADform.TabList.Checked[STEP]=true then begin
            //запрос на показ только выделенных полей
            With DatTab.QTab do begin
              Active:=false;
              SQL.Clear;
              SQL.Add('Select * From System.tables Where Name='''+HEADform.TabList.Items[STEP]+'''');
              Active:=true;
            end;
           //_______________________________________
          if Length(Trim(DatTab.QTabComment.AsVariant))>0 then begin
          if Pos('.',DatTab.QTabComment.AsString)=0 then
             Tabs.add(DatTab.QTabComment.AsString+'='+DatTab.QTabName.AsString+'.')
          else
             Tabs.add(Name_do(DatTab.QTabComment.AsString)+'='+DatTab.QTabName.AsString+'.'+Name_posle(DatTab.QTabComment.AsString))
         end else
         Tabs.add(DatTab.QTabName.AsString+'='+DatTab.QTabName.AsString+'.');
         end;     }
end;



procedure OtmechTabl;
var
i,sum,n:integer;
begin
sum:=0;
   With DatTab.kmTable do begin
     n:=RecNo;
     DisableControls;
     First;
      While not Eof do begin
        if DatTab.kmTableChech.AsBoolean then inc(sum);
        Next;
      end;
     RecNo:=n;
     EnableControls;
    end;
HEADform.Ln.Caption:=IntToStr(sum);
end;

procedure THEADform.AdreEditButtons0Click(Sender: TObject;
  var Handled: Boolean);
begin
if OpenFail.Execute then
Adres.Text:=OpenFail.FileName;
end;

procedure SetSysAlias;
var
   FVer   : string;
   FMajor : integer;
begin
   DatTab.SYSTEM_ALIAS := 'SYSTEM.';
   With DatTab.QVers do begin
      SQL.Text := 'EXECUTE PROCEDURE sp_mgGetInstallInfo()';
      Active := True;
      FVer := FieldByName('Version').AsString;
   end;
   FMajor := Pos('.', FVer);
   if ( FMajor >= 3 ) then
      DatTab.SYSTEM_ALIAS := DatTab.SYSTEM_ALIAS + 'ANSI_';
end;


procedure THEADform.BitBtn1Click(Sender: TObject);
var
  Ini:TIniFile;
  SavedDic : string;
  tabindex,s,RAZDEL,PODRAZDEL:string;
  Nom:TStringList;
  i,razd,podrazd,R,P:integer;
  FF:integer;
begin
  FileNames := ExtractFileName(Adres.Text);
  i := Pos('.', FileNames);
  if (i > 0) then
    FileNames := Copy(FileNames, 1, i - 1);
    //подключаемся к базе
  DatTab.Conect.IsConnected := false;
  DatTab.Conect.ConnectPath := Adres.Text;
      //соединение
  Application.CreateForm(TSoedForm, SoedForm);
  SoedForm.ShowModal;


 try
 IF DatTab.Conect.IsConnected=true then   //запрос на показ названий таблиц
   SetSysAlias;
    with DatTab.QTab do
    begin
      Active := false;
      SQL.Clear;
      SQL.Add('select * from ' + DatTab.SYSTEM_ALIAS + 'tables');
      Active := true;

     //================================
     //Загрузка МемТабле
      DatTab.kmTable.Close;
      DatTab.kmTable.Active := true;
      SavedDic := ExtractFilePath(Application.ExeName) + 'Files\' + FileNames + '.sav';
      if FileExists(SavedDic) = false then
      begin
        FF := FileCreate(SavedDic);
        FileClose(FF);
      end;

      DatTab.kmTable.LoadFromFile(SavedDic);

     //=====================================
     //Удалим все поля которые не встречаются в БД
      DatTab.kmTable.DisableControls;
      DatTab.kmTable.First;
      while not DatTab.kmTable.Eof do
      begin
        with DatTab.TQ do
        begin
          Active := false;
          SQL.Clear;
          SQL.Add('Select Count(Name) from ' + DatTab.SYSTEM_ALIAS + 'tables Where Name=''' + DatTab.kmTableName.AsString + '''');
          Active := true;
          if DatTab.expr.AsInteger = 0 then
          begin
            DatTab.kmTable.Delete;
            DatTab.kmTable.First;
          end
          else
            DatTab.kmTable.Next;
        end;
      end;
     //=====================================
   {
     //===========================================
     //Перенумерация Раздела и Подраздела
     s:=''; razd:=0;
     DatTab.kmTable.First;
     While not DatTab.kmTable.Eof do begin
        if s<>DatTab.kmTableRazdel.AsString then begin
         inc(razd);
         podrazd:=1;
         DatTab.kmTable.Edit;
         DatTab.kmTableNR.AsInteger:=razd;
         DatTab.kmTableNP.AsInteger:=podrazd;
         s:=DatTab.kmTableRazdel.AsString;
        end
        else begin
         inc(podrazd);
         DatTab.kmTable.Edit;
         DatTab.kmTableNR.AsInteger:=razd;
         DatTab.kmTableNP.AsInteger:=podrazd;
        end;
    DatTab.kmTable.Next;
    end;
     //===========================================
      }
    //=================================================
    //Добавление не встречающегося в kmTable поля
      First;
      while not Eof do
      begin
        if not NameTrue(DatTab.QTabName.AsString) then
        begin
          PODRAZDEL := '';
          if length(Name_NoComent(DatTab.QTab.FieldList[11].asstring)) > 0 then
          begin
            if Pos('.', Name_NoComent(DatTab.QTab.FieldList[11].asstring)) > 0 then
            begin
              RAZDEL := Name_do(DatTab.QTab.FieldList[11].asstring);
              PODRAZDEL := Name_NoComent(Name_posle(DatTab.QTab.FieldList[11].asstring));
            end
            else
              RAZDEL := Name_NoComent(DatTab.QTab.FieldList[11].asstring);
          end
          else
            RAZDEL := DatTab.QTab.FieldList[0].asstring;

          R := NRazd(RAZDEL);
          P := ColPodRazd(NRazd(RAZDEL)) + 1;

          DatTab.kmTable.Append;
          DatTab.kmTableRazdel.AsString := RAZDEL;
          DatTab.kmTableChech.AsBoolean := false;
          DatTab.kmTableName.AsString := DatTab.QTabName.AsString;
          DatTab.kmTablePodRazdel.AsString := PODRAZDEL;
          DatTab.kmTableNR.AsInteger := R;
          DatTab.kmTableNP.AsInteger := P;
          DatTab.kmTable.Post;
        end;

        Next;
      end;
    //=================================================
      DatTab.kmTable.IndexName := 'IndPor';
      DatTab.kmTable.EnableControls;

    { First;
       While not Eof do begin
        //Добавляем таблицы в МемТебле
        DatTab.kmTable.Append;
        DatTab.kmTableChech.AsBoolean:=false;
        DatTab.kmTableName.AsString:=DatTab.QTab.FieldList[0].asstring;
        if length(Name_NoComent(DatTab.QTab.FieldList[11].asstring))>0 then begin
           if Pos('.',Name_NoComent(DatTab.QTab.FieldList[11].asstring))>0 then begin
           DatTab.kmTableRazdel.AsString:=Name_do(DatTab.QTab.FieldList[11].asstring);
           DatTab.kmTablePodRazdel.AsString:=Name_NoComent(Name_posle(DatTab.QTab.FieldList[11].asstring));
           end
           else
           DatTab.kmTableRazdel.AsString:=Name_NoComent(DatTab.QTab.FieldList[11].asstring);
        end
        else
        DatTab.kmTableRazdel.AsString:=DatTab.QTab.FieldList[0].asstring;
        DatTab.kmTable.Post;
       Next;
       end;    }
    end;

    //Установим номера РАЗДЕЛОВ и ПОДРАЗДЕЛОВ
   // Nom:=TStringList.Create;
  { DatTab.kmTable.IndexName:='IndRazdel';
    razd:=0;
    s:='';
    DatTab.kmTable.First;
    While not DatTab.kmTable.Eof do begin
      if s<>DatTab.kmTableRazdel.AsString then begin
         inc(razd);
         podrazd:=1;
         DatTab.kmTable.Edit;
         DatTab.kmTableNR.AsInteger:=razd;
         DatTab.kmTableNP.AsInteger:=podrazd;
         s:=DatTab.kmTableRazdel.AsString;
      end
      else begin
      inc(podrazd);
      DatTab.kmTable.Edit;
      DatTab.kmTableNR.AsInteger:=razd;
      DatTab.kmTableNP.AsInteger:=podrazd;
      end;
      DatTab.kmTable.Next;
    end;
        razd:=1;
       // for i:=0 to Nom.Count-1 do
       // Nom.Names[i]

       }



    LTabK.Caption:='Найдено таблиц: '+IntToStr(DatTab.kmTable.RecordCount);
    Vigr.Enabled:=true;
  {  //отмечаем из Ini файла выбранные до этого таблицы
    Ini:=TIniFile.Create(ChangeFileExt(Application.ExeName,'.INI'));
     tabindex:=Ini.ReadString(Adres.Text,'Индексы','');
    s:='';
    For i:=1 to Length(tabindex) do
     if tabindex[i]=' ' then  begin
      TabList.Checked[StrToInt(s)]:=true;
      s:='';
     end
     else
      s:=s+tabindex[i];
    if s<>'' then TabList.Checked[StrToInt(s)]:=true;
    OtmechTabl;
   // Ini.Free;  }
   OtmechTabl;
  except
   ShowMessage('Не удалось совершить запрос!');
  end
end;

procedure THEADform.FormActivate(Sender: TObject);
begin
 SoedForm.Free;
// ProcForm.Free;
end;



procedure THEADform.TabListClickCheck(Sender: TObject);
begin
OtmechTabl;
end;





procedure THEADform.ChAllClick(Sender: TObject);
var
n:integer;
begin
try
n:=DatTab.kmTable.RecNo;
DatTab.kmTable.DisableControls;
 DatTab.kmTable.First;
 While not DatTab.kmTable.Eof do begin
 DatTab.kmTable.Edit;
 DatTab.kmTableChech.AsBoolean:=true;
 DatTab.kmTable.Next;
 end;
DatTab.kmTable.RecNo:=n;
DatTab.kmTable.EnableControls;
OtmechTabl;
except
MessageDlg('Не возможно отметить таблицы!',mtWarning,[mbOk],0);
end;
end;

procedure THEADform.ChnotAllClick(Sender: TObject);
var
n:integer;
begin
try
n:=DatTab.kmTable.RecNo;
DatTab.kmTable.DisableControls;
 DatTab.kmTable.First;
 While not DatTab.kmTable.Eof do begin
 DatTab.kmTable.Edit;
 DatTab.kmTableChech.AsBoolean:=false;
 DatTab.kmTable.Next;
 end;
DatTab.kmTable.RecNo:=n;
DatTab.kmTable.EnableControls;
OtmechTabl;
except
MessageDlg('Не возможно отметить таблицы!',mtWarning,[mbOk],0);
end;
end;




//Процедура отпулючения всех полей для Таблиц
Procedure TabVizFalse;
begin
 With  DatTab do begin
  QTabName.Visible:=false;
  QTabTable_Relative_Path.Visible:=false;
  QTabTable_Type.Visible:=false;
  QTabTable_Auto_Create.Visible:=false;
  QTabTable_Primary_Key.Visible:=false;
  QTabTable_Default_Index.Visible:=false;
  QTabTable_Encryption.Visible:=false;
  QTabTable_Permission_Level.Visible:=false;
  QTabTable_Memo_Block_Size.Visible:=false;
  QTabTable_Validation_Expr.Visible:=false;
  QTabTable_Validation_Msg.Visible:=false;
  QTabComment.Visible:=false;
  QTabUser_Defined_Prop.Visible:=false;
  QTabTriggers_Disabled.Visible:=false;
  QTabPok_table_tape.Visible:=false;
 end;
end;



procedure THEADform.VigrClick(Sender: TObject);
const k_pol=9; //количество свойств таблицы
var
   sl: TStringList;
   Err,s,s1: string;
   HeadList: TStringList;
   WidthList: TStringList;
   CellKeyword: TStringList;
   sum,i,g,dl_1,dl_2,dl_3,tab_s,tab_t,field_s,field_t,DLIN,ind_s,ind_t,z1,z2,n:integer;
   flag:boolean;

begin

//------------------------
//========================

 HEADform.Cursor:=crHourGlass;
   // мем табле
   MemTab.Close;


    MemTab.Open;
   i:=0; Dl_1:=0;
   MemTab.Active:=false;
   for g:=0 to k_pol-1 do MemTab.FieldDefs[g].Name:=IntToStr(g);
   if TabName.Checked then begin  MemTab.FieldDefs[i].Name:='Name'; inc(i); Dl_1:=20; end;
   if TabType.Checked then begin MemTab.FieldDefs[i].Name:='Type'; inc(i); Dl_1:=Dl_1+8;  end;
   if TabCreat.Checked then begin MemTab.FieldDefs[i].Name:='Creat'; inc(i); Dl_1:=Dl_1+5; end;
   if TabPrKey.Checked then begin MemTab.FieldDefs[i].Name:='PrKey'; inc(i); Dl_1:=Dl_1+7; end;
   if TabInd.Checked then begin MemTab.FieldDefs[i].Name:='Index'; inc(i); Dl_1:=Dl_1+10; end;
   if TabKod.Checked then begin MemTab.FieldDefs[i].Name:='Kodir'; inc(i); Dl_1:=Dl_1+5; end;
   if TabPerLiv.Checked then begin MemTab.FieldDefs[i].Name:='PerLiv'; inc(i); Dl_1:=Dl_1+10; end;
   if TabMemo.Checked then begin MemTab.FieldDefs[i].Name:='Memo'; inc(i); Dl_1:=Dl_1+5; end;
   if TabCom.Checked then begin MemTab.FieldDefs[i].Name:='Com'; inc(i); Dl_1:=Dl_1+20; end;
   MemTab.Active:=true;

   // мем табле для полей
   MemField.Close;
   MemField.Open;
   i:=0;     dl_2:=0;
   MemField.Active:=false;
   for g:=0 to 8 do MemField.FieldDefs[g].Name:=IntToStr(g);
   if FieldNum.Checked then begin MemField.FieldDefs[i].Name:='Num'; inc(i); dl_2:=3; end;
   if FieldName.Checked then begin MemField.FieldDefs[i].Name:='Name'; inc(i); dl_2:=dl_2+15; end;
   if FieldType.Checked then begin MemField.FieldDefs[i].Name:='Type'; inc(i); dl_2:=dl_2+10; end;
   //if FieldLen.Checked then begin MemField.FieldDefs[i].Name:='Len'; inc(i); dl_2:=dl_2+7; end;
   if FieldMin.Checked then begin MemField.FieldDefs[i].Name:='Min'; inc(i); dl_2:=dl_2+8; end;
   if FieldMax.Checked then begin MemField.FieldDefs[i].Name:='Max'; inc(i); dl_2:=dl_2+5; end;
   if FieldNull.Checked then begin MemField.FieldDefs[i].Name:='Null'; inc(i); dl_2:=dl_2+7; end;
   if FieldDef.Checked then begin MemField.FieldDefs[i].Name:='Def'; inc(i); dl_2:=dl_2+10; end;
   if FieldCom.Checked then begin MemField.FieldDefs[i].Name:='Com'; inc(i); dl_2:=dl_2+25; end;
   if FieldFree.Checked then begin MemField.FieldDefs[i].Name:='Free'; inc(i); dl_2:=dl_2+7; end;
   MemField.Active:=true;

   MemIndex.Close;

   MemIndex.Open;
   i:=0;     dl_3:=0;
   MemIndex.Active:=false;
   if IndexName.Checked then begin MemIndex.FieldDefs[i].Name:='Name'; inc(i); dl_3:=20; end;
   if IndexField.Checked then begin MemIndex.FieldDefs[i].Name:='Field'; inc(i); dl_3:=dl_3+30; end;
   if IndexLen.Checked then begin MemIndex.FieldDefs[i].Name:='Len'; inc(i); dl_3:=dl_3+7; end;
   if IndexMin.Checked then begin MemIndex.FieldDefs[i].Name:='Min'; inc(i); dl_3:=dl_3+7; end;
   if IndexCom.Checked then begin MemIndex.FieldDefs[i].Name:='Com'; inc(i); dl_3:=dl_3+26; end;
   MemIndex.Active:=true;

   //====================================
        sl:=TStringList.Create;
        HeadList:=TStringList.Create;
        WidthList:=TStringList.Create;
        CellKeyword:=TStringList.Create;
      try
     Flag:=false;
     if VidK.Down=true then begin StartPrint(sl, poPortrait, pfA4); DLIN:=600; end
     else begin StartPrint(sl, poLandscape, pfA4); DLIN:=900; end;

     //Вывод содержания
     PrintString(sl,'{\field {\*\fldinst { TOC \\o "1-3" \\h \\z \\u }}} \par',0, 12, False, False, False);

   //====================================
      //ЦИКЛ ДЛЯ ПО ВЫДЕЛЕННЫМ ТАБЛИЦАМ
     BoxProc.Visible:=true;
     z1:=1; z2:=1;
     STEP:=0;
     n:=DatTab.kmTable.RecNo;
     DatTab.kmTable.DisableControls;
     DatTab.kmTable.First;
     While not DatTab.kmTable.Eof do Begin
     if DatTab.kmTableChech.AsBoolean=true then BEGIN
          Inc(STEP);
          Application.ProcessMessages;
          Prog.Position:=((100*(STEP+1)) div StrToInt(Ln.Caption));
          TabN.Caption:=DatTab.kmTableName.AsString;

       //_______________________________________
       //запрос на показ только выделенных полей
       With DatTab.QTab do begin
         Active:=false;
         SQL.Clear;
         SQL.Add('Select * From ' + DatTab.SYSTEM_ALIAS + 'tables Where Name='''+DatTab.kmTableName.AsString+'''');
         Active:=true;
       end;
       //_______________________________________

     
        //Определение шрифта, размера,
        if Sh1.Checked then tab_t:=0;
        if Sh2.Checked then tab_t:=1;
        if Sh3.Checked then tab_t:=2;

        if Tab_size.Value<>null then tab_s:=Tab_size.Value else tab_s:=12;

        //выводим Заголовки
          //заголовок1

          if s1<>DatTab.kmTableRazdel.AsString then begin
          PrintString(sl,'\page', tab_t, tab_s, False, False, False);
          PrintString(sl,'\s1 '+IntToStr(z1)+'. '+DatTab.kmTableRazdel.AsString+'\par\pard\plain',0, 12, True, False, False);

          inc(z1);
          z2:=1;
          end;
          if DatTab.kmTablePodRazdel.AsString<>'' then begin
          PrintString(sl,'\par', tab_t, tab_s, False, False, False);
          PrintString(sl,'\s2 '+IntToStr(z1-1)+'.'+IntToStr(z2)+'. '+DatTab.kmTablePodRazdel.AsString+'\par\pard\plain',0, 12, True, False, False);
          PrintString(sl,'\par', tab_t, tab_s, False, False, False);
          inc(z2);
          end
           else PrintString(sl,'\par', tab_t, tab_s, False, False, False);
          s1:=DatTab.kmTableRazdel.AsString;

         if TabName.Checked then begin
           PrintString(sl, 'Название таблицы:', tab_t, tab_s, False, False, False);
           PrintString(sl,'  '+DatTab.QTabName.AsString+'\par', tab_t, tab_s, TRUE, False, False);
         end; // MemTab.FieldByName('Name').AsString:=DatTab.QTabName.AsString;
         if TabType.Checked then begin
           PrintString(sl, 'Тип тиблицы:', tab_t, tab_s, False, False, False);
           PrintString(sl,'  '+DatTab.QTabPok_table_tape.AsString+'\par', tab_t, tab_s, False, TRUE, False);
         end; //MemTab.FieldByName('Type').AsString:=DatTab.QTabPok_table_tape.AsString;
         if TabCreat.Checked then begin
           PrintString(sl, 'Автосоздание тиблицы:', tab_t, tab_s, False, False, False);
           PrintString(sl,'  '+DatTab.QTabTable_Auto_Create.AsString+'\par', tab_t, tab_s, False, TRUE, False);
         end;// MemTab.FieldByName('Creat').AsString:=DatTab.QTabTable_Auto_Create.AsString;
         if TabPrKey.Checked then begin
           PrintString(sl, 'Первичный ключ:  ', tab_t, tab_s, False, False, False);
           PrintString(sl, DatTab.QTabTable_Primary_Key.AsString, tab_t, tab_s, False, False, False);
            With DatTab.QIndex do begin
              Active:=false;
              SQl.Clear;
              SQL.Add('Select * From ' + DatTab.SYSTEM_ALIAS + 'indexes Where Parent='''+DatTab.kmTableName.AsString+''' and Name='''+DatTab.QTabTable_Primary_Key.AsString+'''');
              Active:=true;
            end;
           if  DatTab.QTabTable_Primary_Key.AsVariant=Null then
            PrintString(sl,'\par', tab_t, tab_s, False, False, False)
           else
            PrintString(sl,' ('+DatTab.QIndexIndex_Expression.AsString+')\par', tab_t, tab_s, False, False, False);
         end;
         if TabInd.Checked then begin
           PrintString(sl, 'Индекс по умолчанию:  ', tab_t, tab_s, False, False, False);
           PrintString(sl,DatTab.QTabTable_Default_Index.AsString, tab_t, tab_s, False, False, False);
           With DatTab.QIndex do begin
              Active:=false;
              SQl.Clear;
              SQL.Add('Select * From ' + DatTab.SYSTEM_ALIAS + 'indexes Where Parent='''+DatTab.kmTableName.AsString+''' and Name='''+DatTab.QTabTable_Default_Index.AsString+'''');
              Active:=true;
            end;
           if  DatTab.QTabTable_Default_Index.AsVariant=Null then
            PrintString(sl,'\par', tab_t, tab_s, False, False, False)
           else
            PrintString(sl,' ('+DatTab.QIndexIndex_Expression.AsString+')\par', tab_t, tab_s, False, False, False);
         end; //MemTab.FieldByName('Index').AsString:=DatTab.QTabTable_Default_Index.AsString;
         if TabKod.Checked then begin
           PrintString(sl, 'Таблица кодирована:', tab_t, tab_s, False, False, False);
           PrintString(sl,'  '+DatTab.QTabTable_Encryption.AsString+'\par', tab_t, tab_s, False, TRUE, False);
         end;// MemTab.FieldByName('Kodir').AsString:=DatTab.QTabTable_Encryption.AsString;
         if TabPerLiv.Checked then begin
           PrintString(sl, 'Уровень доступа тиблицы:', tab_t, tab_s, False, False, False);
           PrintString(sl,'  '+DatTab.QTabPok_Permission_Livel.AsString+'\par', tab_t, tab_s, False, TRUE, False);
         end; // MemTab.FieldByName('PerLiv').AsString:=DatTab.QTabPok_Permission_Livel.AsString;
         if TabMemo.Checked then begin
           PrintString(sl, 'Размер мемо блока тиблицы:', tab_t, tab_s, False, False, False);
           PrintString(sl,'  '+DatTab.QTabTable_Memo_Block_Size.AsString+'\par', tab_t, tab_s, False, TRUE, False);
         end; // MemTab.FieldByName('Memo').AsString:=DatTab.QTabTable_Memo_Block_Size.AsString;
         if TabCom.Checked then begin
           PrintString(sl, 'Описание таблицы:', tab_t, tab_s, False, False, False);
           if Pos('.',DatTab.QTabComment.AsString)=0 then
              PrintString(sl,'  '+Name_NoComent(DatTab.QTabComment.AsString)+'\par', tab_t, tab_s, False, TRUE, False)
           else
           PrintString(sl,'  '+Name_posle(DatTab.QTabComment.AsString)+'\par', tab_t, tab_s, False, TRUE, False);
         end; // MemTab.FieldByName('Com').AsString:=DatTab.QTabComment.AsString;





        //Показываем поля таблицы
        With DatTab.QField do begin
          Active:=false;
          SQL.Clear;
          SQL.Add('Select * From ' + DatTab.SYSTEM_ALIAS + 'columns WHERE Parent='''+DatTab.kmTableName.AsString+'''');
          Active:=true;
        end;

       MemField.Close;
       MemField.DisableControls;
       MemField.Open;
        DatTab.QField.First;
        While not DatTab.QField.Eof do BegiN
        MemField.Append;
         if FieldName.Checked then  MemField.FieldByName('Name').AsString:=DatTab.QFieldName.AsString;
         if FieldNum.Checked then  MemField.FieldByName('Num').AsString:=DatTab.QFieldField_Num.AsString;
         if FieldType.Checked then MemField.FieldByName('Type').AsString:=DatTab.QFieldPok_Field_Type.AsString;
         if FieldLen.Checked then begin
           if FieldSCH.Checked then  MemField.FieldByName('Type').AsString:=MemField.FieldByName('Type').AsString+'('+DatTab.QFieldField_Length.AsString+')' else
            begin
            if DatTab.QFieldPok_Field_Type.AsString='cicharacter' then
            MemField.FieldByName('Type').AsString:=MemField.FieldByName('Type').AsString+'('+DatTab.QFieldField_Length.AsString+')';
            if DatTab.QFieldPok_Field_Type.AsString='character' then
            MemField.FieldByName('Type').AsString:=MemField.FieldByName('Type').AsString+'('+DatTab.QFieldField_Length.AsString+')';
            end;
         end;
         if FieldMin.Checked then MemField.FieldByName('Min').AsString:=DatTab.QFieldField_Min_Value.AsString;
         if FieldMax.Checked then MemField.FieldByName('Max').AsString:=DatTab.QFieldField_Max_Value.AsString;
         if FieldNull.Checked then MemField.FieldByName('Null').AsString:=DatTab.QFieldField_Can_Be_Null.AsString;
         if FieldDef.Checked then MemField.FieldByName('Def').AsString:=DatTab.QFieldField_Default_Value.AsString;
         if FieldCom.Checked then MemField.FieldByName('Com').AsString:=DatTab.QFieldComment.AsString;
        MemField.Post;
        DatTab.QField.Next;
        EnD;

        if FieldNum.Checked then begin
           HeadList.Add('N п/п');
           WidthList.Add(IntToStr(3*(DLIN div dl_2)));
           //ShowMessage('Порядковый номер'+IntToStr(5*(900 div dl_2)));
           CellKeyword.Add('\clvertalc');
        end;
        if FieldName.Checked then begin
           HeadList.Add('Именa полей');
           WidthList.Add(IntToStr(15*(DLIN div dl_2)));
           //ShowMessage('Именa полей'+IntToStr(20*(900 div dl_2)));
           CellKeyword.Add('\clvertalc');
        end;
        if FieldType.Checked then begin
           HeadList.Add('Тип');
           WidthList.Add(IntToStr(10*(DLIN div dl_2)));
           //ShowMessage('Тип'+IntToStr(8*(900 div dl_2)));
           CellKeyword.Add('\clvertalc');
        end;
        {if FieldLen.Checked then begin
           HeadList.Add('Размер (байт)');
           WidthList.Add(IntToStr(7*(DLIN div dl_2)));
           //ShowMessage('Размер (байт)'+IntToStr(7*(900 div dl_2)));
           CellKeyword.Add('\clvertalc');
        end;  }
        if FieldMin.Checked then begin
           HeadList.Add('MIN значение');
           WidthList.Add(IntToStr(8*(DLIN div dl_2)));
           //ShowMessage('MIN значение'+IntToStr(8*(900 div dl_2)));
           CellKeyword.Add('\clvertalc');
        end;
        if FieldMax.Checked then begin
           HeadList.Add('MAX значение');
           WidthList.Add(IntToStr(5*(DLIN div dl_2)));
           //ShowMessage('MAX значение'+IntToStr(5*(900 div dl_2)));
           CellKeyword.Add('\clvertalc');
        end;
        if FieldNull.Checked then begin
           HeadList.Add('Может быть нулевым');
           WidthList.Add(IntToStr(7*(DLIN div dl_2)));
           //ShowMessage('Может быть нулевым'+IntToStr(7*(900 div dl_2)));
           CellKeyword.Add('\clvertalc');
        end;
        if FieldDef.Checked then begin
           HeadList.Add('Значение по умолчанию');
           WidthList.Add(IntToStr(10*(DLIN div dl_2)));
           //ShowMessage('Значение по умолчанию'+IntToStr(10*(900 div dl_2)));
           CellKeyword.Add('\clvertalc');
        end;
        if FieldCom.Checked then begin
           HeadList.Add('Описание поля');
           WidthList.Add(IntToStr(25*(DLIN div dl_2)));
           //ShowMessage('Описание поля'+IntToStr(20*(900 div dl_2)));
           CellKeyword.Add('\clvertalc');
        end;
        if FieldFree.Checked then begin
           HeadList.Add(' ');
           WidthList.Add(IntToStr(7*(DLIN div dl_2)));
           //ShowMessage('Описание поля'+IntToStr(20*(900 div dl_2)));
           CellKeyword.Add('\clvertalc');
        end;
          if Field_size.Value=null then field_s:=12 else field_s:=Field_size.Value;
            if Shf1.Checked then field_t:=0;
            if Shf2.Checked then field_t:=1;
            if Shf3.Checked then field_t:=2;
         PrintTable(sl, MemField, HeadList, WidthList, CellKeyword, field_t, field_s);
        if chInd.Checked then
         PrintString(sl, '  \par', 2, 12, False, False, False)
         else
           begin
           end;
        HeadList.Clear;
        WidthList.Clear;
        CellKeyword.Clear;

        //Показываем идексы
         With DatTab.QIndex do begin
          Active:=false;
          SQL.Clear;
           if ChPrKey.Checked then
            SQL.Add('Select * From ' + DatTab.SYSTEM_ALIAS + 'indexes WHERE Parent='''+DatTab.kmTableName.AsString+'''')
           else
            SQL.Add('Select * From ' + DatTab.SYSTEM_ALIAS + 'indexes WHERE Parent='''+DatTab.kmTableName.AsString+''' and Name<>'''+DatTab.QTabTable_Primary_Key.AsString+'''');
          Active:=true;
        end;

        MemIndex.Close;
        MemIndex.Open;
        DatTab.QIndex.First;
        While not DatTab.QIndex.Eof do
          begin
          MemIndex.Append;
           if IndexName.Checked then  MemIndex.FieldByName('Name').AsString:=DatTab.QIndexName.AsString+'\brdrr';
           if IndexField.Checked then  MemIndex.FieldByName('Field').AsString:=DatTab.QIndexIndex_Expression.AsString;
           if IndexLen.Checked then MemIndex.FieldByName('Len').AsString:=DatTab.QIndexIndex_Key_Length.AsString;
           if IndexMin.Checked then MemIndex.FieldByName('Min').AsString:=DatTab.QIndexIndex_FTS_Min_Length.AsString;
           if IndexCom.Checked then MemIndex.FieldByName('Com').AsString:=DatTab.QIndexComment.AsString;
          MemIndex.Post;
          DatTab.QIndex.Next;
          end;

        if IndexName.Checked then begin
           HeadList.Add('Название индекса');
           WidthList.Add(IntToStr(20*(DLIN div dl_3)));
           CellKeyword.Add('\clvertalc');
        end;
        if IndexField.Checked then begin
           HeadList.Add('Индексные поля');
           WidthList.Add(IntToStr(30*(DLIN div dl_3)));
           CellKeyword.Add('\clvertalc');
        end;
        if IndexLen.Checked then begin
           HeadList.Add('Длина индекса');
           WidthList.Add(IntToStr(7*(DLIN div dl_3)));
           CellKeyword.Add('\clvertalc');
        end;
        if IndexMin.Checked then begin
           HeadList.Add('Min длина');
           WidthList.Add(IntToStr(7*(DLIN div dl_3)));
           CellKeyword.Add('\clvertalc');
        end;
        if IndexCom.Checked then begin
           HeadList.Add('Описание индекса');
           WidthList.Add(IntToStr(26*(DLIN div dl_3)));
           CellKeyword.Add('\clvertalc');
        end;

        if Index_size.Value=null then ind_s:=12 else ind_s:=Index_size.Value;
            if Shi1.Checked then ind_t:=0;
            if Shi2.Checked then ind_t:=1;
            if Shi3.Checked then ind_t:=2;
         if ChInd.Checked then begin
         PrintTable(sl, MemIndex, HeadList, WidthList, CellKeyword, ind_t, ind_s);

         end;
        HeadList.Clear;
        WidthList.Clear;
        CellKeyword.Clear;


      END;
      DatTab.kmTable.Next;
     End; 
          //ShowMessage('По адресу '+Put.Text+' можно увидеть результат');
         DatTab.kmTable.EnableControls;
         DatTab.kmTable.RecNo:=n;
         Flag:=true;
       if not FinishPrint(put.Text, sl, True, Err) then begin
         ShowMessage('Ошибка записи в файл!'+#13+'(Возможно не указан путь для выгрузки rtf)'+Err);
      end;
   finally
      sl.Free;
      HeadList.Free;
      WidthList.Free;
      CellKeyword.Free;
      Tabs.Free;
      HEADform.Cursor:=crDefault;
      BoxProc.Visible:=false;
   end;
   if flag then
   if MessageDlg('Результат соxранён по адресу '+Put.Text+#13+' Хотите открыть этот файл сейчас?',mtConfirmation	,[mbYes,mbNo],0)=mrYes then
       ShellExecute(Application.Handle, nil, PChar(Put.Text), nil, nil, SW_SHOWNORMAL);   
end;



procedure THEADform.TabChekOllClick(Sender: TObject);
begin
TabName.Checked:=true;
TabType.Checked:=true;
TabCreat.Checked:=true;
TabPrKey.Checked:=true;
TabInd.Checked:=true;
TabKod.Checked:=true;
TabPerLiv.Checked:=true;
TabMemo.Checked:=true;
TabCom.Checked:=true;
end;

procedure THEADform.NotTabChekOllClick(Sender: TObject);
begin
TabName.Checked:=false;
TabType.Checked:=false;
TabCreat.Checked:=false;
TabPrKey.Checked:=false;
TabInd.Checked:=false;
TabKod.Checked:=false;
TabPerLiv.Checked:=false;
TabMemo.Checked:=false;
TabCom.Checked:=false;
end;

procedure THEADform.NotFieldChekOlClick(Sender: TObject);
begin
HEADform.FieldName.Checked:=false;
HEADform.FieldNum.Checked:=false;
HEADform.FieldType.Checked:=false;
HEADform.FieldLen.Checked:=false;
HEADform.FieldMin.Checked:=false;
HEADform.FieldMax.Checked:=false;
HEADform.FieldNull.Checked:=false;
HEADform.FieldDef.Checked:=false;
HEADform.FieldCom.Checked:=false;
HEADform.FieldSCH.Checked:=false;
HEADform.FieldFree.Checked:=false;
end;

procedure THEADform.FieldChekOllClick(Sender: TObject);
begin
HEADform.FieldName.Checked:=true;
HEADform.FieldNum.Checked:=true;
HEADform.FieldType.Checked:=true;
HEADform.FieldLen.Checked:=true;
HEADform.FieldMin.Checked:=true;
HEADform.FieldMax.Checked:=true;
HEADform.FieldNull.Checked:=true;
HEADform.FieldDef.Checked:=true;
HEADform.FieldCom.Checked:=true;
HEADform.FieldSCH.Checked:=true;
HEADform.FieldFree.Checked:=true;
end;

procedure THEADform.AdresChange(Sender: TObject);
begin
  if Length(Adres.Text) > 0 then
    BitBtn1.Enabled := true
  else
    BitBtn1.Enabled := false;
end;

procedure THEADform.FormCreate(Sender: TObject);
var
 Ini:TIniFile;
 tab,field,index,Ts,Tt,Ds,Dt,Fs,Ft:string;
begin
   Ini:=TIniFile.Create(ChangeFileExt(Application.ExeName,'.INI'));
    try
     Adres.Text:=Ini.ReadString('PARAM','Adres','');
     Put.Text:=Ini.ReadString('PARAM','Put','');
     tab:=Ini.ReadString('PARAM','Tab','');
     field:=Ini.ReadString('PARAM','Field','');
     index:=Ini.ReadString('PARAM','Index','');
     Ts:=Ini.ReadString('PARAM','Ts','');
     Fs:=Ini.ReadString('PARAM','Fs','');
     Ds:=Ini.ReadString('PARAM','Ds','');
     Tt:=Ini.ReadString('PARAM','Tt','');
     Ft:=Ini.ReadString('PARAM','Ft','');
     Dt:=Ini.ReadString('PARAM','Dt','');


     //устанавливаем метки
     if length(tab)<9 then tab:='000000000';
       if tab[1]='1' then TabName.Checked:=true else TabName.Checked:=false;
       if tab[2]='1' then TabType.Checked:=true else TabType.Checked:=false;
       if tab[3]='1' then TabCreat.Checked:=true else TabCreat.Checked:=false;
       if tab[4]='1' then TabPrKey.Checked:=true else TabPrKey.Checked:=false;
       if tab[5]='1' then TabInd.Checked:=true else TabInd.Checked:=false;
       if tab[6]='1' then TabKod.Checked:=true else TabKod.Checked:=false;
       if tab[7]='1' then TabPerliv.Checked:=true else TabPerliv.Checked:=false;
       if tab[8]='1' then TabMemo.Checked:=true else TabMemo.Checked:=false;
       if tab[9]='1' then TabCom.Checked:=true else TabCom.Checked:=false;
         if length(Ts)>0 then Tab_size.Value:=StrToInt(Ts) else Tab_size.Value:=12;
         if length(Tt)>0 then begin
          if Tt[1]='0' then Sh1.Checked:=true;
          if Tt[1]='1' then Sh2.Checked:=true;
          if Tt[1]='2' then Sh3.Checked:=true;
         end;
    //для полей
      if length(field)<9 then field:='00000000000';
       if field[1]='1' then FieldName.Checked:=true else FieldName.Checked:=false;
       if field[2]='1' then FieldNum.Checked:=true else FieldNum.Checked:=false;
       if field[3]='1' then FieldType.Checked:=true else FieldType.Checked:=false;
       if field[4]='1' then FieldLen.Checked:=true else FieldLen.Checked:=false;
       if field[5]='1' then FieldMin.Checked:=true else FieldMin.Checked:=false;
       if field[6]='1' then FieldMax.Checked:=true else FieldMax.Checked:=false;
       if field[7]='1' then FieldNull.Checked:=true else FieldNull.Checked:=false;
       if field[8]='1' then FieldDef.Checked:=true else FieldDef.Checked:=false;
       if field[9]='1' then FieldCom.Checked:=true else FieldCom.Checked:=false;
       if field[10]='1' then FieldSCH.Checked:=true else FieldSCH.Checked:=false;
       if field[11]='1' then FieldFree.Checked:=true else FieldFree.Checked:=false;
         if length(Fs)>0 then Field_size.Value:=StrToInt(Fs) else Field_size.Value:=12;
         if length(Ft)>0 then begin
          if Ft[1]='0' then Shf1.Checked:=true;
          if Ft[1]='1' then Shf2.Checked:=true;
          if Ft[1]='2' then Shf3.Checked:=true;
         end;
     //для индексов
     if length(index)<7 then index:='0000000';
       if index[1]='1' then ChInd.Checked:=true else ChInd.Checked:=false;
       if index[2]='1' then IndexName.Checked:=true else IndexName.Checked:=false;
       if index[3]='1' then IndexField.Checked:=true else IndexField.Checked:=false;
       if index[4]='1' then IndexLen.Checked:=true else IndexLen.Checked:=false;
       if index[5]='1' then IndexMin.Checked:=true else IndexMin.Checked:=false;
       if index[6]='1' then IndexCom.Checked:=true else IndexCom.Checked:=false;
       if index[7]='1' then ChPrKey.Checked:=true else ChPrKey.Checked:=false;
          if length(Ds)>0 then Index_size.Value:=StrToInt(Ds) else Index_size.Value:=12;
          if length(Dt)>0 then begin
           if Dt[1]='0' then Shi1.Checked:=true;
           if Dt[1]='1' then Shi2.Checked:=true;
           if Dt[1]='2' then Shi3.Checked:=true;
          end;
     //задодим путь по умолчанию
     if Length(Put.Text)=0 then Put.Text:='F:\temp.doc';
    finally
     ini.Free;
    end;
  if ChInd.Checked then GrInd.Visible:=true else GrInd.Visible:=false;
  if HEADform.FieldLen.Checked then FieldSCH.Enabled:=true else FieldSCH.Enabled:=false;
end;

procedure THEADform.FormDestroy(Sender: TObject);
var
Ini:TIniFile;
 tab,field,index,Ts,Tt,Ds,Dt,Fs,Ft:string;
 i:integer;
begin
tab:='';  field:=''; index:=''; Ts:=''; Tt:=''; Ds:=''; Dt:=''; Fs:=''; Ft:='';
        //устанавливаем метки
       if TabName.Checked then tab:=tab+'1' else tab:=tab+'0';
       if TabType.Checked then tab:=tab+'1' else tab:=tab+'0';
       if TabCreat.Checked then tab:=tab+'1' else tab:=tab+'0';
       if TabPrKey.Checked then tab:=tab+'1' else tab:=tab+'0';
       if TabInd.Checked then tab:=tab+'1' else tab:=tab+'0';
       if TabKod.Checked then tab:=tab+'1' else tab:=tab+'0';
       if TabPerliv.Checked then tab:=tab+'1' else tab:=tab+'0';
       if TabMemo.Checked then tab:=tab+'1' else tab:=tab+'0';
       if TabCom.Checked then tab:=tab+'1' else tab:=tab+'0';
       if Tab_size.Value=null then Ts:='12' else Ts:=Tab_size.Text;
       if Sh1.Checked then Tt:='0';
       if Sh2.Checked then Tt:='1';
       if Sh3.Checked then Tt:='2';
        //для полей
       if FieldName.Checked then field:=field+'1' else field:=field+'0';
       if FieldNum.Checked then field:=field+'1' else field:=field+'0';
       if FieldType.Checked then field:=field+'1' else field:=field+'0';
       if FieldLen.Checked then field:=field+'1' else field:=field+'0';
       if FieldMin.Checked then field:=field+'1' else field:=field+'0';
       if FieldMax.Checked then field:=field+'1' else field:=field+'0';
       if FieldNull.Checked then field:=field+'1' else field:=field+'0';
       if FieldDef.Checked then field:=field+'1' else field:=field+'0';
       if FieldCom.Checked then field:=field+'1' else field:=field+'0';
       if FieldSCH.Checked then field:=field+'1' else field:=field+'0';
       if FieldFree.Checked then field:=field+'1' else field:=field+'0';
       if Field_size.Value=null then Fs:='12' else Fs:=Field_size.Text;
       if Shf1.Checked then Ft:='0';
       if Shf2.Checked then Ft:='1';
       if Shf3.Checked then Ft:='2';
        //для индексов
       if ChInd.Checked then index:=index+'1' else index:=index+'0';
       if IndexName.Checked then index:=index+'1' else index:=index+'0';
       if IndexField.Checked then index:=index+'1' else index:=index+'0';
       if IndexLen.Checked then index:=index+'1' else index:=index+'0';
       if IndexMin.Checked then index:=index+'1' else index:=index+'0';
       if IndexCom.Checked then index:=index+'1' else index:=index+'0';
       if ChPrKey.Checked then index:=index+'1' else index:=index+'0';
       if Index_size.Value=null then Ds:='12' else Ds:=Index_size.Text;
       if Shi1.Checked then Dt:='0';
       if Shi2.Checked then Dt:='1';
       if Shi3.Checked then Dt:='2';


  Ini:=TIniFile.Create(ChangeFileExt(Application.ExeName,'.INI'));
    try
     if Length(Adres.Text)>0 then
     Ini.WriteString('PARAM','Adres',Adres.Text);
     if Length(Put.Text)>0 then
     Ini.WriteSTring('PARAM','Put',Put.Text);
     Ini.WriteSTring('PARAM','Tab',tab);
     Ini.WriteSTring('PARAM','Field',field);
     Ini.WriteSTring('PARAM','Index',index);
     Ini.WriteSTring('PARAM','Ts',Ts);
     Ini.WriteSTring('PARAM','Tt',Tt);
     Ini.WriteSTring('PARAM','Ft',Ft);
     Ini.WriteSTring('PARAM','Fs',Fs);
     Ini.WriteSTring('PARAM','Ds',Ds);
     Ini.WriteSTring('PARAM','Dt',Dt);
     finally
     ini.Free;
    end;
end;



procedure THEADform.ChIndClick(Sender: TObject);
begin
  if ChInd.Checked then GrInd.Visible:=true else GrInd.Visible:=false;
end;

procedure THEADform.IndexChekOllClick(Sender: TObject);
begin
IndexName.Checked:=true;
IndexField.Checked:=true;
IndexLen.Checked:=true;
IndexMin.Checked:=true;
IndexCom.Checked:=true;
end;

procedure THEADform.NotIndexChekOllClick(Sender: TObject);
begin
IndexName.Checked:=false;
IndexField.Checked:=false;
IndexLen.Checked:=false;
IndexMin.Checked:=false;
IndexCom.Checked:=false;
end;

procedure THEADform.FieldLenClick(Sender: TObject);
begin
if FieldLen.Checked then FieldSCH.Enabled:=true else FieldSCH.Enabled:=false;
end;


procedure THEADform.RVClick(Sender: TObject);
var
N_strok,N_podr,n:integer;
begin
try
N_strok:=DatTab.kmTableNR.AsInteger;
N_podr:=DatTab.kmTableNP.AsInteger;
if N_strok>1 then Begin
DatTab.kmTable.IndexName:='';
DatTab.kmTable.DisableControls;

//Присваиваем записям с номером ниже мах значение
    DatTab.kmTable.First;
    While not DatTab.kmTable.Eof do begin
      if DatTab.kmTableNR.AsInteger=N_strok-1 then begin
         DatTab.kmTable.Edit;
         DatTab.kmTableNR.AsInteger:=DatTab.kmTable.RecordCount+1;
      end;
      DatTab.kmTable.Next;
    end;
//Присваиваем записям с Требуемым номером значение -1
    DatTab.kmTable.First;
    While not DatTab.kmTable.Eof do begin
      if DatTab.kmTableNR.AsInteger=N_strok then begin
         DatTab.kmTable.Edit;
         DatTab.kmTableNR.AsInteger:=N_strok-1;
      end;
      DatTab.kmTable.Next;
    end;
//Присваиваем записям с максимальным значение номер  N_strok
    DatTab.kmTable.First;
    While not DatTab.kmTable.Eof do begin
      if DatTab.kmTableNR.AsInteger=DatTab.kmTable.RecordCount+1 then begin
         DatTab.kmTable.Edit;
         DatTab.kmTableNR.AsInteger:=N_strok;
      end;
      DatTab.kmTable.Next;
    end;
    DatTab.kmTable.IndexName:='IndPor';
DatTab.kmTable.EnableVersioning;;
   DatTab.kmTable.First;
    While not DatTab.kmTable.Eof do begin
      if (DatTab.kmTableNR.AsInteger=N_strok-1) and (DatTab.kmTableNP.AsInteger=N_podr) then
      n:=DatTab.kmTable.RecNo;
      DatTab.kmTable.Next;
    end;
    DatTab.kmTable.RecNo:=n;
DatTab.kmTable.EnableControls;
end;
except
MessageDlg('Ошибка!!! Раздел не найден',mtWarning,[mbOk],0);
end;
end;

procedure THEADform.PVClick(Sender: TObject);
var
P,n,R:integer;
begin
n:=DatTab.kmTable.RecNo;
P:=DatTab.kmTableNP.AsInteger;
R:=DatTab.kmTableNR.AsInteger;
 if P>1 then begin
    DatTab.kmTable.DisableControls;
    DatTab.kmTable.First;
    While not DatTab.kmTable.Eof do begin
      if (DatTab.kmTableNP.AsInteger=P-1) and (DatTab.kmTableNR.AsInteger=R) then begin
      DatTab.kmTable.Edit;
      DatTab.kmTableNP.AsInteger:=P;
      DatTab.kmTable.Next;
      DatTab.kmTable.Edit;
      DatTab.kmTableNP.AsInteger:=P-1
      end;
      DatTab.kmTable.Next;
    end;
 DatTab.kmTable.IndexName:='IndPor';
 DatTab.kmTable.RecNo:=n-1;
 DatTab.kmTable.EnableControls;
 end;
end;
procedure THEADform.PNClick(Sender: TObject);
var
sch,R,P,n:integer;
begin
try
R:=DatTab.kmTableNR.AsInteger;
P:=DatTab.kmTableNP.AsInteger;
n:=DatTab.kmTable.RecNo;
sch:=0;
DatTab.kmTable.DisableControls;
DatTab.kmTable.First;
While not DatTab.kmTable.Eof do begin
  if DatTab.kmTableNR.AsInteger=R then
  inc(sch);
  DatTab.kmTable.Next;
end;

DatTab.kmTable.RecNo:=n;
 if DatTab.kmTableNP.AsInteger<sch then begin
 DatTab.kmTable.First;
   While not DatTab.kmTable.Eof do begin
    if (DatTab.kmTableNP.AsInteger=P) and (DatTab.kmTableNR.AsInteger=R) then begin
       DatTab.kmTable.Edit;
       DatTab.kmTableNP.AsInteger:=P+1;
       DatTab.kmTable.Next;
       DatTab.kmTable.Edit;
       DatTab.kmTableNP.AsInteger:=P;
    end;

    DatTab.kmTable.Next;
   end;
  DatTab.kmTable.IndexName:='IndPor';
  DatTab.kmTable.RecNo:=n+1;
 end;

DatTab.kmTable.EnableControls;
except
MessageDlg('Ошибка!!! Подраздел не найден',mtWarning,[mbOk],0);
end;
end;

procedure THEADform.DBGridEh1GetCellParams(Sender: TObject;
  Column: TColumnEh; AFont: TFont; var Background: TColor;
  State: TGridDrawState);
begin
if (DatTab.kmTable.FieldValues['NR'] mod 2) =0 then
    Background:=clMoneyGreen
    else Background:=clCream;
end;

procedure THEADform.RNClick(Sender: TObject);
var
R_count,P,R,n:integer;
s:string;
begin
R:=DatTab.kmTableNR.AsInteger;
P:=DatTab.kmTableNP.AsInteger;
//Вначале узнаем количество разделов
R_count:=0;
s:='';
DatTab.kmTable.DisableControls;
try
DatTab.kmTable.First;
While not DatTab.kmTable.Eof do begin
  if DatTab.kmTableRazdel.AsString<>s then begin
  s:=DatTab.kmTableRazdel.AsString;
  inc(R_count);
  end;
DatTab.kmTable.Next;
end;

   if R<R_count then begin
   DatTab.kmTable.IndexName:='';
     DatTab.kmTable.First;
     While not DatTab.kmTable.Eof do begin
       if DatTab.kmTableNR.AsInteger=R+1 then begin
          DatTab.kmTable.Edit;
          DatTab.kmTableNR.AsInteger:=DatTab.kmTable.RecordCount+1;
       end;
       DatTab.kmTable.Next;
     end;

    DatTab.kmTable.First;
     While not DatTab.kmTable.Eof do begin
       if DatTab.kmTableNR.AsInteger=R then begin
          DatTab.kmTable.Edit;
          DatTab.kmTableNR.AsInteger:=R+1;
       end;
       DatTab.kmTable.Next;
     end;

     DatTab.kmTable.First;
     While not DatTab.kmTable.Eof do begin
       if DatTab.kmTableNR.AsInteger=DatTab.kmTable.RecordCount+1 then begin
          DatTab.kmTable.Edit;
          DatTab.kmTableNR.AsInteger:=R;
       end;
       DatTab.kmTable.Next;
     end;

     DatTab.kmTable.IndexName:='IndPor';

     DatTab.kmTable.First;
     While not DatTab.kmTable.Eof do begin
       if (DatTab.kmTableNR.AsInteger=R+1) and (DatTab.kmTableNP.AsInteger=P) then
       n:=DatTab.kmTable.RecNo;
       DatTab.kmTable.Next;
     end;
     DatTab.kmTable.RecNo:=n;
   end;
DatTab.kmTable.EnableControls;
except
MessageDlg('Невозможно произвести перемещение',MtWarning,[mbOk],0);
end;
end;

procedure THEADform.DBGridEh1CellClick(Column: TColumnEh);
begin

 if Column.ID=0  then
 if DatTab.kmTableChech.AsBoolean=true then Ln.Caption:=IntToStr(StrToInt(Ln.Caption)-1) else
 Ln.Caption:=IntToStr(StrToInt(Ln.Caption)+1);
if DatTab.kmTable.Modified then OtmechTabl;

end;





procedure THEADform.FormClose(Sender: TObject; var Action: TCloseAction);
var flag:boolean;
begin
if Length(FileNames)>0 then
If MessageDlg('Сохранить изменения',mtInformation,[mbYes,mbNo],0)=mrYes then begin
  try
   flag:=false;
   DatTab.kmTable.SaveToFile(ExtractFilePath(Application.ExeName)+'Files\'+FileNames+'.sav');
  except
  flag:=true;
  MessageDlg('Ошибка записи в файл!',mtError,[mbOk],0);
  end;
     if not flag then begin
      DeleteFile(ExtractFilePath(Application.ExeName)+'Files\'+FileNames+'.sav');
      DatTab.kmTable.SaveToFile(ExtractFilePath(Application.ExeName)+'Files\'+FileNames+'.sav');
     end;
 end;
end;



procedure THEADform.GAllClick(Sender: TObject);
var
n,R:integer;
begin
try
R:=DatTab.kmTableNR.AsInteger;
  With DatTab.kmTable do begin
  n:=RecNo;
  DatTab.kmTable.DisableControls;
  First;
    While not Eof do begin
     if DatTab.kmTableNR.AsInteger=R then begin
        Edit;
        DatTab.kmTableChech.AsBoolean:=true;
        end;
     Next;
    end;
  RecNo:=n;
  EnableControls;
  end;
OtmechTabl;
except
MessageDlg('Не возможно отметить таблицы!',mtWarning,[mbOk],0);
end;
end;

procedure THEADform.GNowClick(Sender: TObject);
var
n,R:integer;
begin
try
R:=DatTab.kmTableNR.AsInteger;
  With DatTab.kmTable do begin
  n:=RecNo;
  DatTab.kmTable.DisableControls;
  First;
    While not Eof do begin
     if DatTab.kmTableNR.AsInteger=R then begin
        Edit;
        DatTab.kmTableChech.AsBoolean:=false;
        end;
     Next;
    end;
  RecNo:=n;
  EnableControls;
  end;
OtmechTabl;
except
MessageDlg('Не возможно отметить таблицы!',mtWarning,[mbOk],0);
end;
end;

end.
