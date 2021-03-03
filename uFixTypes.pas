unit uFixTypes;

interface

uses
  SysUtils,
  //Classes,
  //adsset,
  adscnnct,
  //DB,
  adsdata,
  //adsfunc,
  adstable,
  ace,
  kbmMemTable,
  //EncdDecd,
  uServiceProc,
  AdsDAO,
  uFixDups,
  uTableUtils;

type
  IFixErrs = Interface
  ['{06866869-3DFD-49D0-B1EF-BEF2BCE8E4F5}']
    function ChangeOriginal : Boolean;
  end;

type

  TFixBase = class(TInterfacedObject)
  // Класс исправления ошибок в таблицах ADS
  private
    FPars    : TFixPars;
    FTblList : TAdsList;
    function TblErrorController(SrcTbl: TTableInf): Integer;
    function ChangeOriginal(P2Src, P2Tmp: string; SrcTbl: TTableInf): Boolean;
    function RecoverOneTable(TName: string; TID: Integer; Ptr2TableInf: Integer; Q: TAdsQuery): TTableInf;
  protected
    // Проверить и исправить отмеченные
    procedure RecoverAllBase(FixAll : Boolean = True);
  public
    // Параметры проверки и исправления
    property FixPars : TFixPars read FPars write FPars;
    // Список таблиц (словарь или папка)
    property FixList : TAdsList read FTblList write FTblList;

    // Проверить и исправить все, что обнаружится
    procedure RecoverAll(TableName : string = '');

    constructor Create(FixBasePars: TFixPars); overload;
    constructor Create(IniName : string; Path2Fix : string = ''); overload;
    destructor Destroy; override;
  published
  end;

  TFixBaseUI = class(TFixBase)
  // Класс исправления ошибок в таблицах ADS
  private
  protected
  public
    // Проверить и исправить все отмеченные
    procedure RecoverMarked;

    // Исправить отмеченные
    procedure FixAllMarked;

    // Применить исправления
    procedure ApplyFixMarked;
  published
  end;


var
  //FixBase   : TFixBase;
  FixBaseUI : TFixBaseUI;

implementation

uses
  FileUtil,
  FuncPr,
  SasaINiFile,
  uIFixDmgd;


constructor TFixBase.Create(FixBasePars : TFixPars);
begin
  inherited Create;
  FixPars := FixBasePars;
end;

constructor TFixBase.Create(IniName : string; Path2Fix : string = '');
var
  Ini: TSasaIniFile;
begin
  inherited Create;
  Ini := TSasaIniFile.Create(IniName);
  FixPars := TFixPars.Create(Ini);
  if (Path2Fix <> '') then
    FixPars.Src := Path2Fix;
end;

destructor TFixBase.Destroy;
begin
  inherited Destroy;

end;

// вызов метода для кода ошибки
function TFixBase.TblErrorController(SrcTbl: TTableInf): Integer;
var
  FixState : Integer;
  FixDupU  : TFixUniq;
begin
  try
    dtmdlADS.cnnTmp.IsConnected := False;
    dtmdlADS.cnnTmp.ConnectPath := FixPars.Tmp;
    dtmdlADS.cnnTmp.Connect;

    dtmdlADS.tblTmp.Close;
    dtmdlADS.tblTmp.AdsConnection := dtmdlADS.cnnTmp;

    FixState := FIX_GOOD;
    SrcTbl.RowsFixed := 0;

    case SrcTbl.ErrInfo.ErrClass of
      7008, 7207:
        begin
            FixDupU := TFixUniq.Create(SrcTbl, FixPars);
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
            FixDupU := TFixUniq.Create(SrcTbl, FixPars);
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

// Вставка в обнуляемый оригинал исправленных записей
function TFixBase.ChangeOriginal(P2Src, P2Tmp: string; SrcTbl: TTableInf): Boolean;
var
  ErrAdm, ecb: Boolean;
  i: Integer;
  FileSrc, FileDst, TmpName, ss, sd: string;
  Span: TSpan;
  Conn: TAdsConnection;


