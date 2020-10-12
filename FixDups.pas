unit FixDups;

interface

uses
  SysUtils, Classes, adsset, adscnnct, DB, adsdata, adsfunc, adstable, ace,
  kbmMemTable,
  //EncdDecd,
  ServiceProc, AdsDAO, TableUtils;

const
  ORGPFX : string = 'tmp_';

  FWT_BOOL : Integer = 1;
  FWT_NUM  : Integer = 3;
  FWT_DATE : Integer = 5;
  FWT_STR  : Integer = 30;
  FWT_BIN  : Integer = 5;

type
  TBadRec = class
  //info по сбойной записи
    RecNo : Integer;
    BadFieldI : Integer;
    RowID : string;
    UseInSpan : Boolean;
    InTOP     : Integer;
    InSTART   : Integer;
  end;
  TSpan = class
  //info по интервалу хороших записей
    InTOP     : Integer;
    InSTART   : Integer;
  end;

  TRowIDStruct = record
    DBID : Integer;
    TBID : Integer;
    RecN : Integer;
  end;

type
  TFixBase = class(TObject)
  private
    FPars : TAppPars;
  protected
  public
    property FixPars : TAppPars read FPars write FPars;

    constructor Create(FixBasePars: TAppPars);
    destructor Destroy; override;
  published
  end;

procedure FixAllMarked;
// Исправить оригинал для отмеченных
procedure ChangeOriginalAllMarked;
procedure DelBackUps;

// Easy Mode - one button
procedure FullFixAllMarked(FixAll : Boolean = True);

var
  TableInf : TTableInf;
  UInd : TIndexInf;

implementation

uses
  FuncPr,
  FileUtil,
  Math;

constructor TFixBase.Create(FixBasePars : TAppPars);
begin
  inherited Create;
  FixPars := FixBasePars;
end;


destructor TFixBase.Destroy;
begin
  inherited Destroy;

end;

function CopyOneFile(const Src, Dst: string): Integer;
begin
  Result := 0;
  try
    CopyFileEx(Src, Dst, True, True, nil);
  except
    Result := 1;
  end;
end;
  
function EmptyFCond(FieldName : String; FieldType : Integer; IsNOT : Boolean = False) : string;
var
  bInBrck : Boolean;
begin
  bInBrck := True;
  Result := '(' + FieldName + ' is NULL)';
  if  (FieldType in ADS_NUMBERS) then
    Result := Result + ' OR (' + FieldName + ' <= 0)'
  else if (FieldType in ADS_STRINGS) then
    Result := Result + ' OR EMPTY(' + FieldName + ')'
  else
    bInBrck := False;
  if (bInBrck = True) then
    Result := '(' + Result + ')';
  if (IsNOT = True) then
    Result := '( NOT ' + Result + ' )';
end;


function FieldInIndex(FieldName : String) : Boolean;
begin
  Result := False;
end;


{-------------------------------------------------------------------------------
  Procedure: UniqRepeat
  Построение запроса на поиск совпадающих уникальных ключей вида
  SELECT f1, f2, ... COUNT(*) as DupCount
    FROM T GROUP BY 1, 2, ...
    HAVING (COUNT(*) >= 1)
  Arguments: AdsTble: string
  Result:    None
-------------------------------------------------------------------------------}
function UniqRepeat(AdsTbl : TTableInf; iI : Integer) : string;
var
  IndInf : TIndexInf;
