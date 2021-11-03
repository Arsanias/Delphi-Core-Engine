// Copyright (c) 2021 Arsanias
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.Mesh;

interface

uses
  System.Types, System.Variants, System.Math, System.Classes, System.SysUtils,
  Vcl.Forms, Vcl.Dialogs, Vcl.Graphics,
  Core.Types, Core.Arrays, Core.Material, Core.Messages,
  Core.RenderDevice;

type
  TMesh = class
  private
    FUniqueID:      Cardinal;
    FMaterial:      TGX_Material;
    FName:          string;
    FStatus:        TGX_Status;
    FBlendState:    TGX_BlendState;
    FFaces:         TGX_Array;
    FFaceIndex:     Integer;
    FPolyCount:     Integer;
    FTopology:      TVertexTopology;
    FIndexed:       Boolean;
    FShaderIndex:   Integer;
    FSemantics:     TGX_Semantics;
    FVisible:       LongBool;
    FShadeMode:     TGX_ShadeMode;
    function        GetFaceCount: Integer;
    function        GetFieldCount: Integer;
    function        GetFieldOffset(ASemantic: TGX_Semantic): Integer;
  public
    IndexSize: Integer;
    property Topology: TVertexTopology read FTopology;
    property FaceCount: Integer read GetFaceCount;
    property FieldCount: Integer read GetFieldCount;
    property ShaderIndex: Integer read FShaderIndex write FShaderIndex;
    property PolyCount: Integer read FPolyCount;
    property Semantics: TGX_Semantics read FSemantics;
    property Faces: TGX_Array read FFaces;
    function GetFaceIndex(AFace, APolygon: Integer; ASemantic: TGX_Semantic): Integer;
    function GetStride: Integer;
    procedure SetFaceIndex(AFace, APolygon: Integer; ASemantic: TGX_Semantic; AIndex: Integer);
  public
    VBufferIndex: Integer;
    IBufferIndex: Integer;
    Stripes: TInstanceArray;
    constructor Create(AName: string ; ATopology: TVertexTopology ; AShadeMode: TGX_ShadeMode ; ASemantics: TGX_Semantics );
    destructor Destroy(); override;
    procedure AddFace( AElements: Variant );
    function AddSemantic( ASemantic: TGX_Semantic ): LongBool;
    function Load( AUniqueID: Cardinal ): Boolean;
    function Save( AObjectID: Cardinal ): Boolean;
  public
    property UniqueID:     UInt32      read FUniqueID;
    property Status:       TGX_Status      read FStatus;
    property BlendState:   TGX_BlendState  read FBlendState    write FBlendState;
    property Indexed:      Boolean         read FIndexed       write FIndexed;
    property Name:         string           read FName          write FName;
    property Stride:       Integer     read GetStride;
    property Material:     TGX_Material    read FMaterial      write FMaterial;
    property ShadeMode:    TGX_ShadeMode   read FShadeMode     write FShadeMode;
    property Visible:      LongBool        read FVisible       write FVisible;
  end;
  TMeshList = TGX_NodeList<TMesh>;

implementation

constructor TMesh.Create(AName: string; ATopology: TVertexTopology; AShadeMode: TGX_ShadeMode; ASemantics: TGX_Semantics);
begin
  inherited Create();

  FUniqueID     := 0;
  FStatus       := stCreated;
  FName         := AName;
  FShadeMode    := AShadeMode;
  FFaceIndex    := 0;
  FIndexed      := False;
  FTopology     := ATopology;
  FFaces        := TGX_Array.Create();
  FVisible      := True;
  VBufferIndex  := -1;
  IBufferIndex  := -1;

  { add field semantics - position is the minimum required semantic }

  AddSemantic( asPosition );

  if( asNormal    in ASemantics ) then AddSemantic( asNormal );
  if( asTexcoord  in ASemantics ) then AddSemantic( asTexcoord );
  if( asColor     in ASemantics ) then AddSemantic( asColor );
  if( asBoneIndex in ASemantics ) then AddSemantic( asBoneIndex );
end;

destructor TMesh.Destroy();
begin
  FFaces.Free;
  inherited Destroy();
end;

function TMesh.AddSemantic( ASemantic: TGX_Semantic ): LongBool;
var
  F: TGX_ArrayField;
begin
  if( ASemantic in FSemantics ) then Exit;
  try
    F := FFaces.AddField( ASemantic, '', SizeOf(Integer));
  except
    Exit( False );
  end;
  Result := ( F <> nil );
  FSemantics := FSemantics + [ ASemantic ];
end;

procedure TMesh.AddFace( AElements: Variant );
var
  iField, iRow: Integer;
  StartIndex: Integer;
  DataCount:  Integer;
  nRow: Integer;
begin
  if( FFaces = nil ) then Exit;

  StartIndex := FFaces.RowCount;
  DataCount  := ( VarArrayHighBound( AElements, 1 ) + 1 );

  { count of data must be dividable through column count of mesh }

  if(( DataCount mod FieldCount ) > 0 ) then Exit;

  nRow := DataCount div FieldCount;
  FFaces.RowCount := FFaces.RowCount + nRow;

  for iRow := 0 to nRow - 1 do
    for iField := 0 to FieldCount - 1 do
      FFaces[ iField ].AsInteger[ StartIndex + iRow ] := Integer( AElements[ iRow * FieldCount + iField ]);
end;

function TMesh.GetFaceCount(): Integer;
begin
  case Topology of
    ptPoints:     Result := FFaces.RowCount;
    ptLines:      Result := FFaces.RowCount div 2;
    ptTriangles:  Result := FFaces.RowCount div 3;
  end;
