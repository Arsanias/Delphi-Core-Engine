// Copyright (c) 2021 Arsanias
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.Database;

interface
	{$Define USE_FIRE_DAC}

uses
  System.Variants, System.Classes, System.SysUtils, System.StrUtils,
  Data.DB,
  {$IF Defined(USE_FIRE_DAC)}
    FireDAC.Comp.Client,  FireDAC.Phys.MySQL, FireDAC.Comp.UI, FireDAC.Stan.Def, FireDAC.Stan.Intf, FireDAC.Stan.Async, FireDAC.DApt,
    FireDAC.Stan.Option, FireDAC.VCLUI.Wait, FireDAC.ConsoleUI.Wait, FireDAC.Phys.Intf, FireDAC.Phys.MySQLWrapper,
  {$ELSE}
    Data.Win.ADODB, Datasnap.Provider, Datasnap.DBClient, midaslib,
  {$ENDIF}
  Core.Types, Core.Utils;

const
  A_RIGHTS_NONE =  0;
  A_RIGHTS_VISITOR =  1;
  A_RIGHTS_USER =  2;
  A_RIGHTS_LEADER =  3;
  A_RIGHTS_MANAGER =  4;
  A_RIGHTS_ADMIN =  5;

  SQL_TRUE = 255;
  SQL_FALSE = 0;

type
  TDX_DataFlag = (dfOpen, dfAsync, dfControls, dfMemory, dfReadOnly);
  TDX_DataFlags = set of TDX_DataFlag;
  TdxCommandType = (ctUnknown, ctSelect, ctInsert, ctUpdate, ctDelete);

  TDataSetHelper = class helper for TDataSet
  private
    function GetField(AIndex: Integer): TField; overload;
    function GetField(AFieldName: string): TField; overload;
  public
    procedure Open(ASql: string); overload;
    procedure OpenLinked(ASql: string; MasterSource: TDataSource; MasterField, IndexFields: string);
    procedure Reload(AKeepRow: Boolean);
    property Fields[AFieldName: string]: TField read GetField; default;
    property Fields[AFieldIndex: Integer]: TField read GetField; default;
  end;

  TCoreConnector = class
  private
    {$IF Defined(USE_FIRE_DAC)}
      FConnection: TFDConnection;
      FManager: TFDManager;
      dacDriverLink: TFDPhysMySQLDriverLink;
      dacWaitCursor: TFDGUIxWaitCursor;
    {$ELSE}
      FConnection: TADOConnection;
    {$ENDIF}
    FActive: Boolean;
    FUserName: string;
    FPassword: string;
    FApplicationPath: string;
    function GetConnectionStr(): string;
  protected
    procedure RecoverConnection(Sender: TObject; const Initiator: IFDStanObject; AException: Exception; var Action: TFDPhysConnectionRecoverAction);
  public
    OnGogo: TNotifyEvent;
    constructor Create(UseManager: Boolean); virtual;
    destructor Destroy; override;
    {$IF Defined(USE_FIRE_DAC)}
      property Connection: TFDConnection read FConnection;
    {$ELSE}
      property Connection: TADOConnection read FConnection;
    {$ENDIF}
    procedure Connect(ADataBase, AServer, APort, ARoot, APassword: string); overload;
    procedure Connect(ConnectionDefName: string); overload;
    procedure Connect(SharedHandle: Pointer); overload;
    function CreateControlSet(ASql: string): TDataSet;
    procedure Disconnect;
    function DoSQL(SQL: string): Integer;
    function DoDeleteSql(ATable: string ; ACriteriaFields, ACriteriaValues: array of Variant ): Boolean;
    function DoInsert(ATable: string ; const AFields: Variant ; const AValues: Variant ): Boolean;
    function DoUpdate(ATable: string ; const AFields: Variant; const AValues: Variant; const AConditionSql: string): Boolean;
    function GetValue(sField, sTable, sCriteria: WideString ): Variant;
    function GetNextNo(Field, Table, Mask: string; Start, NLength: Integer): string;
    function GetCount(sField, sTable, sCriteria: WideString ): Integer;
    function GetMin(sField, sTable, sCriteria: WideString ): Integer;
    function GetSum(sField, sTable, sCriteria: WideString ): Integer;
    function GetLastAutoIncValue: Cardinal;
    function GetTableNames(Strings: TStrings): Boolean;
    function Reconnect: Boolean;
    function SetValue(sField, sTable, sCriteria: WideString; Value: Variant): Boolean;
    property Active: Boolean read FActive;
    property ConnectionString: string read GetConnectionStr;
    property ApplicationPath: string read FApplicationPath write FApplicationPath;
    property UserName: string read FUserName write FUserName;
    property Password: string read FPassword;
  end;

  TDX_RowStatus = (rsCreated, rsLoaded, rsModified, rsDeleted);

