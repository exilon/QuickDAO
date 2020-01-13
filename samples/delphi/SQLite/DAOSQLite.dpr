program DAOSQLite;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.Chrono,
  Quick.DAO,
  Quick.DAO.Engine.FireDAC;
  //Quick.DAO.Engine.SQLite3;

type
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
  iresult : IDAOResult<TUser>;
  NumUsers : Integer;
  i : Integer;
  crono : TChronometer;
  location : TLocation;
begin
  try
    ReportMemoryLeaksOnShutdown := True;
    crono := TChronometer.Create(False);

    DAODatabase := TDAODataBaseFireDAC.Create;
    DAODatabase.Connection.Provider := TDBProvider.daoSQLite;
    DAODatabase.Connection.Database := '.\test.db3';
    DAODatabase.Models.PluralizeTableNames := True;
    DAODatabase.Models.Add(TUser,'IdUser');
    DAODatabase.Indexes.Add(TUser,['Name'],orAscending);
    if DAODatabase.Connect then cout('Connected to database',etSuccess)
      else cout('Can''t connect to database',etError);

    NumUsers := 100;

    cout('Adding %d users to db...',[NumUsers],etInfo);
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
    coutFmt('Elapsed %s to insert %d records (Total in DB = %s)',[crono.ElapsedTime,NumUsers,NumberToStr(DAODatabase.From<TUser>.Count)],etSuccess);
    cout('< Press a key to continue to next test >',etTrace);
    Readln;

    //get users
    cout('Where query...',etInfo);
    //User := TUser.Create(DAODatabase,'IdUser > ?',[0]);
    //User := TUser.Create(DAODatabase,'Age > ? AND Age < ?',[30,35]);
    iresult := DAODatabase.From<TUser>.Where('Age > ? AND Age < ?',[30,35]).OrderBy('Name').SelectTop(10);
    //iresult := DAODatabase.From<TUser>.Where('Name = ?',['Anna']).SelectTop(10);
    for User in iresult do
    begin
      cout('IdUser: %d Name: %s %s Age: %d Genre: %d LastInfo: %s',[User.IdUser,User.Name,User.Surname,User.Age,Ord(User.Genre),DateTimetoStr(User.LastInfo)],etSuccess);
      User.Free;
    end;
    cout('Query results: %s',[NumberToStr(iresult.Count)],etInfo);

    cout('< Press a key to continue to next test >',etTrace);
    Readln;

    //modify user
    cout('Modify a existing User...',etInfo);
    User := DAODatabase.From<TUser>.Where('IdUser = ?',[1]).SelectFirst;
    try
      if User <> nil then
      begin
        cout('Found -> IdUser: %d Name: %s %s Age: %d',[User.IdUser,User.Name,User.Surname,User.Age],etInfo);
        User.Age := 30;
        User.Active := True;
        DAODatabase.Update(User);
      end
      else cout('Can''t found this User',etError);
    finally
      User.Free;
    end;

    cout('Count total Users...',etInfo);
    coutFmt('Num users in DB: %s',[NumberToStr(DAODatabase.From<TUser>.Count)],etInfo);

    cout('< Press a key to Exit >',etInfo);
    ConsoleWaitForEnterKey;
    DAODatabase.Free;
    crono.Free;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
