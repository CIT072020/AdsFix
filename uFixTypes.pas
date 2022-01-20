unit uFixTypes;

interface

uses
  SysUtils,
  adscnnct,
  adsdata,
  adstable,
  ace,
  kbmMemTable,
  AdsDAO,
  uServiceProc,
  uFixDups,
  uTableUtils;

type
  IFixErrs = Interface
  ['{06866869-3DFD-49D0-B1EF-BEF2BCE8E4F5}']
    function ChangeOriginal : Boolean;
  end;

type

  TFixADSTables = class(TInterfacedObject)
  // Класс исправления ошибок в таблицах ADS
  private
    FIniName : string;
    FFixPars : TFixPars;
    FAdsList : TAdsList;

    function TblErrorController(SrcTbl: TTableInf): Integer;
    function ChangeOriginal(P2Src, P2Tmp: string; SrcTbl: TTableInf): Boolean;
    function RecoverOneTable(TName: string; TID: Integer; Ptr2TableInf: Integer): TTableInf;
  protected
    // Проверить и исправить отмеченные
    procedure RecoverAllBase(FixAll : Boolean = True);
  public
    // Параметры проверки и исправления
    property FixPars : TFixPars read FFixPars write FFixPars;
    // Список таблиц (словарь или папка)
    property FixList : TAdsList read FAdsList;

    // Построить список таблиц (словарь или папка)
    function NewAdsList(TableName: string = ''): Boolean;

    // Проверить и исправить все, что обнаружится
    function RecoverAll(TableName : string = '') : Integer;

    constructor Create(FixBasePars: TFixPars); overload;
    constructor Create(IniName : string; Path2Fix : string = ''); overload;
    destructor Destroy; override;
  published
  end;

  TFixADSTablesUI = class(TFixADSTables)
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
  //FixBase   : TFixADSTables;
  FixBaseUI : TFixADSTablesUI;

implementation

uses
  FileUtil,
  FuncPr,
  SasaINiFile,
  uIFixDmgd;


constructor TFixADSTables.Create(FixBasePars : TFixPars);
begin
  inherited Create;
  FixPars  := FixBasePars;
  FIniName := '';
  FAdsList := nil;
end;

constructor TFixADSTables.Create(IniName : string; Path2Fix : string = '');
begin
  inherited Create;
  FIniName := IniName;
  FFixPars := TFixPars.Create(TSasaIniFile.Create(IniName));
  if (Path2Fix <> '') then
    FFixPars.Src := Path2Fix;
  FAdsList := nil;
end;

destructor TFixADSTables.Destroy;
begin
  inherited Destroy;
  if (FIniName <> '') then
    FreeAndNil(FFixPars);
  FreeAndNil(FAdsList);
end;

//-------------------------------------------------------------
// Поолучить/создать список таблиц ADS-базы для исправлений
function TFixADSTables.NewAdsList(TableName: string = ''): Boolean;
begin
  Result := False;
  if (Assigned(FAdsList)) then
    FreeAndNil(FAdsList);
  if (FixPars.IsDict) then
    FAdsList := TDictList.Create(FixPars)
  else
    FAdsList := TFreeList.Create(FixPars);
  if (FAdsList.FillList4Fix(TableName) = UE_OK) then
    Result := True
  else
    FreeAndNil(FAdsList);
end;



// вызов метода для кода ошибки
function TFixADSTables.TblErrorController(SrcTbl: TTableInf): Integer;
var
  FixState : Integer;
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
            FixState := TFixUniq.FixDupRec(SrcTbl, FixPars);
        end;
      7200:
        begin
          if (SrcTbl.ErrInfo.NativeErr = 7123) then begin
          // неизвестный тип поля
            FixState := FIX_NOTHG;
            PutError(EMSG_SORRY);
          end
          else begin
            FixState := TFixUniq.FixDupRec(SrcTbl, FixPars);
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
      s := 'ALTER TABLE "' + SrcTbl.TableName + '"';
      for i := 0 to (SrcTbl.FieldsAI.Count - 1) do begin
        s := s + ' ALTER COLUMN ' + SrcTbl.FieldsAI[i] + ' ' + SrcTbl.FieldsAI[i] + AIType;
      end;
      Conn.Execute(s);
      if (Length(DelExt) > 0) then
        DeleteFiles(IncludeTrailingPathDelimiter(Conn.GetConnectionPath) + SrcTbl.NameNoExt + DelExt);
    end;
  except
    Result := False;
  end;
end;

