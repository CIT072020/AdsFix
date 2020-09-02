unit FixDups;

interface

uses
  SysUtils, Classes, adsset, adscnnct, DB, adsdata, adsfunc, adstable, ace,
  kbmMemTable, ServiceProc, AdsDAO;
const
  ORGPFX : string = 'tmp_';

procedure FixAllMarked(Sender: TObject);
function ChangeOriginal(AdsTbl: TTableInf): Boolean;
function DelOriginalTable(AdsTbl: TTableInf): Boolean;

var
  TInfLast,
  TableInf : TTableInf;
  UInd : TIndexInf;

implementation

uses
  FileUtil;


function SQL_7207_SearchEmpty(TblInf : TTableInf; iI : Integer; nMode : Integer) : string;
var
  i,
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
    s := s + 'EMPTY(' + IndInf.Fields.Strings[i] + ') OR (' +
                        IndInf.Fields.Strings[i] + ' <= 0)';
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
function Fix7207(TblInf : TTableInf; DstPath: string) : Integer;
var
  j,
  i : Integer;
  sExec : string;
begin
    try
      //TableName := Table;
      //Open;
      Result := 0;
      //dtmdlADS.qAny.
      with dtmdlADS.qDst do begin
        if Active then
          Close;
        if (dtmdlADS.cnABTmp.IsConnected) then
          dtmdlADS.cnABTmp.IsConnected := False;

        dtmdlADS.cnABTmp.ConnectPath := AppPars.Path2Tmp;
        dtmdlADS.cnABTmp.IsConnected := True;
        AdsConnection := dtmdlADS.cnABTmp;
        for i := 0 to TblInf.IndCount - 1 do begin
          SQL.Clear;
          sExec := SQL_7207_SearchEmpty(TblInf, i, 1);
          SQL.Add(sExec);
          VerifySQL;
          j := dtmdlADS.cnABTmp.Execute(sExec);
          Result := Result + j;
          //ExecSQL;
          //Active := True;
          //Result := Result + RowsAffected;
        end;
      end;

    finally
      sExec := '';

    end;
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

procedure IndexesInf(AdsTbl : TTableInf);
var
  i : Integer;
  s : string;
