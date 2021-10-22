unit uFixDups;

interface

uses
  SysUtils, Classes, adsset, adscnnct, DB, adsdata, adsfunc, adstable, ace,
  kbmMemTable,
  //EncdDecd,
  //FixTypes,
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

    // Список
    //property RowIDs4Del : string read FIDs4Del write FIDs4Del;

    // Исправление ошибок 7200, 7207
    function Fix7207 : Integer;

    constructor Create(TI : TTableInf; Pars : TFixPars);
    destructor Destroy; override;
  published
  end;


//procedure FixAllMarked;

// Исправить оригинал для отмеченных
//procedure ChangeOriginalAllMarked;
procedure ProceedBackUps(Mode : Integer);

// Easy Mode - one button
//procedure FullFixAllMarked(FixAll : Boolean = True);

var
  UInd : TIndexInf;

implementation

uses
  FuncPr,
  FileUtil,
  Math,
  uIFixDmgd;


constructor TFixUniq.Create(TI : TTableInf; Pars : TFixPars);
begin
  SrcTbl  := TI;
  FixPars := Pars;
  TmpConn := dtmdlADS.cnnTmp;

  QDups := TAdsQuery.Create(SrcTbl.AdsT.Owner);
  QDups.AdsConnection := TmpConn;

  //TI.ErrInfo.Plan2Del := TAdsQuery.Create(SrcTbl.AdsT.Owner);
  //TI.ErrInfo.Plan2Del.AdsConnection := Cn;

  //TI.ErrInfo.PlanFix := PlanTable;
  //TI.ErrInfo.PlanFix.AdsConnection := Cn;
  PlanFixQ := dtmdlADS.qDst;

  FBadRows := TStringList.Create;
  FBadRows.CaseSensitive := True;
  //FBadRows.Sorted := True;
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
function MakeEdiAbleCursor(const SQLMain1, SQLMain2 : string; SortBy : string = ''; TmpName : string = TMP_PLAN) : string;
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
  sSQL,
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
    Q.SQL.Text := MakeEdiAbleCursor(sBeg, sEnd, '', TMP_PLAN);
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




{
procedure TFixUniq.SetList4Del(NewIDs: string);
begin
  if (Length(NewDis) = 0) then
    FIDs4Del := ''
  else begin
    if (Length(FIDs4Del) > 0) then
      NewIDs := ',' + NewDis;
    FIDs4Del := FIDs4Del + NewIDs;
  end;
end;
}

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
  IndInf := SrcTbl.IndexInf.Items[iI];
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

        FDelEmps := FDelEmps + FindDelEmpty(SrcTbl.IndexInf.Items[i], Q, DelNow);

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

// вызов метода для кода ошибки
{
function TblErrorController(SrcTbl: TTableInf): Integer;
var
  FixState : Integer;
  FixDupU  : TFixUniq;
begin
  try
    //if (dtmdlADS.cnABTmp.IsConnected) then
    dtmdlADS.cnnTmp.IsConnected := False;

    dtmdlADS.cnnTmp.ConnectPath := AppPars.Path2Tmp;
    dtmdlADS.cnnTmp.IsConnected := True;

    //if (dtmdlADS.tblTmp.Active = True) then
    dtmdlADS.tblTmp.Close;
    dtmdlADS.tblTmp.AdsConnection := dtmdlADS.cnnTmp;

    FixState := FIX_GOOD;
    SrcTbl.RowsFixed := 0;

    case SrcTbl.ErrInfo.ErrClass of
      7008, 7207:
        begin
            FixDupU := TFixUniq.Create(SrcTbl, AppPars);
            SrcTbl.RowsFixed := FixDupU.Fix7207;
        end;
      7200:
        begin
          if (SrcTbl.ErrInfo.NativeErr = 7123) then begin
          // неизвестный тип поля
            PutError(EMSG_SORRY);
            FixState := FIX_NOTHG;
          end
          else begin
            FixDupU := TFixUniq.Create(SrcTbl, AppPars);
            SrcTbl.RowsFixed := FixDupU.Fix7207;
          end;
        end;
        7016,
      UE_BAD_DATA:
        begin
          SrcTbl.RowsFixed := Fix8901(SrcTbl, dtmdlADS.tblTmp);
        end;
    end;

    SrcTbl.ErrInfo.State := FixState;
    if (SrcTbl.RowsFixed > 0) then
      SrcTbl.ErrInfo.FixErr := 0
    else
      SrcTbl.ErrInfo.FixErr := FIX_NOTHG;

  except
    SrcTbl.ErrInfo.State  := FIX_ERRORS;
    SrcTbl.ErrInfo.FixErr := UE_BAD_FIX;
  end;
  Result := SrcTbl.RowsFixed;
end;
}

// Копия оригинала и освобождение таблицы
{
function PrepTable(P2Src, P2TMP: string; SrcTbl: TTableInf): Integer;
var
  s, FileSrc, FileSrcNoExt, FileDst: string;
begin
  Result   := UE_BAD_PREP;

  // Группа файлов в источнике
  FileSrc := P2Src + SrcTbl.NameNoExt;

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
}










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
procedure ProceedBackUps(Mode : Integer);
var
  PTblInf: ^TTableInf;
  TotFiles: Integer;
