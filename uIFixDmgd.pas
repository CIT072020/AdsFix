unit uIFixDmgd;

interface

uses
  adstable,
  TableUtils;

type
  IFixDamaged = Interface
  ['{9CFB115F-B9EE-4A38-A51A-295F1E7E56EC}']
    function Fix8901(SrcTblInf: TTableInf; TT: TAdsTable): Integer;
  end;

function Fix8901(SrcTblInf: TTableInf; TT: TAdsTable): Integer;

implementation

uses
  SysUtils,
  Classes,
  ServiceProc;


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
 