unit fFixTblErr;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,
  uFixTypes,
  AdsDAO,
  uServiceProc;

type
  TfmFixAds = class(TForm)
    mmProt : TMemo;
    btnTestAndFix: TButton;
    btnRet2Orig: TButton;
    btnExit: TButton;
    procedure btnExitClick(Sender: TObject);
    procedure btnTestAndFixClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    procedure InitPars(FBase : TFixBase; TName : string = '');
    procedure SetResult;
  end;

var
  fmFixAds : TfmFixAds;
  FixAds   : TFixBase;
  Tbl2Recover : string;

implementation

{$R *.dfm}

// �������� �����
procedure TfmFixAds.btnExitClick(Sender: TObject);
begin
  Self.ModalResult := mrOk;
end;

// �������� ������ - ���������
procedure TfmFixAds.FormShow(Sender: TObject);
begin
  if (btnTestAndFix.Enabled = True) then
    btnTestAndFix.SetFocus;
end;

// ���������� ���������� ��� ��������/�����������
procedure TfmFixAds.InitPars(FBase : TFixBase; TName : string = '');
begin
  Application.CreateForm(TdtmdlADS, dtmdlADS);
  FixAds := FBase;
  Tbl2Recover := TName;
  mmProt.Text := Format('���������: %s %s', [FixAds.FixPars.Src, TName]);
  if (FixAds.FixPars.IsDict) then
    btnTestAndFix.Enabled := True;
end;

procedure TfmFixAds.SetResult;
begin
end;


procedure SetProtView(Prot : TMemo);
begin
  Prot.Lines.Add(Format('���������� ������ - %d',[FixAds.FixList.TablesCount]));
  Prot.Lines.Add(Format('������ ������������ - %d',[FixAds.FixList.ErrTested]));
end;

// ����� � ��������� ��� ������
procedure TfmFixAds.btnTestAndFixClick(Sender: TObject);
begin
  TButtonControl(Sender).Enabled := False;
  try
    FixAds.RecoverAll(Tbl2Recover);
    SetProtView(mmProt);
  finally
    TButtonControl(Sender).Enabled := True;
  end;

end;

end.