function BackUpOne(Ext: string) : Boolean;
begin
  ss := FileSrc + Ext;
  sd := TmpName + Ext;
  if (SrcTbl.Pars.IsDict = False) then
    Result := (CopyOneFile(ss, sd) = 0)
  else
    Result := RenameFile(ss, sd);
  if (Result = True) then
    SrcTbl.BackUps.Add(sd)
  else
    raise Exception.Create('Ошибка дубликата - ' + ss);
end;


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

    FileSrc := P2Src + SrcTbl.NameNoExt;
    FileDst := P2Tmp + SrcTbl.NameNoExt + ExtADT;

    if (SrcTbl.NeedBackUp = True) then begin
    // Перед вставкой сделать копию
      TmpName := P2Src + ORGPFX + SrcTbl.NameNoExt;
      ecb := DeleteFiles(TmpName + '.*');

      if FileExists(FileSrc + ExtADI) then
        if (SrcTbl.Pars.IsDict = False) then
          ecb := BackUpOne(ExtADI)
        else
          ecb := DeleteFiles(FileSrc + ExtADI);
{
      ss := FileSrc + ExtADT;
      sd := TmpName + ExtADT;
      if (SrcTbl.IsFree) then
        ecb := (CopyOneFile(ss, sd) = 0)
      else
        ecb := RenameFile(ss, sd);
      if (ecb = True) then
        SrcTbl.BackUps.Add(sd);
}
       ecb := ecb and BackUpOne(ExtADT);
      if FileExists(FileSrc + ExtADM) then begin
{
        ss := FileSrc + ExtADM;
        sd := TmpName + ExtADM;
        if (SrcTbl.IsFree) then
          ErrAdm := (CopyOneFile(ss, sd) = 0)
        else
          ErrAdm := RenameFile(ss, sd);
        if (ErrAdm = True) then
          SrcTbl.BackUps.Add(sd);
}
        ErrAdm := BackUpOne(ExtADM);
      end;
    end;

    Conn.IsConnected := True;
    // Очистить таблицу
    if (Conn.IsDictionaryConn = False) then begin
      Conn.Execute(Format('DELETE FROM "%s"', [SrcTbl.TableName]));
    end
    else begin
    // Удалить таблицу + Memo + index
      ecb := DeleteFiles(FileSrc + '.ad?');
      if (ecb = True) and (ErrAdm = True) then begin
  //--- Auto-create empty table
        SrcTbl.AdsT.Active := True;
        SrcTbl.AdsT.Active := False;
  //---
      end;
    end;
      try
        // врЕменная замена AUTOINC на INTEGER
        if (ChangeAI(SrcTbl, ' INTEGER', Conn) = True) then begin
          SrcTbl.ErrInfo.TotalIns := 0;
          if (SrcTbl.GoodSpans.Count <= 0) then begin
        // Загрузка оптом
            //ss := 'INSERT INTO ' + SrcTbl.TableName + ' SELECT * FROM "' + FileDst + '" SRC';
            ss := Format('INSERT INTO "%s" SELECT * FROM "%s" SRC', [SrcTbl.TableName, FileDst]);
            if (Length(SrcTbl.DmgdRIDs) > 0) then
              ss := ss + ' WHERE SRC.ROWID NOT IN (' + SrcTbl.DmgdRIDs + ')';
            SrcTbl.ErrInfo.TotalIns := Conn.Execute(ss);
          end
          else begin
        // Загрузка интервалами хороших записей
            for i := 0 to SrcTbl.GoodSpans.Count - 1 do begin
              Span := SrcTbl.GoodSpans[i];
              //ss := 'INSERT INTO ' + SrcTbl.TableName + ' SELECT TOP ' + IntToStr(Span.InTOP) + ' START AT ' + IntToStr(Span.InSTART) + ' * FROM "' + FileDst + '" SRC';
              ss := Format('INSERT INTO "%s" SELECT TOP %d START AT %d * FROM "%s"  SRC', [SrcTbl.TableName, Span.InTOP, Span.InSTART, FileDst]);
              SrcTbl.ErrInfo.TotalIns := SrcTbl.ErrInfo.TotalIns + Conn.Execute(ss);
            end;
          end;
        // восстановление AUTOINC на INTEGER
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

  except
    SrcTbl.ErrInfo.InsErr := UE_BAD_INS;
  end;