implementation

function TCoreConnector.GetNextNo(Field, Table, Mask: string; Start, NLength: Integer): string;
var
  ASet: TDataSet;
  s:  string;
  r:  Integer;
begin
  ASet := CreateControlSet(
    'SELECT ' +
      Field + ' ' +
    'FROM ' +
      Table + ' ' +
    'WHERE ' +
      '(' + Field + ' LIKE ' + VarToSql(Mask) + ') ' +
    'ORDER BY ' +
      Field + ';');

    try
      r := 1;

      while (not ASet.Eof) do
      begin
        s := ASet.Fields[0].Value;
        s := MidStr(s, Start, NLength);

        if (StrToInt(s) > r) then
            r := StrToInt(s);

        Inc(r);
        ASet.Next();
      end;

      Result := DupeString('0', NLength - Length(IntToStr(r))) + IntToStr(r);
    finally
      SafeFree(ASet);
    end;
end;

procedure TCoreConnector.RecoverConnection(Sender: TObject; const Initiator: IFDStanObject; AException: Exception; var Action: TFDPhysConnectionRecoverAction);
var
  iRes: Integer;
begin
  if Assigned(OnGogo) then OnGogo(Self);

  {
  case iRes of
    mrYes: Action := faOfflineAbort;
    mrOk: Action := faRetry;
    mrCancel: Action := faFail;
  end;
  }
end;

function TCoreConnector.DoDeleteSql(ATable: string ; ACriteriaFields, ACriteriaValues: array of Variant): Boolean;
var
  ASql: string;
  i: Integer;
begin
  if (ATable = '') or (Length(ACriteriaFields) = 0) or (Length(ACriteriaFields) <> Length(ACriteriaValues )) then Exit(False);
  ASql := 'DELETE FROM ' + ATable + ' WHERE';

  for i := 0 to Length(ACriteriaValues) - 1 do
  begin
    ASql := ASql + ' (' + VarToStr(ACriteriaFields[i]) + ' = ' + VarToSql(ACriteriaValues[i]) + ')';

  	if (i < Length(ACriteriaValues) - 1) then
      ASql := ASql + ' AND';
	end;

	DoSql(ASql);
	Result := True;
end;

constructor TCoreConnector.Create(UseManager: Boolean);
begin
  inherited Create();

  FUserName := '';
  FApplicationPath := '';

  if (UseManager) then
  begin
    FManager := TFDManager.Create(nil);
    FManager.SilentMode := True;
    FManager.Active := true;
  end;
end;

destructor TCoreConnector.Destroy();
var
  i: Integer;
begin
  SafeFree(FConnection);

  {$IF Defined(USE_FIRE_DAC)}
    SafeFree(dacDriverLink);
  {$ENDIF}

  SafeFree(FManager);

  inherited Destroy;
end;

procedure TCoreConnector.Connect(ADataBase, AServer, APort, ARoot, APassword: string);
const
  driverID = 'MySql';
var
  ConnectionParams: TStrings;
