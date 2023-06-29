unit uFixErrs;

interface

uses
  SysUtils, Classes, DB,
  adsset, adscnnct, adsdata, adsfunc, adstable, ace,
  kbmMemTable,
  AdsDAO,
  uServiceProc,
  uTableUtils;

const

  // Эмпирические веса заполненных полей в соответственно типу
  FWT_BOOL : Integer = 1;
  FWT_NUM  : Integer = 3;
  FWT_DATE : Integer = 5;
  FWT_STR  : Integer = 30;
  FWT_BIN  : Integer = 5;

  // Таблица (временная) с планом исправлений
  TMP_PLAN = '#tmpPlanFix';

type
  // Описание планируемой к удалению строки ADT-таблицы
  TRow4Del = class
    RowID : string;
    FillPcnt : Integer;
    DelRow : Boolean;
    Reason : Integer;
    GroupID : string;
  end;

  TFixUniq = class(TInterfacedObject)
  // Класс исправления ошибок уникальности индексов
  // в таблицах ADS
  private
    FPars     : TFixPars;
    FTableInf : TTableInf;
    FTmpConn  : TAdsConnection;
    FQDups    : TAdsQuery;
    FDelEmps  : Integer;
    FDelDups  : Integer;
    //FIDs4Del  : string;

    FBadRows  : TStringList;

    // SQL-запрос поиска пустых значений [под]ключей среди уникадьных индексов
    function SearchEmptyAnyAll(IndInf : TIndexInf; BoolOp : string = ' OR ') : string;

    // Поиск [и удаление]пустых значений [под]ключей среди уникадьных индексов
    function FindDelEmpty(IndInf: TIndexInf; QTmp: TAdsQuery; DelNow: Boolean = True): integer;

    //
    function NewRow4Del(Q: TAdsQuery; Dst : TStringList; var Why: Integer; DelEmpty : Boolean = False): string;

    // Поиск ROWID дубликатов ключей среди уникадьных индексов
    function UniqRepeat(iI : Integer) : string;

    // Отметить все для удаления
    function MarkAll4Del(Q : TAdsQuery; DelNow: Boolean): integer;

    // Перебор дубликатов, выбор и формирование списка для удаления
    function LeaveOnlyAllowed(Q: TAdsQuery; Q1F: TAdsQuery; DelNow : Boolean): integer;
    function Plan4DelByRowIds : Integer;
    // Исправление ошибок 7200, 7207
    function Fix7207 : Integer;
  protected
  public
    //Rows4Del : TStringList;
    // Планируемые исправления
    PlanFixQ : TAdsQuery;

    // Параметры проверки и исправления
    property FixPars : TFixPars read FPars write FPars;
    // Объект состояния таблицы
    property SrcTbl : TTableInf read FTableInf write FTableInf;
    // ADS-Connection для папки TMP
    property TmpConn: TAdsConnection read FTmpConn write FTmpConn;

    // Дубликаты в free-таблице по GROUP BY
    property QDups: TAdsQuery read FQDups write FQDups;

    constructor Create(Table2Fix: TTableInf; Pars: TFixPars);
    destructor Destroy; override;

    // Исправление ошибок 7200, 7207
    class function FixDupRec(Table2Fix: TTableInf; Pars: TFixPars): integer;
  published
  end;

type
  IFixDamaged = Interface
  ['{9CFB115F-B9EE-4A38-A51A-295F1E7E56EC}']
    function Fix8901(SrcTblInf: TTableInf; TT: TAdsTable): Integer;
  end;

function Fix8901(SrcTblInf: TTableInf; TT: TAdsTable): Integer;


// Исправить оригинал для отмеченных
//procedure ChangeOriginalAllMarked;
procedure ProceedBackUps(Mode : Integer; AllTables: TkbmMemTable);

// Easy Mode - one button
//procedure FullFixAllMarked(FixAll : Boolean = True);

var
  UInd : TIndexInf;

implementation

uses
  FileUtil,
  Math,
  FuncPr;

class function TFixUniq.FixDupRec(Table2Fix: TTableInf; Pars: TFixPars): integer;
var
  FixDupU: TFixUniq;
