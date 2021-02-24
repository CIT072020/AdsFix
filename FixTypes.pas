unit FixTypes;

interface

uses
  SysUtils,
  //Classes,
  //adsset,
  adscnnct,
  //DB,
  adsdata,
  //adsfunc,
  //adstable,
  ace,
  kbmMemTable,
  //EncdDecd,
  ServiceProc, AdsDAO, TableUtils;

type
  IFixErrs = Interface
  ['{06866869-3DFD-49D0-B1EF-BEF2BCE8E4F5}']
    function ChangeOriginal : Boolean;
  end;

  TTblDict = class(TTableInf, IFixErrs)
  public
    function ChangeOriginal : Boolean;
  end;

type

  TSafeFix = class
  // Класс поддержки создания/восстановления BackUp/рабочих копий для
  // исправления ошибок в таблицах ADS
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


    function WorkCopy(P2Src, P2TMP : string; Pars : TAppPars; SrcTbl: TTableInf): Integer;

    constructor Create(FixBasePars: TAppPars);
    destructor Destroy; override;
  published
  end;


  TFixBase = class(TInterfacedObject)
  // Класс исправления ошибок в таблицах ADS
  private
    FPars    : TAppPars;
    FTblList : TAdsList;
  protected
  public
    // Параметры проверки и исправления
    property FixPars : TAppPars read FPars write FPars;
    // Список таблиц (словарь или папка)
    property FixList : TAdsList read FTblList write FTblList;

    // Заполнить и вернуть список ADS-таблиц
    function CreateFixList : TAdsList;

    constructor Create(FixBasePars: TAppPars);
    destructor Destroy; override;
  published
  end;

var
  FixBase : TFixBase;

implementation

uses
  FileUtil;

constructor TSafeFix.Create(FixBasePars : TAppPars);
begin
  inherited Create;
  //FixPars := FixBasePars;
end;

destructor TSafeFix.Destroy;
begin
  inherited Destroy;
end;

//-------------------------------------------------------------

// Копия оригинала и освобождение таблицы
function TSafeFix.WorkCopy(P2Src, P2TMP : string; Pars : TAppPars; SrcTbl: TTableInf): Integer;
var

  s, FileSrc, FileSrcNoExt, FileDst: string;
begin
  Result := UE_BAD_PREP;

  if (SrcTbl.IsFree = False)
    OR (UseCopy4Work = True) then begin
    // Исправления выполняются в копии таблицы

    // Группа файлов в источнике
    FileSrc := P2Src + SrcTbl.NameNoExt;


  end
  else begin





  end;


  try
    SrcTbl.FileTmp := P2TMP + SrcTbl.NameNoExt + ExtADT;

    s := FileSrc + ExtADT;
    if (CopyOneFile(s, P2TMP) <> 0) then
      raise Exception.Create('Ошибка копирования ' + s);

    s := FileSrc + ExtADM;
    if FileExists(s) then begin
      if (CopyOneFile(s, P2TMP) <> 0) then
        raise Exception.Create('Ошибка копирования ' + s);
    end;

      if AdsDDFreeTable(PAnsiChar(SrcTbl.FileTmp), nil) = AE_FREETABLEFAILED then
        if (SrcTbl.IsFree = False) then
        // Словарная таблица обязательно освобождается
          raise EADSDatabaseError.Create(SrcTbl.AdsT, UE_BAD_PREP, 'Ошибка освобождения таблицы');

    SrcTbl.ErrInfo.PrepErr := 0;
    Result := 0;
  except
    SrcTbl.ErrInfo.State := FIX_ERRORS;
    SrcTbl.ErrInfo.PrepErr := UE_BAD_PREP;
  end;
end;















constructor TFixBase.Create(FixBasePars : TAppPars);
begin
  inherited Create;
  FixPars := FixBasePars;
end;


destructor TFixBase.Destroy;
begin
  inherited Destroy;

end;

//-------------------------------------------------------------




function TFixBase.CreateFixList : TAdsList;
begin
  if (FixPars.IsDict) then
    Result := TDictList.Create
  else
    Result := TFreeList.Create;
  FixList := Result;
end;

// Проверить и исправить все
{
procedure TFixBase.FullFix(Src: string);
begin
  if (List4Fix(Src) = 0) then begin
    TestSelected(True);
    FullFixAllMarked(False);
  end
  else
  PutError('Таблицы не найдены!');

end;
}


// AutoInc => Integer and reverse
function ChangeAI(SrcTbl: TTableInf; AorIType : string; Conn : TAdsConnection; DelExt : string = ''): Boolean;
var
  i: Integer;
  s: string;