// Вставка в обнуляемый оригинал исправленных записей
function TFixADSTables.ChangeOriginal(P2Src, P2Tmp: string; SrcTbl: TTableInf): Boolean;
var
  ChgAI,
  ErrCopyADM, ErrCopyADT: Boolean;
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

    ErrCopyADT := True;
    ErrCopyADM := True;

    FileSrc := P2Src + SrcTbl.NameNoExt;
    FileDst := P2Tmp + SrcTbl.NameNoExt + ExtADT;

    if (SrcTbl.NeedBackUp = True) then begin
    // Перед вставкой сделать копию
      TmpName := P2Src + ORGPFX + SrcTbl.NameNoExt;
      ErrCopyADT := DeleteFiles(TmpName + '.*');

      if FileExists(FileSrc + ExtADI) then
        if (SrcTbl.Pars.IsDict = False) then
          ErrCopyADT := BackUpOne(ExtADI)
        else
          ErrCopyADT := DeleteFiles(FileSrc + ExtADI);
      ErrCopyADT := BackUpOne(ExtADT);
      if FileExists(FileSrc + ExtADM) then
        ErrCopyADM := BackUpOne(ExtADM);
    end;

    Conn.IsConnected := True;
    // Очистить таблицу
    if (Conn.IsDictionaryConn = False) then begin
      ss := Format('EXECUTE PROCEDURE sp_ZapTable(''%s'')', [SrcTbl.TableName]);
      Conn.Execute(ss);
    end
    else begin
    // Удалить таблицу + Memo + index
      ErrCopyADT := DeleteFiles(FileSrc + '.ad?');
      if (ErrCopyADT = True) and (ErrCopyADM = True) then begin
  //--- Auto-create empty table
        SrcTbl.AdsT.Active := True;
        SrcTbl.AdsT.Active := False;
  //---
      end;
    end;
      try
        // врЕменная замена AUTOINC на INTEGER
        //if (ChangeAI(SrcTbl, ' INTEGER', Conn) = True) then begin
        ChgAI := ChangeAI(SrcTbl, ' INTEGER', Conn);
        ChgAI := True;
        if (ChgAI = True) then begin
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
              Span := TSpan(SrcTbl.GoodSpans[i]);
              //ss := 'INSERT INTO ' + SrcTbl.TableName + ' SELECT TOP ' + IntToStr(Span.InTOP) + ' START AT ' + IntToStr(Span.InSTART) + ' * FROM "' + FileDst + '" SRC';
              ss := Format('INSERT INTO "%s" SELECT TOP %d START AT %d * FROM "%s"  SRC', [SrcTbl.TableName, Span.InTOP, Span.InSTART, FileDst]);
              SrcTbl.ErrInfo.TotalIns := SrcTbl.ErrInfo.TotalIns + Conn.Execute(ss);
            end;
          end;
          // восстановление AUTOINC на INTEGER
          ChangeAI(SrcTbl, ' AUTOINC', Conn, '.ad?.BAK');
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





// Полный цикл для одной таблицы
function TFixADSTables.RecoverOneTable(TName: string; TID: Integer; Ptr2TableInf: Integer): TTableInf;
var
  RowsFixed,
  ec : Integer;
  SrcTbl : TTableInf;
begin
(*
  if (Ptr2TableInf = 0) then begin
    SrcTbl := TTableInf.Create(TName, TID, FixList.SrcConn, FixPars);
    FixList.TestOneAds(Integer(SrcTbl),  FixPars.TableTestMode, ec);
  end else begin
    SrcTbl := TTableInf(Ptr(Ptr2TableInf));
    ec := SrcTbl.ErrInfo.ErrClass;
  end;
*)

  SrcTbl := TTableInf(Ptr(Ptr2TableInf));
  if (SrcTbl.ErrInfo.State = TST_UNKNOWN) then
    FixList.TestOneAds(Integer(SrcTbl),  FixPars.TableTestMode, ec)
  else
    ec := SrcTbl.ErrInfo.ErrClass;

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
procedure TFixADSTables.RecoverAllBase(FixAll: Boolean = True);
var
  ec, i: Integer;
  SrcTbl: TTableInf;
begin
  if (Assigned(FixList) AND (FixList.Filled = True)) then begin
    with FixList.SrcList do begin
      First;
      i := 0;
      while not Eof do begin
        i := i + 1;
        if (FieldByName('IsMark').Value = True) OR (FixAll = True) then begin
          Edit;
          SrcTbl := RecoverOneTable(FieldByName('TableName').Value, FieldByName('Npp').Value, FieldByName('TableInf').Value);
          FieldValues['TableInf']  := Integer(SrcTbl);
          FieldValues['State']     := SrcTbl.ErrInfo.State;
          FieldValues['TestCode']  := SrcTbl.ErrInfo.ErrClass;
          FieldValues['ErrNative'] := SrcTbl.ErrInfo.NativeErr;
          if (SrcTbl.ErrInfo.PrepErr > 0) then
            FieldValues['FixCode'] := SrcTbl.ErrInfo.PrepErr
          else
            FieldValues['FixCode'] := SrcTbl.ErrInfo.FixErr;
          FieldValues['IsMark']    := False;
          Post;
        end;
        Next;
      end;
    end;
  end;
end;


//-------------------------------------------------------------
// Проверить и исправить все
function TFixADSTables.RecoverAll(TableName : string = '') : Integer;
begin
  if (NewAdsList(TableName) = True) then begin
    // Тестировать все подряд
    FixList.TestSelected(FixPars.TableTestMode);
    RecoverAllBase;
    Result := 0;
  end else
    Result := UE_NO_ADS;
end;


// Проверить и исправить все отмеченные
procedure TFixADSTablesUI.RecoverMarked;
begin
  if ( Assigned(FixList) AND (FixList.Filled) ) then begin
    SortByState(False);
    FixList.TestSelected(FixPars.TableTestMode, False);
    RecoverAllBase(False);
    SortByState(True);
  end
  else
    PutError('Таблицы не найдены!');

end;


// Исправить все отмеченные
procedure TFixADSTablesUI.FixAllMarked;
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

// Исправить оригинал для отмеченных
procedure TFixADSTablesUI.ApplyFixMarked;
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


end.
