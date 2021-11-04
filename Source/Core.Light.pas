// Copyright (c) 2021 Arsanias
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.Light;

interface

uses
  System.Types,
  Core.Types, Core.Arrays;

type
  TLightType = (GX_LIGHTTYPE_AMBIENT, GX_LIGHTTYPE_SPOT, GX_LIGHTTYPE_POINT );

  TLight = class(TInterfacedObject, IParameter)
  private
    FStatus: TGX_Status;
    FUniqueID: Cardinal;
    FName: string;
    function GetParameters: TParameterDynArray;
    procedure SetParameters(Parameters: TParameterDynArray);
  public
    Direction: TVector3;
    Intensity: Single;
    LightType: TLightType;
    constructor Create;
    function Load( AUniqueID: Cardinal ): Boolean;
    function Save( ASceneID: Cardinal ): Boolean;
  public
    property UniqueID: Cardinal read FUniqueID;
    property Name: string read FName write Fname;
  end;
  TLightList = TGX_NodeList<TLight>;

implementation

constructor TLight.Create;
begin
  LightType := GX_LIGHTTYPE_AMBIENT;
  Intensity := 1.0;
  Direction := TVector3.Create(-0.25, -0.25, -0.75).Normalize;
end;

function TLight.Load(AUniqueID: Cardinal): Boolean;
var
  ASQL: string;
  i:    Integer;
begin
  (*
  if(( GX_Connector = nil ) or ( AUniqueID = 0 )) then Exit( False );

  ASQL := 'SELECT * FROM tbLight WHERE ( FID = ' + GX_IntToStr( AUniqueID ) + ' );';

  ASet := GX_Connector.GetDataSet( ASQL );
  try
    FName       := ASet[ 'FName' ].AsString;
    Intensity   := ASet[ 'FIntensity' ].AsFloat;
    LightType   := TLightType( ASet[ 'FType' ].AsInteger );
    Direction   := GX_Connector.GetFloat3( ASet, 'FDirection' );
  except
    GX_SafeFree( ASet );
    Exit( False );
  end;

  GX_SafeFree( ASet );

  FUniqueID := AUniqueID;
  FStatus   := stLoaded;
  *)
end;

function TLight.GetParameters: TParameterDynArray;
begin
  SetLength(Result, 4);
  Result[0] := TParameter.Create(0, 'FName', FName);
  Result[1] := TParameter.Create(1, 'FType', Integer(LightType));
  Result[2] := TParameter.Create(2, 'FIntensity',  Intensity);
  //Result[3] := TParameter.Create(3, 'FDirection',  Direction);
end;

procedure TLight.SetParameters(Parameters: TParameterDynArray);
begin
  FName       := Parameters[0].Value;
  Intensity   := Parameters[1].Value;
  LightType   := Parameters[2].Value;
  //Direction   := Parameters[3].Value;
end;

function TLight.Save( ASceneID: Cardinal ): Boolean;
var
  i: Integer;
  ASQL: string;
begin
  (*
  if(( GX_Connector = nil ) or ( ASceneID = 0 )) then Exit( False );

  { create database record }

  if( FUniqueID = 0 ) then
  begin
    GX_Connector.Execute( 'INSERT INTO tbLight ( FSceneID ) VALUES ( 0 );' );
    FUniqueID := GX_Connector.GetLastAutoValue();
  end;

  { save data }

  ASQL := 'UPDATE tbLight SET ' +
            GX_Connector.SetInteger( 'FSceneID',    ASceneID,   True )  +
            GX_Connector.SetString(  'FName',       FName,      True )  +
            GX_Connector.SetInteger( 'FType',       Integer( LightType ),  True )  +
            GX_Connector.SetFloat(   'FIntensity',  Intensity,  True )  +
            GX_Connector.SetVector(  'FDirection',  Direction,  False ) +
          'WHERE ( ' +
            'FID = ' + GX_IntToStr( UniqueID ) + ' );';

  GX_Connector.Execute( ASQL );
  GX_SafeFree( ASet );

  FStatus := stLoaded;
  *)
end;

end.
