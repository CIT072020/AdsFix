unit FixDups;

interface

uses
  SysUtils, Classes, adsset, adscnnct, DB, adsdata, adsfunc, adstable, ace,
  kbmMemTable,
  //EncdDecd,
  FixTypes,
  ServiceProc, AdsDAO, TableUtils;

const

  // Эмпирические веса заполненных полей в соответственно типу
  FWT_BOOL : Integer = 1;
  FWT_NUM  : Integer = 3;
  FWT_DATE : Integer = 5;
  FWT_STR  : Integer = 30;
  FWT_BIN  : Integer = 5;

type
  TFixUniq = class(TInterfacedObject)
  // Класс исправления ошибок уникальности индексов
  // в таблицах ADS
  private
    FPars     : TAppPars;
    FTableInf : TTableInf;
    FTmpConn  : TAdsConnection;
    FQDups    : TAdsQuery;
    FDelEmps  : Integer;
    FDelDups  : Integer;
    FIDs4Del  : string;

    FBadRows  : TStringList;

    // SQL-запрос поиска пустых значений [под]ключей среди уникадьных индексов
    function SearchEmptyAnyAll(IndInf : TIndexInf; BoolOp : string = ' OR ') : string;

    // Поиск [и удаление]пустых значений [под]ключей среди уникадьных индексов
    function FindDelEmpty(IndInf: TIndexInf; QTmp: TAdsQuery; DelNow: Boolean = True): integer;

    //
    function NewRow4Del(Q: TAdsQuery; Dst : TStringList; var Why: Integer): string;

    // Поиск ROWID дубликатов ключей среди уникадьных индексов
    function UniqRepeat(iI : Integer) : string;

    // Отметить все для удаления
    function MarkAll4Del(Q : TAdsQuery; DelNow: Boolean): integer;

    // Перебор дубликатов, выбор и формирование списка для удаления
    function LeaveOnlyAllowed(Q: TAdsQuery; Q1F: TAdsQuery) : integer;
  protected
  public
    // Параметры проверки и исправления
    property FixPars : TAppPars read FPars write FPars;
    // Объект состояния таблицы
    property SrcTbl : TTableInf read FTableInf write FTableInf;
    // ADS-Connection для папки TMP
    property TmpConn: TAdsConnection read FTmpConn write FTmpConn;
    // Дубликаты по GROUP BY
    property QDups: TAdsQuery read FQDups write FQDups;
    // Список
    property RowIDs4Del : string read FIDs4Del write FIDs4Del;

    // Исправление ошибок 7200, 7207
    function Fix7207 : Integer;

    constructor Create(TI : TTableInf; Pars : TAppPars; Cn : TAdsConnection);
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
  UInd : TIndexInf;

implementation

uses
  FuncPr,
  FileUtil,
  Math,
  uIFixDmgd;

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

// Список RowID
function RowIDs2CommList(Rows2Del: TStringList) : string;
var
  i : Integer;
  s : String;
begin
  s := '';
  for i := 0 to Rows2Del.Count - 1 do begin
    if (i > 0) then
      s := s + ',';
    s := s + Rows2Del[i];
  end;
  Result := s;
end;


// Удалить строки по списку ROWID
function DelByRowIds(TName, List4Del : string; Cn : TAdsConnection) : Integer;
var
  s : string;
begin
  s := Format('DELETE FROM %s WHERE ROWID IN (%s)', [TName, List4Del]);
  Result := Cn.Execute(s);
end;


constructor TFixUniq.Create(TI : TTableInf; Pars : TAppPars; Cn : TAdsConnection);
begin
  SrcTbl  := TI;
  FixPars := Pars;
  TmpConn := Cn;

  QDups := TAdsQuery.Create(SrcTbl.AdsT.Owner);
  QDups.AdsConnection := Cn;
  FBadRows := TStringList.Create;
end;

destructor TFixUniq.Destroy;
begin
  inherited Destroy;
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
function TFixUniq.NewRow4Del(Q: TAdsQuery; Dst : TStringList; var Why: Integer): string;
var
  RowDel : TRow4Del;