begin
  Result := 0;
  FixDupU := TFixUniq.Create(Table2Fix, Pars);
  try
    Table2Fix.RowsFixed := FixDupU.Fix7207;
    Result := FIX_GOOD;
  finally
    FreeAndNil(FixDupU);
  end;
end;

constructor TFixUniq.Create(Table2Fix: TTableInf; Pars: TFixPars);
begin
  SrcTbl  := Table2Fix;
  FixPars := Pars;
  TmpConn := dtmdlADS.cnnTmp;

  QDups := TAdsQuery.Create(SrcTbl.AdsT.Owner);
  QDups.AdsConnection := TmpConn;

  //Table2Fix.ErrInfo.Plan2Del := TAdsQuery.Create(SrcTbl.AdsT.Owner);
  //Table2Fix.ErrInfo.Plan2Del.AdsConnection := Cn;

  //Table2Fix.ErrInfo.PlanFix := PlanTable;
  //Table2Fix.ErrInfo.PlanFix.AdsConnection := Cn;
  PlanFixQ := dtmdlADS.qDst;

  FBadRows := TStringList.Create;
  FBadRows.CaseSensitive := True;
  FBadRows.Sorted := False;
end;

destructor TFixUniq.Destroy;
begin
  inherited Destroy;
  FreeAndNil(FQDups);
  FreeAndNil(FBadRows);
end;


// Сткока условия [НЕ]пустого поля для SQL-команды
function EmptyFCond(FieldName: String; FieldType: Integer; NotEmpty: Boolean = False): string;
var
  sT : string;
begin
  sT := '';
  Result := '(' + FieldName + ' is NULL)';

  if  (FieldType in ADS_NUMBERS) then
    sT := ' OR (' + FieldName + ' <= 0)'
//  else if (FieldType in ADS_STRINGS) then
//    Result := Result + ' OR EMPTY(' + FieldName + ')'
  else if (FieldType in ADS_STRINGS) or (FieldType in ADS_DATES) then
    sT := ' OR EMPTY(' + FieldName + ')';

  if ( Length(sT) > 0 ) then
  // если два условия
    Result := '(' + Result + sT + ')';

  if (NotEmpty = True) then
  // Нужно НЕпусто
    Result := '( NOT ' + Result + ' )';
end;


// Удалить строки по списку ROWID
function DelByRowIds(TName, List4Del : string; Cn : TAdsConnection) : Integer;
var
  s : string;
begin
  s := Format('DELETE FROM "%s" WHERE ROWID IN (%s)', [TName, List4Del]);
  Result := Cn.Execute(s);
end;


// Построить SQL-запрос для получения редактируемого DataSet
function MakeEditAbleCursor(const SQLMain1, SQLMain2 : string; SortBy : string = ''; TmpName : string = TMP_PLAN) : string;
begin
  Result := Format('TRY DROP TABLE %s;CATCH ALL END TRY; %s INTO %s %s;',
    [TmpName, SQLMain1, TmpName, SQLMain2]);
  if (SortBy <> '') then
    SortBy := ' ORDER BY ' + SortBy;
  Result := Result + Format(' SELECT * FROM %s %s;', [TmpName, SortBy]);
end;


// Список планируемых удалений
function TFixUniq.Plan4DelByRowIds : Integer;
var
  j,
  r, i: integer;
  sFieldList,
  //sSQL,
  sIDs,
  sEnd,
  sBeg: string;
  Q: TAdsQuery;
  Plan: TAdsTable;
  xR4D : TRow4Del;
