unit uServiceProc;

interface

uses
  Windows, SysUtils, Classes, StrUtils, Forms, DB,
  Contnrs,
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
  // недопустимый LOGICAL
  UE_BAD_LOGIC = 8905;

  // копия не получилась
  UE_BAD_PREP = 9001;
  // Fix не успешный
  UE_BAD_FIX  = 9011;
  // Ins не успешный
  UE_BAD_INS  = 9021;
  // Its impossible
  UE_SORRY    = 13000;

  LOG_FNAME = 'AdsFix.log';

  LOG_MIN    = 1;
  LOG_MEDIUM = 2;
  LOG_MAX    = 3;

  CONNECTIONTYPE_DIRBROWSE = 'Выберите папку...';
  CONNECTIONTYPE_DDBROWSE  = 'Выберите файл словаря...';
  DATA_DICTIONARY_FILTER = 'Advantage Data Dictionaries (*.ADD)|*.ADD|All Files (*.*)|*.*';
  DATA_DIR_FILTER = 'Advantage Data Tables (*.ADT)|All Files (*.*)|*.*';
  DIR_4TMP_FILTER = 'Advantage Data Dictionaries (*.ADD)|*.ADD|All Files (*.*)|*.*';

  EMSG_BAD_DATA  : string = 'Некорректные данные!';
  EMSG_SORRY     : string = 'Восстановление невозможно..Пробуйте AdtFix...';
  EMSG_TBL_EMPTY : string = 'Таблица пуста!';
  EMSG_NO_TBLS   : string = 'Таблицы ADS не найдены!';

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
    FLogFile : string;
    FLogLevel : Integer;
    //FIsDict : Boolean;
    procedure FWriteSrc(const Value : string);
    procedure FWriteTmp(const Value : string);
    function  IsDictionary: Boolean;
  protected
  public
    // Установленные Login/Password для открытия словаря
    ULogin: String;
    UPass: String;

    LogLevel : Integer;

    // Начиная с 10-й версии ADS добавлется префикс ANSI для системных таблиц
    SysAdsPfx: string;

    // Флаг тестирования при построении списка таблиц
    AutoTest: Boolean;
    // Режим тестирования
    TableTestMode: TestMode;

    // Способ удаления дубликатов
    DelDupMode: TDelDupMode;

    // Флаг авто-смены режима тестирования,
    // если ошибки не обнаруживаются
    AutoUpTestMode: Boolean;

    // автопоиск наиболее подходящих строк для удаления из дубликатов
    AutoFix: Boolean;

    IniFile : TSasaIniFile;
    // Form to show result
    ShowForm: TForm;

    // Инфо для BackUp/Work
    SafeFix   : TSafeFix;

    // Путь к списоку таблиц (словарь или папка)
    property Src : string read FSrc write FWriteSrc;
    // Путь к папке с рабочими копиями
    property Tmp : string read FTmp write FWriteTmp;

    // Тип источника - Free или словарь
    property IsDict: Boolean read IsDictionary;

    // Путь к папке с исходными таблицами
    property Path2Src : String read FPath2Src;

    function IsCorrectTmp(Path2Tmp: string): string;

    constructor Create(Ini : TSasaIniFile);
    destructor Destroy; override;
  end;

  TSingleton = class(TObject)
  private
    class procedure RegisterInstance(Instance : TSingleton);
    procedure UnRegisterInstance;
    class function FindInstance: TSingleton;
  protected
    constructor Create; virtual;
  public
    class function NewInstance: TObject; override;
    procedure BeforeDestruction; override;
    constructor GetInstance;
  end;

  TLogFile = class(TSingleton)
    private
      FPars    : TFixPars;
      FLogName : string;
    protected
      constructor Create; override;
    public
      procedure SetPars(FP : TFixPars);
      procedure AddMsg(const Value : string);

      destructor Destroy; override;
    published
  end;

function Iif(const Expr : Boolean; const IfTrue, IfFalse : Variant) : Variant;
function LogText : TLogFile;

function FType2ADS(FT : TFieldType) : Integer ;
function SQLType2ADS(SQLType : string) : Integer ;
function CopyOneFile(const Src, Dst: string): Integer;
function SList2StrCommas(Tokens: TStringList; sKvL : string = ''''; sKvR : string = '''') : string;
function Split(const delim, str: string): TStringList;
function BrowseDir(hOwner: HWND; out SResultDir: string; const SDefaultDir:
  string = ''; const STitle: string = 'Выберите папку'): Boolean;

var
  AppFixPars : TFixPars;
  SingletonList : TObjectList;

implementation

uses
  FileUtil,
  DBFunc,
  FuncPr;
  
function Iif(const Expr : Boolean; const IfTrue, IfFalse : Variant) : Variant;
begin
  if (Expr = True) then
    Result := IfTrue
  else
    Result := IfFalse;
end;

constructor TLogFile.Create;
begin
  inherited Create;
  // Any foo
  FLogName := 'FixLog.log';
end;

destructor TLogFile.Destroy;
begin
  // Any foo
  inherited Destroy;
end;

function LogText : TLogFile;
begin
  Result := TLogFile.GetInstance;
end;

procedure TLogFile.SetPars(FP : TFixPars);
begin
  FPars := FP;
end;

procedure TLogFile.AddMsg(const Value : string);
begin
  MemoWrite(FLogName, Value);
end;

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
begin
  inherited Create;
  IniFile := Ini;
  ULogin := USER_EMPTY;
  try
    Src        := Ini.ReadString(INI_PATHS, 'SRCPath', '');
    Tmp        := Ini.ReadString(INI_PATHS, 'TMPPath', '');
    AutoTest   := Ini.ReadBool(INI_CHECK, 'AutoTest', True);
    TableTestMode      := TestMode(IniFile.ReadInteger(INI_CHECK, 'TestMode', Integer(Simple)));
    DelDupMode := TDelDupMode(Ini.ReadInteger(INI_FIX, 'DelDupMode', Integer(DDUP_EX1)));
    SafeFix    := TSafeFix.Create(Ini);
    FLogFile   := Ini.ReadString(INI_PATHS, 'LogFile', LOG_FNAME);
    FLogLevel  := Ini.ReadInteger(INI_PATHS, 'LogLevel', LOG_MEDIUM);
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






{ TSingleton }
procedure TSingleton.BeforeDestruction;
begin
  UnregisterInstance;
  inherited BeforeDestruction;
end;

constructor TSingleton.Create;
begin
  inherited Create;
end;

class function TSingleton.FindInstance : TSingleton;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to SingletonList.Count - 1 do
    if SingletonList[i].ClassType = Self
    then begin
      Result := TSingleton(SingletonList[i]);
      Break;
    end;
end;

constructor TSingleton.GetInstance;
begin
  inherited Create;
end;

class function TSingleton.NewInstance: TObject;
begin
  Result := FindInstance;
  if Result = nil then begin
    Result := inherited NewInstance;
    TSingleton(Result).Create;
    RegisterInstance(TSingleton(Result));
  end;
end;

class procedure TSingleton.RegisterInstance(Instance : TSingleton);
begin
  SingletonList.Add(Instance);
end;

procedure TSingleton.UnRegisterInstance;
begin
  SingletonList.Extract(Self);
end;

initialization
  SingletonList := TObjectList.Create(True);

finalization
  SingletonList.Free;

end.
