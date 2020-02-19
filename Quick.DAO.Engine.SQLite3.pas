{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.DAO.Engine.SQLite3
  Description : DAODatabase SQLite3 Provider
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 06/07/2019
  Modified    : 08/02/2020

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

unit Quick.DAO.Engine.SQLite3;

{$i QuickDAO.inc}

interface

uses
  Classes,
  SysUtils,
  SQLite3,
  SQLite3Wrap,
  Quick.Commons,
  Quick.DAO,
  Quick.DAO.Database,
  Quick.DAO.Query;

type

  TDAODataBaseSQLite3 = class(TDAODatabase)
  private
    fDataBase : TSQLite3Database;
    fInternalQuery : TSQLite3Statement;
  protected
    function CreateConnectionString: string; override;
    procedure OpenSQLQuery(const aQueryText: string); override;
    procedure ExecuteSQLQuery(const aQueryText: string); override;
    function ExistsTable(aModel : TDAOModel) : Boolean; override;
    function ExistsColumn(aModel: TDAOModel; const aFieldName: string): Boolean; override;
    function GetDBFieldIndex(const aFieldName : string) : Integer;
  public
    constructor Create; override;
    destructor Destroy; override;
    function CreateQuery(aModel : TDAOModel) : IDAOQuery<TDAORecord>; override;
    function Connect : Boolean; override;
    function IsConnected : Boolean; override;
    function From<T : class, constructor> : IDAOLinqQuery<T>;
  end;

  TDAOQuerySQLite3<T : class, constructor> = class(TDAOQuery<T>)
  private
    fConnection : TDBConnectionSettings;
    fQuery : TSQLite3Statement;
  protected
    function GetCurrent : T; override;
    function MoveNext : Boolean; override;
    function GetFieldValue(const aName : string) : Variant; override;
    function OpenQuery(const aQuery : string) : Integer; override;
    function ExecuteQuery(const aQuery : string) : Boolean; override;
    function GetDBFieldIndex(const aFieldName : string) : Integer;
  public
    constructor Create(aDAODataBase : TDAODataBase; aModel : TDAOModel; aQueryGenerator : IDAOQueryGenerator); override;
    destructor Destroy; override;
    function CountResults : Integer; override;
    function Eof : Boolean; override;
  end;

implementation


{ TDAODataBaseSQLite3 }

constructor TDAODataBaseSQLite3.Create;
begin
  inherited;
  fDataBase := TSQLite3Database.Create;
end;

function TDAODataBaseSQLite3.Connect: Boolean;
begin
  //creates connection string based on parameters of connection property
  inherited;
  fDataBase.Open(Connection.Database);
  Result := IsConnected;
  fInternalQuery := TSQLite3Statement.Create(fDataBase,'');
  CreateTables;
  CreateIndexes;
end;

function TDAODataBaseSQLite3.CreateConnectionString: string;
begin
  //nothing to do
end;

function TDAODataBaseSQLite3.CreateQuery(aModel : TDAOModel) : IDAOQuery<TDAORecord>;
begin
  Result := TDAOQuerySQLite3<TDAORecord>.Create(Self,aModel,QueryGenerator);
end;

function TDAODataBaseSQLite3.GetDBFieldIndex(const aFieldName: string): Integer;
var
  i : Integer;
begin
  Result := -1;
  for i := 0 to fInternalQuery.ColumnCount - 1 do
  begin
    if CompareText(fInternalQuery.ColumnName(i),aFieldName) = 0 then Exit(i);
  end;
end;

destructor TDAODataBaseSQLite3.Destroy;
begin
  if Assigned(fInternalQuery) then fInternalQuery.Free;
  if Assigned(fDataBase) then
  begin
    fDataBase.Close;
    fDataBase.Free;
  end;
  inherited;
end;

function TDAODataBaseSQLite3.IsConnected: Boolean;
begin
  Result := True;// fDataBase.Connected;
end;

procedure TDAODataBaseSQLite3.OpenSQLQuery(const aQueryText: string);
begin
  fInternalQuery := fDataBase.Prepare(aQueryText);
end;

procedure TDAODataBaseSQLite3.ExecuteSQLQuery(const aQueryText: string);
begin
  fDataBase.Execute(aQueryText);
end;

function TDAODataBaseSQLite3.ExistsColumn(aModel: TDAOModel; const aFieldName: string): Boolean;
begin
  Result := False;
  OpenSQLQuery(QueryGenerator.ExistsColumn(aModel,aFieldName));
  while fInternalQuery.Step = SQLITE_ROW do
  begin
    if CompareText(fInternalQuery.ColumnText(GetDBFieldIndex('name')),aFieldName) = 0 then
    begin
      Result := True;
      Break;
    end;
  end;
  fInternalQuery.Reset;
end;

function TDAODataBaseSQLite3.ExistsTable(aModel: TDAOModel): Boolean;
begin
  Result := False;
  OpenSQLQuery(QueryGenerator.ExistsTable(aModel));
  while fInternalQuery.Step = SQLITE_ROW do
  begin
    if CompareText(fInternalQuery.ColumnText(GetDBFieldIndex('name')),aModel.TableName) = 0 then
    begin
      Result := True;
      Break;
    end;
  end;
  fInternalQuery.Reset;
end;

function TDAODataBaseSQLite3.From<T>: IDAOLinqQuery<T>;
var
  daoclass : TDAORecordclass;
begin
  daoclass := TDAORecordClass(Pointer(T));
  Result := TDAOQuerySQLite3<T>.Create(Self,Models.Get(daoclass),QueryGenerator);
end;

{ TDAOQuerySQLite3<T> }

constructor TDAOQuerySQLite3<T>.Create(aDAODataBase : TDAODataBase; aModel : TDAOModel; aQueryGenerator : IDAOQueryGenerator);
begin
  inherited;
  fQuery := TSQLite3Statement.Create(TDAODataBaseSQLite3(aDAODataBase).fDataBase,'');
  fConnection := aDAODataBase.Connection;
end;

destructor TDAOQuerySQLite3<T>.Destroy;
begin
  //if Assigned(fQuery) then fQuery.Free;
  inherited;
end;

function TDAOQuerySQLite3<T>.Eof: Boolean;
begin
  Result := False;// fQuery.Eof;
end;

function TDAOQuerySQLite3<T>.OpenQuery(const aQuery: string): Integer;
begin
  fFirstIteration := True;
  fQuery := TDAODataBaseSQLite3(fDAODataBase).fDataBase.Prepare(aQuery);
  fHasResults := sqlite3_data_count(fQuery) > 0;
  Result := sqlite3_data_count(fQuery);
end;

function TDAOQuerySQLite3<T>.ExecuteQuery(const aQuery: string): Boolean;
begin
  TDAODataBaseSQLite3(fDAODataBase).fDataBase.Execute(aQuery);
  fHasResults := False;
  Result := True; //sqlite3_data_count(fQuery) > 0;
end;

function TDAOQuerySQLite3<T>.GetFieldValue(const aName: string): Variant;
var
  idx : Integer;
begin
  idx := GetDBFieldIndex(aName);
  if idx = -1 then Exit;
  case fQuery.ColumnType(idx) of
    SQLITE_INTEGER : Result := fQuery.ColumnInt64(idx);
    SQLITE_FLOAT : Result := fQuery.ColumnDouble(idx);
    SQLITE_TEXT : Result := fQuery.ColumnText(idx);
    SQLITE_NULL : Exit;
  else Result := fQuery.ColumnText(idx);// raise Exception.Create('Unknow type');
  end;
end;

function TDAOQuerySQLite3<T>.CountResults: Integer;
begin
  Result := sqlite3_data_count(fQuery);
end;

function TDAOQuerySQLite3<T>.GetCurrent: T;
begin
  Result := fModel.Table.Create as T;
  Self.FillRecordFromDB(Result);
end;

function TDAOQuerySQLite3<T>.GetDBFieldIndex(const aFieldName: string): Integer;
var
  i : Integer;
begin
  Result := -1;
  for i := 0 to fQuery.ColumnCount - 1 do
  begin
    if CompareText(fQuery.ColumnName(i),aFieldName) = 0 then Exit(i);
  end;
end;

function TDAOQuerySQLite3<T>.MoveNext: Boolean;
begin
  Result := fQuery.Step = SQLITE_ROW;
end;



end.