begin
  Result := Q.FieldValues['ROWID'];
  if (Dst.IndexOf(Result) < 0) then begin
    RowDel := TRow4Del.Create;
    RowDel.RowID := Result;
    RowDel.DelRow := True;
    RowDel.Reason := Why;
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
    s := s + EmptyFCond(IndInf.Fields.Strings[i], TFieldsInf(SrcTbl.FieldsInf[j]).FieldType);
  end;
  Result := Format('SELECT ROWID FROM %s WHERE %s', [SrcTbl.TableName, s]);
end;

// поиск и удаление пустых [под]ключей
function TFixUniq.FindDelEmpty(IndInf: TIndexInf; QTmp: TAdsQuery; DelNow: Boolean = True): integer;
var
  iNew,
  nDel, i: Integer;
  sID, sExec: string;
  RowDel: TRow4Del;
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
      sID := NewRow4Del(QTmp, FBadRows, iNew);
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
  IndInf : TIndexInf;
begin
  IndInf := SrcTbl.IndexInf.Items[iI];
  Result := Format(
    'SELECT %s.ROWID, ''%d'' + %s.ROWID AS %s%s %s',     [AL_SRC, iI, AL_DUP, AL_DKEY, AL_DUPCNTF, IndInf.AlsCommaSet]);
  Result := Result + Format(
    ' FROM %s %s INNER JOIN (SELECT COUNT(*) AS %s, %s', [SrcTbl.TableName, AL_SRC, AL_DUPCNT, IndInf.CommaSet]);
  Result := Result + Format(
    ' FROM %s GROUP BY %s HAVING (COUNT(*) > 1) ) %s',   [SrcTbl.TableName, IndInf.CommaSet, AL_DUP]);
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
      sField := TFieldsInf(AdsTbl.FieldsInf[i]).Name;
      FT := TFieldsInf(AdsTbl.FieldsInf[i]).FieldType;
      sEmpCond := EmptyFCond(sField, FT, True);
      s := 'SELECT ' + sField + ' FROM ' + AdsTbl.TableName + s4All + sEmpCond;
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
function TFixUniq.LeaveOnlyAllowed(Q: TAdsQuery; Q1F: TAdsQuery): integer;
var
  DelNow: Boolean;
  i, iMax, iDel, FillMax, iNew, RWeight, j, jMax, jStart: Integer;
  sID, s: string;
  RowInf: TRow4Del;
begin
  if (FixPars.DelDupMode = TDelDupMode(DDup_USel)) then
  // Пользователь сам определится
    DelNow := False
  else
    DelNow := True;
  Result := 0;
  if (FixPars.DelDupMode = TDelDupMode(DDup_ALL)) then begin
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
  Q : TAdsQuery;
begin
  Result := 0;
  FDelEmps := 0;
  FDelDups := 0;
  Q := TAdsQuery.Create(SrcTbl.AdsT.Owner);
  Q.AdsConnection := TmpConn;
  try
      for i := 0 to SrcTbl.IndCount - 1 do begin
      // для всех уникальных индексов таблицы

        // поиск и удаление строк с пустыми [под]ключами

        //sExec := SQL_7207_SearchEmpty(SrcTbl.IndexInf.Items[i]);
        //FDelEmps := FDelEmps + TmpConn.Execute(sExec);

        FDelEmps := FDelEmps + FindDelEmpty(SrcTbl.IndexInf.Items[i], Q);

        // поиск совпадающих ключей
        QDups.SQL.Clear;
        sExec := UniqRepeat(i);
        QDups.SQL.Add(sExec);
        QDups.VerifySQL;
        QDups.Active := True;
        if (QDups.RecordCount > 0) then begin
          // для всех групп с одинаковым значением индекса
          // оставить одну запись из группы
          FDelDups := FDelDups + LeaveOnlyAllowed(QDups, Q);
        end;
      end;
      // поиск некорректных AUTOINC
      DelOtherDups(SrcTbl);
  except
  end;
  Result := FDelEmps + FDelDups;
  SrcTbl.ErrInfo.Rows4Del := FBadRows;
end;

// вызов метода для кода ошибки
function TblErrorController(SrcTbl: TTableInf): Integer;
var
  FixState : Integer;
  FixDupU  : TFixUniq;
