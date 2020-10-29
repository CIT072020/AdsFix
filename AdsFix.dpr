program AdsFix;

uses
  ExceptionLog,
  Windows,
  Forms,
  AuthF in 'AuthF.pas' {FormAuth},
  AdsDAO in 'AdsDAO.pas' {dtmdlADS: TDataModule},
  UIHelper in 'UIHelper.pas',
  ServiceProc in 'ServiceProc.pas',
  FixDups in 'FixDups.pas',
  MainF in 'MainF.pas' {FormMain},
  TableUtils in 'TableUtils.pas',
  FixTypes in 'FixTypes.pas',
  FixObject in 'FixObject.pas';

{$R *.res}

begin
  SetThreadLocale(1049);
  Application.Initialize;
  Application.CreateForm(TdtmdlADS, dtmdlADS);
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.

