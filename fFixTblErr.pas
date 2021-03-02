unit fFixTblErr;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,
  uFixTypes,
  uServiceProc;

type
  TFixShow = class(TForm)
    mmProt: TMemo;
    btnTestAndFix: TButton;
    btnRet2Orig: TButton;
    btnExit: TButton;
    procedure btnExitClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    procedure InitPars(Pars : TFixPars);
    procedure SetResult;
  end;

var
  Form2   : TFixShow;
  FixPars : TFixPars;
  FixAds  : TFixBase;

implementation

{$R *.dfm}

// Закрытие формы
procedure TFixShow.btnExitClick(Sender: TObject);
begin
  Self.ModalResult := mrOk;
end;

procedure TFixShow.InitPars(Pars : TFixPars);
begin
  FixPars := Pars;
end;

procedure TFixShow.SetResult;
begin
end;

end.