begin
  Result := True;
  try
    if (SrcTbl.FieldsAI.Count > 0) then begin
      s := 'ALTER TABLE ' + SrcTbl.TableName;
      for i := 0 to (SrcTbl.FieldsAI.Count - 1) do begin
        s := s + ' ALTER COLUMN ' + SrcTbl.FieldsAI[i] + ' ' + SrcTbl.FieldsAI[i] + AorIType;
      end;
      Conn.Execute(s);
      if (Length(DelExt) > 0) then
        DeleteFiles(IncludeTrailingPathDelimiter(Conn.GetConnectionPath) + SrcTbl.TableName + DelExt);
    end;
  except
    Result := False;
  end;
end;

// Вставка в обнуляемый оригинал исправленных записей
function TTblDict.ChangeOriginal : Boolean;
var
  ecb: Boolean;
  i: Integer;
  FileSrc, FileDst, TmpName, ss, sd: string;
  Span: TSpan;
  Conn : TAdsConnection;
  SrcTbl: TTableInf;
begin
  Result := False;

  SrcTbl := Self;
  SrcTbl.AdsT.Active := False;
  Conn := SrcTbl.AdsT.AdsConnection;
  Conn.Disconnect;

  FileSrc := SrcTbl.Path2Src + SrcTbl.TableName;
  FileDst := SrcTbl.FileTmp + '.adt';

  SrcTbl.ErrInfo.State  := INS_ERRORS;
  SrcTbl.ErrInfo.InsErr := UE_BAD_INS;

  if (SrcTbl.NeedBackUp = True) then begin
    // Перед вставкой сделать копию
    TmpName := SrcTbl.Path2Src + ORGPFX + SrcTbl.TableName;
    ecb := DeleteFiles(TmpName + '.*');

    if FileExists(FileSrc + '.adi') then
      ecb := DeleteFiles(FileSrc + '.adi');

    ss := FileSrc + '.adt';
    sd := TmpName + '.adt';
    ecb := RenameFile(ss, sd);
    if (ecb = True) then
      SrcTbl.BackUps.Add(sd);

    if FileExists(FileSrc + '.adm') then begin
      ss := FileSrc + '.adm';
      sd := TmpName + '.adm';
      ecb := RenameFile(ss, sd);
      if (ecb = True) then
        SrcTbl.BackUps.Add(sd);
    end;
  end
  else  // Удалить таблицу + Memo + index
    ecb := DeleteFiles(FileSrc + '.ad?');

  //--- Auto-create empty table
  SrcTbl.AdsT.AdsConnection.IsConnected := True;
  SrcTbl.AdsT.Active := True;
  SrcTbl.AdsT.Active := False;
  //---

  try
    if (ChangeAI(SrcTbl, ' INTEGER', Conn) = True) then begin
      if (SrcTbl.GoodSpans.Count <= 0) then begin
        // Загрузка оптом
        //ss := 'INSERT INTO ' + SrcTbl.TableName + ' SELECT * FROM "' + FileDst + '" SRC';
        ss := Format('INSERT INTO "%s" SELECT * FROM "%s" SRC', [SrcTbl.TableName, FileDst]);
        if (Length(SrcTbl.DmgdRIDs) > 0) then
          ss := ss + ' WHERE SRC.ROWID NOT IN (' + SrcTbl.DmgdRIDs + ')';
        Conn.Execute(ss);
      end
      else begin
        // Загрузка интервалами хороших записей
        for i := 0 to SrcTbl.GoodSpans.Count - 1 do begin
          Span := SrcTbl.GoodSpans[i];
          //ss := 'INSERT INTO ' + SrcTbl.TableName + ' SELECT TOP ' + IntToStr(Span.InTOP) + ' START AT ' + IntToStr(Span.InSTART) + ' * FROM "' + FileDst + '" SRC';
          ss := Format('INSERT INTO "%s" SELECT TOP %d START AT %d * FROM "%s"  SRC', [SrcTbl.TableName, Span.InTOP, Span.InSTART, FileDst]);
          Conn.Execute(ss);
        end;
      end;
      ChangeAI(SrcTbl, ' AUTOINC', Conn, '.ad?.bak');
    end;
    SrcTbl.ErrInfo.State := INS_GOOD;
    SrcTbl.ErrInfo.InsErr := 0;
    Result := True;
  except
    on E: EADSDatabaseError do begin
      SrcTbl.ErrInfo.InsErr := E.ACEErrorCode;
    end
    else
      SrcTbl.ErrInfo.InsErr := UE_BAD_INS;
  end;

end;


end.
