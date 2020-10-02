unit ServiceProc;

interface

uses
  Windows, SysUtils, Classes, StrUtils, ShlObj;

const
  // Начальное значение User Login
  USER_EMPTY = '!-IM-USER-!';
  USER_DFLT  = 'AdsSys';
  PASS_DFLT  = 'sysdba';

  TST_UNKNOWN : Integer = 1;
  TST_GOOD    : Integer = 2;
  TST_RECVRD  : Integer = 4;
  TST_ERRORS  : Integer = 8;
  FIX_ERRORS  : Integer = 16;
  INS_ERRORS  : Integer = 32;

  // сортировка списка таблиц
  IDX_SRC     : String = 'OnState';

  // алиасы для SQL-запросов поиска дубликатов
  AL_SRC     : string = 'S';
  AL_DUP     : string = 'D';
  AL_DKEY    : string = 'DUPGKEY';
  AL_DUPCNT  : string = 'DUPCNT';
  AL_DUPCNTF : string = ',D.DUPCNT,';

  // пользовательские коды ошибок
  // мусор в данных
  UE_BAD_DATA = 8901;

  // копия не получилась
  UE_BAD_PREP = 9001;
  // Fix не успешный
  UE_BAD_FIX  = 9011;
  // Ins не успешный
  UE_BAD_INS  = 9021;

const
  EMSG_BAD_DATA : string = 'Некорректные данные!';

const
  MAX_READ_MEDIUM : Integer = 5000;
  
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
    // Установленные Login/Password
    ULogin   : String;
    UPass    : String;
    // Режим тестирования
    TMode    : TestMode;
    // Способ удаления дубликатов
    DelDupMode : TDelDupMode;
    // Флаг тестирования списка таблиц при получении списка
    AutoTest : Boolean;
    // автопоиск наиболее подходящих строк для удаления из дубликатов
    AutoFix  : Boolean;
    //FixDupsMode : Integer;
    SysAdsPfx : string;
    
  end;


function Split(const delim, str: string): TStringList;
function BrowseDir(hOwner: HWND; out SResultDir: string; const SDefaultDir:
  string = ''; const STitle: string = 'Выберите папку'): Boolean;

var
  AppPars : TAppPars;

implementation

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

end.