begin
    {$IF Defined(USE_FIRE_DAC)}
    // Erstellt eine Verbindung über MySQL FireDAC Treiber

    if ((ApplicationPath = '') or (UserName = '')) then
      raise Exception.Create('Verbindung zur Datenbank kann nicht aufgebaut werden. Es ist kein Pfad zur MySQl.dll angegeben oder der Benutzer ist nicht bekannt.');

    if(FConnection = nil) then
    begin
      dacDriverLink := TFDPhysMySQLDriverLink.Create(nil);
      dacDriverLink.DriverID := driverID;
      dacDriverLink.VendorLib := ApplicationPath + 'libmysql.dll';

      dacWaitCursor := TFDGUIxWaitCursor.Create(nil);
      dacWaitCursor.Provider := 'Console';

      FConnection := TFDConnection.Create(nil);
      FConnection.LoginPrompt := false;
      FConnection.FetchOptions.Mode := TFDFetchMode.fmAll;

      FConnection.ResourceOptions.AutoReconnect := true;
      FConnection.ResourceOptions.CmdExecTimeout := 3000;
      FConnection.OnRecover := RecoverConnection;
    end
    else
      FConnection.Close();

    if (FManager <> nil) then
    begin
      ConnectionParams := TStringList.Create();
      ConnectionParams.Add('DriverID=' + driverID);
      ConnectionParams.Add('Server=' + AServer);
      if (APort <> '') then
          ConnectionParams.Add('Port=' + APort);
      ConnectionParams.Add('Database=' + ADataBase);
      ConnectionParams.Add('User_Name=' + ARoot);
      ConnectionParams.Add('Password=' + APassword);
      FManager.AddConnectionDef('MySql_Pooled', driverID, ConnectionParams);
      FConnection.ConnectionDefName := 'MySql_Pooled';
    end
    else
    begin
      FConnection.Params.Add('DriverID=' + DriverID);
      FConnection.Params.Add('Server=' + AServer);
      if (APort <> '') then
          FConnection.Params.Add('Port=' + APort);
      FConnection.Params.Add('Database=' + ADataBase);
      FConnection.Params.Add('User_Name=' + ARoot);
      FConnection.Params.Add('Password=' + APassword);
    end;

    FConnection.Connected := true;
  {$ELSE}
    // Erstellt eine Verbindung über MySQL ADO Treiber

    if(FConnection = nil) then
    begin
      FConnection := TADOConnection.Create(nil);
      FConnection.LoginPrompt := False;
      FConnection.ConnectOptions := TConnectOption.coConnectUnspecified;
    end
    else
      FConnection.Close();

    FConnection.ConnectionString :=
      'Provider=MSDASQL;' +
      'Driver={MySQL ODBC 5.2w Driver};' +
      'Server=' + AServer + ';' +
      'Database=' + ADataBase + ';' +
      'User=' + ARoot + ';' +
      'Option=3;';

    FConnection.Open();
  {$ENDIF}

  FActive := true;
end;

procedure TCoreConnector.Connect(ConnectionDefName: string);
begin
  {$IF Defined(USE_FIRE_DAC)}
    if (FConnection = nil) then
    begin
      FConnection := TFDConnection.Create(nil);
      FConnection.FetchOptions.Mode := TFDFetchMode.fmAll;
    end
    else
      FConnection.Close;

    FConnection.ConnectionDefName := ConnectionDefName;
    FConnection.Connected := true;
  {$ENDIF}

  FActive := True;
end;

procedure TCoreConnector.Connect(SharedHandle: Pointer);
begin
  {$IF Defined(USE_FIRE_DAC)}
    if (FConnection = nil) then
    begin
      FConnection := TFDConnection.Create(nil);
      FConnection.FetchOptions.Mode := TFDFetchMode.fmAll;
    end
    else
      FConnection.Close;

    FConnection.SharedCliHandle := SharedHandle;
    FConnection.Connected := True;
  {$ENDIF}

  FActive := True;
end;

function TCoreConnector.DoInsert(ATable: string; const AFields: Variant; const AValues: Variant): Boolean;
var
  ASql: string;
  i: Integer;
