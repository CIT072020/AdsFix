unit AdsDAO;

interface

uses
  SysUtils, Classes, adsset, adscnnct, DB, adsdata, adsfunc, adstable, ace,
  kbmMemTable, TableUtils, ServiceProc;

const
  TST_UNKNOWN : Integer = 1;
  TST_GOOD    : Integer = 2;
  TST_RECVRD  : Integer = 4;
  TST_ERRORS  : Integer = 8;

  // сортировка списка таблиц
  IDX_SRC     : String = 'OnState';

  // алиасы для SQL-запросов поиска дубликатов
  AL_SRC     : string = 'S';
  AL_DUP     : string = 'D';
  AL_DKEY    : string = 'DUPGKEY';
  AL_DUPCNT  : string = 'DUPCNT';
  AL_DUPCNTF : string = ',D.DUPCNT,';

  //FXDP_DEL_ALL : Integer = 1;
  //FXDP_1_ASIS  : Integer = 2;
  //FXDP_1_MRG   : Integer = 3;

  // типы полей ADS
type
 TAdsFTypes = set of 0..ADS_MAX_FIELD_TYPE;

const
  ADS_BOOL    : TAdsFTypes = [
    ADS_LOGICAL];
  ADS_STRINGS : TAdsFTypes = [
    ADS_STRING,
    ADS_VARCHAR,
    ADS_CISTRING,
    ADS_MEMO,
    ADS_NCHAR,
    ADS_NVARCHAR,
    ADS_NMEMO,
    ADS_VARCHAR_FOX];
  ADS_NUMBERS : TAdsFTypes = [
    ADS_NUMERIC,
    ADS_DOUBLE,
    ADS_INTEGER,
    ADS_SHORTINT,
    ADS_AUTOINC,
    ADS_CURDOUBLE,
    ADS_MONEY,
    ADS_LONGLONG,
    ADS_ROWVERSION];
  ADS_DATES : TAdsFTypes = [
    ADS_DATE,
    ADS_COMPACTDATE,
    ADS_TIME,
    ADS_TIMESTAMP,
    ADS_MODTIME];
  ADS_BIN : TAdsFTypes = [
    ADS_BINARY,
    ADS_IMAGE,
    ADS_RAW,
    ADS_VARBINARY_FOX,
    ADS_SYSTEM_FIELD];

type
  ITest = interface
  end;

type
  // Режимы тестирования
  TestMode = (Simple, Medium, Slow);
  // Режимы удаления дубликатов
  TDelDupMode = (DDup_ALL, DDup_EX1, DDup_USel);



type
  // Параметры для восстановления
  TAppPars = class
    Src      : String;
    IsDict   : Boolean;
    Path2Src : String;
    Path2Tmp : String;
    TMode    : TestMode;
    DelDupMode : TDelDupMode;
    AutoTest : Boolean;
    // автопоиск наиболее подходящих строк для удаления из дубликатов
    AutoFix  : Boolean;
    //FixDupsMode : Integer;
  end;

type
  // Список таблиц для восстановления
  TSrcTableList = class
    IsDict : Boolean;
    Path2Src : String;
    Path2Tmp : String;
    AllT     : TkbmMemTable;
  end;

type
  // Список таблиц для восстановления на базе ADS-Dictionary
  TSrcDic = class(TSrcTableList)
  private
    FSrcDict : string;
    FUName : string;
    FPass : string;
  public
    property SrcDict : string read FSrcDict write FSrcDict;
  end;

type
  // описание одного индекса
  TIndexInf = class
    Options: Integer;
    Expr: string;
    Fields: TStringList;
    CommaSet : string;
    AlsCommaSet : string;
    EquSet : string;
    IndFieldsAdr: array of integer;
  end;

type
  // описание полей таблицы
  TFieldsInf = class
    Name      : string;
    FieldType : integer;
    TypeSQL   : string;
  end;


type
  // описание записи в наборе дубликатов
  TDupRow = class
    RowID : string;
    FillPcnt : Integer;
    DelRow : Boolean;
  end;

  TFixAds = class
  end;

