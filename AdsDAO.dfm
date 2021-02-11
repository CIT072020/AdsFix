object dtmdlADS: TdtmdlADS
  OldCreateOrder = False
  OnCreate = DataModuleCreate
  Left = 1262
  Top = 217
  Height = 263
  Width = 549
  object conAdsBase: TAdsConnection
    AdsServerTypes = [stADS_LOCAL]
    LoginPrompt = False
    Username = 'AdsSys'
    Password = 'sysdba'
    Left = 32
    Top = 32
  end
  object qTablesAll: TAdsQuery
    AdsConnection = conAdsBase
    Left = 104
    Top = 32
    ParamData = <>
  end
  object qAny: TAdsQuery
    AdsConnection = conAdsBase
    Left = 32
    Top = 88
    ParamData = <>
  end
  object mtSrc: TkbmMemTable
    DesignActivation = True
    AttachedAutoRefresh = True
    AttachMaxCount = 1
    FieldDefs = <
      item
        Name = 'Npp'
        DataType = ftInteger
      end
      item
        Name = 'IsMark'
        DataType = ftBoolean
      end
      item
        Name = 'TableName'
        DataType = ftString
        Size = 128
      end
      item
        Name = 'Tested'
        DataType = ftInteger
      end
      item
        Name = 'TestCode'
        DataType = ftInteger
      end
      item
        Name = 'FixCode'
        DataType = ftInteger
      end
      item
        Name = 'TableCaption'
        DataType = ftString
        Size = 128
      end>
    IndexDefs = <>
    SortOptions = []
    PersistentBackup = False
    ProgressFlags = [mtpcLoad, mtpcSave, mtpcCopy]
    LoadedCompletely = False
    SavedCompletely = False
    FilterOptions = []
    Version = '5.52'
    LanguageID = 0
    SortID = 1
    SubLanguageID = 1
    LocaleID = 66560
    Left = 112
    Top = 96
    object FSrcNpp: TIntegerField
      FieldName = 'Npp'
    end
    object FSrcState: TIntegerField
      FieldName = 'State'
    end
    object FSrcMark: TBooleanField
      FieldName = 'IsMark'
    end
    object FSrcTName: TStringField
      FieldName = 'TableName'
      Size = 128
    end
    object FSrcTestCode: TIntegerField
      FieldName = 'TestCode'
    end
    object FSrcFixCode: TIntegerField
      FieldName = 'FixCode'
    end
    object FSrcTCaption: TStringField
      DisplayWidth = 128
      FieldName = 'TableCaption'
      Size = 128
    end
    object FSrcAIncs: TIntegerField
      FieldName = 'AIncs'
    end
    object FSrcErrNative: TIntegerField
      FieldName = 'ErrNative'
    end
    object FSrcFixInf: TIntegerField
      FieldName = 'TableInf'
    end
  end
  object dsSrc: TDataSource
    DataSet = mtSrc
    Left = 112
    Top = 160
  end
  object tblAds: TAdsTable
    AdsConnection = conAdsBase
    AdsTableOptions.AdsRightsCheck = False
    IndexCollationMismatch = icmIgnore
    Left = 40
    Top = 160
  end
  object cnABTmp: TAdsConnection
    AdsServerTypes = [stADS_LOCAL]
    Left = 368
    Top = 32
  end
  object qDst: TAdsQuery
    AdsConnection = cnABTmp
    Left = 424
    Top = 32
    ParamData = <>
  end
  object qSrcFields: TAdsQuery
    AdsConnection = conAdsBase
    Left = 168
    Top = 32
    ParamData = <>
  end
  object qSrcIndexes: TAdsQuery
    AdsConnection = conAdsBase
    Left = 176
    Top = 96
    ParamData = <>
  end
  object qDupGroups: TAdsQuery
    AdsConnection = cnABTmp
    Left = 368
    Top = 128
    ParamData = <>
  end
  object tblTmp: TAdsTable
    AdsConnection = cnABTmp
    Left = 432
    Top = 128
  end
  object dsPlan: TDataSource
    DataSet = qDst
    Left = 473
    Top = 32
  end
  object tblPlan: TAdsTable
    AdsConnection = cnABTmp
    Left = 488
    Top = 128
  end
end
