unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,
  uServiceProc,
  uFixTypes;

type
  TForm1 = class(TForm)
    btnErrOpen: TButton;
    procedure btnErrOpenClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  FixBase : TFixBase;

implementation

uses
  SasaIniFile,
  fFixTblErr;

{$R *.dfm}

procedure TForm1.btnErrOpenClick(Sender: TObject);
var
  Path2Table, Path2Tmp: string;
  Pars: TFixPars;
  FormFix: TfmFixAds;
begin
  Pars := TFixPars.Create(TSasaIniFile.Create('AdsFix.INI'));
  Pars.Src := 'D:\App\ËÀÈÑ÷\Data\SelSovet.add';
  FixBase  := TFixBase.Create(Pars);

  FormFix := TfmFixAds.Create(Self);
  FormFix.InitPars(FixBase); //
  try
    if (FormFix.ShowModal = mrOk) then begin
      FormFix.SetResult;
    end;
  finally
    FreeAndNil(FormFix);
  end;
end;



end.