begin
  result := false;
  if(( VarArrayDimCount( AFields ) = 0 ) or ( VarArrayDimCount( AValues ) = 0 )) then Exit(false);

  ASql := 'INSERT INTO ' + ATable + ' (';

  for i := VarArrayLowBound( AFields, 1 ) to VarArrayHighBound( AFields, 1 ) do
  begin
      ASql := ASql + AFields[ i ];
      if( i < VarArrayHighBound( AFields, 1 )) then
          ASql := ASql + ', ';
  end;
  ASql := ASql + ') VALUES (';

  for i := VarArrayLowBound( AValues, 1 ) to VarArrayHighBound( AValues, 1 ) do
  begin
      ASql := ASql + VarToSql(AValues[i]);

      if( i < VarArrayHighBound(AValues, 1)) then
      ASql := ASql + ', ';
  end;

  ASql := ASql + ');';
  DoSql(ASql);

  Result := True;
end;

function TCoreConnector.DoUpdate( ATable: string ; const AFields: Variant; const AValues: Variant; const AConditionSql: string): Boolean;
var
  ASql: string;
  i: Integer;
begin
	Result := False;
  if ((VarArrayDimCount(AFields) > 0) and (VarArrayDimCount(AValues) > 0)) then
  begin
    ASql := 'UPDATE ' + ATable + ' SET ';

    for i := VarArrayLowBound( AFields, 1 ) to VarArrayHighBound( AFields, 1 ) do
    begin
        ASql := ASql + AFields[ i ] + ' = ' + VarToSql(AValues[i]);
        if( i < VarArrayHighBound( AFields, 1 )) then
            ASql := ASql + ', '
        else
            ASql := ASql + ' ';
    end;

    ASql := ASql + 'WHERE (' + AConditionSql + ');';
    DoSql(ASql);

    Result := True;
  end
  else
  if (not VarIsNull(AFields)) and (not VarIsNull(AValues)) then
  begin
    ASql := 'UPDATE ' + ATable + ' SET ' + AFields + ' = ' + VarToSql(AValues) + ' ';
    ASql := ASql + 'WHERE (' + AConditionSql + ');';
    DoSql(ASql);
    Result := True;
  end;
end;

function TCoreConnector.CreateControlSet(ASql: string): TDataSet;
begin
  {$IF Defined(USE_FIRE_DAC)}
    Result := TFDQuery.Create(nil);
    TFDQuery(Result).Connection  := Connection;
    TFDQuery(Result).SQL.Text := ASql;
    //TFDQuery(Result).ResourceOptions.CmdExecMode := amAsync; // if you want async operations
    TFDQuery(Result).ResourceOptions.CmdExecTimeout := 16000;
  {$ELSE}
    FDataSource.DataSet := TADODataSet.Create(nil);
    TADODataSet(FDataSource.DataSet).Connection  := Connector.Connection;
    TADODataSet(FDataSource.DataSet).CommandText := FSQL;
  {$ENDIF}

  if ASql <> '' then Result.Open;
end;

function TCoreConnector.SetValue(sField, sTable, sCriteria: WideString; Value: Variant): Boolean;
var
  C:  TDataSet;
  sql: string;
  ErrorText: string;
begin
  Result := False;
  if ((sField = '') or (sTable = '') or (sCriteria = '')) then Exit();

  sql := 'SELECT ' + sTable + '.* FROM ' + sTable + ' WHERE (' + sCriteria + ');';

  C := CreateControlSet(Sql);
  try
    if( C.RecordCount > 1 ) then
    begin
      ErrorText := 'Eine Aktualisierungsabfrage zu einem bestimmten Datensatz hätte mehrere Datensätze beschrieben, '+
        'weshalb sie zurückgewiesen wurde.';
      Exit;
    end
    else
    if (C.RecordCount = 1) then
    begin
      C.Edit;
      C[sField].Value := Value;
      C.Post;
      Result := True;
    end;
      C.Close;
  finally
    SafeFree(C);
  end;
end;

function TCoreConnector.GetValue(sField, sTable, sCriteria: WideString) : Variant;
var
  sql: string;
