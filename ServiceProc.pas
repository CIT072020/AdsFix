unit ServiceProc;

interface

uses
  Windows, SysUtils, Classes, StrUtils, ShlObj;

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



end.