end;



// Исправить оригинал для отмеченных
procedure TFixBaseUI.ApplyFixMarked;
var
  GoodChange: Boolean;
  i: Integer;
  SrcTbl: TTableInf;
  //DAds  : TTblDict;
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
            GoodChange := ChangeOriginal(FixPars.Path2Src, FixPars.Tmp, SrcTbl);
            //(TFormMain(AppPars.ShowForm)).lblResIns.Caption := IntToStr(SrcTbl.ErrInfo.TotalIns);
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
    dtmdlADS.cnnSrcAds.Disconnect;
  end;

end;


// Исправить все отмеченные
procedure TFixBaseUI.FixAllMarked;
var
  ErrCode, i: Integer;
  SetBad : Boolean;
  SrcTbl: TTableInf;
  //FixList : TAdsList;
begin
  SetBad := False;
  with FixList.SrcList do begin
    First;
    i := 0;
    while not Eof do begin
      i := i + 1;
      //SrcList.
      if (dtmdlADS.FSrcMark.AsBoolean = True) then begin
        SrcTbl := TTableInf(Ptr(dtmdlADS.FSrcFixInf.AsInteger));
        if (Assigned(SrcTbl)) then begin
          // Тестирование выполнялось, объект создан
          Edit;

          ErrCode := SrcTbl.SetWorkCopy(FixPars.Tmp);
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
          if (FixPars.DelDupMode = DDUP_USEL) then begin
            if (SrcTbl.ErrInfo.State = FIX_GOOD) and (SetBad = False) then begin
              SetBad := True;
              //dtmdlADS.dsPlan.DataSet := SrcTbl.ErrInfo.Plan2Del;
            end;



          end;
        end;
      end;
      Next;
    end;
    First;
  end;
end;


// Полный цикл для одной таблицы
function TFixBase.RecoverOneTable(TName: string; TID: Integer; Ptr2TableInf: Integer; Q: TAdsQuery): TTableInf;
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
    ec := SrcTbl.SetWorkCopy(FixPars.Tmp);
    if (ec = 0) then begin
      // Исправление копии
      RowsFixed := TblErrorController(SrcTbl);
      if (SrcTbl.ErrInfo.FixErr = 0) then begin
        // Исправление оригинала
        if (ChangeOriginal(FixPars.Path2Src, FixPars.Tmp, SrcTbl) = True) then
          SrcTbl.ErrInfo.State := INS_GOOD
        else
          SrcTbl.ErrInfo.State := INS_ERRORS;
      end;
    end;
  end;
end;

//-------------------------------------------------------------
// Full Proceed для всех/отмеченных
procedure TFixBase.RecoverAllBase(FixAll : Boolean = True);
var
  ec, i: Integer;
  SrcTbl: TTableInf;
begin

  with FixList.SrcList do begin
    First;
    i := 0;
    while not Eof do begin
      i := i + 1;
      if (FieldByName('IsMark').Value = True)
        OR (FixAll = True) then begin
        Edit;
        SrcTbl := RecoverOneTable(FieldByName('TableName').Value, FieldByName('Npp').Value, FieldByName('TableInf').Value, dtmdlADS.qAny);
        FieldValues['TableInf'] := Integer(SrcTbl);

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

end;

//-------------------------------------------------------------
// Проверить и исправить все
procedure TFixBase.RecoverAll(TableName : string = '');
begin
  if (FixPars.IsDict) then
    FixList := TDictList.Create(FixPars)
  else
    FixList := TFreeList.Create(FixPars);

  if (FixList.FillList4Fix(TableName) = UE_OK) then begin
    // Тестировать все подряд
    FixList.TestSelected(True, FixPars.TMode);
    RecoverAllBase;
  end
  else
    PutError('Таблицы не найдены!');

end;

// Проверить и исправить все отмеченные
procedure TFixBaseUI.RecoverMarked;
begin

  if (FixList.Filled) then begin
    SortByState(False);
    FixList.TestSelected(True, FixPars.TMode);
    RecoverAllBase(False);
    SortByState(True);
  end
  else
    PutError('Таблицы не найдены!');

end;

end.
