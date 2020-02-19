{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.DAO.Engine.ADO
  Description : DAODatabase ADO Provider
  Author      : Kike Pérez
  Version     : 1.1
  Created     : 22/06/2018
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

unit Quick.DAO.Engine.ADO;

{$i QuickDAO.inc}

interface

uses
  Classes,
  SysUtils,
  {$IFDEF MSWINDOWS}
  Data.Win.ADODB,
  Winapi.ActiveX,
  {$ELSE}
  only Delphi/Firemonkey Windows compatible
  {$ENDIF}
  Quick.Commons,
  Quick.DAO,
  Quick.DAO.Database,
  Quick.DAO.Query;

const

   db_MSAccess2000 = Cardinal(TDBProvider.daoMSAccess2000);
   db_MSAccess2007 = Cardinal(TDBProvider.daoMSAccess2007);
   db_MSSQL        = Cardinal(TDBProvider.daoMSSQL);
   db_MSSQLnc10    = Cardinal(TDBProvider.daoMSSQL) + 1;
   db_MSSQLnc11    = Cardinal(TDBProvider.daoMSSQL) + 2;
   db_IBM400       = Cardinal(TDBProvider.daoIBM400);

type

  TDAODataBaseADO = class(TDAODatabase)
  private
    fADOConnection : TADOConnection;
    fInternalQuery : TADOQuery;
    function GetDBProviderName(aDBProvider: TDBProvider): string;
  protected
    function CreateConnectionString: string; override;
    procedure OpenSQLQuery(const aQueryText: string); override;
    procedure ExecuteSQLQuery(const aQueryText: string); override;
    function ExistsTable(aModel : TDAOModel) : Boolean; override;
    function ExistsColumn(aModel: TDAOModel; const aFieldName: string): Boolean; override;
  public
    constructor Create; override;
    destructor Destroy; override;
    function CreateQuery(aModel : TDAOModel) : IDAOQuery<TDAORecord>; override;
    function Connect : Boolean; override;
    function GetTableNames : TArray<string>; override;
    function GetFieldNames(const aTableName : string) : TArray<string>; override;
    function IsConnected : Boolean; override;
    function From<T : class, constructor> : IDAOLinqQuery<T>;
  end;

  TDAOQueryADO<T : class, constructor> = class(TDAOQuery<T>)
  private
    fConnection : TDBConnectionSettings;
    fQuery : TADOQuery;
  protected
    function GetCurrent : T; override;
    function MoveNext : Boolean; override;
    function GetFieldValue(const aName : string) : Variant; override;
    function OpenQuery(const aQuery : string) : Integer; override;
    function ExecuteQuery(const aQuery : string) : Boolean; override;
  public
    constructor Create(aDAODataBase : TDAODataBase; aModel : TDAOModel; aQueryGenerator : IDAOQueryGenerator); override;
    destructor Destroy; override;
    function CountResults : Integer; override;
    function Eof : Boolean; override;
  end;

implementation


{ TDAODataBaseADO }

constructor TDAODataBaseADO.Create;
begin
  inherited;
  CoInitialize(nil);
  fADOConnection := TADOConnection.Create(nil);
  fInternalQuery := TADOQuery.Create(nil);
end;

function TDAODataBaseADO.Connect: Boolean;
begin
  //creates connection string based on parameters of connection property
  inherited;
  fADOConnection.ConnectionString := CreateConnectionString;
  fADOConnection.Connected := True;
  fInternalQuery.Connection := fADOConnection;
  Result := IsConnected;
  CreateTables;
  CreateIndexes;
end;

function TDAODataBaseADO.CreateConnectionString: string;
var
  dbconn : string;
begin
  if Connection.IsCustomConnectionString then Result := Format('Provider=%s;%s',[GetDBProviderName(Connection.Provider),Connection.GetCustomConnectionString])
  else
  begin
    if Connection.Server = '' then dbconn := 'Data Source=' + Connection.Database
      else dbconn := Format('Database=%s;Data Source=%s',[Connection.Database,Connection.Server]);

    Result := Format('Provider=%s;Persist Security Info=False;User ID=%s;Password=%s;%s',[
                              GetDBProviderName(Connection.Provider),
                              Connection.UserName,
                              Connection.Password,
                              dbconn]);
  end;
end;

function TDAODataBaseADO.CreateQuery(aModel : TDAOModel) : IDAOQuery<TDAORecord>;
begin
  Result := TDAOQueryADO<TDAORecord>.Create(Self,aModel,QueryGenerator);
end;

function TDAODataBaseADO.GetDBProviderName(aDBProvider: TDBProvider): string;
begin
  case aDBProvider of
    TDBProvider.daoMSAccess2000 : Result := 'Microsoft.Jet.OLEDB.4.0';
    TDBProvider.daoMSAccess2007 : Result := 'Microsoft.ACE.OLEDB.12.0';
    TDBProvider.daoMSSQL : Result := 'SQLOLEDB.1';
    TDBProvider.daoMSSQLnc10 : Result := 'SQLNCLI10';
    TDBProvider.daoMSSQLnc11 : Result := 'SQLNCLI11';
    TDBProvider.daoIBM400 : Result := 'IBMDA4000';
    else raise Exception.Create('Unknow DBProvider or not supported by this engine');
  end;
end;

function TDAODataBaseADO.GetFieldNames(const aTableName: string): TArray<string>;
var
  sl : TStrings;
begin
  sl := TStringList.Create;
  try
    fInternalQuery.Connection.GetFieldNames(aTableName,sl);
    Result := StringsToArray(sl);
  finally
    sl.Free;
  end;
end;

function TDAODataBaseADO.GetTableNames: TArray<string>;
var
  sl : TStrings;
begin
  sl := TStringList.Create;
  try
    fInternalQuery.Connection.GetTableNames(sl);
    Result := StringsToArray(sl);
  finally
    sl.Free;
  end;
end;

destructor TDAODataBaseADO.Destroy;
begin
  if Assigned(fInternalQuery) then fInternalQuery.Free;
  if fADOConnection.Connected then fADOConnection.Connected := False;
  fADOConnection.Free;
  CoUninitialize;
  inherited;
end;

function TDAODataBaseADO.IsConnected: Boolean;
begin
  Result := fADOConnection.Connected;
end;

procedure TDAODataBaseADO.OpenSQLQuery(const aQueryText: string);
begin
  fInternalQuery.SQL.Text := aQueryText;
  fInternalQuery.Open;
end;

procedure TDAODataBaseADO.ExecuteSQLQuery(const aQueryText: string);
begin
  fInternalQuery.SQL.Text := aQueryText;
  fInternalQuery.ExecSQL;
end;

function TDAODataBaseADO.ExistsColumn(aModel: TDAOModel; const aFieldName: string): Boolean;
var
  field : string;
begin
  Result := False;
  if (Connection.Provider = TDBProvider.daoMSAccess2000) or (Connection.Provider = TDBProvider.daoMSAccess2007)  then
  begin
    if (Connection.Provider = TDBProvider.daoMSAccess2000) or (Connection.Provider = TDBProvider.daoMSAccess2007)  then
    begin
      for field in GetFieldNames(aModel.TableName) do
      begin
        if CompareText(field,aFieldName) = 0 then Exit(True);
      end;
    end;
  end
  else
  begin
    OpenSQLQuery(QueryGenerator.ExistsColumn(aModel,aFieldName));
    while not fInternalQuery.Eof do
    begin
      if CompareText(fInternalQuery.FieldByName('name').AsString,aFieldName) = 0 then
      begin
        Result := True;
        Break;
      end;
      fInternalQuery.Next;
    end;
    fInternalQuery.SQL.Clear;
  end;
end;

function TDAODataBaseADO.ExistsTable(aModel: TDAOModel): Boolean;
var
  table : string;
begin
  Result := False;
  if (Connection.Provider = TDBProvider.daoMSAccess2000) or (Connection.Provider = TDBProvider.daoMSAccess2007)  then
  begin
    for table in GetTableNames do
    begin
      if CompareText(table,aModel.TableName) = 0 then Exit(True);
    end;
  end
  else
  begin
    OpenSQLQuery(QueryGenerator.ExistsTable(aModel));
    while not fInternalQuery.Eof do
    begin
      if CompareText(fInternalQuery.FieldByName('name').AsString,aModel.TableName) = 0 then
      begin
        Result := True;
        Break;
      end;
      fInternalQuery.Next;
    end;
    fInternalQuery.SQL.Clear;
  end;
end;

function TDAODataBaseADO.From<T>: IDAOLinqQuery<T>;
var
  daoclass : TDAORecordclass;
begin
  daoclass := TDAORecordClass(Pointer(T));
  Result := TDAOQueryADO<T>.Create(Self,Models.Get(daoclass),QueryGenerator);
end;

{ TDAOQueryADO<T> }

constructor TDAOQueryADO<T>.Create(aDAODataBase : TDAODataBase; aModel : TDAOModel; aQueryGenerator : IDAOQueryGenerator);
begin
  inherited;
  fQuery := TADOQuery.Create(nil);
  fQuery.Connection := TDAODataBaseADO(aDAODataBase).fADOConnection;
  fConnection := aDAODataBase.Connection;
end;

destructor TDAOQueryADO<T>.Destroy;
begin
  if Assigned(fQuery) then fQuery.Free;
  inherited;
end;

function TDAOQueryADO<T>.Eof: Boolean;
begin
  Result := fQuery.Eof;
end;

function TDAOQueryADO<T>.OpenQuery(const aQuery: string): Integer;
begin
  fFirstIteration := True;
  fQuery.Close;
  fQuery.SQL.Text := aQuery;
  fQuery.Open;
  fHasResults := fQuery.RecordCount > 0;
  Result := fQuery.RecordCount;
end;

function TDAOQueryADO<T>.ExecuteQuery(const aQuery: string): Boolean;
begin
  fQuery.SQL.Text := aQuery;
  fQuery.ExecSQL;
  fHasResults := False;
  Result := fQuery.RowsAffected > 0;
end;

function TDAOQueryADO<T>.GetFieldValue(const aName: string): Variant;
begin
  Result := fQuery.FieldByName(aName).AsVariant;
end;

function TDAOQueryADO<T>.CountResults: Integer;
begin
  Result := fQuery.RecordCount;
end;

function TDAOQueryADO<T>.GetCurrent: T;
begin
  if fQuery.Eof then Exit(nil);
  Result := fModel.Table.Create as T;
  Self.FillRecordFromDB(Result);
end;

function TDAOQueryADO<T>.MoveNext: Boolean;
begin
  if not fFirstIteration then fQuery.Next;
  fFirstIteration := False;
  Result := not fQuery.Eof;
end;

initialization
  if (IsConsole) or (IsService) then CoInitialize(nil);

finalization
  if (IsConsole) or (IsService) then CoUninitialize;



end.
