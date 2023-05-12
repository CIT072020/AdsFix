object dtmdlADS: TdtmdlADS
  OldCreateOrder = False
  Left = 1262
  Top = 217
  Height = 263
  Width = 549
  object cnnSrcAds: TAdsConnection
    AdsServerTypes = [stADS_LOCAL]
    LoginPrompt = False
    Username = 'AdsSys'
    Password = 'sysdba'
    Left = 32
    Top = 32
  end
  object qTablesAll: TAdsQuery
    AdsConnection = cnnSrcAds
    Left = 104
    Top = 32
    ParamData = <>
  end
  object qAny: TAdsQuery
    AdsConnection = cnnSrcAds
    Left = 32
    Top = 88
    ParamData = <>
  end
  object dsSrc: TDataSource
    Left = 112
    Top = 160
  end
  object tblAds: TAdsTable
    AdsConnection = cnnSrcAds
    AdsTableOptions.AdsRightsCheck = False
    IndexCollationMismatch = icmIgnore
    Left = 40
    Top = 160
  end
  object cnnTmp: TAdsConnection
    AdsServerTypes = [stADS_LOCAL]
    Left = 368
    Top = 32
  end
  object qDst: TAdsQuery
    AdsConnection = cnnTmp
    Left = 424
    Top = 32
    ParamData = <>
  end
  object qSrcFields: TAdsQuery
    AdsConnection = cnnSrcAds
    Left = 168
    Top = 32
    ParamData = <>
  end
  object qSrcIndexes: TAdsQuery
    AdsConnection = cnnSrcAds
    Left = 176
    Top = 96
    ParamData = <>
  end
  object qDupGroups: TAdsQuery
    AdsConnection = cnnTmp
    Left = 368
    Top = 128
    ParamData = <>
  end
  object tblTmp: TAdsTable
    AdsConnection = cnnTmp
    Left = 432
    Top = 128
  end
  object dsPlan: TDataSource
    DataSet = qDst
    Left = 473
    Top = 32
  end
end