begin
  IndInf := AdsTbl.IndexInf.Items[iI];
{
  Result := 'SELECT ' + AdsTbl.IndexInf.Items[iI].CommaSet + ' COUNT(*) as DupCount FROM ' +
    AdsTbl.TableName + ' GROUP BY ' + AdsTbl.IndexInf.Items[iI].CommaSet +
    ' HAVING (COUNT(*) > 1)';
}
  Result := 'SELECT ' + AL_SRC + '.ROWID, ''' + IntToStr(iI) + '''+' +
    AL_DUP + '.ROWID AS ' + AL_DKEY + AL_DUPCNTF + IndInf.AlsCommaSet +
    ' FROM ' + AdsTbl.TableName + ' ' + AL_SRC +
    ' INNER JOIN (SELECT COUNT(*) AS ' + AL_DUPCNT + ',' + IndInf.CommaSet +
    ' FROM ' + AdsTbl.TableName + ' GROUP BY ' + IndInf.CommaSet +
    ' HAVING (COUNT(*) > 1) ) ' + AL_DUP +
    ' ON ' + IndInf.EquSet;
  Result := Result + ' ORDER BY ' + AL_DKEY;
end;


function DelDups4Idx(AdsTbl : TTableInf) : Integer;
var
  nRec : Integer;
  s : string;
begin
  s := 'DELETE FROM ' + AdsTbl.TableName + ' WHERE ' + AdsTbl.TableName +
    '.ROWID IN (' + AdsTbl.List4Del + ')';
  nRec := dtmdlADS.cnABTmp.Execute(s);
  Result := nRec;
end;







// вес одного заполненного поля
function FieldWeight(QF: TAdsQuery; FieldName: string; FieldType: integer): integer;
begin
    // BIN data (default)
  Result := FWT_BIN;
  if (FieldType in ADS_NUMBERS) then begin
    Result := FWT_NUM;
  end
  else if (FieldType in ADS_BOOL) then begin
    Result := FWT_BOOL;
  end
  else if (FieldType in ADS_STRINGS) then begin
    Result := FWT_STR;
  end
  else if (FieldType in ADS_DATES) then begin
    Result := FWT_DATE;
  end;
end;


function RowFill(AdsTbl: TTableInf; RowID: string; Q1F: TAdsQuery): integer;
var
  FT, RowWeight, i: integer;
  sField, sEmpCond, s4All, s: string;
begin
  Result := 0;
  s4All := ' WHERE (ROWID=''' + RowID + ''') AND ';
  RowWeight := 0;
  Q1F.Active := False;

  for i := 0 to AdsTbl.FieldsInfAds.Count - 1 do begin

    if (i > 1) then
      s := s + ' OR ';

    sField := AdsTbl.FieldsInfAds[i].FieldName;
    FT := AdsTbl.FieldsInfAds[i].FieldType;
    sEmpCond := EmptyFCond(sField, FT, True);
    s := 'SELECT ' + sField + ' FROM ' + AdsTbl.TableName + s4All + sEmpCond;
    Q1F.SQL.Clear;
    Q1F.SQL.Add(s);
    Q1F.Active := True;
    if (Q1F.RecordCount > 0) then
      RowWeight := RowWeight + FieldWeight(Q1F, sField, FT);

  end;
  Result := RowWeight;
end;



procedure MarkAll4Del(Q: TAdsQuery; AdsTbl: TTableInf);
var
  i: Integer;
  s: string;
  RowInf: TDupRow;
begin
  Q.First;
  i := 0;
  s := '';
  while not Q.Eof do begin
    RowInf := TDupRow.Create;
    RowInf.DelRow := True;
    if (i > 0) then begin
      s := s + ',';
    end;
    s := s + '''' + Q.FieldValues['ROWID'] + '''';
    AdsTbl.DupRows.Add(RowInf);
    i := i + 1;
    Q.Next;
  end;
  AdsTbl.List4Del := s;
  AdsTbl.TotalDel := Q.RecordCount;
end;


// оставить не больше одной записи из группы
procedure LeaveOnlyAllowed(Q: TAdsQuery; AdsTbl: TTableInf; iI: Integer; Q1F : TAdsQuery);
var
  i, iMax,
  iDel,
  FillMax,
  j,
  jLeave : Integer;
  s: string;
  RowInf: TDupRow;
begin

  if (AppPars.DelDupMode = TDelDupMode(DDup_ALL)) then begin
    MarkAll4Del(Q, AdsTbl);
    Exit;
  end;

  j := 0;
  iDel    := 0;
  Q.First;
  while not Q.Eof do begin
    FillMax := 0;
    jLeave  := -1;
    iMax := Q.FieldValues[AL_DUPCNT];
    for i := 1 to iMax do begin
      RowInf := TDupRow.Create;
      RowInf.RowID := Q.FieldValues['ROWID'];
      RowInf.FillPcnt := RowFill(AdsTbl, RowInf.RowID, Q1F);
      if (RowInf.FillPcnt > FillMax) then begin
        jLeave := j;
        FillMax := RowInf.FillPcnt;
      end;
      AdsTbl.DupRows.Add(RowInf);
      j := j + 1;
      Q.Next;
    end;

    //Q.GotoBookmark(BegGr);
    for i := j - iMax to j - 1 do begin
      RowInf := AdsTbl.DupRows[i];

      if (i = jLeave) then begin
        RowInf.DelRow := False;
      end
      else begin
        RowInf.DelRow := True;
        if (iDel > 0) then begin
          s := s + ',';
        end;
        s := s + '''' + RowInf.RowID + '''';
        iDel := iDel + 1;
      end;
    end;

  end;
  AdsTbl.List4Del := s;
  AdsTbl.TotalDel := iDel;
end;



// оставить не больше одной записи из группы
procedure DelOtherDups(AdsTbl : TTableInf);
begin

end;











function SQL_7207_SearchEmpty(TblInf : TTableInf; iI : Integer; nMode : Integer) : string;
var
  i, j, t,
  iMax : Integer;
  s : String;
  IndInf : TIndexInf;
begin
  iMax := TblInf.IndCount;
  Result := 'DELETE FROM ' + TblInf.TableName + ' WHERE ' + TblInf.TableName + '.ROWID IN ';
  s := '(SELECT ROWID FROM ' + TblInf.TableName + ' WHERE ';
  IndInf := TblInf.IndexInf.Items[iI];

  iMax := IndInf.Fields.Count - 1;
  for i := 0 to iMax do begin
    if (i > 1) then
      s := s + ' OR ';
    j := IndInf.IndFieldsAdr[i];
    t := TblInf.FieldsInfAds[j].FieldType;
    s := s + EmptyFCond(IndInf.Fields.Strings[i], t);
  end;
  Result := Result + s + ')';
end;


{-------------------------------------------------------------------------------
  Procedure: Fix7207
  Author:    Alex
  DateTime:  2020.08.10
  Arguments: Table: string
  Result:    None
-------------------------------------------------------------------------------}
function Fix7207(TblInf: TTableInf; QDupGroups: TAdsQuery): Integer;
var
  RowFix,
  j, i: Integer;
  sExec: string;
begin
    RowFix := 0;
    with QDupGroups do begin
      if Active then
        Close;

      TblInf.DupRows := TList.Create;

      for i := 0 to TblInf.IndCount - 1 do begin
          // для всех уникальных индексов таблицы

          // поиск и удаление пустых [под]ключей
        sExec := SQL_7207_SearchEmpty(TblInf, i, 1);
        j := AdsConnection.Execute(sExec);
        RowFix := RowFix + j;

          // поиск совпадающих ключей
        SQL.Clear;
        sExec := UniqRepeat(TblInf, i);
        SQL.Add(sExec);
        VerifySQL;
        //ExecSQL;
        Active := True;
        if (RecordCount > 0) then begin

          // для всех групп с одинаковым значением индекса
          // оставить одну запись из группы
          LeaveOnlyAllowed(QDupGroups, TblInf, i, dtmdlADS.qDst);

          DelDups4Idx(TblInf);
        end;


          //ExecSQL;
          //Result := Result + RowsAffected;
      end;

      // поиск некорректных AUTOINC
      DelOtherDups(TblInf);

    end;

end;





// Добавить еще интервал хороших записей, если нужно
procedure OneSpan(var iBeg, iEnd: Integer; TotRecs: Integer; GSpans: TList);
var
  Span: TSpan;
begin
  if (iEnd >= iBeg) then begin
    // предыдущий интервал используем
    Span := TSpan.Create;
    // для конструкции TOP
    Span.InTOP   := iEnd - iBeg + 1;
    Span.InSTART := iBeg;
    GSpans.Add(Span);
  end;
  iEnd := TotRecs;
end;


// Список интервалов
procedure BuildSpans(BRecs: TList; SrcTbl: TTableInf);
var
  i,
  iBeg,
  iEnd : Integer;
  BadRec: TBadRec;
begin
  // предполагаемое начало интервала
  iBeg := 1;
  iEnd := SrcTbl.RecCount;
    for i := 0 to BRecs.Count - 1 do begin
      BadRec := TBadRec(BRecs[i]);
      // предыдущая перед ошибочной
      iEnd := BadRec.RecNo - 1;
      OneSpan(iBeg, iEnd, SrcTbl.RecCount, SrcTbl.GoodSpans);
      iBeg := BadRec.RecNo + 1;
    end;
    if (iBeg <= SrcTbl.LastGood) then
      OneSpan(iBeg, iEnd, SrcTbl.RecCount, SrcTbl.GoodSpans);
end;


// Коррктировка таблицы с поврежденными данными (Scan by Skip)
function Fix8901(SrcTblInf: TTableInf; TT: TAdsTable): Integer;
//function Fix8901SkipScan(SrcTblInf: TTableInf; TT: TAdsTable): Integer;
var
  BadField, Step, j, i: Integer;
  BadFInRec: TBadRec;
  BadRecs: TList;
begin
    Result := 0;
{
    if (dtmdlADS.cnABTmp.IsConnected) then
      dtmdlADS.cnABTmp.IsConnected := False;

    dtmdlADS.cnABTmp.ConnectPath := AppPars.Path2Tmp;
    dtmdlADS.cnABTmp.IsConnected := True;
}
    TT.TableName := SrcTblInf.TableName;
    TT.Active    := True;

    if (TT.RecordCount > 0) then begin
      BadRecs := TList.Create;
      i := 0;
      TT.First;
      Step := 1;
      while (not TT.Eof) do begin
        i := i + 1;
        try
          BadField := Read1RecEx(TT.Fields, SrcTblInf.FieldsInf);
          if (BadField >= 0) then begin
            BadFInRec := TBadRec.Create;
            BadFInRec.RecNo := i;
            BadFInRec.BadFieldI := BadField;
            BadRecs.Add(BadFInRec);
          end
          else
            SrcTblInf.LastGood := i;

        except

        end;
        TT.AdsSkip(Step);

      end;
    end
    else
      raise Exception.Create(EMSG_TBL_EMPTY);
    TT.Close;
    BuildSpans(BadRecs, SrcTblInf);
    Result := BadRecs.Count;
end;

// Реккурсивный подбор запроса на хорошие записи
function FloatQ(iStart: Integer; TName: string; Q: TAdsQuery; iMax: Integer): Integer;
var
  Err  : Boolean;
  iRes : Integer;
begin
  // Default - EoF
  Result := -1;
  Err := False;
  Q.SQL.Text := Format('SELECT TOP %d START AT %d * FROM %s', [iMax, iStart, TName]);
  try
    Q.Active := True;
    iRes := Q.RecordCount;
  except
    iRes := Max(1, iMax - 1);
    Err  := True;
  end;

  if (iRes > 0) then begin
    if (iRes <> iMax) or (Err = True) then begin
        // Уменьшаем запрос
      if (iMax > 1)then begin
        Q.Close;
        Q.AdsCloseSQLStatement;
        Result := FloatQ(iStart, TName, Q, iMax div 2);
      end
      else
        Result := -100;

    end
    else begin
      Q.First;
      Result := iRes;
    end;
  end

end;

// Очередной интервал хороших записей или EoF
function EofQ(iStart: Integer; TName: string; Q: TAdsQuery; var iMax: Integer): Boolean;
const
  MAX_RECS: Integer = 50000;
var
  iTry: Integer;
begin
  Result := False;
  if ((iStart + MAX_RECS - 1) > iMax) then
    // Выход за границы таблицы
    iTry := iMax - iStart + 1
  else
    iTry := MAX_RECS;
  iMax := FloatQ(iStart, TName, Q, iTry);
  if (iMax = -1) then
    Result := True;
end;


// Коррктировка таблицы с поврежденными данными (Scan by SQL-Select)
function Fix8901SQLScan(SrcTblInf: TTableInf; TT: TAdsTable): Integer;
//function Fix8901(SrcTblInf: TTableInf; TT: TAdsTable): Integer;
var
  NoRead: Boolean;
  iBeg, ij, jMax, BadField, Step, j, i: Integer;
  Q: TAdsQuery;
  BadFInRec: TBadRec;
  BadRecs: TList;
begin
    Result := 0;

    Q := TAdsQuery.Create(TT.AdsConnection.Owner);
    Q.AdsConnection := TT.AdsConnection;
    Q.Active := False;

    BadRecs := TList.Create;
    NoRead := False;
    iBeg := 1;
    jMax := SrcTblInf.RecCount;

    while not EofQ(iBeg, SrcTblInf.TableName, Q, jMax) do begin
      if (jMax = -100) then begin
        // Текущая запись не читается, в ошибочные
        jMax := 1;
        NoRead := True;
      end;

      for j := 1 to jMax do begin
        ij := iBeg + j - 1;

        try
          if (NoRead = True) then
            BadField := 1
          else
            BadField := Read1RecEx(Q.Fields, SrcTblInf.FieldsInf);
          if (BadField >= 0) then begin
            BadFInRec := TBadRec.Create;
            BadFInRec.RecNo := ij;
            BadFInRec.BadFieldI := BadField;
            BadRecs.Add(BadFInRec);
          end
          else
            SrcTblInf.LastGood := ij;
        except

        end;
        if (not NoRead) then
          Q.Next;

      end;

      Q.Close;
      Q.AdsCloseSQLStatement;

      iBeg   := iBeg + jMax;
      NoRead := False;
      jMax   := SrcTblInf.RecCount;

    end;

    BuildSpans(BadRecs, SrcTblInf);
    Result := BadRecs.Count;
end;
















// вызов метода для кода ошибки
function TblErrorController(SrcTbl: TTableInf): Integer;
var
  FixState : Integer;
begin
  try
    if (dtmdlADS.cnABTmp.IsConnected) then
      dtmdlADS.cnABTmp.IsConnected := False;

    dtmdlADS.cnABTmp.ConnectPath := AppPars.Path2Tmp;
    dtmdlADS.cnABTmp.IsConnected := True;

    if (dtmdlADS.tblTmp.Active = True) then
      dtmdlADS.tblTmp.Close;
    dtmdlADS.tblTmp.AdsConnection := dtmdlADS.cnABTmp;

    case SrcTbl.ErrInfo.ErrClass of
      7008, 7207:
        begin
            SrcTbl.RowsFixed := Fix7207(SrcTbl, dtmdlADS.qDupGroups);
        end;
      7200:
        begin
          if (SrcTbl.ErrInfo.NativeErr = 7123) then begin
          // неизвестный тип поля
            PutError(EMSG_SORRY);
            raise Exception.Create(EMSG_SORRY);
          end
          else
            SrcTbl.RowsFixed := Fix7207(SrcTbl, dtmdlADS.qDupGroups);
        end;
      UE_BAD_DATA:
        begin
          SrcTbl.RowsFixed := Fix8901(SrcTbl, dtmdlADS.tblTmp);
        end;
    end;
    SrcTbl.ErrInfo.State := FIX_GOOD;

  except
    SrcTbl.ErrInfo.State := FIX_ERRORS;
    SrcTbl.ErrInfo.PrepErr := UE_BAD_FIX;
  end;

end;


// Копия оригинала и освобождение таблицы
function PrepTable(SrcTbl: TTableInf): Integer;
var
  s,
  FileSrc,
  FileDst: string;
begin
  Result := UE_BAD_PREP;
  try
    FileSrc := AppPars.Path2Src + SrcTbl.TableName;
    SrcTbl.FileTmp := AppPars.Path2Tmp + SrcTbl.TableName + '.adt';
    s := FileSrc + '.adt';
    if (CopyOneFile(s, AppPars.Path2Tmp) <> 0) then
      raise Exception.Create('Ошибка копирования ' + s);
    s := FileSrc + '.adm';
    if FileExists(s) then begin
      if (CopyOneFile(s, AppPars.Path2Tmp) <> 0) then
        raise Exception.Create('Ошибка копирования ' + s);
    end;
    if AdsDDFreeTable(PAnsiChar(SrcTbl.FileTmp), nil) = AE_FREETABLEFAILED then
      raise EADSDatabaseError.Create(SrcTbl.AdsT, UE_BAD_PREP, 'Ошибка освобождения таблицы');
    SrcTbl.ErrInfo.PrepErr := 0;
    Result := 0;
  except
    SrcTbl.ErrInfo.State   := FIX_ERRORS;
    SrcTbl.ErrInfo.PrepErr := UE_BAD_PREP;
  end;
end;


// Исправить все отмеченные
procedure FixAllMarked;
var
  ErrCode, i: Integer;
  SrcTbl: TTableInf;
begin
  with dtmdlADS.mtSrc do begin
    First;
    i := 0;
    while not Eof do begin
      i := i + 1;
      if (dtmdlADS.FSrcMark.AsBoolean = True) then begin
        SrcTbl := TTableInf(Ptr(dtmdlADS.FSrcFixInf.AsInteger));
        if (Assigned(SrcTbl)) then begin
          // Тестирование выполнялось, объект создан
          dtmdlADS.mtSrc.Edit;

          ErrCode := PrepTable(SrcTbl);
          if (ErrCode = 0) then begin
            dtmdlADS.FSrcFixCode.AsInteger := TblErrorController(SrcTbl);
          end
          else begin
            dtmdlADS.FSrcFixCode.AsInteger := ErrCode;
          end;

          dtmdlADS.mtSrc.Post;
        end;
      end;
      Next;
    end;
  end;
end;




// AutoInc => Integer
function ChangeAI2Int(SrcTbl: TTableInf): Boolean;
var
  i: Integer;
  s: string;
begin
  Result := True;
  try
    if (SrcTbl.FieldsAI.Count > 0) then begin
      s := 'ALTER TABLE ' + SrcTbl.TableName;
      for i := 0 to (SrcTbl.FieldsAI.Count - 1) do begin
        s := s + ' ALTER COLUMN ' + SrcTbl.FieldsAI[i] + ' ' + SrcTbl.FieldsAI[i] + ' INTEGER';
      end;
      SrcTbl.AdsT.AdsConnection.Execute(s);
    end;
  except
    Result := False;
  end;
end;

// Integer => AutoInc
function ChangeInt2AI(SrcTbl: TTableInf): Boolean;
var
  ec : Boolean;
  i  : Integer;
  s  : string;
begin
  Result := True;
  try
    if (SrcTbl.FieldsAI.Count > 0) then begin
      s := 'ALTER TABLE ' + SrcTbl.TableName;
      for i := 0 to (SrcTbl.FieldsAI.Count - 1) do begin
        s := s + ' ALTER COLUMN ' + SrcTbl.FieldsAI[i] + ' ' + SrcTbl.FieldsAI[i] + ' AUTOINC';
      end;
      SrcTbl.AdsT.AdsConnection.Execute(s);
      ec := DeleteFiles(AppPars.Path2Src + SrcTbl.TableName + '.ad?.bak');
    end;
  except
    Result := False;
  end;

end;


// Вставка в обнуляемый оригинал исправленных записей
function ChangeOriginal(SrcTbl: TTableInf): Boolean;
var
  ecb: Boolean;
  i: Integer;
  FileSrc, FileDst, TmpName, ss, sd: string;
  Span: TSpan;
begin
  Result := False;

  SrcTbl.AdsT.Active := False;
  SrcTbl.AdsT.AdsConnection.Disconnect;

  FileSrc := AppPars.Path2Src + SrcTbl.TableName;
  FileDst := AppPars.Path2Tmp + SrcTbl.TableName + '.adt';
  TmpName := AppPars.Path2Src + ORGPFX + SrcTbl.TableName;

  if (SrcTbl.NeedBackUp = True) then begin
    // Перед вставкой сделать копию
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
    if (ChangeAI2Int(SrcTbl) = True) then begin
      if (SrcTbl.GoodSpans.Count <= 0) then begin
        // Загрузка оптом
        ss := 'INSERT INTO ' + SrcTbl.TableName + ' SELECT * FROM "' + FileDst + '" SRC';
        if (Length(SrcTbl.DmgdRIDs) > 0) then
          ss := ss + ' WHERE SRC.ROWID NOT IN (' + SrcTbl.DmgdRIDs + ')';
        SrcTbl.AdsT.AdsConnection.Execute(ss);
      end
      else begin
        // Загрузка интервалами хороших записей
        for i := 0 to SrcTbl.GoodSpans.Count - 1 do begin
          Span := SrcTbl.GoodSpans[i];

          ss := 'INSERT INTO ' + SrcTbl.TableName + ' SELECT TOP ' + IntToStr(Span.InTOP) + ' START AT ' + IntToStr(Span.InSTART) + ' * FROM "' + FileDst + '" SRC';
          SrcTbl.AdsT.AdsConnection.Execute(ss);

        end;

      end;
      ChangeInt2AI(SrcTbl);
      SrcTbl.AdsT.AdsConnection.Disconnect;

    end;
    Result := True;
  except
    on E: EADSDatabaseError do begin
      SrcTbl.ErrInfo.InsErr := E.ACEErrorCode;
    end
    else
      SrcTbl.ErrInfo.InsErr := UE_BAD_INS;
  end;

end;


// Исправить оригинал для отмеченных
procedure ChangeOriginalAllMarked;
var
  GoodChange: Boolean;
  i: Integer;
  SrcTbl: TTableInf;
begin
  with dtmdlADS.mtSrc do begin
    First;
    i := 0;
    while not Eof do begin
      i := i + 1;
      if (dtmdlADS.FSrcMark.AsBoolean = True) then begin
        // для отмеченных

        SrcTbl := TTableInf(Ptr(dtmdlADS.FSrcFixInf.AsInteger));
        if (Assigned(SrcTbl)) then begin
          // Тестирование выполнялось, объект создан
          if (SrcTbl.ErrInfo.State = FIX_GOOD) then begin

            dtmdlADS.mtSrc.Edit;
            GoodChange := ChangeOriginal(SrcTbl);

            if (GoodChange = True) then begin
          // успешно вствлено
              dtmdlADS.FSrcFixCode.AsInteger := SrcTbl.ErrInfo.InsErr;
              dtmdlADS.FSrcMark.AsBoolean := False;
            end
            else begin
          // ошибки вставки
              dtmdlADS.FSrcFixCode.AsInteger := UE_BAD_INS;
            end;

            dtmdlADS.mtSrc.Post;
          end;
        end;
      end;
      Next;
    end;

  end;

end;

// Удаление сохраненных оригиналов с ошибками (BAckups) для одной таблицы
function DelBUps4OneTable(SrcTbl: TTableInf): integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 1 to SrcTbl.BackUps.Count do
    if (DeleteFiles(SrcTbl.BackUps[i - 1]) = True) then
      Result := Result + 1;
end;

// Удалить BAckup оригиналов
procedure DelBackUps;
var
  PTblInf : ^TTableInf;
  TotDel  : Integer;
begin

  with dtmdlADS.mtSrc do begin
    First;
    TotDel := 0;
    while not Eof do begin
      PTblInf := Ptr(dtmdlADS.FSrcFixInf.AsInteger);
      if Assigned(PTblInf) then begin
        TotDel := TotDel + DelBUps4OneTable(TTableInf(PTblInf));
      end;
      Next;
    end;
  end;

end;

// Полный цикл для одной таблицы
function FullFixOneTable(TName: string; TID: Integer; Ptr2TableInf: Integer; FixPars: TAppPars; Q: TAdsQuery): TTableInf;
var
  ec, i: Integer;
  SrcTbl: TTableInf;
begin

  if (Ptr2TableInf = 0) then begin
    SrcTbl := TTableInf.Create(TName, TID, Q.AdsConnection, FixPars.SysAdsPfx);
    ec := SrcTbl.Test1Table(SrcTbl, Q, FixPars.TMode);
  end
  else begin
    SrcTbl := TTableInf(Ptr(Ptr2TableInf));
    ec := SrcTbl.ErrInfo.ErrClass;
  end;
  Result := SrcTbl;

  if (ec > 0) then begin
    // Ошибки тестирования были
    SrcTbl.ErrInfo.PrepErr := PrepTable(SrcTbl);
    if (SrcTbl.ErrInfo.PrepErr = 0) then begin
      // Исправление копии
      SrcTbl.ErrInfo.FixErr := TblErrorController(SrcTbl);
      if (SrcTbl.ErrInfo.FixErr = 0) then begin
        // Исправление оригинала
        if (ChangeOriginal(SrcTbl) = True) then
          SrcTbl.ErrInfo.State := INS_GOOD
        else
          SrcTbl.ErrInfo.State := INS_ERRORS;
      end;
    end;
  end;
end;


// Full Proceed для всех/отмеченных
procedure FullFixAllMarked(FixAll : Boolean = True);
var
  ec, i: Integer;
  TName: string;
  SrcTbl: TTableInf;
begin
  if (dtmdlADS.tblAds.Active) then
    dtmdlADS.tblAds.Close;

  SortByState(False);
  with dtmdlADS.mtSrc do begin
    First;
    i := 0;
    while not Eof do begin
      i := i + 1;
      if (dtmdlADS.FSrcMark.AsBoolean = True)
      or (FixAll = True) then begin

        TName := FieldByName('TableName').Value;

        Edit;
        SrcTbl := FullFixOneTable(TName, FieldByName('Npp').Value, dtmdlADS.FSrcFixInf.AsInteger, AppPars, dtmdlADS.qAny);
        dtmdlADS.FSrcFixInf.AsInteger := Integer(SrcTbl);

        dtmdlADS.FSrcState.AsInteger  := SrcTbl.ErrInfo.State;
        dtmdlADS.FSrcTestCode.AsInteger := SrcTbl.ErrInfo.ErrClass;
        dtmdlADS.FSrcErrNative.AsInteger := SrcTbl.ErrInfo.NativeErr;

        if (SrcTbl.ErrInfo.PrepErr > 0) then
          dtmdlADS.FSrcFixCode.AsInteger := SrcTbl.ErrInfo.PrepErr
        else
          dtmdlADS.FSrcFixCode.AsInteger := SrcTbl.ErrInfo.FixErr;

        dtmdlADS.FSrcMark.AsBoolean := False;
        Post;

      end;
      Next;
    end;

  end;
  SortByState(True);

end;


end.
