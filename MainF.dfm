�
 TFORMMAIN 0�  TPF0	TFormMainFormMainLeft.Top� Width6HeightCaption#   Верификация таблицColor	clBtnFaceFont.CharsetDEFAULT_CHARSET
Font.ColorclWindowTextFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold Menu	MainMenu1OldCreateOrderPositionpoScreenCenterOnCreate
FormCreate	OnDestroyFormDestroyPixelsPerInch`
TextHeight TLabelLtabKLeftTopgWidtheHeightCaption   Найдено таблиц:Font.CharsetDEFAULT_CHARSET
Font.ColorclGrayFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold 
ParentFont  TLabelLvidKLeftTopwWidthlHeightCaption   Отмечено таблиц:Font.CharsetDEFAULT_CHARSET
Font.ColorclGrayFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold 
ParentFont  TLabelLnLeft~TophWidthHeightCaption0Font.CharsetDEFAULT_CHARSET
Font.ColorclGrayFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold 
ParentFont  TPanelPanel1Left Top Width&HeightYAlignalTopTabOrder  TLabelLabel2LeftTop,WidthFHeightCaption   Путь к TMPFont.CharsetDEFAULT_CHARSET
Font.ColorclGrayFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold 
ParentFont  TLabellblPath2TmpLeftTopWidth>HeightCaption   Путь к БДFont.CharsetDEFAULT_CHARSET
Font.ColorclGrayFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold 
ParentFont  	TDBEditEhedtPath2TmpLeftgTop)Width�HeightEditButtonsStyleebsEllipsisEhWidthOnClickChangePath2TmpClick  Font.CharsetDEFAULT_CHARSET
Font.ColorclWindowTextFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold Flat	
ParentFontTabOrderVisible	OnChangeedtPath2TmpChange  TDBComboBoxEhcbbPath2SrcLeftgTopWidth�HeightCtl3DEditButtons Items.Strings%   Выбор словаря базы....   Выбор папки с таблицами... ParentCtl3DTabOrder Visible	OnChangecbbPath2SrcChange	OnCloseUpcbbPath2SrcCloseUp
OnDropDowncbbPath2SrcDropDown  TButton	btnFixAllLeft8TopWidthyHeightCaption   Исправить всеTabOrderOnClickbtnFixAllClick   TPanelPanel2Left Top� Width&Height:AlignalBottomCaptionPanel2TabOrder 	TSplitter	Splitter1LeftTop�Width$HeightCursorcrVSplitAlignalBottom  	TSplitter	Splitter2Left�TopWidth	Height�AutoSnap  TPanelPanel3LeftTop�Width$HeighthAlignalBottomTabOrder  	TGroupBoxBoxProcLeft(Top	Width�HeightQCaption   Процесс выгрузкиFont.CharsetDEFAULT_CHARSET
Font.ColorclGrayFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold 
ParentFontTabOrder  TLabel Left	TopWidth7HeightCaption   Таблица:Font.CharsetDEFAULT_CHARSET
Font.ColorclBlackFont.Height�	Font.NameMS Sans Serif
Font.StylefsBold 
ParentFont  TLabelTabNLeftDTopWidthHeightFont.CharsetDEFAULT_CHARSET
Font.ColorclBlackFont.Height�	Font.NameMS Sans Serif
Font.Style 
ParentFont  TProgressBarProgLeftTop0Width�HeightTabOrder     TPanelPanel4LeftTopWidth�Height�AlignalLeftCaptionPanel4TabOrder 	TDBGridEhdbgAllTLeftTopWidth�Height`AlignalCustom
DataSourcedtmdlADS.dsSrcFooterColorclWindowFooterFont.CharsetDEFAULT_CHARSETFooterFont.ColorclWindowTextFooterFont.Height�FooterFont.NameMS Sans SerifFooterFont.StylefsBold 	SortLocal	TabOrderTitleFont.CharsetDEFAULT_CHARSETTitleFont.ColorclWindowTextTitleFont.Height�TitleFont.NameMS Sans SerifTitleFont.StylefsBold ColumnsEditButtons 	FieldNameNppFooters ReadOnly	Title.Caption	   № п/пWidth- EditButtons 	FieldNameStateFooters Title.Caption   !B0BCATitle.SortIndexTitle.SortMarkersmDownEhWidth< AlwaysShowEditButton	DblClickNextVal	EditButtons 	FieldNameIsMarkFooters Title.Caption   K1@0= EditButtons 	FieldNameTableCaptionFooters Title.AlignmenttaCenterTitle.Caption   08<5=>20=85Width, EditButtons 	FieldNameTestCodeFooters Title.Caption   Тест-Код EditButtons 	FieldName	ErrNativeFooters Title.Caption   #B>G=>4 EditButtons 	FieldNameFixCodeFooters Title.Caption   Испр-Код EditButtons 	FieldNameAIncsFooters Title.Caption   АвтоInc EditButtons 	FieldName	TableNameFooters Title.Caption   "01;8F0    TButtonbtnProcMarkLeft� Top�Width� HeightCaption   Fix копиюTabOrderOnClickbtnProcMarkClick  TButtonbtnGetFixedLeftuTop�Width� HeightCaption#   Исправить оригиналTabOrderOnClickbtnGetFixedClick  TButton
btnDelOrigLeft"Top�Width� HeightCaption   Удалить оригиналTabOrderOnClickbtnDelOrigClick  TButtonbtnTestLeftTop�Width� HeightCaption	   @>25@8BLTabOrder OnClickbtnTestClick  TBitBtn
btnTblListLeftTopyWidth� HeightCaption   Список таблицEnabledTabOrderOnClickbtnTblListClick  	TCheckBoxchkAutoTestLeft� Top|Width� HeightCaption!   Авто-тестированиеChecked	State	cbCheckedTabOrderOnClickchkAutoTestClick  TButtonbtnFullFixOneLeft"TopxWidth� HeightCaption   Fix выбранныеTabOrderOnClickbtnFullFixOneClick   TPanelPanel5Left�TopWidth/Height�AlignalLeft	AlignmenttaRightJustifyTabOrder TRadioGrouprgDelDupModeLeft� TopaWidth� HeightICaption    Удалить дубли Items.Strings   все   кроме 1 #   выбор пользователя TabOrder OnClickrgDelDupModeClick  TRadioGroup
rgTestModeLeft� TopWidth� HeightICaption%    Режим тестирования Items.Strings   простой   средний   медленный TabOrderOnClickrgTestModeClick    TOpenDialog
OpenDialogLeft�Top`  	TMainMenu	MainMenu1LeftPTop` 	TMenuItemN1    