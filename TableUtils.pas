unit TableUtils;

interface

uses
  Classes,
  AdsData, Ace, AdsTable;


type
  // Info по ошибке
  TErrInfo = class
    ErrClass : Integer;
    NativeErr  : Integer;
    MsgErr   : string;
  end;
  
type
  // описание ADS-таблицы для восстановления
  TTableInf = class
  private
    //FOwner : TObject;
  public
    AdsT      : TAdsTable;
    TableName : string;
    // уникальных индексов
    IndCount  : Integer;
    IndexInf  : TList;
    FieldsInf    : TList;
    FieldsInfAds : TACEFieldDefs;
    // поля с типом autoincrement
    FieldsAI  : TStringList;
    ErrInfo  : TErrInfo;

    DupRows   : TList;
    List4Del  : String;
    TotalDel  : Integer;
    RowsFixed : Integer;
    //property Owner : TObject read FOwner write FOwner;
    constructor Create(TName : string; AT: TAdsTable);
    destructor Destroy; override;
  end;

implementation

constructor TTableInf.Create(TName : string; AT: TAdsTable);
begin
  inherited Create;

  Self.TableName := TName;
  Self.AdsT := AT;
  Self.AdsT.TableName := TName;

  IndexInf := TList.Create;
  ErrInfo  := TErrInfo.Create;
end;


destructor TTableInf.Destroy;
begin
  //if FField2 <> nil then FreeAndNil(FField2);
  inherited Destroy;
end;

end.
 