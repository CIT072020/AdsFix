�
 TFORMMAIN 0�  TPF0	TFormMainFormMainLeftTop� WidthcHeight1Caption!   Проверка ADS-таблицColor	clBtnFaceFont.CharsetDEFAULT_CHARSET
Font.ColorclWindowTextFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold Menu	MainMenu1OldCreateOrderPositionpoScreenCenterOnCreate
FormCreate	OnDestroyFormDestroyPixelsPerInch`
TextHeight TLabelLtabKLeftTopNWidtheHeightCaption   Найдено таблиц:Font.CharsetDEFAULT_CHARSET
Font.ColorclGrayFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold 
ParentFont  TLabelLvidKLeftTopeWidthlHeightCaption   Отмечено таблиц:Font.CharsetDEFAULT_CHARSET
Font.ColorclGrayFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold 
ParentFont  TLabelLnLeft~TopLWidthHeightCaption0Font.CharsetDEFAULT_CHARSET
Font.ColorclGrayFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold 
ParentFont  TLabellblTotalInsLeft� TopeWidthyHeightCaption"   Вставлено записей:Font.CharsetDEFAULT_CHARSET
Font.ColorclGrayFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold 
ParentFont  TLabel	lblResInsLeftXTopeWidthHeightCaption000Font.CharsetDEFAULT_CHARSET
Font.ColorclGrayFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold 
ParentFont  TPanelPanel1Left Top WidthSHeightIAlignalTopTabOrder  TLabelLabel2LeftTop,WidthFHeightCaption   Путь к TMPFont.CharsetDEFAULT_CHARSET
Font.ColorclGrayFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold 
ParentFont  TLabellblPath2TmpLeftTopWidth>HeightCaption   Путь к БДFont.CharsetDEFAULT_CHARSET
Font.ColorclGrayFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold 
ParentFont  	TDBEditEhedtPath2TmpLeftgTop)Width�HeightEditButtonsStyleebsEllipsisEhWidthOnClickChangePath2TmpClick  Font.CharsetDEFAULT_CHARSET
Font.ColorclWindowTextFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold Flat	
ParentFontTabOrderVisible	OnChangeedtPath2TmpChange  TDBComboBoxEhcbbPath2SrcLeftgTopWidth�HeightCtl3DEditButtons Items.Strings%   Выбор словаря базы....   Выбор папки с таблицами... ParentCtl3DTabOrder Visible	OnChangecbbPath2SrcChange	OnCloseUpcbbPath2SrcCloseUp
OnDropDowncbbPath2SrcDropDown  TButton	btnFixAllLeft8TopWidthyHeightCaption   Исправить всеTabOrderOnClickbtnFixAllClick  TButtonbtnFullFixOneLeft�TopWidth� HeightCaption%   Исправить выбранныеTabOrderOnClickbtnFullFixOneClick  TButtonbtnTestQLeft�TopWidth� HeightCaption#   Исправить 1 таблицуTabOrderOnClickbtnTestQClick   TPanelPanel2Left Top� WidthSHeightvAlignalBottomCaptionPanel2TabOrder 	TSplitter	Splitter1LeftTop�WidthQHeightCursorcrVSplitAlignalBottom  	TSplitter	Splitter2Left�TopWidth	Height�AutoSnap  TPanelPanel3LeftTop�WidthQHeight� AlignalBottomTabOrder  	TDBGridEhdbgPlanLeftTop WidthIHeight� 
DataSourcedtmdlADS.dsPlanFooterColorclWindowFooterFont.CharsetDEFAULT_CHARSETFooterFont.ColorclWindowTextFooterFont.Height�FooterFont.NameMS Sans SerifFooterFont.StylefsBold TabOrder TitleFont.CharsetDEFAULT_CHARSETTitleFont.ColorclWindowTextTitleFont.Height�TitleFont.NameMS Sans SerifTitleFont.StylefsBold    TPanelPanel4LeftTopWidth�Height�AlignalLeftCaptionPanel4TabOrder 	TDBGridEhdbgAllTLeftTopWidthhHeight`AlignalCustom
DataSourcedtmdlADS.dsSrcFooterColorclWindowFooterFont.CharsetDEFAULT_CHARSETFooterFont.ColorclWindowTextFooterFont.Height�FooterFont.NameMS Sans SerifFooterFont.StylefsBold 	SortLocal	TabOrderTitleFont.CharsetDEFAULT_CHARSETTitleFont.ColorclWindowTextTitleFont.Height�TitleFont.NameMS Sans SerifTitleFont.StylefsBold ColumnsEditButtons 	FieldNameNppFooters ReadOnly	Title.Caption	   № п/пWidth- EditButtons 	FieldNameStateFooters Title.Caption   !B0BCATitle.SortIndexTitle.SortMarkersmDownEhWidth< AlwaysShowEditButton	EditButtons 	FieldNameIsMarkFooters Title.Caption   K1@0= EditButtons 	FieldNameTableCaptionFooters Title.AlignmenttaCenterTitle.Caption   08<5=>20=85Width, EditButtons 	FieldNameTestCodeFooters Title.Caption   Тест-Код EditButtons 	FieldName	ErrNativeFooters Title.Caption   #B>G=>4 EditButtons 	FieldNameFixCodeFooters Title.Caption   Испр-Код EditButtons 	FieldNameAIncsFooters Title.Caption   АвтоInc EditButtons 	FieldName	TableNameFooters Title.Caption   "01;8F0    TButtonbtnProcMarkLeftVTopgWidth� HeightCaption   Исправить копиюTabOrderOnClickbtnProcMarkClick  TButtonbtnGetFixedLeft�TopgWidth� HeightCaption   Копия -> ОригиналTabOrderOnClickbtnGetFixedClick  TButtonbtnRestOrigLeft�TopgWidth� HeightCaption)   Восстановить оригиналTabOrderOnClickbtnRestOrigClick  TButtonbtnTestLeft� TopgWidth� HeightCaption	   @>25@8BLTabOrder OnClickbtnTestClick  TBitBtn
btnTblListLeftTophWidth}HeightCaption   Список таблицEnabledTabOrderOnClickbtnTblListClick   TPanelPanel5Left�TopWidth� Height�AlignalLeft	AlignmenttaRightJustifyTabOrder TRadioGrouprgDelDupModeLeftTop� Width� HeightICaption    Удалить дубли Items.Strings   все   кроме 1 #   выбор пользователя TabOrderOnClickrgDelDupModeClick  TRadioGroup
rgTestModeLeftTop$Width� HeightICaption%    Режим тестирования Items.Strings   простой   средний   медленный TabOrderOnClickrgTestModeClick  	TCheckBoxchkAutoTestLeftTopWidth� HeightCaption!   Авто-тестированиеChecked	State	cbCheckedTabOrder OnClickchkAutoTestClick  	TCheckBoxchkUseWCopyLeftTopxWidth� HeightCaption&   Исправления на копииChecked	State	cbCheckedTabOrderOnClickchkUseWCopyClick  	TCheckBoxchkRewriteCopyLeftTop� Width� HeightCaption   Перезапись копииChecked	State	cbCheckedTabOrderOnClickchkRewriteCopyClick  	TCheckBox	chkBackUpLeftTop� Width� HeightCaption   BackUp исходнойChecked	State	cbCheckedTabOrderOnClickchkBackUpClick    	TGroupBox
grpBoxProcLeft8TopOWidthQHeight)Caption    Обработка Font.CharsetDEFAULT_CHARSET
Font.ColorclGrayFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold 
ParentFontTabOrder TLabel Left	TopWidth7HeightCaption   Таблица:Font.CharsetDEFAULT_CHARSET
Font.ColorclBlackFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold 
ParentFont  TLabellblTabNLeftDTopWidthHeightFont.CharsetDEFAULT_CHARSET
Font.ColorclBlackFont.Height�	Font.NameMS Sans Serif
Font.Style 
ParentFont  TProgressBarpbProgLeft� TopWidth� HeightTabOrder    TButtonbtnTTmpLeft�Top`WidthKHeightCaptionbtnTTmpTabOrderOnClickbtnTTmpClick  TOpenDialog
OpenDialogLeft TopX  	TMainMenu	MainMenu1Left TopX 	TMenuItemN1    