begin
  Result := Null;
  if ((sField = '' ) or (sTable = '')) then Exit();

  sql := 'SELECT ' + sField + ' FROM ' + sTable;
  if (sCriteria <> '') then
      sql := sql + ' WHERE (' + sCriteria + ') LIMIT 1';

  {$IF Defined(USE_FIRE_DAC)}
      Result := Connection.ExecSQLScalar(sql);
  {$ELSE}
      dataSet := DB_CONNECT.CreateControlSet(sql, true);
      try
          if (dataSet.RecordCount > 1) then
              DX_ShowError('Too much Results')
          else
              if (dataSet.RecordCount = 1) then
                  Result := dataSet[0].Value;
      finally
          DX_SafeFree(dataSet);
      end;
  {$ENDIF}
end;

function TCoreConnector.GetCount(sField, sTable, sCriteria: WideString): Integer;
var
  ASql: string;
  {$IF NOT Defined(USE_FIRE_DAC)}
    ASet: TDataSet;
  {$ENDIF}
begin
  Result := 0;
  if ((sField = '') or (sTable = '')) then Exit;

  ASql := 'SELECT COUNT(' + sField + ') AS X FROM ' + sTable;
  if sCriteria <> '' then
    ASql := ASql + ' WHERE (' + sCriteria + ');';

  {$IF Defined(USE_FIRE_DAC)}
    Result := Connection.ExecSQLScalar(ASql);
  {$ELSE}
    ASet := DB_CONNECT.CreateControlSet(ASql);

    try
      if (ASet.RecordCount <= 0) then
        DX_ShowError(DX_Translator.Translate(MSG_NO_RESULTS))
      else
        if (ASet.RecordCount = 1) then
        begin
          ASet.First;
          if ((not ASet.EoF) and (not ASet['X'].IsNull)) then
            Result := ASet['X'].AsInteger;
        end;
    finally
      ASet.Free;
    end;
  {$ENDIF}
end;

function TCoreConnector.GetMin(sField, sTable, sCriteria: WideString): Integer;
var
    sql: string;
{$IF NOT Defined(USE_FIRE_DAC)}
    dataSet: TDataSet;
{$ENDIF}begin
    Result := 0;
    if ((sField = '') or (sTable = '')) then Exit();

    sql := 'SELECT MIN(' + sField + ') AS X FROM ' + sTable;
    if sCriteria <> '' then
        sql := sql + ' WHERE (' + sCriteria + ');';

    {$IF Defined(USE_FIRE_DAC)}
        Result := Connection.ExecSQLScalar(sql);
    {$ELSE}
        dataSet := DB_CONNECT.CreateControlSet(sql, true);

        try
            if (dataSet.RecordCount <= 0) then
                DX_ShowError(DX_Translator.Translate(MSG_NO_RESULTS))
            else
                if (dataSet.RecordCount = 1) then
                begin
                    dataSet.First();
                    if ((not dataSet.EoF) and (not dataSet.Field('X').IsNull)) then
                        Result := dataSet.Field('X').AsInteger;
                end;
        finally
            DX_SafeFree(dataSet);
        end;
    {$ENDIF}
end;

function TCoreConnector.GetSum(sField, sTable, sCriteria: WideString): Integer;
var
  ASql: string;
  {$IF NOT Defined(USE_FIRE_DAC)}
    ASet: TDataSet;
  {$ENDIF}
begin
  Result := 0;
  if ((sField = '') or (sTable = '')) then Exit;

  ASql := 'SELECT SUM(' + sField + ') AS X FROM ' + sTable;
  if sCriteria <> '' then
    ASql := ASql + ' WHERE (' + sCriteria + ');';

  {$IF Defined(USE_FIRE_DAC)}
    Result := Connection.ExecSQLScalar(ASql);
  {$ELSE}
    ASet := DB_CONNECT.CreateControlSet(ASql, True);

    try
      if (ASet.RecordCount <= 0) then
        DX_ShowError(DX_Translator.Translate(MSG_NO_RESULTS))
      else
        if (ASet.RecordCount = 1) then
        begin
          ASet.First;
          if (not ASet.EoF) and (not ASet['X'].IsNull) then
            Result := ASet['X'].AsInteger;
        end;
    finally
      SafeFree(ASet);
    end;
  {$ENDIF}