begin
  try
    if (dtmdlADS.cnABTmp.IsConnected) then
      dtmdlADS.cnABTmp.IsConnected := False;

    dtmdlADS.cnABTmp.ConnectPath := AppPars.Path2Tmp;
    dtmdlADS.cnABTmp.IsConnected := True;

    if (dtmdlADS.tblTmp.Active = True) then
      dtmdlADS.tblTmp.Close;
    dtmdlADS.tblTmp.AdsConnection := dtmdlADS.cnABTmp;

    FixState := FIX_GOOD;
    SrcTbl.RowsFixed := 0;


    case SrcTbl.ErrInfo.ErrClass of
      7008, 7207:
        begin
            FixDupU := TFixUniq.Create(SrcTbl, AppPars, dtmdlADS.cnABTmp);
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
            FixDupU := TFixUniq.Create(SrcTbl, AppPars, dtmdlADS.cnABTmp);
            SrcTbl.RowsFixed := FixDupU.Fix7207;
          end;
        end;
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

// Копия оригинала и освобождение таблицы
function PrepTable(P2Src, P2TMP : string; SrcTbl: TTableInf): Integer;
var
  s,
  FileSrc,
  FileDst: string;
begin
  Result := UE_BAD_PREP;
  try
    FileSrc := P2Src + SrcTbl.TableName;
    SrcTbl.FileTmp := P2TMP + SrcTbl.TableName + '.adt';
    s := FileSrc + '.adt';
    if (CopyOneFile(s, P2TMP) <> 0) then
      raise Exception.Create('Ошибка копирования ' + s);
    s := FileSrc + '.adm';
    if FileExists(s) then begin
      if (CopyOneFile(s, P2TMP) <> 0) then
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
  FixList : TAdsList;
begin

  with FixBase.FixList.SrcList do begin
    First;
    i := 0;
    while not Eof do begin
      i := i + 1;
      if (dtmdlADS.FSrcMark.AsBoolean = True) then begin
        SrcTbl := TTableInf(Ptr(dtmdlADS.FSrcFixInf.AsInteger));
        if (Assigned(SrcTbl)) then begin
          // Тестирование выполнялось, объект создан
          Edit;

          ErrCode := PrepTable(FixBase.FixList.Path2Src, AppPars.Path2Tmp, SrcTbl);
          if (ErrCode = 0) then begin
            ErrCode := TblErrorController(SrcTbl);
            dtmdlADS.FSrcState.AsInteger := SrcTbl.ErrInfo.State;
            dtmdlADS.FSrcFixCode.AsInteger := SrcTbl.ErrInfo.FixErr;
          end
          else begin
            dtmdlADS.FSrcState.AsInteger   := FIX_ERRORS;
            dtmdlADS.FSrcFixCode.AsInteger := ErrCode;
          end;

          Post;
        end;
      end;
      Next;
    end;
    First;
  end;
end;




// AutoInc => Integer and reverse
function ChangeAI(SrcTbl: TTableInf; AIType : string; Conn : TAdsConnection; DelExt : string = ''): Boolean;
var
  i: Integer;
  s: string;
begin
  Result := True;
  try
    if (SrcTbl.FieldsAI.Count > 0) then begin
      s := 'ALTER TABLE ' + SrcTbl.TableName;
      for i := 0 to (SrcTbl.FieldsAI.Count - 1) do begin
        s := s + ' ALTER COLUMN ' + SrcTbl.FieldsAI[i] + ' ' + SrcTbl.FieldsAI[i] + AIType;
      end;
      Conn.Execute(s);
      if (Length(DelExt) > 0) then
        DeleteFiles(IncludeTrailingPathDelimiter(Conn.GetConnectionPath) + SrcTbl.TableName + DelExt);
    end;
  except
    Result := False;
  end;
end;

// Integer => AutoInc
{
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
    end;
  except
    Result := False;
  end;

end;
}


// Вставка в обнуляемый оригинал исправленных записей
function ChangeOriginal(P2Src, P2Tmp: string; SrcTbl: TTableInf): Boolean;
var
  ErrAdm, ecb: Boolean;
  i: Integer;
  FileSrc, FileDst, TmpName, ss, sd: string;
  Span: TSpan;
  Conn: TAdsConnection;
