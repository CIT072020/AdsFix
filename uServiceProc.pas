unit uServiceProc;

interface

uses
  Windows, SysUtils, Classes, StrUtils, Forms, DB,
  ShlObj,
  adsdata,
  ace,
  SasaINiFile;

  
  // типы полей ADS
type
 TAdsFTypes = set of 0..ADS_MAX_FIELD_TYPE;

const
  ADS_BOOL    : TAdsFTypes = [
    ADS_LOGICAL];
  ADS_STRINGS : TAdsFTypes = [
    ADS_STRING,
    ADS_MEMO,
    ADS_VARCHAR,
    ADS_CISTRING,
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

  ExtADT = '.adt';
  ExtADM = '.adm';
  ExtADI = '.adi';

const
  // Секции INI
  INI_PATHS  = 'PATH';
  INI_CHECK  = 'CHECK';
  INI_SAFETY = 'SAFETY';
  INI_FIX    = 'FIXPARS';

  // Начальное значение User Login
  USER_EMPTY = '!-IM-USER-!';
  USER_DFLT  = 'AdsSys';
  PASS_DFLT  = 'sysdba';

  // Статусы таблицы
  TST_UNKNOWN : Integer = 1;
  TST_GOOD    : Integer = 2;
  TST_ERRORS  : Integer = 4;

  FIX_ERRORS  : Integer = 8;
  FIX_GOOD    : Integer = 16;
  FIX_NOTHG   : Integer = 32;

  INS_GOOD    : Integer = 64;
  INS_ERRORS  : Integer = 128;

  // Пользователь отмечает удаляемые дубликаты
  FIX_UWAIT   : Integer = (1 SHL 20);


  // Причины удаления строк
  RSN_EMP_KEY = 1;
  RSN_DUP_KEY = 2;

  // алиасы для SQL-запросов поиска дубликатов
  AL_SRC     : string = 'S';
  AL_DUP     : string = 'D';
  AL_DKEY    : string = 'DUPGKEY';
  AL_DUPCNT  : string = 'DUPCNT';
  AL_DUPCNTF : string = ',D.DUPCNT,';

  // пользовательские коды ошибок
  // Фсе есть гут
  UE_OK       = 0;
  // Таблицы не найдены
  UE_NO_ADS   = 1;
  UE_BAD_USER = 2;
  UE_BAD_PATH = 3; 

  // мусор в данных
  UE_BAD_DATA = 8901;
  // недопустимый год
  UE_BAD_YEAR = 8902;
  // недопустимый TimeStamp
  UE_BAD_TMSTMP = 8903;
  // недопустимый AUTOINC
  UE_BAD_AINC = 8904;

  // копия не получилась
  UE_BAD_PREP = 9001;
  // Fix не успешный
  UE_BAD_FIX  = 9011;
  // Ins не успешный
  UE_BAD_INS  = 9021;
  // Its impossible
  UE_SORRY    = 13000;

  CONNECTIONTYPE_DIRBROWSE = 'Выберите папку...';
  CONNECTIONTYPE_DDBROWSE  = 'Выберите файл словаря...';
  DATA_DICTIONARY_FILTER = 'Advantage Data Dictionaries (*.ADD)|*.ADD|All Files (*.*)|*.*';
  DATA_DIR_FILTER = 'Advantage Data Tables (*.ADT)|All Files (*.*)|*.*';
  DIR_4TMP_FILTER = 'Advantage Data Dictionaries (*.ADD)|*.ADD|All Files (*.*)|*.*';
  EMSG_BAD_DATA  : string = 'Некорректные данные!';
  EMSG_SORRY     : string = 'Восстановление невозможно..Пробуйте AdtFix...';
  EMSG_TBL_EMPTY : string = 'Таблица пуста!';

const
  // модификатор имени файла при создании backup
  ORGPFX : string = 'tmp_';

  CMPNT_NAME = 'tblSrcAds';

const
  // Выборочных чтений таблицы при среднем уровне тестирования
  MAX_READ_MEDIUM : Integer = 5000;

type
  // Режимы тестирования
  TestMode = (Simple, Medium, Slow);
  // Режимы удаления дубликатов
  TDelDupMode = (DDUP_ALL, DDUP_EX1, DDUP_USEL);

type

  // Класс поддержки создания/восстановления BackUp/рабочих копий для
  // исправления ошибок в таблицах ADS
  TSafeFix = class
  private
    FUseCopy4Work : Boolean;
    FReWriteWork  : Boolean;
    FUseBackUp    : Boolean;
  protected
  public
    // Исправление ошибок на копии таблицы
    property UseCopy4Work : Boolean read FUseCopy4Work write FUseCopy4Work;
    // Пересоздать рабочую копию, если имеется
    property ReWriteWork : Boolean read FReWriteWork write FReWriteWork;
    // Копия оригинальной таблицы перед внесением изменений
    property UseBackUp : Boolean read FUseBackUp write FUseBackUp;

    constructor Create(Ini : TSasaIniFile);
    destructor Destroy; override;
  published
  end;

  // Параметры для восстановления
  TFixPars = class
  private
    FSrc    : String;
    FPath2Src : String;
    FTmp    : String;
    //FIsDict : Boolean;
    procedure FWriteSrc(const Value : string);
    procedure FWriteTmp(const Value : string);
    function  IsDictionary: Boolean;
  protected
  public
    // Установленные Login/Password
    ULogin: String;
    UPass: String;

    // всего таблиц
    //TotTbls  : Integer;

    // Режим тестирования
    TMode: TestMode;

    // Способ удаления дубликатов
    DelDupMode: TDelDupMode;

    // Флаг тестирования при построении списка таблиц
    AutoTest: Boolean;

    // Флаг авто-смены режима тестирования,
    // если ошибки не обнаруживаются
    AutoUpTestMode: Boolean;

    // автопоиск наиболее подходящих строк для удаления из дубликатов
    AutoFix: Boolean;

    // FixDupsMode : Integer;
    SysAdsPfx: string;

    IniFile : TSasaIniFile;
    // Form to show result
    ShowForm: TForm;

    // Инфо для BackUp/Work
    SafeFix   : TSafeFix;

    // Путь к списоку таблиц (словарь или папка)
    property Src : string read FSrc write FWriteSrc;
    // Путь к папке с рабочими копиями
    property Tmp : string read FTmp write FWriteTmp;
    // Путь к папке таблиц (Free) или словарю
    property IsDict: Boolean read IsDictionary;
    
    property Path2Src : String read FPath2Src;

    function IsCorrectTmp(Path2Tmp: string): string;

    constructor Create(Ini : TSasaIniFile);
    destructor Destroy; override;
  end;


function FType2ADS(FT : TFieldType) : Integer ;
function SQLType2ADS(SQLType : string) : Integer ;
function CopyOneFile(const Src, Dst: string): Integer;
function SList2StrCommas(Tokens: TStringList; sKvL : string = ''''; sKvR : string = '''') : string;
function Split(const delim, str: string): TStringList;
function BrowseDir(hOwner: HWND; out SResultDir: string; const SDefaultDir:
  string = ''; const STitle: string = 'Выберите папку'): Boolean;

var
  AppFixPars : TFixPars;

implementation

uses
  FileUtil,
  DBFunc;


constructor TSafeFix.Create(Ini : TSasaIniFile);
begin
  inherited Create;
  UseCopy4Work := Ini.ReadBool(INI_SAFETY, 'COPY4FIX', True);
  ReWriteWork  := Ini.ReadBool(INI_SAFETY, 'RWRCOPY', True);
  UseBackUp    := Ini.ReadBool(INI_SAFETY, 'BACKUP', True);
end;

destructor TSafeFix.Destroy;
begin
  inherited Destroy;
end;

constructor TFixPars.Create(Ini : TSasaIniFile);
var
  i : Integer;
begin
  inherited Create;
  IniFile := Ini;
  // Default values
  ULogin := USER_EMPTY;

  try
    Src        := Ini.ReadString(INI_PATHS, 'SRCPath', '');
    Tmp        := Ini.ReadString(INI_PATHS, 'TMPPath', 'C:\Temp\');
    AutoTest   := Ini.ReadBool(INI_CHECK, 'AutoTest', True);
    TMode      := TestMode(IniFile.ReadInteger(INI_CHECK, 'TestMode', Integer(Simple)));
    DelDupMode := TDelDupMode(Ini.ReadInteger(INI_FIX, 'DelDupMode', Integer(DDUP_EX1)));
    SafeFix    := TSafeFix.Create(Ini);
  finally
  end;
end;

destructor TFixPars.Destroy;
begin
  inherited Destroy;
  FreeAndNil(SafeFix);
end;

function TFixPars.IsDictionary : Boolean;
begin
  Result := False;
  if (Pos('.ADD', UpperCase(ExtractFileExt(Src))) > 0) then
    Result := True;
    //FIsDict := Result;
  if (Result = True) then
      FPath2Src := ExtractFilePath(Src)
    else
      FPath2Src := IncludeTrailingPathDelimiter(Src);
end;

procedure TFixPars.FWriteSrc(const Value : string);
begin
  FSrc := Value;
  if (FSrc <> '') then
    IsDictionary;
end;
procedure TFixPars.FWriteTmp(const Value : string);
begin
  FTmp := Value;
end;

function GetEnvironmentTemp : string;
{Переменные среды}
var
  ptr: PChar;
  PosEqu : Integer;
  s: string;
  Done: boolean;
begin
  Result := '';
  s := '';
  Done := FALSE;
  ptr := Windows.GetEnvironmentStrings;
  while Done = false do begin
    if ptr^ = #0 then begin
      inc(ptr);
      if ptr^ = #0 then
        Done := TRUE
      else
        if (LeftStr(UpperCase(s),4) = 'TEMP') OR (LeftStr(UpperCase(s),3) = 'TMP') then begin
          PosEqu := Pos('=', s);
          if (PosEqu > 0) then
            Result := Copy(s, PosEqu + 1, Length(s) - PosEqu);
          Break;
        end;
      s := ptr^;
    end
    else
      s := s + ptr^;
    inc(ptr);
  end;
end;

// Проверка существования и нормализация пути к рабочей папке
// Для пустого предлагается системный TEMP/TMP
function TFixPars.IsCorrectTmp(Path2Tmp: string): string;
begin
  Result := '';
  if (Path2Tmp = '') then
    Path2Tmp := GetEnvironmentTemp;
  if (DirectoryExists(Path2Tmp)) then
    Result := IncludeTrailingPathDelimiter(Path2Tmp);
end;



// Перевод TFieldType в ADS-типы (ace.pas)
function FType2ADS(FT : TFieldType) : Integer ;
var
  i : Integer;
begin
  Result := 0;
  for i := 0 to Length(AdsDataTypeMap) - 1 do
    if (AdsDataTypeMap[i] = FT) then begin
      Result := i;
      Break;
    end;
end;

// Перевод SQL-able типов в ADS-типы (ace.pas)
function SQLType2ADS(SQLType : string) : Integer ;
var
  i : Integer;
begin
  Result := -1;
  for i := 0 to Length(ArrSootv) - 1 do
    if (ArrSootv[i].Name = SQLType) then begin
      Result := i;
      Break;
    end;
end;

// Скопировать группу файлов по шаблону имени
function CopyOneFile(const Src, Dst: string): Integer;
begin
  Result := 0;
  try
    CopyFileEx(Src, Dst, True, True, nil);
  except
    Result := 1;
  end;
end;

// Список строк через запятую
function SList2StrCommas(Tokens: TStringList; sKvL : string = ''''; sKvR : string = '''') : string;
var
  i : Integer;
  s : AnsiString;
begin
  s := '';
  for i := 0 to Tokens.Count - 1 do
      s := s + sKvL + Tokens.Strings[i] + sKvR + ',';
  i := Length(s);
  if (i > 1) then
    Delete(s, i, 1);
  Result := s;
end;


function Split(const delim, str: string): TStringList;
var
  offset,
  cur,
  sl,
  dl: integer;
begin
  Result := TStringList.Create;
  dl     := Length(delim);
  sl     := Length(str);
  offset := 1;
  while True do begin
    cur := PosEx(delim, str, offset);
    if cur > 0 then
      Result.Add(Copy(str, offset, cur - offset))
    else begin
      Result.Add(Copy(str, offset, sl - offset + 1));
      Break
    end;
    offset := cur + dl;
  end;
end;


function BrowseCallbackProc(hWindow: HWND; uMsg: Cardinal; lParam, lpData: Integer): Integer; stdcall;
begin
  Result := 0;
  if uMsg = BFFM_INITIALIZED then
    SendMessage(hWindow, BFFM_SETSELECTION, 1, lpData);
end;

//if BrowseDir( Handle, s, 'C:\Temp' ) then
//  LtabK.Caption := s;

function BrowseDir(hOwner: HWND; out SResultDir: string; const SDefaultDir:
  string = ''; const STitle: string = 'Выберите папку'): Boolean;
var
  lpbi: TBROWSEINFO;
  il: PItemIDList;
  Buffer: array[0..MAX_PATH] of Char;
begin
  Result := False;
  FillChar(lpbi, sizeof(lpbi), 0);
  lpbi.hwndOwner := hOwner;
  lpbi.lpszTitle := LPSTR(STitle);
  lpbi.ulFlags := BIF_RETURNONLYFSDIRS;
  lpbi.pszDisplayName := StrAlloc(MAX_PATH);
  if SDefaultDir <> '' then begin
    lpbi.lParam := lParam(PChar(SDefaultDir));
    lpbi.lpfn := @BrowseCallbackProc;
  end;

  il := SHBrowseForFolder(lpbi);
  if Assigned(il) then begin
    if ShGetPathFromIDList(il, @Buffer) then begin
      SResultDir := string(Buffer);
      Result := True;
    end;
  end;
end;





// может, пригодится. А может и нет



// сведения о полях одной таблицы (SQL)
{
class procedure TTableInf.FieldsInfBySQL(AdsTbl: TTableInf; QWork : TAdsQuery);
var
  i: Integer;
  s: string;
  UFlds: TFieldsInf;
  ACEField: TACEFieldDef;
begin
  AdsTbl.FieldsInf := TList.Create;
  AdsTbl.FieldsAI := TStringList.Create;

  AdsTbl.FieldsInfAds := TACEFieldDefs.Create(AdsTbl.AdsT.Owner);

  with QWork do begin

    Active := false;
    SQL.Clear;
    s := 'SELECT * FROM ' + AppPars.SysAdsPfx + 'COLUMNS WHERE PARENT=''' +
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
}

{
// Список ROWIDs с поврежденными данными (из списка Recno)
function ConvertRecNo2RowID(BRecs: TList; AdsTbl: TAdsTable): string;
var
  b, i: Integer;
  sID1st: string;
  Q: TAdsQuery;
  BadFInRec: TBadRec;
begin
  Result := '';
  if (BRecs.Count > 0) then begin
    Q := TAdsQuery.Create(AdsTbl.Owner);
    Q.AdsConnection := AdsTbl.AdsConnection;
    b := 0;
    for i := 0 to BRecs.Count - 1 do begin
      BadFInRec := TBadRec(BRecs[i]);

      Q.Active := False;
      Q.SQL.Text := 'SELECT TOP 1 START AT ' + IntToStr(BadFInRec.Recno) + ' ROWID FROM ' + AdsTbl.TableName;
      Q.Active := True;
      if (Q.RecordCount > 0) then begin
        sID1st := Q.FieldValues['ROWID'];
        if (Length(sID1st) > 0) then begin
          b := b + 1;
          BadFInRec.RowID := sID1st;
          if (b > 1) then
            Result := Result + ',';
          Result := Result + '''' + sID1st + '''';
        end;

      end;
    end;
  end;

end;
}



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
}




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




// тестирование одной таблицы на ошибки
{
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

  except
    on E: EADSDatabaseError do begin
      Result := E.ACEErrorCode;
      AdsTI.ErrInfo.ErrClass := E.ACEErrorCode;
      AdsTI.ErrInfo.NativeErr := E.SQLErrorCode;
      AdsTI.ErrInfo.MsgErr := E.Message;
    end;
  end;

end;
}

// Построение списка таблиц для восстановления
{
function List4Fix(Src : string) : Integer;
var
  IsAdsDict : Boolean;
begin
  Result := 0;
  IsAdsDict := AppPars.IsDictionary;
  if (IsCorrectSrc(Src, IsAdsDict) = True) then begin
    AppPars.IsDict := IsAdsDict;
    AppPars.Src := Src;
    if (IsAdsDict = True) then
      AppPars.Path2Src := ExtractFilePath(Src)
    else
      AppPars.Path2Src := IncludeTrailingPathDelimiter(Src);
    if (PrepareList(Src) <= 0) then
      Result := UE_NO_ADS;
  end
  else
    Result := UE_NO_ADS;
end;
}


end.