end;

function TCoreConnector.GetLastAutoIncValue(): Cardinal;
{$IF NOT Defined(USE_FIRE_DAC)}
var
    ASet: TDataSet;
{$ENDIF}
begin
    {$IF Defined(USE_FIRE_DAC)}
        Result := FConnection.GetLastAutoGenValue('');
    {$ELSE}
        ASet := DB_CONNECT.CreateControlSet('SELECT @@Identity', true);
        if (ASet = nil) then Exit();

        try
            Result := ASet.Field(0).AsInteger;
        finally
            DX_SafeFree(ASet);
        end;
    {$ENDIF}
end;

function TCoreConnector.GetTableNames(Strings: TStrings): Boolean;
begin
{$IF Defined(USE_FIRE_DAC)}
    //FConnection.GetTableNames('', '', '', '', Strings, [osMy, osSystem, osOther], [tkTable, tkView], true);
    FConnection.GetTableNames('', '', '', Strings, [osMy], [tkTable], false);
    Result := true;
{$ENDIF}
end;

function TCoreConnector.Reconnect(): Boolean;
begin
    FConnection.Connected := True;
    Result := true;
end;

function TCoreConnector.DoSQL(Sql: string): Integer;
begin
  Result := 0;

  {$IF Defined(USE_FIRE_DAC)}
  if (Assigned(FConnection)) then
    Result := Connection.ExecSQL(SQL);
  {$ELSE}
  if (Assigned(FConnection)) then
    Result := FConnection.Execute(SQL, Result, [eoExecuteNoRecords]);
  {$ENDIF}
end;

procedure TCoreConnector.Disconnect();
begin
  FActive := false;
  FConnection.Connected := false;
end;

function TCoreConnector.GetConnectionStr(): string;
begin
  Result := FConnection.ConnectionString;
end;

//======================================================================================================

function TDataSetHelper.GetField(AIndex: Integer): TField;
begin
  Result := inherited Fields[AIndex];
end;

function TDataSetHelper.GetField(AFieldName: string): TField;
begin
  Result := FieldByName(AFieldName);
end;

procedure TDataSetHelper.Open(ASql: string);
begin
  if Active then Close;
  {$IF Defined(USE_FIRE_DAC)}
    TFDQuery(Self).SQL.Text := ASql;
  {$ELSE}
    TADODataSet(Self).CommandType := cmdText;
    TADODataSet(Self).CommandText := SQL;
  {$ENDIF}
  if ASql <> '' then Open;
end;

procedure TDataSetHelper.OpenLinked(ASql: string; MasterSource: TDataSource; MasterField, IndexFields: string);
begin
  if Active then Close;

  {$IF Defined(USE_FIRE_DAC)}
    TFDQuery(Self).SQL.Text := ASql;

    if (MasterSource <> nil) then
    begin
      TFDQuery(Self).MasterFields := MasterField;
      TFDQuery(Self).IndexFieldNames := IndexFields;
      TFDQuery(Self).DataSource := MasterSource;
    end;
  {$ELSE}
    TADODataSet(Self).CommandType := cmdText;
    TADODataSet(Self).CommandText := SQL;

    if (MasterSet <> nil) then
    begin
      TADODataSet(Self).MasterFields := MasterField;
      TADODataSet(Self).IndexFieldNames := IndexFields;
      TADODataSet(Self).DataSource := MasterSource;
    end;
  {$ENDIF}

  Open;
end;

procedure TDataSetHelper.Reload(AKeepRow: Boolean);
var
  bm: TBookmark;
begin
  if Modified then Post;

  if AKeepRow then
  begin
    bm := GetBookmark;
    Refresh;
    GotoBookmark(bm);
    FreeBookmark(bm);
    bm := nil;
  end
  else
    Refresh;
end;

end.