begin
  AdsTbl.IndexInf := TList.Create;
  with dtmdlADS.qAny do begin
    if Active then
      Close;
    SQL.Text := 'SELECT INDEX_OPTIONS, INDEX_EXPRESSION, PARENT FROM ' +
      dtmdlADS.SYSTEM_ALIAS + 'INDEXES WHERE (PARENT = ''' + AdsTbl.TableName +
      ''') AND ((INDEX_OPTIONS & 1) = 1)';
    Active := True;
    AdsTbl.IndCount := RecordCount;
    First;
    while not Eof do begin
      UInd := TIndexInf.Create;
      UInd.Options := FieldByName('INDEX_OPTIONS').AsInteger;
      //UInd.Expr := FieldByName('INDEX_EXPRESSION').AsInteger;
      UInd.Fields := TStringList.Create;
      UInd.Fields.Delimiter := ';';
      UInd.Fields.Text := FieldByName('INDEX_EXPRESSION').AsString;
      AdsTbl.IndexInf.Add(UInd);
      Next;
    end;

  end;

end;

procedure GetFieldsInf(AdsTbl: TTableInf);
var
  i: Integer;
  s: string;
  UFlds: TFieldsInf;
begin
  //AdsTbl.FieldsInf := Tlist.Create;
  AdsTbl.FieldsInfAds := TACEFieldDefs.Create(AdsTbl.AdsT.Owner);

  AdsTbl.FieldsInf := TList.Create;

  AdsTbl.FieldsAI := TStringList.Create;

  with dtmdlADS.qAny do begin
    if Active then
      Close;
    SQL.Text := 'SELECT Name, Field_Type FROM ' + dtmdlADS.SYSTEM_ALIAS + 'COLUMNS WHERE (PARENT = ''' + AdsTbl.TableName + ''')';
    Active := True;
    First;
    while not Eof do begin
      UFlds := TFieldsInf.Create;
      UFlds.Name := FieldByName('Name').AsString;
      UFlds.FieldType := FieldByName('Field_Type').AsInteger;
      if (UFlds.FieldType = FTYPE_AUTOINC) then
        AdsTbl.FieldsAI.Add(UFlds.Name);
      AdsTbl.FieldsInf.Add(UFlds);
      Next;
    end;

  end;

end;

function FixTable(AdsTbl: TTableInf; Sender: TObject): Integer;
var
  ec : Integer;
  FileSrc,
  FileDst,
  s : String;
  ErrInf : TStringList;
begin
  Result := 1;
  try

    GetFieldsInf(AdsTbl);
    IndexesInf(AdsTbl);

    FileSrc := AppPars.Path2Src + AdsTbl.TableName;
    FileDst := AppPars.Path2Tmp + AdsTbl.TableName + '.adt';

    if (CopyOneFile(FileSrc + '.adt', AppPars.Path2Tmp) = 0) then begin


      if FileExists(FileSrc + '.adm') then begin
        if (CopyOneFile(FileSrc + '.adm', AppPars.Path2Tmp) = 0) then begin
        end;
      end;
      if AdsDDFreeTable(PAnsiChar(FileDst), nil) = AE_FREETABLEFAILED then
        ErrInf.Text := 'Error while free Table from datadictionary';
      AdsTbl.RowsFixed := Fix7207(AdsTbl, FileDst);

    end;
    Result := 0;
  except

    on E: EADSDatabaseError do begin
      dtmdlADS.FSrcFixCode.AsInteger := E.ACEErrorCode;
      end;

    end;

end;

procedure FixAllMarked(Sender: TObject);
var
  i: Integer;
begin
  with dtmdlADS.mtSrc do begin
    First;
    i := 0;
    while not Eof do begin
      i := i + 1;
      if (dtmdlADS.FSrcMark.AsBoolean = True) then begin
        if (dtmdlADS.tblAds.Active) then
          dtmdlADS.tblAds.Close;

        TableInf := TTableInf.Create;
        TableInf.AdsT := dtmdlADS.tblAds;
        TableInf.Owner := dtmdlADS.tblAds.Owner;

        TableInf.AdsT.TableName := dtmdlADS.FSrcTName.AsString;


        TableInf.TableName := dtmdlADS.FSrcTName.AsString;

        dtmdlADS.mtSrc.Edit;
        dtmdlADS.FSrcFixCode.AsInteger := FixTable(TableInf, Sender);
        TInfLast := TableInf;
        dtmdlADS.FSrcMark.AsBoolean := False;
        dtmdlADS.mtSrc.Post;
      end;
      Next;
    end;

  end;

end;




// AutoInc => Integer
function ChangeAI2Int(AdsTbl: TTableInf): Boolean;
var
  i: Integer;
  s: string;
begin
  Result := True;
  try
    if (AdsTbl.FieldsAI.Count > 0) then begin
      s := 'ALTER TABLE ' + AdsTbl.TableName;
      for i := 0 to (AdsTbl.FieldsAI.Count - 1) do begin
        s := s + ' ALTER COLUMN ' + AdsTbl.FieldsAI[i] + ' ' + AdsTbl.FieldsAI[i] + ' INTEGER';
      end;
      dtmdlADS.conAdsBase.Execute(s);
    end;
  except
    Result := False;
  end;
end;

function ChangeInt2AI(AdsTbl: TTableInf): Boolean;
var
  i: Integer;
  s: string;
begin
  Result := True;
  try
    if (AdsTbl.FieldsAI.Count > 0) then begin
      s := 'ALTER TABLE ' + AdsTbl.TableName;
      for i := 0 to (AdsTbl.FieldsAI.Count - 1) do begin
        s := s + ' ALTER COLUMN ' + AdsTbl.FieldsAI[i] + ' ' + AdsTbl.FieldsAI[i] + ' AUTOINC';
      end;
      dtmdlADS.conAdsBase.Execute(s);
    end;
  except
    Result := False;
  end;

end;



function ChangeOriginal(AdsTbl: TTableInf): Boolean;
var
  ec: Boolean;
  FileSrc, FileDst, TmpName, ss, sd: string;
begin
  Result := False;
  FileSrc := AppPars.Path2Src + AdsTbl.TableName;
  FileDst := AppPars.Path2Tmp + AdsTbl.TableName + '.adt';
  TmpName := AppPars.Path2Src + ORGPFX + AdsTbl.TableName;

  if FileExists(FileSrc + '.adi') then
    ec := DeleteFiles(FileSrc + '.adi');

  DeleteFiles(TmpName + '.*');

  ss := FileSrc + '.adt';
  sd := TmpName + '.adt';
  RenameFile(ss, sd);

  if FileExists(FileSrc + '.adm') then begin
    ss := FileSrc + '.adm';
    sd := TmpName + '.adm';
    ec := RenameFile(ss, sd);
  end;

  if (not dtmdlADS.conAdsBase.IsConnected) then
    dtmdlADS.conAdsBase.IsConnected := True;

  if (dtmdlADS.tblAds.Active) then
    dtmdlADS.tblAds.Active := False;
  dtmdlADS.tblAds.TableName := AdsTbl.TableName;
  dtmdlADS.tblAds.Active := True;
  //
  dtmdlADS.tblAds.Active := False;


  if (ChangeAI2Int(AdsTbl) = True) then begin
    ss := 'INSERT INTO ' + AdsTbl.TableName + ' SELECT * FROM "' + FileDst + '"';
    dtmdlADS.conAdsBase.Execute(ss);
    ChangeInt2AI(AdsTbl);
  end;
  Result := True;

end;


function DelOriginalTable(AdsTbl: TTableInf): Boolean;
var
  ec: Boolean;
  TmpName : string;
begin
  ec := True;
  TmpName := AppPars.Path2Src + ORGPFX + AdsTbl.TableName;

  if FileExists(TmpName + '.adt') then
    ec := DeleteFiles(TmpName + '.adt');

  if FileExists(TmpName + '.adm') then
    ec := DeleteFiles(TmpName + '.adm');

  if FileExists(TmpName + '.adi') then
    ec := DeleteFiles(TmpName + '.adm');

  Result := ec;
end;


end.
