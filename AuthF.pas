unit AuthF;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, Mask, DBCtrlsEh, IniFiles;

type
AParams = array[0..1] of string;

type
  TFormAuth = class(TForm)
    Login: TDBEditEh;
    Parol: TDBEditEh;
    Label1: TLabel;
    Label2: TLabel;
    Vxod: TBitBtn;
    Vixod: TBitBtn;
    ChB: TCheckBox;
    procedure VxodClick(Sender: TObject);
    procedure VixodClick(Sender: TObject);
    procedure ParolChange(Sender: TObject);
    procedure ChBClick(Sender: TObject);
    //procedure FormCreate(Sender: TObject);
    //procedure FormDestroy(Sender: TObject);
    procedure InitPars(aPars: AParams);
    procedure SetResult(var UL, UP : string);
    procedure LoginKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ParolKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FormAuth: TFormAuth;

implementation

uses
  AdsDAO;

{$R *.dfm}

procedure TFormAuth.InitPars(aPars: AParams);
begin
  Login.Text := aPars[0];
  Parol.Text := aPars[1];
end;

procedure TFormAuth.SetResult(var UL, UP : string);
var
  aPars: AParams;
begin
  UL := Login.Text;
  UP := Parol.Text;
end;

procedure TFormAuth.VxodClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TFormAuth.VixodClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TFormAuth.ParolChange(Sender: TObject);
begin
if ChB.Checked then Parol.PasswordChar:=#0 else Parol.PasswordChar:='*'
end;

procedure TFormAuth.ChBClick(Sender: TObject);
begin
if ChB.Checked then Parol.PasswordChar:=#0 else Parol.PasswordChar:='*'
end;

procedure TFormAuth.ParolKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
if (Key = VK_RETURN) then
   Vxod.Click;
end;

procedure TFormAuth.LoginKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
if (Key = VK_RETURN) then
   Parol.SetFocus;
end;

end.
