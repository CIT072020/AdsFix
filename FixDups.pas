unit FixDups;

interface

uses
  SysUtils, Classes, adsset, adscnnct, DB, adsdata, adsfunc, adstable, ace,
  kbmMemTable,
  //EncdDecd,
  FixTypes,
  ServiceProc, AdsDAO, TableUtils;

const

  // ������������ ���� ����������� ����� � �������������� ����
  FWT_BOOL : Integer = 1;
  FWT_NUM  : Integer = 3;
  FWT_DATE : Integer = 5;
  FWT_STR  : Integer = 30;
  FWT_BIN  : Integer = 5;


procedure FixAllMarked;
// ��������� �������� ��� ����������
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
//  else if (FieldType in ADS_STRINGS) then
//    Result := Result + ' OR EMPTY(' + FieldName + ')'
  else if (FieldType in ADS_STRINGS) or (FieldType in ADS_DATES) then
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
  ���������� ������� �� ����� ����������� ���������� ������ ����
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







// ��� ������ ������������ ����
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


// �������� �� ������ ����� ������ �� ������
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



// �������� �� ������ ����� ������ �� ������
procedure DelOtherDups(AdsTbl : TTableInf);
begin

end;











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
          // ��� ���� ���������� �������� �������

          // ����� � �������� ������ [���]������
        sExec := SQL_7207_SearchEmpty(TblInf, i, 1);
        j := AdsConnection.Execute(sExec);
        RowFix := RowFix + j;

          // ����� ����������� ������
        SQL.Clear;
        sExec := UniqRepeat(TblInf, i);
        SQL.Add(sExec);
        VerifySQL;
        //ExecSQL;
        Active := True;
        if (RecordCount > 0) then begin

          // ��� ���� ����� � ���������� ��������� �������
          // �������� ���� ������ �� ������
          LeaveOnlyAllowed(QDupGroups, TblInf, i, dtmdlADS.qDst);

          DelDups4Idx(TblInf);
        end;


          //ExecSQL;
          //Result := Result + RowsAffected;
      end;

      // ����� ������������ AUTOINC
      DelOtherDups(TblInf);

    end;

end;







// ����� ������ ��� ���� ������
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

    FixState := FIX_GOOD;
    SrcTbl.RowsFixed := 0;
    case SrcTbl.ErrInfo.ErrClass of
      7008, 7207:
        begin
            SrcTbl.RowsFixed := Fix7207(SrcTbl, dtmdlADS.qDupGroups);
        end;
      7200:
        begin
          if (SrcTbl.ErrInfo.NativeErr = 7123) then begin
          // ����������� ��� ����
            PutError(EMSG_SORRY);
            FixState := FIX_NOTHG;
          end
          else
            SrcTbl.RowsFixed := Fix7207(SrcTbl, dtmdlADS.qDupGroups);
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


// ����� ��������� � ������������ �������
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
      raise Exception.Create('������ ����������� ' + s);
    s := FileSrc + '.adm';
    if FileExists(s) then begin
      if (CopyOneFile(s, P2TMP) <> 0) then
        raise Exception.Create('������ ����������� ' + s);
    end;
    if AdsDDFreeTable(PAnsiChar(SrcTbl.FileTmp), nil) = AE_FREETABLEFAILED then
      raise EADSDatabaseError.Create(SrcTbl.AdsT, UE_BAD_PREP, '������ ������������ �������');
    SrcTbl.ErrInfo.PrepErr := 0;
    Result := 0;
  except
    SrcTbl.ErrInfo.State   := FIX_ERRORS;
    SrcTbl.ErrInfo.PrepErr := UE_BAD_PREP;
  end;
end;


// ��������� ��� ����������
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
          // ������������ �����������, ������ ������
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


// ������� � ���������� �������� ������������ �������
function ChangeOriginal(P2Src, P2Tmp : string; SrcTbl: TTableInf): Boolean;
var
  ecb: Boolean;
  i: Integer;
  FileSrc, FileDst, TmpName, ss, sd: string;
  Span: TSpan;
  Conn : TAdsConnection;
