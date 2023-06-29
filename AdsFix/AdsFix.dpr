program AdsFix;

uses
  ExceptionLog,
  Windows,
  Forms,
  AuthF in '..\AuthF.pas' {FormAuth},
  AdsDAO in '..\AdsDAO.pas' {dtmdlADS: TDataModule},
  uServiceProc in '..\uServiceProc.pas',
  MainF in '..\MainF.pas' {FormMain},
  uTableUtils in '..\uTableUtils.pas',
  uFixTypes in '..\uFixTypes.pas',
  uLoggerThr in '..\..\Lais7\OAIS\uLoggerThr.pas',
  uFixErrs in '..\uFixErrs.pas';

{$R *.res}

begin
  SetThreadLocale(1049);
  Application.Initialize;
  Application.CreateForm(TdtmdlADS, dtmdlADS);
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.