begin
  try

    sIDs := SList2StrCommas(FBadRows);
    sFieldList := SList2StrCommas(SrcTbl.FieldsInf, '', '');
    sBeg := 'SELECT ''GDUP'' AS ' + AL_DKEY + ', ROWID, ROWNUM() AS NPP_, ''DUP'' AS RSN_, TRUE AS FDEL_, ' + sFieldList;
    sEnd := Format('FROM "%s" WHERE ROWID IN (%s) ', [SrcTbl.TableName, sIDs]);
    sEnd := sEnd + Format('; ALTER TABLE %s ALTER COLUMN %s %s CHAR(20) ALTER COLUMN RSN_ RSN_ CHAR(10)',
    [TMP_PLAN, AL_DKEY, AL_DKEY]);


    Q := PlanFixQ;
    Q.Close;
    Q.AdsCloseSQLStatement;
    Q.SQL.Clear;
    Q.SQL.Text := MakeEditAbleCursor(sBeg, sEnd, '', TMP_PLAN);
    Q.RequestLive := True;
    MemoWrite('z222', Q.SQL.Text);
    Q.Active := True;
    Q.First;

    i := 0;
    while not Q.Eof do begin
      j := FBadRows.IndexOf(Q.FieldValues['ROWID']);

      if (j >= 0) then begin
        xR4D := TRow4Del(FBadRows.Objects[j]);
        r := xR4D.Reason;
        Q.Edit;
        Q.FieldValues['FDEL_'] := xR4D.DelRow;
        Q.FieldValues[AL_DKEY] := xR4D.GroupID;
{

        if (r = RSN_EMP_KEY) then
          Q.FieldValues['RSN_'].AsString := 'Пусто'
        else if (r = RSN_DUP_KEY) then
          Q.FieldValues['RSN_'] := 'Дубль';
}          
        Q.Post;
      end;

      i := i + 1;
      Q.Next;
    end;

    Result := Q.RecordCount;
  except
    Result := -1;
  end;
end;




// Добавить в список
function TFixUniq.NewRow4Del(Q: TAdsQuery; Dst : TStringList; var Why: Integer; DelEmpty : Boolean = False): string;
var
  RowDel : TRow4Del;
begin
  Result := Q.FieldValues['ROWID'];
  if (Dst.IndexOf(Result) < 0) then begin
    RowDel := TRow4Del.Create;
    RowDel.RowID := Result;
    RowDel.DelRow := True;
    RowDel.Reason := Why;
    //RowDel.GroupID := Iif(DelEmpty, '', Q.FieldValues[AL_DKEY]);
    if (DelEmpty) then
      RowDel.GroupID := ''
    else
      RowDel.GroupID := Q.FieldValues[AL_DKEY];
    Dst.AddObject(Result, RowDel);
    Why := Dst.Count - 1;
  end
  else
    Why := -1;
end;

// SQL-команда поиска записей с любым/всеми пустыми [под]ключами уникального индекса
function TFixUniq.SearchEmptyAnyAll(IndInf : TIndexInf; BoolOp : string = ' OR ') : string;
var
  i, j : Integer;
  s : String;
begin
  s := '';
  for i := 0 to IndInf.Fields.Count - 1 do begin
    if (i > 0) then
      s := s + BoolOp;
    j := IndInf.IndFieldsAdr[i];
    s := s + EmptyFCond(IndInf.Fields.Strings[i], TFieldsInf(SrcTbl.FieldsInf.Objects[j]).FieldType);
  end;
  Result := Format('SELECT ROWID FROM "%s" WHERE %s', [SrcTbl.TableName, s]);
end;

// поиск и удаление пустых [под]ключей
function TFixUniq.FindDelEmpty(IndInf: TIndexInf; QTmp: TAdsQuery; DelNow: Boolean = True): integer;
var
  iNew,
  nDel, i: Integer;
  sID, sExec: string;
  //RowDel: TRow4Del;
begin
  nDel := 0;
  sExec := SearchEmptyAnyAll(IndInf);
  QTmp.SQL.Clear;
  QTmp.SQL.Add(sExec);
  QTmp.Active := True;

  if (QTmp.RecordCount > 0) then begin
    QTmp.First;
    sExec := '';
    for i := 0 to (QTmp.RecordCount - 1) do begin
      iNew := RSN_EMP_KEY;
      sID := NewRow4Del(QTmp, FBadRows, iNew, True);
      if (iNew >= 0) then begin
        nDel := nDel + 1;
        if (nDel > 1) then
          sExec := sExec + ',';
        sExec := sExec + '''' + sID + '''';
      end;
      QTmp.Next;
    end;
    if (nDel > 0) then begin
      if (DelNow = True) then
        nDel := DelByRowIds(SrcTbl.TableName, sExec, TmpConn);
    end;
  end;
  Result := nDel;
