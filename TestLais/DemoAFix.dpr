program DemoAFix;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Form1},
  fFixTblErr in '..\fFixTblErr.pas' {Form2};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TFixShow, Form2);
  Application.Run;
end.
