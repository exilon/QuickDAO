{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.DAO.Query
  Description : DAODatabase Query
  Author      : Kike Pérez
  Version     : 1.1
  Created     : 31/08/2018
  Modified    : 19/02/2020

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

unit Quick.DAO.Query;

{$i QuickDAO.inc}

interface

uses
  Classes,
  RTTI,
  {$IFNDEF FPC}
  System.SysUtils,
  System.TypInfo,
  Json,
  System.Variants,
  System.Generics.Collections,
  System.Generics.Defaults,
  {$ELSE}
  SysUtils,
  TypInfo,
  Generics.Collections,
  Generics.Defaults,
  Variants,
  Quick.Json.fpc.Compatibility,
  Quick.Rtti.fpc.Compatibility,
  {$ENDIF}
  Quick.Commons,
  Quick.Json.Serializer,
  Quick.DAO,
  Quick.DAO.Database;

type

  TDAOQuery<T : class, constructor>  = class(TInterfacedObject,IDAOQuery<T>,IDAOLinqQuery<T>)
  private
    fWhereClause : string;
    fOrderClause : string;
    fOrderAsc : Boolean;
    fSelectedFields : TArray<string>;
    function FormatParams(const aWhereClause : string; aWhereParams : array of const) : string;
  protected
    fDAODataBase : TDAODataBase;
    fModel : TDAOModel;
    fQueryGenerator : IDAOQueryGenerator;
    fHasResults : Boolean;
    fFirstIteration : Boolean;
    function MoveNext : Boolean; virtual; abstract;
    function GetCurrent : T; virtual; abstract;
    function GetFieldValue(const aName : string) : Variant; virtual; abstract;
    function GetFieldValues(aDAORecord : TDAORecord; aExcludeAutoIDFields : Boolean)  : TStringList;
    procedure FillRecordFromDB(aDAORecord : T);
    function GetDBFieldValue(const aFieldName : string; aValue : TValue): TValue;
    function GetFieldsPairs(aDAORecord : TDAORecord): string; overload;
    function GetFieldsPairs(const aFieldNames : string; aFieldValues : array of const): string; overload;
    function GetRecordValue(const aFieldName : string; aValue : TValue) : string;
    function GetModel : TDAOModel;
    function OpenQuery(const aQuery : string) : Integer; virtual; abstract;
    function ExecuteQuery(const aQuery : string) : Boolean; virtual; abstract;
  public
    constructor Create(aDAODataBase : TDAODataBase; aModel : TDAOModel; aQueryGenerator : IDAOQueryGenerator); virtual;
    property Model : TDAOModel read fModel write fModel;
    property HasResults : Boolean read fHasResults write fHasResults;
    function Eof : Boolean; virtual; abstract;
    function AddOrUpdate(aDAORecord : TDAORecord) : Boolean; virtual;
    function Add(aDAORecord : TDAORecord) : Boolean; virtual;
    function CountResults : Integer; virtual; abstract;
    function Update(aDAORecord : TDAORecord) : Boolean; overload; virtual;
    function Delete(aDAORecord : TDAORecord) : Boolean; overload; virtual;
    function Delete(const aWhere : string) : Boolean; overload; virtual;
    //LINQ queries
    function Where(const aFormatSQLWhere: string; const aValuesSQLWhere: array of const) : IDAOLinqQuery<T>;
    function SelectFirst : T;
    function SelectLast : T;
    function Select : IDAOResult<T>; overload;
    function Select(const aFieldNames : string) : IDAOResult<T>; overload;
    function SelectTop(aNumber : Integer) : IDAOResult<T>;
    function Sum(const aFieldName : string) : Int64;
    function Count : Int64;
    function Update(const aFieldNames : string; const aFieldValues : array of const) : Boolean; overload;
    function Delete : Boolean; overload;
    function OrderBy(const aFieldValues : string) : IDAOLinqQuery<T>;
    function OrderByDescending(const aFieldValues : string) : IDAOLinqQuery<T>;
  end;

implementation

{ TDAOQuery }

constructor TDAOQuery<T>.Create(aDAODataBase : TDAODataBase; aModel : TDAOModel; aQueryGenerator : IDAOQueryGenerator);
begin
  fFirstIteration := True;
  fDAODataBase := aDAODataBase;
  fModel := aModel;
  fWhereClause := '1=1';
  fSelectedFields := [];
  fQueryGenerator := aQueryGenerator;
  fHasResults := False;
end;

function TDAOQuery<T>.GetFieldValues(aDAORecord : TDAORecord; aExcludeAutoIDFields : Boolean) : TStringList;
var
  ctx: TRttiContext;
  {$IFNDEF FPC}
  attr : TCustomAttribute;
  {$ENDIF}
  rType: TRttiType;
  rProp: TRttiProperty;
  propertyname : string;
  propvalue : TValue;
  skip : Boolean;
begin
  Result := TStringList.Create;
  Result.Delimiter := ',';
  Result.StrictDelimiter := True;
  try
    rType := ctx.GetType(aDAORecord.ClassInfo);
    try
      for rProp in rType.GetProperties do
      begin
        propertyname := rProp.Name;
        if IsPublishedProp(aDAORecord,propertyname) then
        begin
          {$IFNDEF FPC}
          for attr in rProp.GetAttributes do
          begin
            if attr is TMapField then propertyname := TMapField(attr).Name;
          end;
          {$ENDIF}
          skip := False;
          propvalue := rProp.GetValue(aDAORecord);
          if CompareText(rProp.Name,fModel.PrimaryKey) = 0 then
          begin
            if not aExcludeAutoIDFields then
            begin
              if (rProp.PropertyType.Name = 'TAutoID') and ((propvalue.IsEmpty) or (propvalue.AsInt64 = 0)) then skip := True;
            end
            else skip := True;
          end;
          if not skip then Result.Add(GetRecordValue(propertyname,propvalue));
        end;
      end;
    finally
      ctx.Free;
    end;
  except
    on E : Exception do
    begin
      raise Exception.CreateFmt('Error getting field values "%s" : %s',[Self.ClassName,e.Message]);
    end;
  end;
end;

function TDAOQuery<T>.GetModel: TDAOModel;
begin
  Result := fModel;
end;

function TDAOQuery<T>.GetRecordValue(const aFieldName: string; aValue: TValue): string;
var
  rttijson : TRTTIJson;
  jpair : TJsonPair;
  //a : TTypeKind;
begin
  //a := aValue.Kind;
  case aValue.Kind of
    tkDynArray :
      begin
        rttijson := TRTTIJson.Create(TSerializeLevel.slPublishedProperty);
        try
          jpair := rttijson.Serialize(aFieldName,aValue);
          try
            {$IFNDEF FPC}
            Result := QuotedStr(jpair.JsonValue.ToJson);
            {$ELSE}
            Result := QuotedStr(jpair.JsonValue.AsJson);
            {$ENDIF}
          finally
            jpair.Free;
          end;
        finally
          rttijson.Free;
        end;
      end;
    tkString, tkLString, tkWString, tkUString{$IFDEF FPC}, tkAnsiString{$ENDIF} : Result := QuotedStr(aValue.AsString);
    tkInteger : Result := aValue.AsInteger.ToString;
    tkInt64 : Result := aValue.AsInt64.ToString;
    {$IFDEF FPC}
    tkBool : Result := aValue.AsBoolean.ToString;
    {$ENDIF}
    tkFloat :
      begin
        if aValue.TypeInfo = TypeInfo(TDateTime) then
        begin
          Result := QuotedStr(fQueryGenerator.DateTimeToDBField(aValue.AsExtended));
        end
        else if aValue.TypeInfo = TypeInfo(TDate) then
        begin
          Result := QuotedStr(aValue.AsExtended.ToString);
        end
        else if aValue.TypeInfo = TypeInfo(TTime) then
        begin
          Result := QuotedStr(aValue.AsExtended.ToString);
        end
        else Result := StringReplace(string(aValue.AsVariant),',','.',[]);
      end;
    tkEnumeration :
      begin
        if (aValue.TypeInfo = System.TypeInfo(Boolean)) then
        begin
          if CompareText(string(aValue.AsVariant),'true') = 0 then Result := '1'
            else Result := '0';
        end
        else
        begin
          //value := value;
        end;
      end;
    tkRecord, tkClass :
      begin
        rttijson := TRTTIJson.Create(TSerializeLevel.slPublishedProperty);
        try
          jpair := rttijson.Serialize(aFieldName,aValue);
          try
            Result := QuotedStr(jpair.{$IFNDEF FPC}ToJSON{$ELSE}JsonString{$ENDIF});
          finally
            jpair.Free;
          end;
        finally
          rttijson.Free;
        end;
      end;
    else Result := 'null';
  end;
end;

function TDAOQuery<T>.GetFieldsPairs(aDAORecord : TDAORecord): string;
var
  ctx: TRttiContext;
  {$IFNDEF FPC}
  attr : TCustomAttribute;
  {$ENDIF}
  rType: TRttiType;
  rProp: TRttiProperty;
  propertyname : string;
  propvalue : TValue;
  value : string;
begin
  Result := '';
  try
    rType := ctx.GetType(fModel.Table);
    try
      for rProp in rType.GetProperties do
      begin
        propertyname := rProp.Name;
        if IsPublishedProp(aDAORecord,propertyname) then
        begin
          {$IFNDEF FPC}
          for attr in rProp.GetAttributes do
          begin
            if  attr is TMapField then propertyname := TMapField(attr).Name;
          end;
          {$ENDIF}
          propvalue := rProp.GetValue(aDAORecord);
          value := GetRecordValue(propertyname,propvalue);
          if not ((CompareText(propertyname,fModel.PrimaryKey) = 0) and (rProp.PropertyType.Name = 'TAutoID')) then Result := Result + Format('[%s]=%s,',[propertyname,value]);
          //rProp.SetValue(Self,GetDBFieldValue(propertyname,rProp.GetValue(Self)));
        end;
      end;
      Result := RemoveLastChar(Result);
    finally
      ctx.Free;
    end;
  except
    on E : Exception do
    begin
      raise Exception.CreateFmt('Error getting fields "%s" : %s',[aDAORecord.ClassName,e.Message]);
    end;
  end;
end;

function TDAOQuery<T>.GetFieldsPairs(const aFieldNames : string; aFieldValues : array of const): string;
var
  fieldname : string;
  value : string;
  i : Integer;
begin
  i := 0;
  for fieldname in aFieldNames do
  begin
    case aFieldValues[i].VType of
      vtInteger : value := IntToStr(aFieldValues[i].VInteger);
      vtInt64 : value := IntToStr(aFieldValues[i].VInt64^);
      vtExtended : value := FloatToStr(aFieldValues[i].VExtended^);
      vtBoolean : value := BoolToStr(aFieldValues[i].VBoolean);
      vtWideString : value := DbQuotedStr(string(aFieldValues[i].VWideString^));
      {$IFNDEF NEXTGEN}
      vtAnsiString : value := DbQuotedStr(AnsiString(aFieldValues[i].VAnsiString));
      vtString : value := DbQuotedStr(aFieldValues[i].VString^);
      {$ENDIF}
      vtChar : value := DbQuotedStr(aFieldValues[i].VChar);
      vtPChar : value := string(aFieldValues[i].VPChar).QuotedString;
    else value := DbQuotedStr(string(aFieldValues[i].VUnicodeString));
    end;
    Result := Result + fieldname + '=' + value + ',';
    Inc(i);
  end;
  RemoveLastChar(Result);
end;

procedure TDAOQuery<T>.FillRecordFromDB(aDAORecord : T);
var
  ctx: TRttiContext;
  {$IFNDEF FPC}
  attr : TCustomAttribute;
  {$ENDIF}
  rType: TRttiType;
  rProp: TRttiProperty;
  propertyname : string;
  rvalue : TValue;
  dbfield : TDBField;
  IsFilterSelect : Boolean;
  skip : Boolean;
begin
  try
    IsFilterSelect := not IsEmptyArray(fSelectedFields);
    rType := ctx.GetType(fModel.Table);
    try
      for rProp in rType.GetProperties do
      begin
        propertyname := rProp.Name;
        if IsPublishedProp(aDAORecord,propertyname) then
        begin
          {$IFNDEF FPC}
          for attr in rProp.GetAttributes do
          begin
            if  attr is TMapField then propertyname := TMapField(attr).Name;
          end;
          {$ENDIF}
          skip := False;
          if (IsFilterSelect) and (not StrInArray(propertyname,fSelectedFields)) then skip := True;
          if not skip then rvalue := GetDBFieldValue(propertyname,rProp.GetValue(TDAORecord(aDAORecord)))
            else rvalue := nil;
          if CompareText(propertyname,fModel.PrimaryKey) = 0 then
          begin
            if not rvalue.IsEmpty then
            begin
              dbfield.FieldName := fModel.PrimaryKey;
              dbfield.Value := rValue.AsVariant;
              TDAORecord(aDAORecord).PrimaryKey := dbfield;
            end;
          end;
          if not rvalue.IsEmpty then rProp.SetValue(TDAORecord(aDAORecord),rvalue);
        end;
      end;
    finally
      ctx.Free;
    end;
  except
    on E : Exception do
    begin
      raise Exception.CreateFmt('Error filling record "%s" field : %s',[fModel.TableName,e.Message]);
    end;
  end;
end;

function TDAOQuery<T>.GetDBFieldValue(const aFieldName : string; aValue : TValue): TValue;
var
  IsNull : Boolean;
  fieldvalue : variant;
  rttijson : TRTTIJson;
  json : TJsonObject;
  jArray : TJSONArray;
  //a : TTypeKind;
begin
  fieldvalue := GetFieldValue(aFieldName);
  IsNull := IsEmptyOrNull(fieldvalue);
  //a := aValue.Kind;
  try
    case aValue.Kind of
      tkDynArray :
        begin
          if IsNull then Exit(nil);
          rttijson := TRTTIJson.Create(TSerializeLevel.slPublishedProperty);
          try
            jArray := TJSONObject.ParseJSONValue(fieldvalue) as TJSONArray;
            try
              {$IFNDEF FPC}
              Result := rttijson.DeserializeDynArray(aValue.TypeInfo,Self,jArray);
              {$ELSE}
              rttijson.DeserializeDynArray(aValue.TypeInfo,aFieldName,aValue.AsObject,jArray);
              {$ENDIF}
            finally
              jArray.Free;
            end;
          finally
            rttijson.Free;
          end;
        end;
      tkClass :
        begin
          if IsNull then Exit(nil);
          rttijson := TRTTIJson.Create(TSerializeLevel.slPublishedProperty);
          try
            json := TJSONObject.ParseJSONValue('{'+fieldvalue+'}') as TJSONObject;
            try
              Result := rttijson.DeserializeObject(Self,json.GetValue(aFieldName) as TJSONObject);
            finally
              json.Free;
            end;
          finally
            rttijson.Free;
          end;
        end;
      tkString, tkLString, tkWString, tkUString{$IFDEF FPC}, tkAnsiString{$ENDIF} :
        begin
          if not IsNull then Result := string(fieldvalue)
            else Result := '';
        end;
      tkChar, tkWChar :
        begin
          if not IsNull then Result := string(fieldvalue)
            else Result := '';
        end;
      tkInteger :
        begin
          if not IsNull then Result := Integer(fieldvalue)
            else Result := 0;
        end;
      tkInt64 :
        begin
          if not IsNull then Result := Int64(fieldvalue)
            else Result := 0;
        end;
      {$IFDEF FPC}
      tkBool :
        begin
          if not IsNull then Result := Boolean(fieldvalue)
            else Result := False;
        end;
      {$ENDIF}
      tkFloat :
        begin
          if aValue.TypeInfo = TypeInfo(TDateTime) then
          begin
            if not IsNull then
            begin
              {$IFNDEF FPC}
              if not Self.ClassName.StartsWith('TDAOQueryFireDAC') then Result := fQueryGenerator.DBFieldToDateTime(fieldvalue)
              {$ELSE}
              if not string(Self.ClassName).StartsWith('TDAOQueryFireDAC') then Result := fQueryGenerator.DBFieldToDateTime(fieldvalue)
              {$ENDIF}
                else Result := StrToDateTime(fieldvalue);
            end
            else Result := 0;
          end
          else if aValue.TypeInfo = TypeInfo(TDate) then
          begin
            if not IsNull then Result := {$IFNDEF FPC}TDate{$ELSE}VarToDateTime{$ENDIF}(fieldvalue)
              else Result := 0;
          end
          else if aValue.TypeInfo = TypeInfo(TTime) then
          begin
            if not IsNull then Result := {$IFNDEF FPC}TTime{$ELSE}VarToDateTime{$ENDIF}(fieldvalue)
              else Result := 0;
          end
          else if not IsNull then Result := Extended(fieldvalue)
            else Result := 0;
        end;
      tkEnumeration :
        begin
          if (aValue.TypeInfo = System.TypeInfo(Boolean)) then
          begin
            if not IsNull then Result := Boolean(fieldvalue)
              else Result := False;
          end
          else
          begin
            if not IsNull then TValue.Make({$IFDEF FPC}@{$ENDIF}fieldvalue,aValue.TypeInfo,Result)
              else TValue.Make(0,aValue.TypeInfo, Result);
          end;
        end;
      tkSet :
        begin
          //Result.JsonValue := TJSONString.Create(aValue.ToString);
        end;
      tkRecord :
        begin
          if IsNull then Exit(nil);
          {$IFNDEF FPC}
          rttijson := TRTTIJson.Create(TSerializeLevel.slPublishedProperty);
          try
            json := TJSONObject.ParseJSONValue('{'+fieldvalue+'}') as TJSONObject;
            try
              Result := rttijson.DeserializeRecord(aValue,Self,json.GetValue(aFieldName) as TJSONObject);
            finally
              json.Free;
            end;
          finally
            rttijson.Free;
          end;
          {$ENDIF}
        end;
      tkMethod, tkPointer, tkClassRef ,tkInterface, tkProcedure :
        begin
          //skip these properties
        end
    else
      begin
        {$IFNDEF FPC}
        raise Exception.Create(Format('Error %s %s',[aFieldName,GetTypeName(aValue.TypeInfo)]));
        {$ELSE}
        Exit(nil);
        raise Exception.CreateFmt('Error getting DB field "%s"',[aFieldName]);
        {$ENDIF}
      end;
    end;
  except
    on E : Exception do
    begin
      if aValue.Kind = tkClass then raise Exception.CreateFmt('Serialize error class "%s.%s" : %s',[aFieldName,aValue.ToString,e.Message])
        else raise Exception.CreateFmt('Serialize error property "%s=%s" : %s',[aFieldName,aValue.ToString,e.Message]);
    end;
  end;
end;

function TDAOQuery<T>.Add(aDAORecord: TDAORecord): Boolean;
var
  sqlfields : TStringList;
  sqlvalues : TStringList;
begin
  try
    sqlfields := fModel.GetFieldNames(aDAORecord,False);
    try
      sqlvalues := GetFieldValues(aDAORecord,False);
      try
        Result := ExecuteQuery(fQueryGenerator.Add(fModel.TableName,sqlfields.CommaText,CommaText(sqlvalues)));
      finally
        sqlvalues.Free;
      end;
    finally
      sqlfields.Free;
    end;
  except
    on E : Exception do raise EDAOCreationError.CreateFmt('Insert error: %s',[e.message]);
  end;
end;

function TDAOQuery<T>.AddOrUpdate(aDAORecord: TDAORecord): Boolean;
var
  sqlfields : TStringList;
  sqlvalues : TStringList;
begin
  Result := False;
  try
    if fQueryGenerator.Name = 'MSSQL' then
    begin
      if (aDAORecord.PrimaryKey.FieldName = '') or (VarIsEmpty(aDAORecord.PrimaryKey.Value))
        or (Where(Format('%s = ?',[aDAORecord.PrimaryKey.FieldName]),[aDAORecord.PrimaryKey.Value]).Count = 0) then
      begin
        Add(aDAORecord);
      end
      else
      begin
        Update(aDAORecord);
      end;
    end
    else
    begin
      sqlfields := fModel.GetFieldNames(aDAORecord,False);
      try
        sqlvalues := GetFieldValues(aDAORecord,False);
        try
          Result := ExecuteQuery(fQueryGenerator.AddOrUpdate(fModel.TableName,sqlfields.CommaText,CommaText(sqlvalues)));
        finally
          sqlvalues.Free;
        end;
      finally
        sqlfields.Free;
      end;
    end;
  except
    on E : Exception do raise EDAOCreationError.CreateFmt('AddOrUpdate error: %s',[e.message]);
  end;
end;


function TDAOQuery<T>.Delete(aDAORecord : TDAORecord): Boolean;
begin
  try
    Result := ExecuteQuery(fQueryGenerator.Delete(fModel.TableName,Format('%s=%s',[aDAORecord.PrimaryKey.FieldName,aDAORecord.PrimaryKey.Value])));
  except
    on E : Exception do raise EDAODeleteError.CreateFmt('Delete error: %s',[e.message]);
  end;
end;

function TDAOQuery<T>.Delete(const aWhere: string): Boolean;
begin
  try
    Result := ExecuteQuery(fQueryGenerator.Delete(fModel.TableName,aWhere));
  except
    on E : Exception do raise EDAODeleteError.CreateFmt('Delete error: %s',[e.message]);
  end;
end;

{ LINQ queries }

function TDAOQuery<T>.Count: Int64;
begin
  try
    if OpenQuery(fQueryGenerator.Count(fModel.TableName,fWhereClause)) > 0 then Result := GetFieldValue('cnt')
      else Result := 0;
    HasResults := False;
  except
    on E : Exception do raise EDAOSelectError.CreateFmt('Select count error: %s',[e.message]);
  end;
end;

function TDAOQuery<T>.FormatParams(const aWhereClause: string; aWhereParams: array of const): string;
var
  i : Integer;
  value : string;
  vari : variant;
begin
  Result := aWhereClause;
  if aWhereClause = '' then
  begin
    Result := '1 = 1';
    Exit;
  end;
  for i := 0 to aWhereClause.CountChar('?') - 1 do
  begin
    case aWhereParams[i].VType of
      vtInteger : value := IntToStr(aWhereParams[i].VInteger);
      vtInt64 : value := IntToStr(aWhereParams[i].VInt64^);
      vtExtended : value := FloatToStr(aWhereParams[i].VExtended^);
      vtBoolean : value := BoolToStr(aWhereParams[i].VBoolean);
      vtWideString : value := fQueryGenerator.QuotedStr(string(aWhereParams[i].VWideString^));
      {$IFNDEF NEXTGEN}
      vtAnsiString : value := fQueryGenerator.QuotedStr(AnsiString(aWhereParams[i].VAnsiString));
      vtString : value := fQueryGenerator.QuotedStr(aWhereParams[i].VString^);
      {$ENDIF}
      vtChar : value := fQueryGenerator.QuotedStr(aWhereParams[i].VChar);
      vtPChar : value := fQueryGenerator.QuotedStr(string(aWhereParams[i].VPChar));
      vtVariant :
      begin
        vari := aWhereParams[i].VVariant^;
        case VarType(vari) of
          varInteger,varInt64 : value := IntToStr(vari);
          varDouble : value := FloatToStr(vari);
          varDate : value := DateTimeToSQL(vari);
          else value := string(vari);
        end;
      end
    else value := fQueryGenerator.QuotedStr(string(aWhereParams[i].VUnicodeString));
    end;
    Result := StringReplace(Result,'?',value,[]);
  end;
end;

function TDAOQuery<T>.OrderBy(const aFieldValues: string): IDAOLinqQuery<T>;
begin
  Result := Self;
  fOrderClause := aFieldValues;
  fOrderAsc := True;
end;

function TDAOQuery<T>.OrderByDescending(const aFieldValues: string): IDAOLinqQuery<T>;
begin
  Result := Self;
  fOrderClause := aFieldValues;
  fOrderAsc := False;
end;

function TDAOQuery<T>.Select: IDAOResult<T>;
var
  query : string;
begin
  try
    query := fQueryGenerator.Select(fModel.TableName,'',0,fWhereClause,fOrderClause,fOrderAsc);
    OpenQuery(query);
    Result := TDAOResult<T>.Create(Self);
  except
    on E : Exception do raise EDAOSelectError.CreateFmt('Select error: %s',[e.message]);
  end;
end;

function TDAOQuery<T>.Select(const aFieldNames: string): IDAOResult<T>;
var
  query : string;
  filter : string;
begin
  try
    for filter in aFieldNames.Split([',']) do fSelectedFields := fSelectedFields + [filter];
    query := fQueryGenerator.Select(fModel.TableName,aFieldNames,0,fWhereClause,fOrderClause,fOrderAsc);
    OpenQuery(query);
    Result := TDAOResult<T>.Create(Self);
  except
    on E : Exception do raise EDAOSelectError.CreateFmt('Select error: %s',[e.message]);
  end;
end;

function TDAOQuery<T>.SelectFirst: T;
var
  query : string;
begin
  try
    query := fQueryGenerator.Select(fModel.TableName,'',1,fWhereClause,fOrderClause,fOrderAsc);
    OpenQuery(query);
    Self.Movenext;
    Result := Self.GetCurrent;
  except
    on E : Exception do raise EDAOSelectError.CreateFmt('Select error: %s',[e.message]);
  end;
end;

function TDAOQuery<T>.SelectLast: T;
var
  query : string;
begin
  try
    query := fQueryGenerator.Select(fModel.TableName,'',1,fWhereClause,fOrderClause,not fOrderAsc);
    OpenQuery(query);
    Self.Movenext;
    Result := Self.GetCurrent;
  except
    on E : Exception do raise EDAOSelectError.CreateFmt('Select error: %s',[e.message]);
  end;
end;

function TDAOQuery<T>.SelectTop(aNumber: Integer): IDAOResult<T>;
var
  query : string;
begin
  try
    query := fQueryGenerator.Select(fModel.TableName,'',aNumber,fWhereClause,fOrderClause,fOrderAsc);
    OpenQuery(query);
    Result := TDAOResult<T>.Create(Self);
  except
    on E : Exception do raise EDAOSelectError.CreateFmt('Select error: %s',[e.message]);
  end;
end;

function TDAOQuery<T>.Sum(const aFieldName: string): Int64;
var
  query : string;
begin
  try
    query := fQueryGenerator.Sum(fModel.TableName,aFieldName,fWhereClause);
    if OpenQuery(query) > 0 then Result := GetFieldValue('cnt')
  except
    on E : Exception do raise EDAOSelectError.CreateFmt('Select error: %s',[e.message]);
  end;
end;

function TDAOQuery<T>.Update(aDAORecord: TDAORecord): Boolean;
begin
  try
    Result := ExecuteQuery(fQueryGenerator.Update(fModel.TableName,GetFieldsPairs(aDAORecord),
                           Format('%s=%s',[aDAORecord.PrimaryKey.FieldName,aDAORecord.PrimaryKey.Value])));
  except
    on E : Exception do raise EDAOUpdateError.CreateFmt('Update error: %s',[e.message]);
  end;
end;

function TDAOQuery<T>.Update(const aFieldNames: string; const aFieldValues: array of const): Boolean;
begin
  try
    Result := ExecuteQuery(fQueryGenerator.Update(fModel.TableName,GetFieldsPairs(aFieldNames,aFieldValues),fWhereClause));
  except
    on E : Exception do raise EDAOUpdateError.CreateFmt('Update error: %s',[e.message]);
  end;
end;

function TDAOQuery<T>.Where(const aFormatSQLWhere: string; const aValuesSQLWhere: array of const): IDAOLinqQuery<T>;
begin
  Result := Self;
  fWhereClause := FormatParams(aFormatSQLWhere,aValuesSQLWhere);
end;

function TDAOQuery<T>.Delete: Boolean;
begin
  try
    Result := ExecuteQuery(fQueryGenerator.Delete(fModel.TableName,fWhereClause));
  except
    on E : Exception do raise EDAOUpdateError.CreateFmt('Delete error: %s',[e.message]);
  end;
end;

end.
