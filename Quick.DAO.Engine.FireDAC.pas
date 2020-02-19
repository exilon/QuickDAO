{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.DAO.Engine.FireDAC
  Description : DAODatabase FireDAC Provider
  Author      : Kike Pérez
  Version     : 1.1
  Created     : 31/08/2018
  Modified    : 12/01/2020

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

 unit Quick.DAO.Engine.FireDAC;

{$i QuickDAO.inc}

interface

uses
  Classes,
  System.SysUtils,
  //Winapi.ActiveX,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  FireDAC.Phys,
  FireDAC.Phys.Intf,
  FireDAC.Phys.SQLite,
  {$IFDEF FPC}
  only Delphi/Firemonkey compatible
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  FireDAC.Phys.MSAcc,
  {$ENDIF}
  //FireDAC.Phys.MSSQL,
  {$IFDEF CONSOLE}
    FireDAC.ConsoleUI.Wait,
  {$ELSE}
    FireDAC.UI.Intf,
    {$IFDEF VCL}
    FireDAC.VCLUI.Wait,
    {$ELSE}
    FireDAC.FMXUI.Wait,
    {$ENDIF}
    FireDAC.Comp.UI,
  {$ENDIF}
  Quick.Commons,
  Quick.DAO,
  Quick.DAO.Database,
  Quick.DAO.Query;

type

  TDAODataBaseFireDAC = class(TDAODatabase)
  private
    fFireDACConnection : TFDConnection;
    fInternalQuery : TFDQuery;
    function GetDriverID(aDBProvider : TDBProvider) : string;
  protected
    function CreateConnectionString: string; override;
    procedure ExecuteSQLQuery(const aQueryText : string); override;
    procedure OpenSQLQuery(const aQueryText: string); override;
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

  TDAOQueryFireDAC<T : class, constructor> = class(TDAOQuery<T>)
  private
    fConnection : TDBConnectionSettings;
    fQuery : TFDQuery;
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

{$IFNDEF CONSOLE}
var
  FDGUIxWaitCursor : TFDGUIxWaitCursor;
{$ENDIF}

implementation

{ TDAODataBaseADO }

constructor TDAODataBaseFireDAC.Create;
begin
  inherited;
  fFireDACConnection := TFDConnection.Create(nil);
  fInternalQuery := TFDQuery.Create(nil);
end;

function TDAODataBaseFireDAC.Connect: Boolean;
begin
  //creates connection string based on parameters of connection property
  inherited;
  fFireDACConnection.ConnectionString := CreateConnectionString;
  fFireDACConnection.Connected := True;
  fInternalQuery.Connection := fFireDACConnection;
  Result := IsConnected;
  CreateTables;
  CreateIndexes;
end;

function TDAODataBaseFireDAC.CreateConnectionString: string;
begin
  if Connection.IsCustomConnectionString then Result := Format('DriverID=%s;%s',[GetDriverID(Connection.Provider),Connection.GetCustomConnectionString])
  else
  begin
    Result := Format('DriverID=%s;User_Name=%s;Password=%s;Database=%s;Server=%s',[
                              GetDriverID(Connection.Provider),
                              Connection.UserName,
                              Connection.Password,
                              Connection.Database,
                              Connection.Server]);
  end;
end;

function TDAODataBaseFireDAC.CreateQuery(aModel: TDAOModel): IDAOQuery<TDAORecord>;
begin
  Result := TDAOQueryFireDAC<TDAORecord>.Create(Self,aModel,QueryGenerator);
end;

destructor TDAODataBaseFireDAC.Destroy;
begin
  if Assigned(fInternalQuery) then fInternalQuery.Free;
  if fFireDACConnection.Connected then fFireDACConnection.Connected := False;
  fFireDACConnection.Free;
  inherited;
end;

procedure TDAODataBaseFireDAC.ExecuteSQLQuery(const aQueryText: string);
begin
  fInternalQuery.SQL.Text := aQueryText;
  fInternalQuery.ExecSQL;
end;

procedure TDAODataBaseFireDAC.OpenSQLQuery(const aQueryText: string);
begin
  fInternalQuery.SQL.Text := aQueryText;
  fInternalQuery.Open;
end;

function TDAODataBaseFireDAC.ExistsColumn(aModel: TDAOModel; const aFieldName: string): Boolean;
begin
  Result := False;
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

function TDAODataBaseFireDAC.ExistsTable(aModel: TDAOModel): Boolean;
begin
  Result := False;
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

function TDAODataBaseFireDAC.From<T>: IDAOLinqQuery<T>;
var
  daoclass : TDAORecordclass;
begin
  daoclass := TDAORecordClass(Pointer(T));
  Result := TDAOQueryFireDAC<T>.Create(Self,Models.Get(daoclass),QueryGenerator);
end;

function TDAODataBaseFireDAC.GetDriverID(aDBProvider: TDBProvider): string;
begin
  case aDBProvider of
    TDBProvider.daoMSAccess2007 : Result := 'MSAcc';
    TDBProvider.daoMSSQL : Result := 'MSSQL';
    TDBProvider.daoMySQL : Result := 'MySQL';
    TDBProvider.daoSQLite : Result := 'SQLite';
    else raise Exception.Create('Unknow DBProvider or not supported by this engine');
  end;
end;

function TDAODataBaseFireDAC.GetFieldNames(const aTableName: string): TArray<string>;
var
  sl : TStrings;
begin
  sl := TStringList.Create;
  try
    fInternalQuery.Connection.GetFieldNames('','',aTableName,'',sl);
    Result := StringsToArray(sl);
  finally
    sl.Free;
  end;
end;

function TDAODataBaseFireDAC.GetTableNames: TArray<string>;
var
  sl : TStrings;
begin
  sl := TStringList.Create;
  try
    fInternalQuery.Connection.GetTableNames(Connection.Database,'dbo','',sl,[osMy],[tkTable],True);
    Result := StringsToArray(sl);
  finally
    sl.Free;
  end;
end;

function TDAODataBaseFireDAC.IsConnected: Boolean;
begin
  Result := fFireDACConnection.Connected;
end;

{ TDAOQueryFireDAC<T> }

function TDAOQueryFireDAC<T>.CountResults: Integer;
begin
  Result := fQuery.RecordCount;
end;

constructor TDAOQueryFireDAC<T>.Create(aDAODataBase : TDAODataBase; aModel : TDAOModel; aQueryGenerator : IDAOQueryGenerator);
begin
  inherited;
  fQuery := TFDQuery.Create(nil);
  fQuery.Connection := TDAODataBaseFireDAC(aDAODataBase).fFireDACConnection;
  fConnection := aDAODataBase.Connection;
end;

destructor TDAOQueryFireDAC<T>.Destroy;
begin
  if Assigned(fQuery) then fQuery.Free;
  inherited;
end;

function TDAOQueryFireDAC<T>.Eof: Boolean;
begin
  Result := fQuery.Eof;
end;

function TDAOQueryFireDAC<T>.OpenQuery(const aQuery : string) : Integer;
begin
  fFirstIteration := True;
  fQuery.Close;
  fQuery.SQL.Text := aQuery;
  fQuery.Open;
  fHasResults := fQuery.RecordCount > 0;
  Result := fQuery.RecordCount;
end;

function TDAOQueryFireDAC<T>.ExecuteQuery(const aQuery : string) : Boolean;
begin
  fQuery.SQL.Text := aQuery;
  fQuery.ExecSQL;
  fHasResults := False;
  Result := fQuery.RowsAffected > 0;
end;

function TDAOQueryFireDAC<T>.GetFieldValue(const aName: string): Variant;
begin
  Result := fQuery.FieldByName(aName).AsVariant;
end;

function TDAOQueryFireDAC<T>.GetCurrent: T;
begin
  if fQuery.Eof then Exit(nil);
  Result := fModel.Table.Create as T;
  Self.FillRecordFromDB(Result);
end;

function TDAOQueryFireDAC<T>.MoveNext: Boolean;
begin
  if not fFirstIteration then fQuery.Next;
  fFirstIteration := False;
  Result := not fQuery.Eof;
end;

initialization
  //if (IsConsole) or (IsService) then CoInitialize(nil);
  {$IFNDEF CONSOLE}
  FDGUIxWaitCursor := TFDGUIxWaitCursor.Create(nil);
  {$ENDIF}

finalization
  //if (IsConsole) or (IsService) then CoUninitialize;
  {$IFNDEF CONSOLE}
  FDGUIxWaitCursor.Free;
  {$ENDIF}

end.