begin
  Result := False;

  SrcTbl.AdsT.Active := False;
  Conn := SrcTbl.AdsT.AdsConnection;
  Conn.Disconnect;

  FileSrc := P2Src + SrcTbl.TableName;
  FileDst := P2Tmp + SrcTbl.TableName + '.adt';

  SrcTbl.ErrInfo.State  := INS_ERRORS;
  SrcTbl.ErrInfo.InsErr := UE_BAD_INS;

  if (SrcTbl.NeedBackUp = True) then begin
    // ����� �������� ������� �����
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
      ecb := RenameFile(ss, sd);
      if (ecb = True) then
        SrcTbl.BackUps.Add(sd);
    end;
  end
  else  // ������� ������� + Memo + index
    ecb := DeleteFiles(FileSrc + '.ad?');

  //--- Auto-create empty table
  SrcTbl.AdsT.AdsConnection.IsConnected := True;
  SrcTbl.AdsT.Active := True;
  SrcTbl.AdsT.Active := False;
  //---

  try
    if (ChangeAI(SrcTbl, ' INTEGER', Conn) = True) then begin
      if (SrcTbl.GoodSpans.Count <= 0) then begin
        // �������� �����
        ss := 'INSERT INTO ' + SrcTbl.TableName + ' SELECT * FROM "' + FileDst + '" SRC';
        if (Length(SrcTbl.DmgdRIDs) > 0) then
          ss := ss + ' WHERE SRC.ROWID NOT IN (' + SrcTbl.DmgdRIDs + ')';
        Conn.Execute(ss);
      end
      else begin
        // �������� ����������� ������� �������
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


// ��������� �������� ��� ����������
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
        // ��� ����������

        SrcTbl := TTableInf(Ptr(dtmdlADS.FSrcFixInf.AsInteger));
        if (Assigned(SrcTbl)) then begin
          // ������������ �����������, ������ ������, ���� ���������� ������
          if (SrcTbl.ErrInfo.State = FIX_GOOD) then begin

            dtmdlADS.mtSrc.Edit;
            GoodChange := ChangeOriginal(FixBase.FixList.Path2Src, AppPars.Path2Tmp, SrcTbl);
            //GoodChange := DAds.ChangeOriginal;
            if (GoodChange = True) then begin
          // ������� ��������
              dtmdlADS.FSrcMark.AsBoolean := False;
            end
            else begin
          // ������ �������
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

// �������� ����������� ���������� � �������� (BAckups) ��� ����� �������
function DelBUps4OneTable(SrcTbl: TTableInf): integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 1 to SrcTbl.BackUps.Count do
    if (DeleteFiles(SrcTbl.BackUps[i - 1]) = True) then
      Result := Result + 1;
end;

// ������� BAckup ����������
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


// ������ ���� ��� ����� �������
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
    // ������ ������������ ����
    ec := PrepTable(FixBase.FixList.Path2Src, AppPars.Path2Tmp, SrcTbl);
    if (ec = 0) then begin
      // ����������� �����
      RowsFixed := TblErrorController(SrcTbl);
      if (SrcTbl.ErrInfo.FixErr = 0) then begin
        // ����������� ���������
        if (ChangeOriginal(FixBase.FixList.Path2Src, AppPars.Path2Tmp, SrcTbl) = True) then
          SrcTbl.ErrInfo.State := INS_GOOD
        else
          SrcTbl.ErrInfo.State := INS_ERRORS;
      end;
    end;
  end;
end;


// Full Proceed ��� ����/����������
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


// ������������ ������ ������� �� ������� ������
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
        // ��������� ������
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

// ��������� �������� ������� ������� ��� EoF
function EofQ(iStart: Integer; TName: string; Q: TAdsQuery; var iMax: Integer): Boolean;
const
  MAX_RECS: Integer = 50000;
var
  iTry: Integer;
begin
  Result := False;
  if ((iStart + MAX_RECS - 1) > iMax) then
    // ����� �� ������� �������
    iTry := iMax - iStart + 1
  else
    iTry := MAX_RECS;
  iMax := FloatQ(iStart, TName, Q, iTry);
  if (iMax = -1) then
    Result := True;
end;


// ������������ ������� � ������������� ������� (Scan by SQL-Select)
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
        // ������� ������ �� ��������, � ���������
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
end.
