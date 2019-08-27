{ ***************************************************************************

  Copyright (c) 2016-2019 Kike Pérez

  Unit        : Quick.DAO.QueryGenerator
  Description : DAODatabase ADO Provider
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 22/06/2018
  Modified    : 02/07/2019

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

unit Quick.DAO.Factory.QueryGenerator;

{$i QuickDAO.inc}

interface

uses
  Quick.DAO,
  Quick.DAO.QueryGenerator.MSSQL,
  Quick.DAO.QueryGenerator.MSAccess,
  Quick.DAO.QueryGenerator.SQLite,
  Quick.DAO.QueryGenerator.MySQL;

type

  TDAOQueryGeneratorFactory = class
  public
    class function Create(aDBProvider : TDBProvider) : IDAOQueryGenerator;
  end;

implementation

{ TDAOQueryGeneratorFactory }

class function TDAOQueryGeneratorFactory.Create(aDBProvider : TDBProvider) : IDAOQueryGenerator;
begin
  case aDBProvider of
    TDBProvider.daoMSAccess2000 : Result := TMSAccessQueryGenerator.Create;
    TDBProvider.daoMSAccess2007 : Result := TMSAccessQueryGenerator.Create;
    TDBProvider.daoMSSQL : Result := TMSSQLQueryGenerator.Create;
    TDBProvider.daoMySQL : Result := TMySQLQueryGenerator.Create;
    TDBProvider.daoSQLite : Result := TSQLiteQueryGenerator.Create;
    //TDAODBType.daoFirebase : Result := TFireBaseQueryGenerator.Create;
  end;
end;

end.
