{ ***************************************************************************

  Copyright (c) 2016-2019 Kike Pérez

  Unit        : Quick.DAO.Database
  Description : DAO Database
  Author      : Kike Pérez
  Version     : 1.2
  Created     : 22/06/2018
  Modified    : 08/11/2019

  This file is part of QuickDAO: https://github.com/exilon/QuickDAO

 ***************************************************************************

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

 *************************************************************************** }

unit Quick.DAO.Database;

{$i QuickDAO.inc}

interface

uses
  SysUtils,
  Classes,
  Rtti,
  TypInfo,
  {$IFDEF FPC}
   rttiutils,
   fpjson,
   jsonparser,
   strUtils,
   //jsonreader,
   //fpjsonrtti,
   Quick.Json.fpc.Compatibility,
  {$ELSE}
    {$IFDEF DELPHIXE7_UP}
    System.Json,
    {$ENDIF}
  {$ENDIF}
  Quick.Json.Serializer,
  Quick.DAO,
  Quick.DAO.Factory.QueryGenerator;

type

  IDBConnectionSettings = interface
  ['{B4AE214B-432F-409C-8A15-AEEEE39CBAB5}']
    function GetProvider : TDBProvider;
    function GetServer : string;
    function GetDatabase : string;
    function GetUserName : string;
    function GetPassword : string;
    property Provider : TDBProvider read GetProvider;
    property Server : string read GetServer;
    property Database : string read GetDatabase;
    property UserName : string read GetUserName;
    property Password : string read GetPassword;
    function IsCustomConnectionString : Boolean;
    procedure FromConnectionString(aDBProviderID : Integer; const aConnectionString: string);
    function GetCustomConnectionString : string;
  end;

  TDBConnectionSettings = class(TInterfacedObject,IDBConnectionSettings)
  private
    fDBProvider : TDBProvider;
    fServer : string;
    fDatabase : string;
    fUserName : string;
    fPassword : string;
    fCustomConnectionString : string;
    fIsCustomConnectionString : Boolean;
    function GetProvider : TDBProvider; virtual;
    function GetServer : string;
    function GetDatabase : string;
    function GetUserName : string;
    function GetPassword : string;
  public
    constructor Create;
    property Provider : TDBProvider read GetProvider write fDBProvider;
    property Server : string read fServer write fServer;
    property Database : string read fDatabase write fDatabase;
    property UserName : string read fUserName write fUserName;
    property Password : string read fPassword write fPassword;
    function IsCustomConnectionString : Boolean;
    procedure FromConnectionString(aDBProviderID : Integer; const aConnectionString: string);
    function GetCustomConnectionString : string;
  end;

  TDAODataBase = class
  private
    fDBConnection : TDBConnectionSettings;
    fQueryGenerator : IDAOQueryGenerator;
    fModels : TDAOModels;
    fIndexes : TDAOIndexes;
  protected
    function CreateConnectionString : string; virtual; abstract;
    procedure ExecuteSQLQuery(const aQueryText : string); virtual; abstract;
    procedure OpenSQLQuery(const aQueryText: string); virtual; abstract;
    function ExistsTable(aModel : TDAOModel) : Boolean; virtual; abstract;
    function CreateTable(const aModel : TDAOModel): Boolean; virtual;
    function ExistsColumn(aModel: TDAOModel; const aFieldName: string): Boolean; virtual; abstract;
    procedure AddColumnToTable(aModel : TDAOModel; aField : TDAOField); virtual;
    procedure CreateTables; virtual;
    procedure SetPrimaryKey(aModel : TDAOModel); virtual;
    procedure CreateIndexes; virtual;
    procedure CreateIndex(aModel : TDAOModel; aIndex : TDAOIndex); virtual;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    function QueryGenerator : IDAOQueryGenerator;
    property Connection : TDBConnectionSettings read fDBConnection write fDBConnection;
    property Models : TDAOModels read fModels write fModels;
    property Indexes : TDAOIndexes read fIndexes write fIndexes;
    function CreateQuery(aModel : TDAOModel) : IDAOQuery<TDAORecord>; virtual; abstract;
    function GetTableNames : TArray<string>; virtual; abstract;
    function GetFieldNames(const aTableName : string) : TArray<string>; virtual; abstract;
    function Connect : Boolean; virtual;
    function IsConnected : Boolean; virtual; abstract;
    function AddOrUpdate(aDAORecord : TDAORecord) : Boolean; virtual;
    function Add(aDAORecord : TDAORecord) : Boolean; virtual;
    function Update(aDAORecord : TDAORecord) : Boolean; virtual;
    function Delete(aDAORecord : TDAORecord) : Boolean; overload; virtual;
  end;

implementation

{ TDAODataBase }

function TDAODataBase.Connect: Boolean;
begin
  Result := False;
  fQueryGenerator := TDAOQueryGeneratorFactory.Create(fDBConnection.Provider);
end;

constructor TDAODataBase.Create;
begin
  fDBConnection := TDBConnectionSettings.Create;
  fModels := TDAOModels.Create;
  fIndexes := TDAOIndexes.Create;
end;

