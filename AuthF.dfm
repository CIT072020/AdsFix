object FormAuth: TFormAuth
  Left = 510
  Top = 388
  Width = 389
  Height = 194
  Caption = #1057#1086#1077#1076#1080#1085#1077#1085#1080#1077'...'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 53
    Top = 34
    Width = 112
    Height = 16
    Caption = #1055#1086#1083#1100#1079#1086#1074#1072#1090#1077#1083#1100':'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'MS Sans Serif'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object Label2: TLabel
    Left = 55
    Top = 78
    Width = 60
    Height = 16
    Caption = #1055#1072#1088#1086#1083#1100':'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'MS Sans Serif'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object Login: TDBEditEh
    Left = 168
    Top = 32
    Width = 161
    Height = 21
    EditButtons = <>
    TabOrder = 0
    Text = 'AdsSys'
    Visible = True
    OnKeyUp = LoginKeyUp
  end
  object Parol: TDBEditEh
    Left = 168
    Top = 74
    Width = 161
    Height = 21
    EditButtons = <>
    PasswordChar = '*'
    TabOrder = 1
    Visible = True
    OnChange = ParolChange
    OnKeyUp = ParolKeyUp
  end
  object Vxod: TBitBtn
    Left = 168
    Top = 120
    Width = 75
    Height = 25
    Caption = #1042#1093#1086#1076
    TabOrder = 2
    OnClick = VxodClick
    Glyph.Data = {
      36030000424D3603000000000000360000002800000010000000100000000100
      18000000000000030000C40E0000C40E00000000000000000000FFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6
      FCFAEFFBF7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF63C8A025B884EBFDF8FFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFEFE81D8B706
      9E620491573EBB90F6FDFAFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFF9FDBC40BA46817A66D189B650190575BC7A2F9FEFCFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC9F3E416A76F1AA56E1F
      A7721BA36D1595600392597BD2B5FDFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFE0FAF14CDBAA16AB721FA67223A57220A36F1BA06B13915D06965E9EE3
      CCFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF63DEB529C38A22B0792AAF7C31
      B3832DB2811EA46F1B9D69118D5910A26BBAEADAFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFF9FF0DA68DEBA3AC39032BE8B49C39662D3AF3ABB8E20A46E1D9C691190
      5C1AA673FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0FBF89CECD759D5AE2FC38CC2
      EDDCF5FDFB76DBC237BA8C21A7721E9E6A0E8F5BFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFEAFEF967D2B0A6E4CDFFFFFFFFFFFFE5F9F570D9BD3ABD8F1FA9
      731DAA73FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF4FBF9FDFEFEFF
      FFFFFFFFFFFFFFFFD7F6EF63D5B423BE8569D6ACFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBEF7E57EEF
      C6E2FAF0FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFDFFFEF8FFFCFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
  end
  object Vixod: TBitBtn
    Left = 256
    Top = 120
    Width = 75
    Height = 25
    Caption = #1054#1090#1084#1077#1085#1072
    TabOrder = 3
    OnClick = VixodClick
    Glyph.Data = {
      36030000424D3603000000000000360000002800000010000000100000000100
      18000000000000030000C40E0000C40E00000000000000000000FFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5C64E4FFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFF444CDFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFF5C64E42338E21E2FDBFFFFFFFFFFFFFFFFFF1F2CCE1A2DDF2430
      D6FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF9498F0263CE63851E5394FE626
      38DFFFFFFF3441D8273EE43146E21E33E23642E6FFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFF818AE43A52E63A51E53D53E7253CE23347E4374DE22F45E31B2B
      D7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF949AE7475DE73D
      53E63F57E73C53E5374DE52F3DDFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFF5865E14D61E84259E63F56E72C43E3FFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5862E0808DEF7B
      89EC6B7CEC586BE94E64E83647E0FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFF7580E6A0ACF59CA8F3909FF1707EE97E8BEF707FED6878EC3D4B
      E0FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBDC1F9BFC7F6C5CEFAB4C1F873
      80E8FFFFFF707FED8894F07D8CEC6979EE5661EDFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFC5C6EADFE2FA949FEEFFFFFFFFFFFFFFFFFFB5B9E98A9AF15F6B
      DDFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFCBCDFAFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFB1B9F7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
  end
  object ChB: TCheckBox
    Left = 24
    Top = 125
    Width = 129
    Height = 17
    Caption = #1054#1090#1086#1073#1088#1072#1078#1072#1090#1100' '#1087#1072#1088#1086#1083#1100
    TabOrder = 4
    OnClick = ChBClick
  end
end
