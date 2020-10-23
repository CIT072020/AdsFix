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
  //ace,
  //kbmMemTable,
  //EncdDecd,
  //ServiceProc, AdsDAO, TableUtils;
  ServiceProc,
  TableUtils;

type
  IFixErrs = Interface
  ['{06866869-3DFD-49D0-B1EF-BEF2BCE8E4F5}']
    function ChangeOriginal : Boolean;
  end;

  TDictAds = class(TTableInf, IFixErrs)
  public
    function ChangeOriginal : Boolean;
  end;


implementation

uses
  FileUtil;

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
function TDictAds.ChangeOriginal : Boolean;
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


end.
 