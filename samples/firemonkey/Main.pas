unit Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  System.IOUtils,
  FMX.StdCtrls, FMX.Controls.Presentation,
  FMX.ScrollBox, FMX.Memo,
  Quick.Commons,
  Quick.Chrono,
  Quick.DAO,
  Quick.DAO.Engine.FireDAC;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    Panel1: TPanel;
    btnProcess: TButton;
    procedure btnProcessClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

  TGenre = (gMale, gFemale);

  TConnection = class
  private
    fIdConnection : Integer;
    fConnectionDate : TDateTime;
  published
    property IdConnection : Integer read fIdConnection write fIdConnection;
    property ConnectionDate : TDateTime read fConnectionDate write fConnectionDate;
  end;

  TConnections = array of TConnection;

  TGroups = array of Int64;

  TLocation = record
    Street : string;
    Number : Integer;
    City : string;
  end;

  TUser = class(TDAORecord)
  private
    fIdUser : TAutoID;
    fName : string;
    fSurname : string;
    fAge : Integer;
    fActive : Boolean;
    fGenre : TGenre;
    fMoney : Double;
    fLastInfo : TDateTime;
    fGroups : TGroups;
    fLocation : TLocation;
    //fConnections : TConnections;
  published
    property IdUser : TAutoID read fIdUser write fIdUser;
    //[TFieldVARCHAR(50)]
    property Name : string index 50 read fName write fName;
    [TFieldVARCHAR(255)]
    property Surname : string read fSurname write fSurname;
    //[TMapField('UserAge')]
    property Age : Integer read fAge write fAge;
    property Active : Boolean read fActive write fActive;
    property Genre : TGenre read fGenre write fGenre;
    //[TFieldDECIMAL(10,2)]
    property Money : Double index 2 read fMoney write fMoney;
    property LastInfo : TDateTime read fLastInfo write fLastInfo;
    property Groups : TGroups read fGroups write fGroups;
    property Location : TLocation read fLocation write fLocation;
    //property Connections : TConnections read fConnections write fConnections;
  end;

const
  UserNames : array of string = ['Cliff','Alan','Anna','Phil','John','Michel','Jennifer','Peter','Brandon','Joe','Steve','Lorraine','Bill','Tom'];
  UserSurnames : array of string = ['Gordon','Summer','Huan','Paterson','Johnson','Michelson','Smith','Peterson','Miller','McCarney','Roller','Gonzalez','Thomson','Muller'];

var
  DAODatabase : TDAODataBaseFireDAC;
  User : TUser;
  NumUsers : Integer;
  i : Integer;
  crono : TChronometer;

var
  Form1: TForm1;

implementation

{$R *.fmx}

procedure TForm1.btnProcessClick(Sender: TObject);
var
  connection : TConnection;
  location : TLocation;
  iresult : IDAOResult<TUser>;
begin
  crono := TChronometer.Create(False);
  DAODatabase := TDAODataBaseFireDAC.Create;
    DAODatabase.Connection.Provider := TDBProvider.daoSQLite;
    {$IFNDEF NEXTGEN}
    DAODatabase.Connection.Database := '.\test.db3';
    {$ELSE}
    DAODatabase.Connection.Database := TPath.GetDocumentsPath + PathDelim + 'test.db3';
    {$ENDIF}
    DAODatabase.Models.Add(TUser,'IdUser');
    DAODatabase.Indexes.Add(TUser,['Name'],orAscending);
    if DAODatabase.Connect then Memo1.Lines.Add('Connected to database')
      else Memo1.Lines.Add('Can''t connect to database');

    NumUsers := 100;

    Memo1.Lines.Add(Format('Adding %d users to db...',[NumUsers]));
    crono.Start;
    //create random records
    User := TUser.Create;
    try
      for i := 1 to NumUsers do
      begin
        //User.IdUser := Random(999999999999999);
        User.Name := UserNames[Random(High(UserNames))];
        User.Surname := UserSurnames[Random(High(UserSurnames))] + ' ' + UserSurnames[Random(High(UserSurnames))];;
        User.Age := Random(30)+18;
        User.Genre := TGenre(Random(1));
        User.LastInfo := Now();
        User.Money := Random(50000);
        User.Active := True;
        User.Groups := [1,2,3,4,5,6,7];
        location.Street := 'Main St';
        location.Number := 1;
        location.City := 'London';
        User.Location := location;
        DAODatabase.Add(User);
      end;
    finally
      User.Free;
    end;
    crono.Stop;
    Memo1.Lines.Add(Format('Elapsed %s to insert %d records (Total in DB = %s)',[crono.ElapsedTime,NumUsers,NumberToStr(DAODatabase.From<TUser>.Count)]));

    //get users
    Memo1.Lines.Add('Where query...');
    iresult := DAODatabase.From<TUser>.Where('Age > ? AND Age < ?',[30,35]).OrderBy('Name').SelectTop(10);
    for User in iresult do
    begin
      Memo1.Lines.Add(Format('IdUser: %d Name: %s %s Age: %d Genre: %d LastInfo: %s',[User.IdUser,User.Name,User.Surname,User.Age,Ord(User.Genre),DateTimetoStr(User.LastInfo)]));
      User.Free;
    end;
    Memo1.Lines.Add(Format('Query results: %s',[NumberToStr(iresult.Count)]));

    //modify user
    Memo1.Lines.Add('Modify a existing User...');
    User := DAODatabase.From<TUser>.Where('IdUser = ?',[1]).SelectFirst;
    try
      if User <> nil then
      begin
        Memo1.Lines.Add(Format('Found -> IdUser: %d Name: %s %s Age: %d',[User.IdUser,User.Name,User.Surname,User.Age]));
        User.Age := 30;
        User.Active := True;
        DAODatabase.Update(User);
      end
      else Memo1.Lines.Add('Can''t found this User');
    finally
      User.Free;
    end;

    Memo1.Lines.Add('Count total Users...');
    Memo1.Lines.Add(Format('Num users in DB: %s',[NumberToStr(DAODatabase.From<TUser>.Count)]));

    Memo1.Lines.Add('< Finished >');
    DAODatabase.Free;
    crono.Free;
end;

end.