end;

function TMesh.GetStride(): Integer;
begin
  Result := FFaces.Stride;
end;

function TMesh.GetFaceIndex( AFace, APolygon: Integer ; ASemantic: TGX_Semantic ): Integer;
var
  n: Integer;
begin
  n := FFaces.FieldIndex( ASemantic );
  Result := FFaces[ n ].AsInteger[ AFace * FPolycount + APolygon ];
end;

procedure TMesh.SetFaceIndex( AFace, APolygon: Integer ; ASemantic: TGX_Semantic; AIndex: Integer);
var
  n: Integer;
begin
  n := FFaces.FieldIndex( ASemantic );
  FFaces[ n ].AsInteger[ AFace * FPolyCount + APolygon ];
end;

function TMesh.GetFieldCount(): Integer;
begin
  Result := FFaces.FieldCount;
end;

function TMesh.GetFieldOffset( ASemantic: TGX_Semantic ): Integer;
begin
  Result := FFaces.FieldIndex( ASemantic );
end;

function TMesh.Load( AUniqueID: Cardinal ): Boolean;
var
  //ASet: TGX_DataSet;
  ASQL: string;
  i:    Integer;
begin
  (*
  if(( GX_Connector = nil ) or ( AUniqueID = 0 )) then Exit( False );

  ASet := GX_Connector.GetDataSet( 'SELECT * FROM tbMesh WHERE ( FID = ' + IntToStr( AUniqueID ) + ' );' );

  try
    FName := ASet[ 'FName' ].AsString;

    if( ASet[ 'FSemanticPosition' ].AsInteger > 0 ) then AddSemantic( asPosition );
    if( ASet[ 'FSemanticNormal' ].AsInteger   > 0 ) then AddSemantic( asNormal );
    if( ASet[ 'FSemanticTexcoord' ].AsInteger > 0 ) then AddSemantic( asTexcoord );
    if( ASet[ 'FSemanticColor' ].AsInteger    > 0 ) then AddSemantic( asColor );

    FFaces.RowCount := ASet[ 'FFaceCount' ].AsInteger * 3;
    GX_Connector.LoadArrayFromBlob( ASet[ 'FFaceData' ], FFaces, Faces.RowCount );

    { assign material to mesh }

    if( FModel <> nil ) then
    begin
      if( FModel.Materials.Count > 0 ) then
        for i := 0 to FModel.Materials.Count - 1 do
          if( FModel.Materials[ i ].UniqueID = ASet[ 'FMaterialID' ].AsInteger ) then
          begin
            FMaterial := FModel.Materials[ i ];
            Break;
          end;
      if( FMaterial = nil ) then
        GX_ShowError( GX_MSG_MeshLoadedButNoMaterialFound );
    end
    else
      GX_ShowError( GX_MSG_MeshLoadedButNoMaterialExists );
  except
    GX_SafeFree( ASet );
    FUniqueID := 0;
    FStatus   := stCreated;
    Exit( False );
  end;

  GX_SafeFree( ASet );

  FUniqueID := AUniqueID;
  FStatus   := stLoaded;
  Result    := True;
  *)
end;

function TMesh.Save( AObjectID: Cardinal ): Boolean;
var
  ASQL: string;
  //ASet: TGX_DataSet;
  function SemanticToByteBool( ASemantics: TGX_Semantics ; ASemantic: TGX_Semantic ): Byte;
  begin
    if( ASemantic in ASemantics ) then Result := 255 else Result := 0;
  end;
begin
  (*
  if( GX_Connector = nil ) then Exit( False );
  if(( FUniqueID > 0 ) and ( FStatus = stLoaded )) then Exit( True );

  { create database record if none exists }

  if( UniqueID = 0 ) then
  begin
    GX_Connector.Execute( 'INSERT INTO tbMesh ( FModelID, FMaterialID, FName ) VALUES ( 0, 0, ' + QuotedStr( 'Temporäres Mesh' ) + ' );' );
    FUniqueID := GX_Connector.GetLastAutoValue();
  end;

  ASQL := 'UPDATE tbMesh SET ' +
            GX_Connector.SetInteger(  'FModelID',          AObjectID,          True ) +
            GX_Connector.SetInteger(  'FMaterialID',        FMaterial.UniqueID, True ) +
            GX_Connector.SetString(   'FName',              FName,              True ) +
            GX_Connector.SetInteger(  'FSemanticPosition',  SemanticToByteBool( Semantics, asPosition ),  True ) +
            GX_Connector.SetInteger(  'FSemanticNormal',    SemanticToByteBool( Semantics, asNormal ),    True ) +
            GX_Connector.SetInteger(  'FSemanticTexcoord',  SemanticToByteBool( Semantics, asTexcoord ),  True ) +
            GX_Connector.SetInteger(  'FSemanticColor',     SemanticToByteBool( Semantics, asColor ),     True ) +
            GX_Connector.SetInteger(  'FFaceCount',         FaceCount,          False ) +
          'WHERE ( FID = ' + GX_IntToStr( UniqueID ) + ' );';

  GX_Connector.Execute( ASQL );

  ASet := GX_Connector.GetDataSet( 'SELECT FID, FFaceData FROM tbMesh WHERE FID = ' + IntToStr( UniqueID ) + ';' );
  GX_Connector.SaveArrayToBlob( ASet[ 'FFaceData' ], Faces );
  GX_SafeFree( ASet );

  FStatus := stLoaded;
  *)
end;

end.