end;

// SQL-запрос создания списка ROWID дубликатов с пустыми [под]ключами уникального индекса
// ---
// SELECT S.ROWID, '0'+D.ROWID AS DUPGKEY,D.DUPCNT,S.TYPEOBJ,S.ID,S.DATES,S.POKAZ
//   FROM BaseTextProp S INNER JOIN
//   (
//     SELECT COUNT(*) AS DUPCNT,TYPEOBJ,ID,DATES,POKAZ
//       FROM BaseTextProp GROUP BY TYPEOBJ,ID,DATES,POKAZ HAVING (COUNT(*) > 1)
//    ) D
//    ON (S.TYPEOBJ=D.TYPEOBJ) AND (S.ID=D.ID) AND (S.DATES=D.DATES) AND (S.POKAZ=D.POKAZ)
//    ORDER BY DUPGKEY'
function TFixUniq.UniqRepeat(iI : Integer) : string;
var
  CommasList : string;
  IndInf : TIndexInf;
begin
  IndInf := TIndexInf(SrcTbl.IndexInf.Items[iI]);
  CommasList := SList2StrCommas(IndInf.Fields, '', '');
  Result := Format(
    'SELECT %s.ROWID, ''%d'' + %s.ROWID AS %s%s %s',     [AL_SRC, iI, AL_DUP, AL_DKEY, AL_DUPCNTF, SList2StrCommas(IndInf.Fields, AL_SRC + '.', '')]);
  Result := Result + Format(
    ' FROM "%s" %s INNER JOIN (SELECT %s, COUNT(*) AS %s', [SrcTbl.TableName, AL_SRC, CommasList, AL_DUPCNT]);
  Result := Result + Format(
    ' FROM "%s" GROUP BY %s HAVING (COUNT(*) > 1) ) %s',   [SrcTbl.TableName, CommasList, AL_DUP]);
  Result := Result + Format(
    ' ON %s ORDER BY %s',                                [IndInf.EquSet, AL_DKEY]);
end;


// вес (% заполнения) одного непустого поля
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

// Расчет веса одной строки на основе весов заполненных полей
function RowFill(AdsTbl: TTableInf; RowID: string; Q1F: TAdsQuery): integer;
var
  FT, RowWeight, i: integer;
  sField, sEmpCond, s4All, s: string;