type
  TdtmdlADS = class(TDataModule)
    conAdsBase: TAdsConnection;
    qTablesAll: TAdsQuery;
    qAny: TAdsQuery;
    mtSrc: TkbmMemTable;
    FSrcNpp: TIntegerField;
    FSrcMark: TBooleanField;
    FSrcTName: TStringField;
    FSrcTestCode: TIntegerField;
    FSrcTCaption: TStringField;
    dsSrc: TDataSource;
    tblAds: TAdsTable;
    FSrcState: TIntegerField;
    FSrcFixCode: TIntegerField;
    cnABTmp: TAdsConnection;
    qDst: TAdsQuery;
    FSrcAIncs: TIntegerField;
    qSrcFields: TAdsQuery;
    qSrcIndexes: TAdsQuery;
    qDupGroups: TAdsQuery;
    procedure DataModuleCreate(Sender: TObject);
  private
    { Private declarations }
    FSysAlias : string;
  public
    { Public declarations }
    property SYSTEM_ALIAS : string read FSysAlias write FSysAlias;

    procedure AdsConnect(Path2Dic, Login, Password: string);
  end;

function SetSysAlias(QV : TAdsQuery) : string;

//procedure FieldInfByFilter(AdsTbl: TTableInf);
procedure FieldsInfBySQL(AdsTbl: TTableInf);
procedure IndexesInf(AdsTbl: TTableInf);

function TablesListFromDic(QA: TAdsQuery): string;
procedure TestSelected(ModeAll : Boolean);

var
  AppPars : TAppPars;
  dtmdlADS: TdtmdlADS;
  SrcList : TSrcTableList;

implementation
uses
  StrUtils,
  FileUtil,
  DBFunc,
  FixDups;
{$R *.dfm}



// добавление префикса /ANSI_ (начиная с версия 10)
function SetSysAlias(QV: TAdsQuery): string;
begin
  Result := 'SYSTEM.';
  with QV do begin
    Active := False;
    SQL.Text := 'EXECUTE PROCEDURE sp_mgGetInstallInfo()';
    Active := True;
    if (Pos('.', FieldByName('Version').AsString) >= 3) then
      Result := Result + 'ANSI_';
  end;
end;

// установка сортировки списка таблиц по статусу
procedure TdtmdlADS.DataModuleCreate(Sender: TObject);
begin
  dtmdlADS.mtSrc.AddIndex(IDX_SRC, 'State', [ixDescending]);
  dtmdlADS.mtSrc.IndexName := IDX_SRC;
end;

//
procedure TdtmdlADS.AdsConnect(Path2Dic, Login, Password: string);
begin
    //подключаемся к базе
  dtmdlADS.conAdsBase.IsConnected := False;
  dtmdlADS.conAdsBase.Username := Login;
  dtmdlADS.conAdsBase.Password := Password;
  dtmdlADS.conAdsBase.ConnectPath := Path2Dic;
  try
    dtmdlADS.conAdsBase.IsConnected := True;
  except
    RaiseLastOSError();
  end;
end;

// сведения о полях/индексах всех таблиц базы
{
procedure SrcFieldsIndexes;
begin
    with dtmdlADS.qSrcFields do begin
      Active := false;
      SQL.Clear;
      SQL.Add('SELECT * FROM ' + dtmdlADS.SYSTEM_ALIAS + 'COLUMNS ORDER BY PARENT');
      Active := true;
    end;

    with dtmdlADS.qSrcIndexes do begin
      Active := false;
      SQL.Clear;
      SQL.Add('SELECT * FROM ' + dtmdlADS.SYSTEM_ALIAS + 'INDEXES');
      Active := true;
    end;
end;
}

