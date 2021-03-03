program DemoAFix;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Form1},
  fFixTblErr in '..\fFixTblErr.pas' {fmFixAds};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TfmFixAds, fmFixAds);
  Application.Run;
end.