begin
  Result := False;
  SrcTbl.ErrInfo.State := INS_ERRORS;
  SrcTbl.ErrInfo.InsErr := UE_BAD_INS;
  try
    SrcTbl.AdsT.Active := False;
    Conn := SrcTbl.AdsT.AdsConnection;
    Conn.Disconnect;

    ecb := True;
    ErrAdm := True;

    FileSrc := P2Src + SrcTbl.TableName;
    FileDst := P2Tmp + SrcTbl.TableName + '.adt';

    if (SrcTbl.NeedBackUp = True) then begin
    // Перед вставкой сделать копию
      TmpName := P2Src + ORGPFX + SrcTbl.TableName;
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
        ErrAdm := RenameFile(ss, sd);
        if (ecb = True) then
          SrcTbl.BackUps.Add(sd);
      end;
    end
    else  // Удалить таблицу + Memo + index
      ecb := DeleteFiles(FileSrc + '.ad?');

    if (ecb = True) and (ErrAdm = True) then begin
  //--- Auto-create empty table
      SrcTbl.AdsT.AdsConnection.IsConnected := True;
      SrcTbl.AdsT.Active := True;
      SrcTbl.AdsT.Active := False;
  //---

      try
        if (ChangeAI(SrcTbl, ' INTEGER', Conn) = True) then begin
          if (SrcTbl.GoodSpans.Count <= 0) then begin
        // Загрузка оптом
            ss := 'INSERT INTO ' + SrcTbl.TableName + ' SELECT * FROM "' + FileDst + '" SRC';
            if (Length(SrcTbl.DmgdRIDs) > 0) then
              ss := ss + ' WHERE SRC.ROWID NOT IN (' + SrcTbl.DmgdRIDs + ')';
            Conn.Execute(ss);
          end
          else begin
        // Загрузка интервалами хороших записей
            for i := 0 to SrcTbl.GoodSpans.Count - 1 do begin
              Span := SrcTbl.GoodSpans[i];
              ss := 'INSERT INTO ' + SrcTbl.TableName + ' SELECT TOP ' + IntToStr(Span.InTOP) + ' START AT ' + IntToStr(Span.InSTART) + ' * FROM "' + FileDst + '" SRC';
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
  except
  end;

end;




// Исправить оригинал для отмеченных
procedure ChangeOriginalAllMarked;
var
  GoodChange: Boolean;
  i: Integer;
  SrcTbl: TTableInf;
  DAds  : TTblDict;
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
          // Тестирование выполнялось, объект создан, есть пофиксеные записи
          if (SrcTbl.ErrInfo.State = FIX_GOOD) then begin

            dtmdlADS.mtSrc.Edit;
            GoodChange := ChangeOriginal(FixBase.FixList.Path2Src, AppPars.Path2Tmp, SrcTbl);
            //GoodChange := DAds.ChangeOriginal;
            if (GoodChange = True) then begin
          // успешно вствлено
              dtmdlADS.FSrcMark.AsBoolean := False;
            end
            else begin
          // ошибки вставки
            end;
            dtmdlADS.FSrcState.AsInteger   := SrcTbl.ErrInfo.State;
            dtmdlADS.FSrcFixCode.AsInteger := SrcTbl.ErrInfo.InsErr;

            dtmdlADS.mtSrc.Post;
          end;
        end;
      end;
      Next;
    end;
    First;
    dtmdlADS.conAdsBase.Disconnect;
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
  PTblInf: ^TTableInf;
  TotDel: Integer;
begin
  if (dtmdlADS.mtSrc.Active = True) then
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
  RowsFixed,
  ec, i: Integer;
  SrcTbl: TTableInf;
begin

  if (Ptr2TableInf = 0) then begin
    SrcTbl := TTableInf.Create(TName, TID, Q.AdsConnection, FixPars.SysAdsPfx);
    ec := SrcTbl.Test1Table(SrcTbl, FixPars.TMode);
  end
  else begin
    SrcTbl := TTableInf(Ptr(Ptr2TableInf));
    ec := SrcTbl.ErrInfo.ErrClass;
  end;
  Result := SrcTbl;

  if (ec > 0) then begin
    // Ошибки тестирования были
    ec := PrepTable(FixBase.FixList.Path2Src, AppPars.Path2Tmp, SrcTbl);
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