begin
  Result := 0;
  s4All := ' WHERE (ROWID=''' + RowID + ''') AND ';
  RowWeight := 0;
  Q1F.Active := False;

  try
    for i := 0 to AdsTbl.FieldsInf.Count - 1 do begin
      if (i > 0) then
        s := s + ' OR ';
      sField := AdsTbl.FieldsInf[i];
      FT := TFieldsInf(AdsTbl.FieldsInf.Objects[i]).FieldType;
      sEmpCond := EmptyFCond(sField, FT, True);
      //s := 'SELECT ' + sField + ' FROM ' + AdsTbl.TableName + s4All + sEmpCond;
      s := Format('SELECT %s FROM "%s" %s %s', [sField, AdsTbl.TableName, s4All, sEmpCond]);
      Q1F.SQL.Clear;
      Q1F.SQL.Add(s);
      Q1F.Active := True;
      if (Q1F.RecordCount > 0) then
        RowWeight := RowWeight + FieldWeight(Q1F, sField, FT);
    end;
  except
  end;
  Result := RowWeight;
end;

// Отметить все для удаления
function TFixUniq.MarkAll4Del(Q : TAdsQuery; DelNow: Boolean): integer;
var
  iNew, i: Integer;
  sID, s: string;
begin
  Q.First;
  i := 0;
  try
    s := '';
    while not Q.Eof do begin
      iNew := RSN_DUP_KEY;
      sID := NewRow4Del(Q, FBadRows, iNew);
      if (iNew >= 0) then begin
        if (i > 0) then
          s := s + ',';
        s := s + '''' + sID + '''';
        i := i + 1;
      end;
      Q.Next;
    end;
    if (i > 0) then begin
      if (DelNow = True) then
        i := DelByRowIds(SrcTbl.TableName, s, TmpConn);
    end;
  finally
    Result := i;
  end;
end;

// оставить не больше одной записи из группы дубликатов
// в зависимости от режима удаления
function TFixUniq.LeaveOnlyAllowed(Q: TAdsQuery; Q1F: TAdsQuery; DelNow : Boolean): integer;
var
  i, iMax, iDel, FillMax, iNew, RWeight, j, jMax, jStart: Integer;
  sID, s: string;
  RowInf: TRow4Del;
begin
  Result := 0;
  if (FixPars.DelDupMode = TDelDupMode(DDup_ALL)) then begin
    // удалить все дубли
    Result := MarkAll4Del(Q, DelNow);
    Exit;
  end;

  j := 0;
  iDel := 0;
  Q.First;
  while not Q.Eof do begin
    FillMax := 0;
    // если добавим, с него и начнем
    jStart := FBadRows.Count;
    // дубликатов в группе
    iMax := Q.FieldValues[AL_DUPCNT];
    for i := 1 to iMax do begin
    // только для текущего набора подключей
      iNew := RSN_DUP_KEY;
      sID := NewRow4Del(Q, FBadRows, iNew);
      if (iNew >= 0) then begin
        RWeight := RowFill(SrcTbl, sID, Q1F);
        TRow4Del(FBadRows.Objects[iNew]).FillPcnt := RWeight;
        if (RWeight >= FillMax) then begin
         // запомним максивальное заполнение строки в группе
          jMax := iNew;
          FillMax := RWeight;
        end;
      end;
      j := j + 1;
      Q.Next;
    end;

    // проход по вновь добавленным
    for i := jStart to FBadRows.Count - 1 do begin
      RowInf := TRow4Del(FBadRows.Objects[i]);

      if (i = jMax) then
      // с максимальным весом - оставим
        RowInf.DelRow := False
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
  if (DelNow = True) then
    Result := DelByRowIds(SrcTbl.TableName, s, TmpConn)
  else
    Result := iDel;

end;

// поиск некорректных AUTOINC
procedure DelOtherDups(AdsTbl : TTableInf);
begin

end;

// Ошибки уникальных ключей
function TFixUniq.Fix7207: Integer;
var
  RowFix, j, i: Integer;
  sExec: string;
  DelNow : Boolean;
  Q : TAdsQuery;
begin
  Result := 0;
  FDelEmps := 0;
  FDelDups := 0;
  if (FixPars.DelDupMode = TDelDupMode(DDup_USel)) then
  // Пользователь сам определится
    DelNow := False
  else
    DelNow := True;

  Q := TAdsQuery.Create(SrcTbl.AdsT.Owner);
  Q.AdsConnection := TmpConn;
  try
      for i := 0 to SrcTbl.IndCount - 1 do begin
      // для всех уникальных индексов таблицы

        // поиск и удаление строк с пустыми [под]ключами

        //sExec := SQL_7207_SearchEmpty(SrcTbl.IndexInf.Items[i]);
        //FDelEmps := FDelEmps + TmpConn.Execute(sExec);

        FDelEmps := FDelEmps + FindDelEmpty(TIndexInf(SrcTbl.IndexInf.Items[i]), Q, DelNow);

        // поиск совпадающих ключей
        QDups.SQL.Clear;
        sExec := UniqRepeat(i);
        QDups.SQL.Add(sExec);
        QDups.VerifySQL;
        QDups.Active := True;
        if (QDups.RecordCount > 0) then begin
          // для всех групп с одинаковым значением индекса
          // оставить одну запись из группы
          FDelDups := FDelDups + LeaveOnlyAllowed(QDups, Q, DelNow);
        end;
      end;
      // поиск некорректных AUTOINC
      DelOtherDups(SrcTbl);
  except
    on E: EADSDatabaseError do begin
      Result := 0;
      SrcTbl.ErrInfo.ErrClass  := E.ACEErrorCode;
      SrcTbl.ErrInfo.NativeErr := E.SQLErrorCode;
      SrcTbl.ErrInfo.MsgErr    := E.Message;
      SrcTbl.ErrInfo.State     := FIX_ERRORS;
    end;
  end;
  Result := FDelEmps + FDelDups;
  if (Result > 0) then
    Plan4DelByRowIds;
end;


// Восстановление сохраненных оригиналов с ошибками (BAckups) для одной таблицы
function RestBUps4OneTable(SrcTbl: TTableInf): integer;
var
  FullName, Orig: string;
  i: Integer;
begin
  Result := 0;
  try
    Orig := SrcTbl.Pars.Path2Src + SrcTbl.NameNoExt;
    FullName := Orig + ExtADI;
    if (FileExists(FullName)) then
        DeleteFile(FullName);

    for i := 0 to SrcTbl.BackUps.Count-1 do begin
      FullName := Orig + ExtractFileExt(SrcTbl.BackUps[i]);
      if (FileExists(FullName)) then
        DeleteFile(FullName);
      if (RenameFile(SrcTbl.BackUps[i], FullName) = True) then begin
        Result := Result + 1;
        SrcTbl.BackUps[i] := '';
      end
      else
        raise Exception.Create('Ошибка восстановления оригинала ' + FullName);
    end;
    SrcTbl.BackUps.Clear;
  except
    Result := -1;
  end;
end;


// Удаление сохраненных оригиналов с ошибками (BAckups) для одной таблицы
function DelBUps4OneTable(SrcTbl: TTableInf): integer;
var
  i: Integer;
begin
  Result := 0;
  try
  for i := 0 to SrcTbl.BackUps.Count-1 do
    if (DeleteFiles(SrcTbl.BackUps[i]) = True) then begin
      Result := Result + 1;
      SrcTbl.BackUps[i] := '';
    end;
  SrcTbl.BackUps.Clear;
  except
    Result := -1;
  end;
end;

// Удалить BAckup оригиналов
procedure ProceedBackUps(Mode : Integer; AllTables: TkbmMemTable);
var
  PTblInf: ^TTableInf;
  TotFiles: Integer;
begin
  if (AllTables.Active = True) then
    with AllTables do begin
      First;
      TotFiles := 0;
      while not Eof do begin
        PTblInf := Ptr(FieldByName('TableInf').AsInteger);
        if Assigned(PTblInf) then begin
          if (Mode = 0) then
            TotFiles := TotFiles + DelBUps4OneTable(TTableInf(PTblInf))
          else
            TotFiles := TotFiles + RestBUps4OneTable(TTableInf(PTblInf));
        end;
        Next;
      end;
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
procedure BuildSpans(SrcTbl: TTableInf);
var
  i,
  iBeg,
  iEnd : Integer;
  BadRec: TBadRec;
begin
  // предполагаемое начало интервала
  iBeg := 1;
  iEnd := SrcTbl.RecCount;
    for i := 0 to SrcTbl.BadRecs.Count - 1 do begin
      BadRec := TBadRec(SrcTbl.BadRecs[i]);
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
  Step, i: Integer;
  BadFInRec: TBadRec;
begin
  Result := 0;
  TT.TableName := SrcTblInf.TableName;
  TT.Active := True;
  try

    SrcTblInf.BadRecs.Clear;
    SrcTblInf.GoodSpans.Clear;
    if (TT.RecordCount > 0) then begin
      i := 0;
      TT.First;
      Step := 1;
      while (not TT.Eof) do begin
        i := i + 1;
        BadFInRec := Read1RecEx(TT.Fields, SrcTblInf.FieldsInf);
        if (Assigned(BadFInRec)) then begin
          BadFInRec.RecNo := i;
          SrcTblInf.BadRecs.Add(BadFInRec);
        end
        else
          SrcTblInf.LastGood := i;
        TT.AdsSkip(Step);
      end;

      BuildSpans(SrcTblInf);
      Result := SrcTblInf.BadRecs.Count;
    end
    else
      raise Exception.Create(EMSG_TBL_EMPTY);
  finally
    TT.Close;
  end;
end;

















end.