begin
  if (dtmdlADS.mtSrc.Active = True) then
    with dtmdlADS.mtSrc do begin
      First;
      TotFiles := 0;
      while not Eof do begin
        PTblInf := Ptr(dtmdlADS.FSrcFixInf.AsInteger);
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


// Полный цикл для одной таблицы
{
function FullFixOneTable(TName: string; TID: Integer; Ptr2TableInf: Integer; FixPars: TAppPars; Q: TAdsQuery): TTableInf;
var
  RowsFixed,
  ec, i: Integer;
  SrcTbl: TTableInf;
begin

  if (Ptr2TableInf = 0) then begin
    SrcTbl := TTableInf.Create(TName, TID, Q.AdsConnection, FixPars);
    ec := SrcTbl.Test1Table(SrcTbl, FixPars.TMode, FixPars.SysAdsPfx);
  end
  else begin
    SrcTbl := TTableInf(Ptr(Ptr2TableInf));
    ec := SrcTbl.ErrInfo.ErrClass;
  end;
  Result := SrcTbl;

  if (ec > 0) then begin
    // Ошибки тестирования были
    ec := SrcTbl.SetWorkCopy(AppPars.Path2Tmp);
    if (ec = 0) then begin
      // Исправление копии
      RowsFixed := TblErrorController(SrcTbl);
      if (SrcTbl.ErrInfo.FixErr = 0) then begin
        // Исправление оригинала
        if (ChangeOriginal(FixBase.FixList.Path2Src, AppPars.Path2Tmp, SrcTbl) = True) then
          SrcTbl.ErrInfo.State := INS_GOOD
        else
          SrcTbl.ErrInfo.State := INS_ERRORS;
      end;
    end;
  end;
end;
}


// Full Proceed для всех/отмеченных
{
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
}



//!!!===!!! Not used
{


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
}


{
function SQL_7207_SearchEmpty(TblInf : TTableInf; iI : Integer; nMode : Integer) : string;
var
  i, j : Integer;
  s : String;
  IndInf : TIndexInf;

  FI : TFieldsInf;
begin
  Result := 'DELETE FROM ' + TblInf.TableName + ' WHERE ' + TblInf.TableName + '.ROWID IN ';
  s := '(SELECT ROWID FROM ' + TblInf.TableName + ' WHERE ';
  IndInf := TblInf.IndexInf.Items[iI];

  for i := 0 to IndInf.Fields.Count - 1 do begin
    if (i > 0) then
      s := s + ' OR ';
    j := IndInf.IndFieldsAdr[i];
    //s := s + EmptyFCond(IndInf.Fields.Strings[i], TFieldsInf(TblInf.FieldsInf[j]).FieldType);

    FI := TblInf.FieldsInf[j];
    s := s + EmptyFCond(IndInf.Fields.Strings[i], FI.FieldType);

  end;
  Result := Result + s + ')';
end;


function Fix7207(TblInf: TTableInf; QDups: TAdsQuery): Integer;
var
  RowFix,
  j, i: Integer;
  sExec: string;
begin
    RowFix := 0;
    with QDups do begin
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
          LeaveOnlyAllowed(QDups, TblInf, i, dtmdlADS.qDst);

          DelDups4Idx(TblInf);
        end;


          //ExecSQL;
          //Result := Result + RowsAffected;
      end;

      // поиск некорректных AUTOINC
      DelOtherDups(TblInf);

    end;

end;
}

{
function UniqRepeat(AdsTbl : TTableInf; iI : Integer) : string;
var
  IndInf : TIndexInf;
begin
  IndInf := AdsTbl.IndexInf.Items[iI];
  Result := 'SELECT ' + AL_SRC + '.ROWID, ''' + IntToStr(iI) + '''+' +
    AL_DUP + '.ROWID AS ' + AL_DKEY + AL_DUPCNTF + IndInf.AlsCommaSet +
    ' FROM ' + AdsTbl.TableName + ' ' + AL_SRC +
    ' INNER JOIN (SELECT COUNT(*) AS ' + AL_DUPCNT + ',' + IndInf.CommaSet +
    ' FROM ' + AdsTbl.TableName + ' GROUP BY ' + IndInf.CommaSet +
    ' HAVING (COUNT(*) > 1) ) ' + AL_DUP +
    ' ON ' + IndInf.EquSet;
  Result := Result + ' ORDER BY ' + AL_DKEY;
end;
}

// SQL-команда удаления записей с пустыми [под]ключами уникального индекса
{
function TFixUniq.SQL_7207_SearchEmpty(IndInf : TIndexInf) : string;
var
  i, j : Integer;
  s : String;
begin
  s := '';

  for i := 0 to IndInf.Fields.Count - 1 do begin
    if (i > 0) then
      s := s + ' OR ';
    j := IndInf.IndFieldsAdr[i];
    s := s + EmptyFCond(IndInf.Fields.Strings[i], TFieldsInf(SrcTbl.FieldsInf[j]).FieldType);
  end;
  Result := Format(
    'DELETE FROM %s WHERE %s.ROWID IN (SELECT ROWID FROM %s WHERE %s)'
    ,[SrcTbl.TableName, SrcTbl.TableName, SrcTbl.TableName, s]
    );
end;
}

end.
