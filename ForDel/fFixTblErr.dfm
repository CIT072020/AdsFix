object fmFixAds: TfmFixAds
  Left = 698
  Top = 178
  Width = 627
  Height = 613
  Caption = #1055#1088#1086#1074#1077#1088#1082#1072' ADS-'#1090#1072#1073#1083#1080#1094
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object mmProt: TMemo
    Left = 49
    Top = 87
    Width = 513
    Height = 393
    Lines.Strings = (
      'mmProt')
    TabOrder = 0
  end
  object btnTestAndFix: TButton
    Left = 55
    Top = 513
    Width = 137
    Height = 25
    Caption = #1048#1089#1087#1088#1072#1074#1080#1090#1100
    Enabled = False
    TabOrder = 1
    OnClick = btnTestAndFixClick
  end
  object btnRet2Orig: TButton
    Left = 228
    Top = 513
    Width = 137
    Height = 25
    Caption = #1042#1086#1089#1089#1090#1072#1085#1086#1074#1080#1090#1100' '#1086#1088#1080#1075#1080#1085#1072#1083
    Enabled = False
    TabOrder = 2
  end
  object btnExit: TButton
    Left = 401
    Top = 513
    Width = 137
    Height = 25
    Caption = #1042#1099#1093#1086#1076
    TabOrder = 3
    OnClick = btnExitClick
  end
end
