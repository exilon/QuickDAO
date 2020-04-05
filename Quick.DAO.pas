{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.DAO
  Description : DAO Easy access
  Author      : Kike Pérez
  Version     : 1.1
  Created     : 22/06/2018
  Modified    : 31/03/2020

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

unit Quick.DAO;

{$i QuickDAO.inc}

interface

uses
  Classes,
  SysUtils,
  Rtti,
  TypInfo,
  Generics.Collections,
  Variants,
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
  Quick.RTTI.Utils,
  Quick.Commons,
  Quick.Json.Serializer;

type

  {$IFNDEF FPC}
  TMapField = class(TCustomAttribute)
  private
    fName : string;
  public
    constructor Create(const aName: string);
    property Name : string read fName;
  end;

  TFieldVARCHAR = class(TCustomAttribute)
  private
    fSize : Integer;
  public
    constructor Create(aSize : Integer);
    property Size : Integer read fSize;
  end;

  TFieldDECIMAL = class(TCustomAttribute)
  private
    fSize : Integer;
    fDecimals : Integer;
  public
    constructor Create(aSize, aDecimals : Integer);
    property Size : Integer read fSize;
    property Decimals : Integer read fdecimals;
  end;
  {$ENDIF}

  TDBProvider = (
  daoMSAccess2000 = $00010,
  daoMSAccess2007 = $00011,
  daoMSSQL        = $00020,
  daoMSSQLnc10    = $00021,
  daoMSSQLnc11    = $00022,
  daoMySQL        = $00030,
  daoSQLite       = $00040,
  daoIBM400       = $00050,
  daoFirebase     = $00060);

  TDAODataType = (dtString, dtstringMax, dtChar, dtInteger, dtAutoID, dtInt64, dtFloat, dtBoolean, dtDate, dtTime, dtDateTime, dtCreationDate, dtModifiedDate);

  EDAOModelError = class(Exception);
  EDAOCreationError = class(Exception);
  EDAOUpdateError = class(Exception);
  EDAOSelectError = class(Exception);
  EDAODeleteError = class(Exception);

  TDAORecord = class;

  TDAORecordArray = array of TDAORecord;

  TDAORecordClass = class of TDAORecord;

  TDAORecordClassArray = array of TDAORecordClass;

  TDAOIndexOrder = (orAscending, orDescending);

  TFieldNamesArray = array of string;

  TAutoID = type Int64;

  TDAOIndex = class
  private
    fTable : TDAORecordClass;
    fFieldNames : TFieldNamesArray;
    fOrder : TDAOIndexOrder;
  public
    property Table : TDAORecordClass read fTable write fTable;
    property FieldNames : TFieldNamesArray read fFieldNames write fFieldNames;
    property Order : TDAOIndexOrder read fOrder write fOrder;
  end;

  TDAOIndexes = class
  private
    fList : TObjectList<TDAOIndex>;
  public
    constructor Create;
    destructor Destroy; override;
    property List : TObjectList<TDAOIndex> read fList write fList;
    procedure Add(aTable: TDAORecordClass; aFieldNames: TFieldNamesArray; aOrder : TDAOIndexOrder);
  end;

  TDAOField = class
  private
    fName : string;
    fDataType : TDAODataType;
    fDataSize : Integer;
    fPrecision : Integer;
    fIsPrimaryKey : Boolean;
  public
    property Name : string read fName write fName;
    property DataType : TDAODataType read fDataType write fDataType;
    property DataSize : Integer read fDataSize write fDataSize;
    property Precision : Integer read fPrecision write fPrecision;
    property IsPrimaryKey : Boolean read fIsPrimaryKey write fIsPrimaryKey;
  end;

  TDAOFields = TObjectList<TDAOField>;

  TDBField = record
    FieldName : string;
    Value : variant;
  end;

  TDAOModel = class
  private
    fTable : TDAORecordClass;
    fTableName : string;
    fPrimaryKey : TDAOField;
    fFields : TDAOFields;
    fFieldsMap : TDictionary<string,TDAOField>;
    procedure GetFields;
    procedure SetTable(const Value: TDAORecordClass);
    procedure SetPrimaryKey(const Value: TDAOField);
  public
    constructor Create;
    destructor Destroy; override;
    property Table : TDAORecordClass read fTable write SetTable;
    property TableName : string read fTableName write fTableName;
    property PrimaryKey : TDAOField read fPrimaryKey write SetPrimaryKey;
    property Fields : TDAOFields read fFields;
    function GetFieldNames(aDAORecord : TDAORecord; aExcludeAutoIDFields : Boolean) : TStringList;
    function GetFieldByName(const aName : string) : TDAOField;
    function HasPrimaryKey : Boolean;
    function IsPrimaryKey(const aName : string) : Boolean;
  end;

  TDAOModels = class
  private
    fList : TObjectDictionary<TDAORecordClass,TDAOModel>;
    fPluralizeTableNames : Boolean;
    function GetTableNameFromClass(aTable : TDAORecordClass) : string;
  public
    constructor Create;
    destructor Destroy; override;
    property List : TObjectDictionary<TDAORecordClass,TDAOModel> read fList write fList;
    property PluralizeTableNames : Boolean read fPluralizeTableNames write fPluralizeTableNames;
    procedure Add(aTable: TDAORecordClass; const aPrimaryKey: string; const aTableName : string = '');
    function GetPrimaryKey(aTable : TDAORecordClass) : string;
    function Get(aTable : TDAORecordClass) : TDAOModel; overload;
    function Get(aDAORecord : TDAORecord) : TDAOModel; overload;
    procedure Clear;
  end;

  IDAOResult<T : class> = interface
  ['{0506DF8C-2749-4DB0-A0E9-44793D4E6AB7}']
    function Count : Integer;
    function HasResults : Boolean;
    function GetEnumerator: TEnumerator<T>;
    function ToList : TList<T>;
    function ToObjectList : TObjectList<T>;
    function ToArray : TArray<T>;
    function GetOne(aDAORecord : T) : Boolean;
  end;

  IDAOQuery<T> = interface
  ['{6AA202B4-CBBC-48AA-9D5A-855748D02DCC}']
    function Eof : Boolean;
    function MoveNext : Boolean;
    function GetCurrent : T;
    function GetModel : TDAOModel;
    procedure FillRecordFromDB(aDAORecord : T);
    function GetFieldValue(const aName : string) : Variant;
    function CountResults : Integer;
    function AddOrUpdate(aDAORecord : TDAORecord) : Boolean;
    function Add(aDAORecord : TDAORecord) : Boolean;
    function Update(aDAORecord : TDAORecord) : Boolean; overload;
    function Update(const aFieldNames : string; const aFieldValues : array of const) : Boolean; overload;
    function Delete(aDAORecord : TDAORecord) : Boolean; overload;
    function Delete(const aQuery : string) : Boolean; overload;
  end;

  IDAOQueryGenerator = interface
  ['{9FD0E61E-0568-49F4-A9D4-2D540BE72384}']
    function Name : string;
    function CreateTable(const aTable : TDAOModel) : string;
    function ExistsTable(aModel : TDAOModel) : string;
    function ExistsColumn(aModel : TDAOModel; const aFieldName : string) : string;
    function AddColumn(aModel : TDAOModel; aField : TDAOField) : string;
    function SetPrimaryKey(aModel : TDAOModel) : string;
    function CreateIndex(aModel : TDAOModel; aIndex : TDAOIndex) : string;
    function Select(const aTableName, aFieldNames : string; aLimit : Integer; const aWhere : string; aOrderFields : string; aOrderAsc : Boolean) : string;
    function Sum(const aTableName, aFieldName, aWhere : string) : string;
    function Count(const aTableName : string; const aWhere : string) : string;
    function Add(const aTableName: string; const aFieldNames, aFieldValues : string) : string;
    function AddOrUpdate(const aTableName: string; const aFieldNames, aFieldValues : string) : string;
    function Update(const aTableName, aFieldPairs, aWhere : string) : string;
    function Delete(const aTableName : string; const aWhere : string) : string;
    function DateTimeToDBField(aDateTime : TDateTime) : string;
    function DBFieldToDateTime(const aValue : string) : TDateTime;
    function QuotedStr(const aValue : string) : string;
  end;

  IDAOLinqQuery<T : class> = interface
  ['{5655FDD9-1D4C-4B67-81BB-7BDE2D2C860B}']
    function Where(const aFormatSQLWhere: string; const aValuesSQLWhere: array of const) : IDAOLinqQuery<T>; overload;
    function Where(const aWhereClause: string) : IDAOLinqQuery<T>; overload;
    function Select : IDAOResult<T>; overload;
    function Select(const aFieldNames : string) : IDAOResult<T>; overload;
    function SelectFirst : T;
    function SelectLast : T;
    function SelectTop(aNumber : Integer) : IDAOResult<T>;
    function Sum(const aFieldName : string) : Int64;
    function Count : Int64;
    function Update(const aFieldNames : string; const aFieldValues : array of const) : Boolean;
    function Delete : Boolean;
    function OrderBy(const aFieldValues : string) : IDAOLinqQuery<T>;
    function OrderByDescending(const aFieldValues : string) : IDAOLinqQuery<T>;
  end;

  TDAOResult<T : class, constructor> = class(TInterfacedObject,IDAOResult<T>)
  type
    TDAOEnumerator = class(TEnumerator<T>)
    private
      fDAOQuery : IDAOQuery<T>;
      fModel : TDAOModel;
    protected
      function DoGetCurrent: T; override;
      function DoMoveNext: Boolean; override;
    public
      constructor Create(aDAOQuery: IDAOQuery<T>);
    end;
  private
    fDAOQuery : IDAOQuery<T>;
  public
    constructor Create(aDAOQuery : IDAOQuery<T>);
    function GetEnumerator: TEnumerator<T>; inline;
    function GetOne(aDAORecord : T) : Boolean;
    function ToList : TList<T>;
    function ToObjectList : TObjectList<T>;
    function ToArray : TArray<T>;
    function Count : Integer;
    function HasResults : Boolean;
  end;

  TDAOQueryGenerator = class(TInterfacedObject)
    function QuotedStr(const aValue: string): string; virtual;
  end;

  TDAORecord = class
  private
    fTableName : string;
    fPrimaryKey : TDBField;
  public
    constructor Create;
    [TNotSerializableProperty]
    property PrimaryKey : TDBField read fPrimaryKey write fPrimaryKey;
  end;

  TCreationDate = type TDateTime;
  TModifiedDate = type TDateTime;

  TDAORecordTS = class(TDAORecord)
  private
    fCreationDate : TCreationDate;
    fModifiedDate : TModifiedDate;
  published
    property CreationDate : TCreationDate read fCreationDate write fCreationDate;
    property ModifiedDate : TModifiedDate read fModifiedDate write fModifiedDate;
  end;

  function QuotedStrEx(const aValue : string) : string;
  function FormatSQLParams(const aSQLClause : string; aSQLParams : array of const) : string;
  function IsEmptyOrNull(const Value: Variant): Boolean;

implementation

uses
  Quick.DAO.Factory.QueryGenerator;

function QuotedStrEx(const aValue : string) : string;
var
  sb : TStringBuilder;
begin
  sb := TStringBuilder.Create;
  try
    sb.Append('''');
    sb.Append(aValue);
    sb.Append('''');
    Result := sb.ToString(0, sb.Length - 1);
  finally
    sb.Free;
  end;
end;

function FormatSQLParams(const aSQLClause : string; aSQLParams : array of const) : string;
var
  i : Integer;
begin
  Result := aSQLClause;
  if aSQLClause = '' then
  begin
    Result := '1=1';
    Exit;
  end;
  for i := 0 to aSQLClause.CountChar('?') - 1 do
  begin
    case aSQLParams[i].VType of
      vtInteger : Result := StringReplace(Result,'?',IntToStr(aSQLParams[i].VInteger),[]);
      vtInt64 : Result := StringReplace(Result,'?',IntToStr(aSQLParams[i].VInt64^),[]);
      vtExtended : Result := StringReplace(Result,'?',FloatToStr(aSQLParams[i].VExtended^),[]);
      vtBoolean : Result := StringReplace(Result,'?',BoolToStr(aSQLParams[i].VBoolean),[]);
      vtAnsiString : Result := StringReplace(Result,'?',string(aSQLParams[i].VAnsiString),[]);
      vtWideString : Result := StringReplace(Result,'?',string(aSQLParams[i].VWideString^),[]);
      {$IFNDEF NEXTGEN}
      vtString : Result := StringReplace(Result,'?',aSQLParams[i].VString^,[]);
      {$ENDIF}
      vtChar : Result := StringReplace(Result,'?',aSQLParams[i].VChar,[]);
      vtPChar : Result := StringReplace(Result,'?',aSQLParams[i].VPChar,[]);
    else Result := StringReplace(Result,'?', QuotedStr(string(aSQLParams[i].VUnicodeString)),[]);
    end;
  end;
end;

{ TDAORecord }

constructor TDAORecord.Create;
begin
  fTableName := Copy(Self.ClassName,2,Length(Self.ClassName));
  //fPrimaryKey.FieldName := aDataBase.Models.GetPrimaryKey(TDAORecordClass(Self.ClassType));
end;

function IsEmptyOrNull(const Value: Variant): Boolean;
begin
  Result := VarIsClear(Value) or VarIsEmpty(Value) or VarIsNull(Value) or (VarCompareValue(Value, Unassigned) = vrEqual);
  if (not Result) and VarIsStr(Value) then
    Result := Value = '';
end;

{ TMapField }

{$IFNDEF FPC}
constructor TMapField.Create(const aName: string);
begin
  fName := aName;
end;
{$ENDIF}

{ TDAOIndexes }

procedure TDAOIndexes.Add(aTable: TDAORecordClass; aFieldNames: TFieldNamesArray; aOrder : TDAOIndexOrder);
var
  daoindex : TDAOIndex;
begin
  daoindex := TDAOIndex.Create;
  daoindex.Table := aTable;
  daoindex.FieldNames := aFieldNames;
  daoindex.Order := aOrder;
  fList.Add(daoindex);
end;

constructor TDAOIndexes.Create;
begin
  fList := TObjectList<TDAOIndex>.Create(True);
end;

destructor TDAOIndexes.Destroy;
begin
  fList.Free;
  inherited;
end;

{ TDAOModels }

procedure TDAOModels.Add(aTable: TDAORecordClass; const aPrimaryKey: string; const aTableName : string = '');
var
  daomodel : TDAOModel;
begin
  daomodel := TDAOModel.Create;
  daomodel.Table := aTable;
  {$IFNDEF FPC}
  if aTableName = '' then daomodel.TableName := GetTableNameFromClass(aTable)
  {$ELSE}
  if aTableName = '' then daomodel.TableName := GetTableNameFromClass(aTable)
  {$ENDIF}
    else daomodel.TableName := aTableName;
  if not aPrimaryKey.IsEmpty then daomodel.PrimaryKey := daomodel.GetFieldByName(aPrimaryKey);
  fList.Add(aTable,daomodel);
end;

procedure TDAOModels.Clear;
begin
  fList.Clear;
end;

constructor TDAOModels.Create;
begin
  fList := TObjectDictionary<TDAORecordClass,TDAOModel>.Create([doOwnsValues]);
  fPluralizeTableNames  := False;
end;

destructor TDAOModels.Destroy;
begin
  fList.Free;
  inherited;
end;

function TDAOModels.Get(aTable: TDAORecordClass): TDAOModel;
begin
  if not fList.TryGetValue(aTable,Result) then raise EDAOModelError.CreateFmt('Model "%s" not exists in database',[aTable.ClassName]);
end;

function TDAOModels.Get(aDAORecord : TDAORecord) : TDAOModel;
begin
  if aDAORecord = nil then raise EDAOModelError.Create('Model is empty');
  Result := Get(TDAORecordClass(aDAORecord.ClassType));
end;

function TDAOModels.GetPrimaryKey(aTable: TDAORecordClass): string;
begin
  Result := Get(aTable).PrimaryKey.Name;
end;

function TDAOModels.GetTableNameFromClass(aTable: TDAORecordClass): string;
begin
  Result := Copy(aTable.ClassName,2,aTable.ClassName.Length);
  if fPluralizeTableNames then Result := Result + 's';
end;

{$IFNDEF FPC}
{ TFieldVARCHAR }

constructor TFieldVARCHAR.Create(aSize: Integer);
begin
  fSize := aSize;
end;

{ TFieldDECIMAL }

constructor TFieldDECIMAL.Create(aSize, aDecimals: Integer);
begin
  fSize := aSize;
  fDecimals := aDecimals;
end;
{$ENDIF}

{ TDAOModel }

constructor TDAOModel.Create;
begin
  fFields := TObjectList<TDAOField>.Create(True);
  fFieldsMap := TDictionary<string,TDAOField>.Create;
end;

destructor TDAOModel.Destroy;
begin
  fFieldsMap.Free;
  fFields.Free;
  inherited;
end;

function TDAOModel.GetFieldByName(const aName: string): TDAOField;
begin
  if not fFieldsMap.TryGetValue(aName,Result) then raise EDAOModelError.CreateFmt('Field "%s" not found in table "%s"!',[aName,Self.TableName]);
end;

function TDAOModel.GetFieldNames(aDAORecord : TDAORecord; aExcludeAutoIDFields : Boolean) : TStringList;
var
  value : TValue;
  skip : Boolean;
  field : TDAOField;
begin
  Result := TStringList.Create;
  Result.Delimiter := ',';
  Result.StrictDelimiter := True;
  try
    for field in fFields do
    begin
      skip := False;
      if field.IsPrimaryKey then
      begin
        if (not aExcludeAutoIDFields) and (aDAORecord <> nil) then
        begin
          if field.DataType = dtAutoID then
          begin
            value := TRTTI.GetPropertyValue(aDAORecord,field.Name);
            if (value.IsEmpty) or (value.AsInt64 = 0) then skip := True;
          end;
        end
        else skip := True;
      end;
      if not skip then Result.Add(Format('[%s]',[field.Name]));
    end;
  except
    on E : Exception do
    begin
      raise Exception.CreateFmt('Error getting field names "%s" : %s',[Self.ClassName,e.Message]);
    end;
  end;
end;

procedure TDAOModel.GetFields;
var
  ctx: TRttiContext;
  {$IFNDEF FPC}
  attr : TCustomAttribute;
  {$ENDIF}
  rType: TRttiType;
  rProp: TRttiProperty;
  propertyname : string;
  daofield : TDAOField;
  value : TValue;
begin
  try
    rType := ctx.GetType(Self.Table.ClassInfo);
    for rProp in TRTTI.GetProperties(rType,roFirstBase) do
    begin
      propertyname := rProp.Name;
      if IsPublishedProp(Self.Table,propertyname) then
      begin
        daofield := TDAOField.Create;
        daofield.DataSize := 0;
        daofield.Precision := 0;
        {$IFNDEF FPC}
        //get datasize from attributes
        for attr in rProp.GetAttributes do
        begin
          if attr is TMapField then propertyname := TMapField(attr).Name;
          if attr is TFieldVARCHAR then daofield.DataSize := TFieldVARCHAR(attr).Size;
          if attr is TFieldDecimal then
          begin
            daofield.DataSize := TFieldDECIMAL(attr).Size;
            daofield.Precision := TFieldDECIMAL(attr).Decimals;
          end;
        end;
        {$ENDIF}
        daofield.Name := propertyname;

        //value := rProp.GetValue(Self.Table);
        //propType := rProp.PropertyType.TypeKind;
        case rProp.PropertyType.TypeKind of
          tkDynArray, tkArray, tkClass, tkRecord :
            begin
              daofield.DataType := dtstringMax;
            end;
          tkString, tkLString, tkWString, tkUString{$IFDEF FPC}, tkAnsiString{$ENDIF} :
            begin
              //get datasize from index
              {$IFNDEF FPC}
              if TRttiInstanceProperty(rProp).Index > 0 then daofield.DataSize := TRttiInstanceProperty(rProp).Index;
              {$ELSE}
              if GetPropInfo(Self.Table,propertyname).Index > 0 then daofield.DataSize := GetPropInfo(Self.Table,propertyname).Index;
              {$ENDIF}

              if daofield.DataSize = 0 then daofield.DataType := dtstringMax
                else daofield.DataType := dtString;
            end;
          tkChar, tkWChar :
            begin
              daofield.DataType := dtString;
              daofield.DataSize := 1;
            end;
          tkInteger : daofield.DataType := dtInteger;
          tkInt64 :
            begin
              if rProp.PropertyType.Name = 'TAutoID' then daofield.DataType := dtAutoId
                else daofield.DataType := dtInt64;
            end;
          {$IFDEF FPC}
          tkBool : daofield.DataType := dtBoolean;
          {$ENDIF}
          tkFloat :
            begin
              value := rProp.GetValue(Self.Table);
              if value.TypeInfo = TypeInfo(TCreationDate) then
              begin
                daofield.DataType := dtCreationDate;
              end
              else if value.TypeInfo = TypeInfo(TModifiedDate) then
              begin
                daofield.DataType := dtModifiedDate;
              end
              else if value.TypeInfo = TypeInfo(TDateTime) then
              begin
                daofield.DataType := dtDateTime;
              end
              else if value.TypeInfo = TypeInfo(TDate) then
              begin
                daofield.DataType := dtDate;
              end
              else if value.TypeInfo = TypeInfo(TTime) then
              begin
                daofield.DataType := dtTime;
              end
              else
              begin
                daofield.DataType := dtFloat;
                if daofield.DataSize = 0 then daofield.DataSize := 10;
                //get decimals from index
                {$IFNDEF FPC}
                if TRttiInstanceProperty(rProp).Index > 0 then daofield.Precision := TRttiInstanceProperty(rProp).Index;
                {$ELSE}
                if GetPropInfo(Self.Table,propertyname).Index > 0 then daofield.Precision := GetPropInfo(Self.Table,propertyname).Index;
                {$ENDIF}
                if daofield.Precision = 0 then daofield.Precision := 4;
              end;
            end;
          tkEnumeration :
            begin
              value := rProp.GetValue(Self.Table);
              if (value.TypeInfo = System.TypeInfo(Boolean)) then
              begin
                daofield.DataType := dtBoolean;
              end
              else
              begin
                daofield.DataType := dtInteger;
              end;
            end;
        end;
        fFields.Add(daofield);
        fFieldsMap.Add(daofield.Name,daofield);
      end;
    end;
  except
    on E : Exception do
    begin
      raise Exception.CreateFmt('Error getting fields "%s" : %s',[Self.ClassName,e.Message]);
    end;
  end;
end;

function TDAOModel.HasPrimaryKey: Boolean;
begin
  Result := not fPrimaryKey.Name.IsEmpty;
end;

function TDAOModel.IsPrimaryKey(const aName: string): Boolean;
begin
  Result := HasPrimaryKey and (CompareText(PrimaryKey.Name,aName) = 0);
end;

procedure TDAOModel.SetPrimaryKey(const Value: TDAOField);
begin
  fPrimaryKey := Value;
  fPrimaryKey.IsPrimaryKey := True;
end;

procedure TDAOModel.SetTable(const Value: TDAORecordClass);
begin
  fTable := Value;
  GetFields;
end;

{ TDAOResult }

constructor TDAOResult<T>.Create(aDAOQuery: IDAOQuery<T>);
begin
  fDAOQuery := aDAOQuery;
end;

function TDAOResult<T>.GetEnumerator: TEnumerator<T>;
begin
  Result := TDAOEnumerator.Create(fDAOQuery);
end;

function TDAOResult<T>.GetOne(aDAORecord: T): Boolean;
begin
  //Result := not fDAOQuery.Eof;
  //if not Result then Exit;
  Result := fDAOQuery.MoveNext;
  if not Result then Exit;
  fDAOQuery.FillRecordFromDB(aDAORecord);
end;

function TDAOResult<T>.ToArray: TArray<T>;
var
  daorecord : T;
  i : Integer;
begin
  SetLength(Result,Self.Count);
  i := 0;
  for daorecord in Self do
  begin
    Result[i] := daorecord;
    Inc(i);
  end;
end;

function TDAOResult<T>.ToList: TList<T>;
var
  daorecord : T;
begin
  Result := TList<T>.Create;
  for daorecord in Self do Result.Add(daorecord);
end;

function TDAOResult<T>.ToObjectList: TObjectList<T>;
var
  daorecord : T;
begin
  Result := TObjectList<T>.Create(True);
  for daorecord in Self do Result.Add(daorecord);
end;

function TDAOResult<T>.Count: Integer;
begin
  Result := fDAOQuery.CountResults;
end;

function TDAOResult<T>.HasResults: Boolean;
begin
  Result := fDAOQuery.CountResults > 0;
end;

{ TDAOResult<T>.TEnumerator }

constructor TDAOResult<T>.TDAOEnumerator.Create(aDAOQuery: IDAOQuery<T>);
begin
  fDAOQuery := aDAOQuery;
  fModel := aDAOQuery.GetModel;
end;

function TDAOResult<T>.TDAOEnumerator.DoGetCurrent: T;
var
  {$IFNDEF FPC}
  daorecord : TDAORecord;
  {$ELSE}
  daorecord : T;
  {$ENDIF}
begin
  {$IFNDEF FPC}
  daorecord := fDAOQuery.GetModel.Table.Create;
  {$ELSE}
  daorecord := T.Create;
  {$ENDIF}
  fDAOQuery.FillRecordFromDB(daorecord);
  Result := daorecord as T;
  //Result := fDAOQuery.GetCurrent;
end;

function TDAOResult<T>.TDAOEnumerator.DoMoveNext: Boolean;
begin
  Result := fDAOQuery.MoveNext;
end;

{ TDAOQueryGenerator }

function TDAOQueryGenerator.QuotedStr(const aValue: string): string;
begin
  Result := '''' + aValue + '''';
end;

end.