procedure TDAODataBase.CreateIndexes;
var
  daoindex : TDAOIndex;
  daomodel : TDAOModel;
begin
  for daoindex in Indexes.List do
  begin
    for daomodel in Models.List do
    begin
      if daomodel.Table = daoindex.Table then CreateIndex(daomodel,daoindex);
    end;
  end;
end;

procedure TDAODataBase.CreateTables;
var
  daomodel : TDAOModel;
begin
  for daomodel in Models.List do
  begin
    if not ExistsTable(daomodel) then CreateTable(daomodel);
    SetPrimaryKey(daomodel);
  end;
end;

function TDAODataBase.CreateTable(const aModel : TDAOModel): Boolean;
var
  field : TDAOField;
begin
  Result := False;
  try
    ExecuteSQLQuery(QueryGenerator.CreateTable(aModel));
    Result := True;
  except
    on E : Exception do raise EDAOCreationError.CreateFmt('Error creating table "%s" : %s!',[aModel.TableName,e.Message])
  end;
  //add new fields
  for field in aModel.GetFields do
  begin
    if not ExistsColumn(aModel,field.Name) then AddColumnToTable(aModel,field);
  end;
end;

procedure TDAODataBase.AddColumnToTable(aModel : TDAOModel; aField : TDAOField);
begin
  try
    ExecuteSQLQuery(QueryGenerator.AddColumn(aModel,aField));
  except
    on E : Exception do raise EDAOCreationError.CreateFmt('Error creating table "%s" fields',[aModel.TableName]);
  end;
end;

procedure TDAODataBase.SetPrimaryKey(aModel : TDAOModel);
var
  query : string;
begin
  try
    query := QueryGenerator.SetPrimaryKey(aModel);
    if not query.IsEmpty then ExecuteSQLQuery(query);
  except
    on E : Exception do raise EDAOCreationError.Create('Error modifying primary key field');
  end;
  if fDBConnection.Provider = daoSQLite then Indexes.Add(aModel.Table,[aModel.PrimaryKey],TDAOIndexOrder.orAscending);
end;

procedure TDAODataBase.CreateIndex(aModel : TDAOModel; aIndex : TDAOIndex);
var
  query : string;
begin
  try
    query := QueryGenerator.CreateIndex(aModel,aIndex);
    if query.IsEmpty then Exit;
    ExecuteSQLQuery(query);
  except
    on E : Exception do raise EDAOCreationError.CreateFmt('Error creating index "%s" on table "%s"',[aIndex.FieldNames[0],aModel.TableName]);
  end;
end;

function TDAODataBase.Add(aDAORecord : TDAORecord) : Boolean;
begin
  Result := CreateQuery(fModels.Get(aDAORecord)).Add(aDAORecord);
end;

function TDAODataBase.AddOrUpdate(aDAORecord : TDAORecord) : Boolean;
begin
  Result := CreateQuery(fModels.Get(aDAORecord)).AddOrUpdate(aDAORecord);
end;

function TDAODataBase.Delete(aDAORecord : TDAORecord) : Boolean;
begin
  Result := CreateQuery(fModels.Get(aDAORecord)).Delete(aDAORecord);
end;

function TDAODataBase.Update(aDAORecord : TDAORecord) : Boolean;
begin
  Result := CreateQuery(fModels.Get(aDAORecord)).Update(aDAORecord);
end;

destructor TDAODataBase.Destroy;
begin
  fDBConnection.Free;
  fModels.Free;
  fIndexes.Free;
  inherited;
end;

function TDAODataBase.QueryGenerator: IDAOQueryGenerator;
begin
  Result := fQueryGenerator;
end;

{ TDBConnectionSettings }

constructor TDBConnectionSettings.Create;
begin
  fCustomConnectionString := '';
  fIsCustomConnectionString := False;
end;

procedure TDBConnectionSettings.FromConnectionString(aDBProviderID : Integer; const aConnectionString: string);
begin
  if aConnectionString.IsEmpty then fIsCustomConnectionString := False
  else
  begin
    fCustomConnectionString := aConnectionString;
    fIsCustomConnectionString := True;
  end;
  //get provider from connectionstring
  if aDBProviderID <> 0 then fDBProvider := TDBProvider(aDBProviderID)
  else
  begin
    if fCustomConnectionString.ToUpper.Contains('DRIVERID=SQLITE') then fDBProvider := TDBProvider.daoSQLite;
  end;
end;

function TDBConnectionSettings.GetCustomConnectionString: string;
begin
  Result := fCustomConnectionString;
end;

function TDBConnectionSettings.GetDatabase: string;
begin
  Result := fDatabase;
end;

function TDBConnectionSettings.GetProvider: TDBProvider;
begin
  Result := fDBProvider;
end;

function TDBConnectionSettings.GetServer: string;
begin
  Result := fServer;
end;

function TDBConnectionSettings.GetUserName: string;
begin
  Result := fUserName;
end;

function TDBConnectionSettings.IsCustomConnectionString: Boolean;
begin
  Result := fIsCustomConnectionString;
end;

function TDBConnectionSettings.GetPassword: string;
begin
  Result := fPassword;
end;

end.
