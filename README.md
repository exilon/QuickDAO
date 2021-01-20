**QuickDAO**
--------

Data Access Object library for delphi/Firemonkey(Windows, Linux, Android, OSX & IOS) and Freepascal(Alpha: Windows/Linux) using objects & LinQ to simplify access to databases.

**Features:**
  
* **DAO**: Abstracts database layer, working with objects directly.
* **MultiEngine**: Supports different database engines/components like FireDAC, ADODB and SQLite3 (by Plasenkov).
* **MultiLanguage**: Automatic query translation to different database languages (SQLite, MSSSQL, MySQL, MSAccess,...)
* **Querying**: Use LinQ to simplify database interaction.

**Main units description:**
- **Quick.DAO:** Main library core.
- **Quick.DAO.Database:** Database management core.
- **Quick.DAO.Query:** Query and lambda LinQ operators core.
- **Quick.DAO.Engine.FireDAC:** Embarcadero FireDAC engine (supports many databases: MSSQL, MySQL, SQLite, etc...).
- **Quick.DAO.Engine.ADO:** Microsoft ADO engine (Supports many databases: MSSQL, MSAccess and ODBC connectors)
- **Quick.DAO.Engine.SQLite:** SQLite engine (SQLite library implementation by Plasenkov (https://github.com/plashenkov/SQLite3-Delphi-FPC)
- **Quick.DAO.Query.Generator:** Query translation language core.
- **Quick.DAO.QueryGenerator.MSSSQL:** Query functions for MSSQL.
- **Quick.DAO.QueryGenerator.MySQL:** Query functions for MySQL.
- **Quick.DAO.QueryGenerator.SQLite3:** Query functions for SQLite.

**Updates:**

* NEW: Optional Pluralize Tablenames convention.
* NEW: Freepascal alpha version (partially supported).
* NEW: First Delphi/Firemonkey beta version.

**Documentation:**
----------
With QuickDAO you can work with databases the similar way you work with objects, abstracting database layer. With LinQ lambda operators integrated you can make powerful queries easily.

**DAORecord:**
----
----
DAORecord is a data model class. Works as a mapping to a database table record. DAORecord class name determines corresponding table name (TUser -> User) and every published property will correspon to a field in database.
DAORecord can connect to existing tables (database-first) or will create it if not exists yet (code-first).
DAORecord class name and properties can be mapped to different table and property names.
You ever must define a primary key for every DAORecord.

```delphi
TUser = class(TDAORecord)
private
  fName : string;
  fAge : Integer;
published
  property Name : string read fName write fName;
  property Age : Integer read fAge write fAge;
end;
```

**Field types:**
Quick DAO automatically converts class types to database types and viceversa. By default, string properties will be nvarchar(MAX) and Double don't have decimal limit, if you want to limit lenght you can use index property or custom attributes.
Arrays, List and ObjectList properties stores as JSON in database.

```delphi
//limit Name to 30 chars in database
property Name : string index 30 read fName write fName;
//...or
[TFieldVARCHAR(50)]
property Name : string read fName write fName;

//limit Money to 2 decimals in database
property Money : Double index 2 read fMoney write fMoney;
//...or
[TFieldDECIMAL(10,2)]
property Money : Double read fMoney write fMoney;
```
Auto numeric fields must be indicated as TAutoID type to work correctly.
```delphi
property IdUser : TAutoID read fIdUser write fIdUser;
```

**Field mapping:**
Field mapping allows connect DAORecord properties to a different named field of your database. 
The only condition is both should be same type.
```delphi
//Maps your "Name" property with database field "UserName"
[TMapField('UserName')]
property Name : string index 30 read fName write fName;
```
**DAODatabase**:
----
----
DAODatabase is responsible of iterate with your database. Connect, create missing tables and indexes and querying. You can use code-first or database-first patterns. If you have an existing database and tables previously created, you need to create a DAORecord class with same name properties as your database have (or mapping to correspondent table field names). All properties without correspondent field into database will be created on connect to it.
Database engine must be selected on creation.
```delphi
DAODatabase := TDAODataBaseFireDAC.Create;
DAODatabase.Connection.Provider := TDBProvider.daoSQLite;
DAODatabase.Connection.Database := '.\test.db3';
```

**Database engine selection:**
- **FireDAC:** (Recommended) Is embarcadero database components to access databases. It's powerfull and supports many database servers. Add Quick.DAO.Engine.FireDAC to your uses clause. Delphi/Firemonkey Windows compatible.
```delphi
DAODatabase := TDAODataBaseFireDAC.Create;
```

- **ADO:** Database components to access databases. Supports many database servers and ODBC connectors. Add Quick.DAO.Engine.ADO to your uses clause. Delphi compatible.
```delphi
DAODatabase := TDAODataBaseADO.Create;
```

- **SQLite3:** Implementation of SQLite3 by Plasenkov (https://github.com/plashenkov/SQLite3-Delphi-FPC). Supports only SQLite3 databases. Add Quick.DAO.Engine.SQLite3 to your uses clause. Delphi/Firemonkey compatible.
```delphi
DAODatabase := TDAODataBaseSQLite3.Create;
```

**Database connection settings:**
- **MSSQL:**
```delphi
DAODatabase := TDAODataBaseADO.Create;
DAODatabase.Connection.Provider := TDBProvider.daoMSSQL;
DAODatabase.Connection.Server := 'MSSQLhostname';
DAODatabase.Connection.Database := 'MyTable';
DAODatabase.Connection.UserName := 'MyUser';
DAODatabase.Conneciton.Password := 'MyPassword';
```
- **MYSQL:**
```delphi
DAODatabase := TDAODataBaseFireDAC.Create;
DAODatabase.Connection.Provider := TDBProvider.daoMySQL;
DAODatabase.Connection.Server := 'MySQLhostname';
DAODatabase.Connection.Database := 'MyTable';
DAODatabase.Connection.UserName := 'MyUser';
DAODatabase.Conneciton.Password := 'MyPassword';
```
- **MSAccess:**
```delphi
DAODatabase := TDAODataBaseADO.Create;
DAODatabase.Connection.Provider := TDBProvider.daoMSAccess;
DAODatabase.Connection.Database := '.\test.accdb';
```
- **SQLite:**
```delphi
DAODatabase := TDAODataBaseFireDAC.Create;
DAODatabase.Connection.Provider := TDBProvider.daoSQLite;
DAODatabase.Connection.Database := '.\test.db3';
```

**Defining Models**:

Models are all DAORecords defined (corresponding to database tables). You need to indicate wich models use your database and primary key.
DAORecord class name can be mapped to a different table name.
PluralizingTableNameConvention option allows pluralize your tables.
```delphi
//Add model TUser with IdUser as primary key field
DAODatabase.Models.Add(TUser,'IdUser');
//Add model TUser with Id as primary key field, mapped to a table named "AppUsers"
DAODatabase.Models.Add(TUser,'Id','AppUsers');ñ
```

**Creating Indexes:**

Indexes added to DAODatabase will be recreated on real database. You can indicate one or more fields to index.
```delphi
//Add an index to field "Name" on table "User" in ascending order
DAODatabase.Indexes.Add(TUser,['Name'],orAscending);
```

**Connect to your database:**
When Models and Indexes has been defined, you can connect to database. Missing tables, fields and indexes will be recreated. Deleted properties won't be replicated.
```delphi
if DAODatabase.Connect then cout('Connected to database',etSuccess)
  else cout('Can''t connect to database',etError);
```

**DAOQuery:**
----
----
DAOQuery retrieves/stores data from/to database, abstracting database layer.

**Basic queries:** Records can be added, modified or deleted using DAORecord as parameter. These methods use DAORecord primary key to know which record must be processed.

- **Add:** Adds new record to a table database.
```delphi
DAODatabase.Add(User);
```

- **Update:** Updates an existing table database record.
```delphi
DAODatabase.Update(User);
```

- **Delete:** Deletes an existing table database record.
```delphi
DAODataBase.Delete(User);
```

**LinQ queries:**
LinQ queries offers a simplified way to work with database records. Queries use lambda operators to concatenate commands in same object.

- **From<Model>:** Indicate on which Model(table) query will be executed.

- **Where(Expression)**: Applies a conditional filter to current query.
```delphi
DAODatabase.From<TUser>.Where('Age =',[30]).SelectFirst;
DAODatabase.From<TUser>.Where('Age = ? OR Name = ?',[30,'Peter']).Select('Name,Age');
DAODatabase.From<TUser>.Where('(Age > ? AND Age < ?) AND (Name LIKE ?)',[30,35,'%BILLY%]).Select;
```
- **Count:** Returns number of records matching where clause. If no where clause specified, returns total records in database table.
```delphi
DAODatabase.From<TUser>.Count
DAODatabase.From<TUser>.Where('Age > ?',[30]).Count
```
- **Select:** Returns all matching records.
- **Select(FieldNamesList):** Returns all matching records, but only indicated field names will be filled in resulting DAORecords (more lightweight database query if not all fields are needed). FieldNamesList parameter needs a comma separated list of property names.
- **SelectFirst:** Returns first matching record.
- **SelectLast:** Returns last matching record.
- **SelectTop(limit):** Returns first x matching records.
```delphi
iresult := DAODatabase.From<TUser>.Where('Age > ? AND Age < ?',[30,35]).SelectTop(10);
User := DAODatabase.From<TUser>.Where('Age > ? AND Age < ?',[30,35]).SelectFirst;
```
Queries could return one or more records. On multiple results an iterator will be returned.
```delphi
iresult := DAODatabase.From<TUser>.Where('SurName = ?',['Perterson']).Select;
for User in iresult do
begin
  cout('Name: %d SurName: %s',[User.Name,User.SurName],etSuccess);
  User.Free;
end;
```
- **OrderBy:** Defines ordenation field names in ascending order.
```delphi
DAODatabase.From<TUser>.Where('SurName = ?',['Perterson']).OrderBy('SurName,Name').Select;
```

- **OrderByDescending:** Defines ordenation field names in descending order.
```delphi
DAODatabase.From<TUser>.Where('SurName = ?',['Perterson']).OrderByDescending('SurName,Name').Select;
```

- **Update(FieldNames,FieldValuesArray):** Updates table fields matching where clause with new values provided.
```delphi
DAODatabase.From<TUser>.Where('Name = ?',['Joe']).Update('Working',[True]);
DAODatabase.From<TUser>.Where('Age > ?',[30]).Update('ModifiedDate,ContractId',[Now(),12]);
```

- **Delete:** Removes all matching records from database table.
```delphi
DAODatabase.From<TUser>.Where('ContractId = ?',[12]).Delete;
```

>Do you want to learn delphi or improve your skills? [learndelphi.org](https://learndelphi.org)