// сведения о полях одной таблицы (Filter)
{
procedure FieldInfByFilter(AdsTbl: TTableInf);
var
  i: Integer;
  s: string;
  UFlds: TFieldsInf;
  ACEField : TACEFieldDef;
begin
  AdsTbl.FieldsInf := TList.Create;
  AdsTbl.FieldsAI := TStringList.Create;

  AdsTbl.FieldsInfAds := TACEFieldDefs.Create(AdsTbl.AdsT.Owner);

  with dtmdlADS.qSrcFields do begin
    Filtered := False;
    Filter := 'PARENT = ''' + AdsTbl.TableName + '''';
    Filtered := True;
    First;
    while not Eof do begin
      UFlds := TFieldsInf.Create;
      UFlds.Name := FieldByName('Name').AsString;
      UFlds.FieldType := FieldByName('Field_Type').AsInteger;
      if (UFlds.FieldType = ADS_AUTOINC) then
        AdsTbl.FieldsAI.Add(UFlds.Name);
      AdsTbl.FieldsInf.Add(UFlds);

      ACEField := AdsTbl.FieldsInfAds.Add;
      ACEField.FieldName := FieldByName('Name').AsString;
      ACEField.FieldType := FieldByName('Field_Type').AsInteger;

      Next;
    end;

  end;

end;
}

// сведения о полях одной таблицы (SQL)
procedure FieldsInfBySQL(AdsTbl: TTableInf);
var
  i: Integer;
  s: string;
  UFlds: TFieldsInf;
  ACEField: TACEFieldDef;
  QF : TAdsQuery;
begin
  QF := dtmdlADS.qAny;
  AdsTbl.FieldsInf := TList.Create;
  AdsTbl.FieldsAI := TStringList.Create;

  AdsTbl.FieldsInfAds := TACEFieldDefs.Create(AdsTbl.AdsT.Owner);

  with QF do begin

    Active := false;
    SQL.Clear;
    s := 'SELECT * FROM ' + dtmdlADS.SYSTEM_ALIAS + 'COLUMNS WHERE PARENT=''' +
      AdsTbl.TableName + '''';
    SQL.Add(s);
    Active := true;

    First;
    while not Eof do begin
      UFlds := TFieldsInf.Create;
      UFlds.Name := FieldByName('Name').AsString;
      UFlds.FieldType := FieldByName('Field_Type').AsInteger;
      UFlds.TypeSQL   := ArrSootv[UFlds.FieldType].Name;
      if (UFlds.FieldType = ADS_AUTOINC) then
        AdsTbl.FieldsAI.Add(UFlds.Name);
      AdsTbl.FieldsInf.Add(UFlds);

      ACEField := AdsTbl.FieldsInfAds.Add;
      ACEField.FieldName := FieldByName('Name').AsString;
      ACEField.FieldType := FieldByName('Field_Type').AsInteger;

      Next;
    end;

  end;

end;















procedure ClearFieldInExp(Flds: TStringList);
var
  i, j, k: Integer;
begin
  for i := 0 to Flds.Count - 1 do begin
    j := Pos('(', Flds[i]);
    if (j > 0) then begin
      Flds[i] := RightStr(Flds[i], j + 1);
      k := Pos(')', Flds[i]);
      if (k > 0) then begin
        Flds[i] := LeftStr(Flds[i], k - 1);
      end;
    end;
  end;
end;


// сведения об индексах одной таблицы (SQL)
procedure IndexesInf(AdsTbl: TTableInf);
var
  i, j: Integer;
  CommaList: string;
label
  QFor;
begin
  AdsTbl.IndexInf := TList.Create;
  with dtmdlADS.qAny do begin
    if Active then
      Close;
    // все уникальные индексы
    SQL.Text := 'SELECT INDEX_OPTIONS, INDEX_EXPRESSION, PARENT FROM ' +
      dtmdlADS.SYSTEM_ALIAS + 'INDEXES WHERE (PARENT = ''' + AdsTbl.TableName +
      ''') AND ((INDEX_OPTIONS & 1) = 1)';
    Active := True;
    AdsTbl.IndCount := RecordCount;
    First;
    while not Eof do begin
      UInd := TIndexInf.Create;
      UInd.Options := FieldByName('INDEX_OPTIONS').AsInteger;
      //UInd.Expr := FieldByName('INDEX_EXPRESSION').AsInteger;
      UInd.Fields := TStringList.Create;
      UInd.Fields.Delimiter := ';';
      UInd.Fields.DelimitedText := FieldByName('INDEX_EXPRESSION').AsString;
      ClearFieldInExp(UInd.Fields);

      SetLength(UInd.IndFieldsAdr, UInd.Fields.Count);

      CommaList := '';
      UInd.AlsCommaSet := '';
      UInd.EquSet := '';
      for j := 0 to UInd.Fields.Count - 1 do begin
        if (j > 0) then begin
          CommaList := CommaList + ',';
          UInd.AlsCommaSet := UInd.AlsCommaSet + ',';
          UInd.EquSet := UInd.EquSet + ' AND ';
        end;

        CommaList := CommaList + Uind.Fields[j];
        UInd.AlsCommaSet := UInd.AlsCommaSet + AL_SRC + '.' + Uind.Fields[j];
        UInd.EquSet := UInd.EquSet + '(' + AL_SRC + '.' + Uind.Fields[j] + '=' + AL_DUP + '.' + Uind.Fields[j] + ')';
        for i := 0 to AdsTbl.FieldsInfAds.Count - 1 do
          if (AdsTbl.FieldsInfAds[i].FieldName = UInd.Fields[j]) then begin
            UInd.IndFieldsAdr[j] := i;
            goto QFor;
          end;
      end;
QFor:
      UInd.CommaSet := CommaList;

      AdsTbl.IndexInf.Add(UInd);
      Next;
    end;

  end;

end;


{
procedure GetFieldsInf(AdsTbl: TTableInf);
var
  i: Integer;
  s: string;
  UFlds: TFieldsInf;
begin
  //AdsTbl.FieldsInf := Tlist.Create;
  AdsTbl.FieldsInfAds := TACEFieldDefs.Create(AdsTbl.AdsT.Owner);

  AdsTbl.FieldsInf := TList.Create;

  AdsTbl.FieldsAI := TStringList.Create;

  with dtmdlADS.qAny do begin
    if Active then
      Close;
    SQL.Text := 'SELECT Name, Field_Type FROM ' + dtmdlADS.SYSTEM_ALIAS + 'COLUMNS WHERE (PARENT = ''' + AdsTbl.TableName + ''')';
    Active := True;
    First;
    while not Eof do begin
      UFlds := TFieldsInf.Create;
      UFlds.Name := FieldByName('Name').AsString;
      UFlds.FieldType := FieldByName('Field_Type').AsInteger;
      if (UFlds.FieldType = ADS_AUTOINC) then
        AdsTbl.FieldsAI.Add(UFlds.Name);
      AdsTbl.FieldsInf.Add(UFlds);
      Next;
    end;

  end;

end;
}


function TablesListFromDic(QA: TAdsQuery): string;
var
  i: Integer;
  s: string;
  TblCapts: TStringList;
begin
  with QA do begin
    //TblCapts := TStringList.Create;
    //TblCapts.Delimiter := '.';
    dtmdlADS.mtSrc.Close;
    dtmdlADS.mtSrc.Active := True;

    First;
    i := 0;
    while not Eof do begin
      i := i + 1;
      dtmdlADS.mtSrc.Append;
      dtmdlADS.FSrcNpp.AsInteger := i;
      dtmdlADS.FSrcMark.AsBoolean := False;
      dtmdlADS.FSrcTName.AsString := FieldByName('NAME').AsString;
      s := FieldByName('COMMENT').AsString;
      if (Length(s) > 0) then begin
        TblCapts := Split('.', s);
        //TblCapts.Text := s;
        s := TblCapts[TblCapts.Count - 1];
      end
      else
        s := '???';

      dtmdlADS.FSrcTCaption.AsString := s;
      dtmdlADS.FSrcTestCode.AsInteger := 0;
      dtmdlADS.FSrcState.AsInteger := TST_UNKNOWN;

      dtmdlADS.mtSrc.Post;
      Next;
    end;
  end;

  //SrcFieldsIndexes;

end;


function Field4Alter(AdsTI: TTableInf): integer;
var
  i, j, k, t: Integer;
  IndInf: TIndexInf;
begin
  Result := -1;

  for i := 0 to AdsTI.IndexInf.Count - 1 do begin

    IndInf := AdsTI.IndexInf.Items[i];

    for j := 0 to IndInf.Fields.Count - 1 do begin
      k := IndInf.IndFieldsAdr[j];
      t := AdsTI.FieldsInfAds[k].FieldType;
      if (t in [ADS_INTEGER, ADS_SHORTINT, ADS_AUTOINC]) then begin
        Result := k;
        Exit;
      end;
    end;
  end;

end;



// тестирование одной таблицы на ошибки
function Test1Table(AdsTI: TTableInf; Check: TestMode): Integer;
var
  iFld, ec: Integer;
  TypeName, s: string;
  ErrInf: TStringList;
  AdsFT: UNSIGNED16;
  QA: TAdsQuery;
  CN: TAdsConnection;
begin
  Result := 0;
  if (AdsTI.AdsT.Active) then
    AdsTI.AdsT.Close;
  AdsTI.AdsT.TableName := AdsTI.TableName;

  try
    FieldsInfBySQL(AdsTI);
    IndexesInf(AdsTI);

    // Easy Mode and others
    AdsTI.AdsT.Open;
    AdsTI.AdsT.Close;

    if (Check = Medium)
      OR (Check = Slow) then begin
          if (AdsTI.IndCount > 0) then begin
        // есть уникальные индексы
            iFld := Field4Alter(AdsTI);
            if (iFld >= 0) then begin
              s := AdsTI.FieldsInfAds[iFld].FieldName;
              TypeName := ArrSootv[AdsTI.FieldsInfAds[iFld].FieldType].Name;
              s := 'ALTER TABLE ' + AdsTI.TableName + ' ALTER COLUMN ' + s + ' ' + s + ' ' + TypeName;
              dtmdlADS.conAdsBase.Execute(s);
              s := AppPars.Path2Src + AdsTI.TableName + '*.BAK';
              DeleteFiles(s);
            end;
          end;

      if (Check = Slow) then begin

      end;

    end;

    case Check of
      Medium:
        begin

        end;

      Slow:
        begin

        end;
    end;

  except
    on E: EADSDatabaseError do begin
      Result := E.ACEErrorCode;
      AdsTI.ErrInfo.ErrClass := E.ACEErrorCode;
      AdsTI.ErrInfo.NativeErr := E.SQLErrorCode;
      AdsTI.ErrInfo.MsgErr := E.Message;
    end;
  end;

end;

procedure TestSelected(ModeAll : Boolean);
var
  ec, i: Integer;
begin
  if (AppPars.IsDict = True) then begin
    dtmdlADS.mtSrc.DisableControls;
    with dtmdlADS.mtSrc do begin

    //Close;
    //Active := True;
      dtmdlADS.tblAds.AdsConnection := dtmdlADS.conAdsBase;
      //dtmdlADS.tblAds.ReadOnly := True;

      First;
      i := 0;
      while not Eof do begin
        i := i + 1;
        if ((dtmdlADS.FSrcState.AsInteger = TST_UNKNOWN) AND (ModeAll = True)) OR
          ((dtmdlADS.FSrcMark.AsBoolean = True) AND (ModeAll = False)) then begin

        TableInf := TTableInf.Create(dtmdlADS.FSrcTName.AsString, dtmdlADS.tblAds);
        //TableInf.TableName := dtmdlADS.FSrcTName.AsString;
        //TableInf.AdsT := ;
        //TableInf.Owner := dtmdlADS.tblAds.Owner;

        //TableInf.AdsT.TableName := dtmdlADS.FSrcTName.AsString;

          dtmdlADS.mtSrc.Edit;
          ec := Test1Table(TableInf, AppPars.TMode);
          dtmdlADS.FSrcTestCode.AsInteger := ec;
          if (ec > 0) then begin
            dtmdlADS.FSrcMark.AsBoolean := True;
            ec := TST_ERRORS;
          end
          else begin
            dtmdlADS.FSrcMark.AsBoolean := False;
            ec := TST_GOOD;
            end;
          dtmdlADS.FSrcState.AsInteger := ec;
          dtmdlADS.mtSrc.Post;
        end;
        Next;
      end;
      First;

    end;
    dtmdlADS.mtSrc.EnableControls;

  end;

end;


end.
