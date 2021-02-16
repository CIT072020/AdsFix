unit ServiceProc;

interface

uses
  Windows, SysUtils, Classes, StrUtils, Forms,
  ShlObj,
  ace;
  
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

const
  // Ќачальное значение User Login
  USER_EMPTY = '!-IM-USER-!';
  USER_DFLT  = 'AdsSys';
  PASS_DFLT  = 'sysdba';

  // —татусы таблицы
  TST_UNKNOWN : Integer = 1;
  TST_GOOD    : Integer = 2;
  TST_ERRORS  : Integer = 4;

  FIX_ERRORS  : Integer = 8;
  FIX_GOOD    : Integer = 16;
  FIX_NOTHG   : Integer = 32;

  INS_GOOD    : Integer = 64;
  INS_ERRORS  : Integer = 128;

  // ѕользователь должен установить удал€емые дубликаты
  FIX_UWAIT   : Integer = 1 SHL 20;


  // ѕричины удалени€ строк
  RSN_EMP_KEY = 1;
  RSN_DUP_KEY = 2;

  // алиасы дл€ SQL-запросов поиска дубликатов
  AL_SRC     : string = 'S';
  AL_DUP     : string = 'D';
  AL_DKEY    : string = 'DUPGKEY';
  AL_DUPCNT  : string = 'DUPCNT';
  AL_DUPCNTF : string = ',D.DUPCNT,';

  // пользовательские коды ошибок
  // ‘се есть гут
  UE_OK       = 0;
  // “аблицы не найдены
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

  // копи€ не получилась
  UE_BAD_PREP = 9001;
  // Fix не успешный
  UE_BAD_FIX  = 9011;
  // Ins не успешный
  UE_BAD_INS  = 9021;
  // Its impossible
  UE_SORRY    = 13000;

const
  EMSG_BAD_DATA  : string = 'Ќекорректные данные!';
  EMSG_SORRY     : string = '¬осстановление невозможно..ѕробуйте AdtFix...';
  EMSG_TBL_EMPTY : string = '“аблица пуста!';

const
  // модификатор имени файла при создании backup
  ORGPFX : string = 'tmp_';
  
  CMPNT_NAME = 'tblSrcAds';

const
  // ¬ыборочных чтений таблицы при среднем уровне тестировани€
  MAX_READ_MEDIUM : Integer = 5000;

type
  // –ежимы тестировани€
  TestMode = (Simple, Medium, Slow);
  // –ежимы удалени€ дубликатов
  TDelDupMode = (DDup_ALL, DDup_EX1, DDup_USel);

type
  // ѕараметры дл€ восстановлени€
  TAppPars = class
    Src      : String;
    IsDict   : Boolean;
    //Path2Src : String;
    Path2Tmp : String;
    // ”становленные Login/Password
    ULogin   : String;
    UPass    : String;
    // всего таблиц
    //TotTbls  : Integer;
    // –ежим тестировани€
    TMode    : TestMode;
    // —пособ удалени€ дубликатов
    DelDupMode : TDelDupMode;
    // ‘лаг тестировани€ при получении списка таблиц
    AutoTest : Boolean;
    // автопоиск наиболее подход€щих строк дл€ удалени€ из дубликатов
    AutoFix  : Boolean;
    //FixDupsMode : Integer;
    SysAdsPfx : string;
    // Form to show result
    ShowForm : TForm;

    function IsDictionary : Boolean;

  end;


function Split(const delim, str: string): TStringList;
function BrowseDir(hOwner: HWND; out SResultDir: string; const SDefaultDir:
  string = ''; const STitle: string = '¬ыберите папку'): Boolean;

var
  AppPars : TAppPars;

implementation

function TAppPars.IsDictionary : Boolean;
begin
  Result := False;
  if (Pos('.ADD', UpperCase(Src)) > 0) then
    Result := True;
  IsDict := Result;
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
  string = ''; const STitle: string = '¬ыберите папку'): Boolean;
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





// может, пригодитс€. ј может и нет



// сведени€ о пол€х одной таблицы (SQL)
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
// —писок ROWIDs с поврежденными данными (из списка Recno)
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



// сведени€ о пол€х/индексах всех таблиц базы
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

// сведени€ о пол€х одной таблицы (Filter)
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


// сведени€ о пол€х одной таблицы (SQL)
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

// ѕостроение списка таблиц дл€ восстановлени€
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
