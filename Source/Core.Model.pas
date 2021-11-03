// Copyright (c) 2021 Arsanias
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.Model;

interface

uses
  System.Types, System.Variants, System.Math, System.Classes, System.SysUtils,
  Vcl.Forms, Vcl.Dialogs, Vcl.Graphics,
  Core.Types, Core.Utils, Core.Arrays, Core.Material, Core.Messages, Core.Mesh;

type
  TGX_ShapeType = (stUnknown, stTest, stGrid, stGridNet, stCube, stCone, stCylindar, stSphere, stTorus, stPyramide, stSpiderNet, stModel);

  TModel = class
  private
    FDirection:     TVector3;
    FBounds:        array[ 0..7 ] of TVector3;
    FShapeType:     TGX_ShapeType;
  protected
    FUniqueID:      Cardinal;
    FStatus:        TGX_Status;
    FName:          string;
    FCenter:        TVector3;
    FVertices:      TGX_Array;
    FNormals:       TGX_Array;
    FTexcoords:     TGX_Array;
    FColors:        TGX_Array;
    FVertexArray:   TGX_Array;
    FIndexArray:    TGX_Array;
    FMeshes:        TMeshList;
    FMaterials:     TGX_NodeList<TGX_Material>;
    FSize:          TVector3;
    FVBufferIndex:  Integer;
    FIBufferIndex:  Integer;
    FMinSize: TVector3;
    FMaxSize: TVector3;
  public
    constructor Create( AName: string ; ADefaultMaterial: LongBool);
    destructor Destroy(); override;
    procedure Clear();
    function AddVertex( AVertex: TVector3 ): DWord;
    function AddNormal( ANormal: TVector3 ): DWord;
    function AddTexcoord( ATexcoord: TVector2 ): DWord;
    function AddColor( AColor: TVector4 ): DWord;
    procedure GetBuffer(AMesh: TMesh; AVertexArray, AIndexArray: TGX_Array; AIndexList: TStringList);
    function Load( AUniqueID: Cardinal ): Boolean; virtual; abstract;
    function Save(): Boolean; virtual; abstract;
    property        Direction: TVector3 read FDirection;
    property        ShapeType: TGX_ShapeType read FShapeType;
    property        Status: TGX_Status read FStatus;
    //property      Skeleton: TGX_Skeleton read FSkeleton write FSkeleton;
    function        LoadModel(AUniqueID: Cardinal): Boolean;
    procedure       UpdateSize();
    function        SaveModel(): Boolean;
  public
    property        Center:       TVector3        read FCenter              write FCenter;
    property        Name:         string            read FName                write FName;
    property        VertexArray:  TGX_Array         read FVertexArray;
    property        IndexArray:   TGX_Array         read FIndexArray;
    property        Vertices:     TGX_Array         read FVertices;
    property        Normals:      TGX_Array         read FNormals;
    property        Texcoords:    TGX_Array         read FTexcoords           write FTexcoords;
    property        Colors:       TGX_Array         read FColors;
    property        Meshes:       TMeshList      read FMeshes;
    property        Materials:    TGX_MaterialList  read FMaterials;
    property        Size:         TVector3        read FSize                write FSize;
    property        UniqueID:     Cardinal          read FUniqueID;
    property        IBufferIndex: Integer           read FIBufferIndex        write FIBufferIndex;
    property        VBufferIndex: Integer           read FVBufferIndex        write FVBufferIndex;
    property MinSize: TVector3 read FMinSize;
    property MaxSize: TVector3 read FMaxSize;
  end;
  TModelList = TGX_NodeList<TModel>;

implementation

constructor TModel.Create( AName: string; ADefaultMaterial: LongBool);
var
  AMaterial: TGX_Material;
begin
  inherited Create();

  { set basic values }

  FVBufferIndex := -1;

  FName := AName;
  FMaterials := TGX_MaterialList.Create();
  FMeshes := TMeshList.Create();

  { create arrays }

  FVertices := TGX_Array.Create([asPosition]);
  FNormals := TGX_Array.Create([asNormal]);
  FColors := TGX_Array.Create([asColor]);
  FTexcoords := TGX_Array.Create([asTexcoord]);

  { create default material }

  if( ADefaultMaterial = True ) then
  begin
    AMaterial := TGX_Material.Create();
    FMaterials.Add( AMaterial );
  end;
end;

destructor TModel.Destroy();
begin
  Clear();

  SafeFree( FVertices );
  SafeFree( FNormals );
  SafeFree( FColors );
  SafeFree( FTexcoords );

  SafeFree( FMaterials );

  inherited Destroy();
end;

procedure TModel.Clear();
var
  i: Integer;
  AMaterial: TGX_Material;
begin
  FUniqueID := 0;

  { clear vector arrays }

  FVertices.Clear();
  FNormals.Clear();
  FTexcoords.Clear();
  FColors.Clear();

  { clear meshes }

  if( Meshes.Count > 0 ) then
    for i := 0 to Meshes.Count - 1 do
      FMeshes[ i ].Free;
  Meshes.Clear();

  { clear materials }

  if( FMaterials.Count > 0 ) then
    for i := 0 to FMaterials.Count - 1 do
      FMaterials[ i ].Free;
  FMaterials.Clear();
end;

function TModel.AddVertex( AVertex: TVector3 ): DWord;
var
  i: Integer;
begin
  if( Vertices.RowCount > 0 ) then
    for i := 0 to Vertices.RowCount - 1 do
      if (FVertices[0].AsFloat3[i] = AVertex) then Exit(i);

  Result := FVertices.RowCount;
  FVertices.RowCount := FVertices.RowCount + 1;
  FVertices[ 0 ].AsFloat3[ Result ] := AVertex;
end;

function TModel.AddNormal( ANormal: TVector3 ): DWord;
begin
  Result := FNormals.RowCount;
  FNormals.RowCount := FNormals.RowCount + 1;
  FNormals[0].AsFloat3[Result] := ANormal;
end;

function TModel.AddTexcoord( ATexcoord: TVector2 ): DWord;
begin
  Result := FTexcoords.RowCount;
  FTexcoords.RowCount := FTexcoords.RowCount + 1;
  FTexcoords[ 0 ].AsFloat2[ Result ] := ATexcoord;
end;

function TModel.AddColor( AColor: TVector4 ): DWord;
begin
  Result := FColors.RowCount;
  FColors.RowCount := FColors.RowCount + 1;
  FColors[ 0 ].AsFloat4[ Result ] := AColor;
end;

procedure TModel.GetBuffer(AMesh: TMesh; AVertexArray, AIndexArray: TGX_Array ; AIndexList: TStringList);
var
  ACol, iFace: Integer;
  AIndex: Integer;
  AKeyIndex: Integer;
  AHex: string;
begin
  if ((AMesh.Faces = nil) or (AMesh.Faces.FieldCount = 0) or (AMesh.Faces.RowCount = 0)) then Exit;
  if( AVertexArray = nil ) then Exit;

  { fill vertex buffer }

  for iFace := 0 to AMesh.Faces.RowCount - 1 do
  begin
    if (AMesh.Indexed) then
    begin
      if(( AIndexArray = nil ) or ( AIndexList = nil )) then Exit;

      if( AIndexArray.FieldCount = 0 ) then
        AIndexArray.AddField( asUnknown, '', 4 );

      AHex := AMesh.Faces.AsHex(iFace);
      if( not AIndexList.Find( AHex, AKeyIndex )) then
      begin
        AKeyIndex := AVertexArray.RowCount;
        AIndexList.AddObject( AHex, Pointer( AKeyIndex ));
        AVertexArray.RowCount := AVertexArray.RowCount + 1;

        for ACol := 0 to AMesh.Faces.FieldCount - 1 do
        begin
          AIndex := AMesh.Faces.Fields[ ACol ].AsInteger[ iFace ];
          case AMesh.Faces[ACol].Semantic of
            asPosition: AVertexArray[asPosition].AsFloat3[AKeyIndex] := Vertices[0].AsFloat3[AIndex];
            asNormal: AVertexArray[asNormal].AsFloat3[AKeyIndex] := Normals[0].AsFloat3[AIndex];
            asColor: AVertexArray[asColor].AsFloat4[AKeyIndex] := Colors[0].AsFloat4[AIndex];
            asTexcoord: AVertexArray[asTexcoord].AsFloat2[AKeyIndex] := Texcoords[0].AsFloat2[AIndex];
          end;
        end;
      end
      else
        AKeyIndex := Integer( AIndexList.Objects[ AKeyIndex ]);

      AIndex := AIndexArray.RowCount;
      AIndexArray.RowCount := AIndexArray.RowCount + 1;
      AIndexArray[ 0 ].AsInteger[ AIndex ] := AKeyIndex;
    end
    else
    begin
      AKeyIndex := AVertexArray.RowCount;
      AVertexArray.RowCount := AVertexArray.RowCount + 1;
      for ACol := 0 to AMesh.Faces.FieldCount - 1 do
      begin
        AIndex := AMesh.Faces.Fields[ACol].AsInteger[iFace];
        case AMesh.Faces[ACol].Semantic of
          asPosition: AVertexArray[asPosition].AsFloat3[AKeyIndex] := Vertices[0].AsFloat3[AIndex];
          asNormal: AVertexArray[asNormal].AsFloat3[AKeyIndex]:= Normals[0].AsFloat3[AIndex];
          asColor:    AVertexArray[asColor].AsFloat4[AKeyIndex] := Colors[0].AsFloat4[AIndex];
          asTexcoord: AVertexArray[asTexcoord].AsFloat2[AKeyIndex] := Texcoords[0].AsFloat2[AIndex];
        end;
      end;
    end;
  end;
end;

//------------------------------------------------------------------------------
// From obsolete Model

function TModel.LoadModel(AUniqueID: Cardinal): Boolean;
var
  ASQL:       string;
  //ASet:       TGX_DataSet;
  AMesh:      TMesh;
  AMaterial:  TGX_Material;
  ASemantics: TGX_Semantics;
begin
  (*
  if( GX_Connector = nil ) then Exit( False );

  Clear();

  { load object }

  ASQL := 'SELECT * FROM tbModel WHERE ( FID = ' + IntToStr( AUniqueID ) + ' );';

  ASet := GX_Connector.GetDataSet( ASQL );

  try
    FName               := Aset[ 'FName' ].AsString;
    FVertices.RowCount  := ASet[ 'FVertexCount' ].AsInteger;
    FNormals.RowCount   := ASet[ 'FNormalCount' ].AsInteger;
    FTexcoords.RowCount := ASet[ 'FTexcoordCount' ].AsInteger;
    FColors.RowCount    := ASet[ 'FColorCount' ].AsInteger;

    GX_Connector.LoadArrayFromBlob( ASet[ 'FVertexData' ],   Vertices,   ASet[ 'FVertexCount' ].AsInteger );
    GX_Connector.LoadArrayFromBlob( ASet[ 'FNormalData' ],   Normals,    ASet[ 'FNormalCount' ].AsInteger );
    GX_Connector.LoadArrayFromBlob( ASet[ 'FTexcoordData' ], Texcoords,  ASet[ 'FTexcoordCount' ].AsInteger );
    GX_Connector.LoadArrayFromBlob( ASet[ 'FColorData' ],    Colors,     ASet[ 'FColorCount' ].AsInteger );
  except
    SafeFree( ASet );
    Clear();
    Exit( False );
  end;

  SafeFree( ASet );

  { load materials }

  ASet := GX_Connector.GetDataSet( 'SELECT FID FROM tbMaterial WHERE ( FModelID = ' + IntToStr( AUniqueID ) + ' );' );
  try
    while( not ASet.Eof ) do
    begin
      if(( ASet.RecNo = 1 ) and ( FMaterials.Count = 1 )) then
        FMaterials[ 0 ].Load( ASet[ 'FID' ].AsInteger )
      else
      begin
        AMaterial := TGX_Material.Create();
        if( AMaterial.Load( ASet[ 'FID' ].AsInteger )) then
          FMaterials.Add( AMaterial );
      end;
      ASet.Next;
    end;
  except
    SafeFree( ASet );
    Clear();
    Exit( False );
  end;

  SafeFree( ASet );

  { load meshes }

  ASet := GX_Connector.GetDataSet( 'SELECT FID FROM tbMesh WHERE ( FModelID = ' + IntToStr( AUniqueID ) + ' ) ORDER BY FOrder;' );
  try
    while( not ASet.Eof ) do
    begin
      AMesh := TMesh.Create( Self, '', ptTriangles, smFlat, []);
      Meshes.Add(AMesh);
      AMesh.Load( ASet[ 'FID' ].AsInteger );
      AMesh.Indexed := False;
      ASet.Next;
    end;
  except
    SafeFree( ASet );
    Clear();
    Exit( False );
  end;

  SafeFree( ASet );

  UpdateSize();

  FUniqueID := AUniqueID;
  FStatus   := stLoaded;
  Result    := True;
  *)
end;

function TModel.SaveModel: Boolean;
var
  i: Integer;
  ASQL: string;
  //ASet: TGX_DataSet;
begin
  (*
  if( GX_Connector = nil ) then Exit( False );
  if(( FUniqueID > 0 ) and ( FStatus = stLoaded )) then Exit( True );

  { create object record if none exists }

  if( UniqueID = 0 ) then
  begin
    GX_Connector.Execute( 'INSERT INTO tbModel ( FName ) VALUES ( ' + QuotedStr( '' ) + ' );' );
    FUniqueID := GX_Connector.GetLastAutoValue();
  end;

  { save object data }

  ASQL := 'UPDATE tbModel SET ' +
            GX_Connector.SetString(   'FName',          Name,                 True ) +
            GX_Connector.SetVector(   'FCenter',        Center,               True ) +
            GX_Connector.SetInteger(  'FVertexCount',   Vertices.RowCount,    True ) +
            GX_Connector.SetInteger(  'FNormalCount',   Normals.RowCount,     True ) +
            GX_Connector.SetInteger(  'FTexcoordCount', Texcoords.RowCount,   True ) +
            GX_Connector.SetInteger(  'FColorCount',    Colors.RowCount,      False ) +
          'WHERE ( ' +
            'FID = ' + GX_IntToStr( UniqueID ) + ' );';

  GX_Connector.Execute( ASQL );

  { save object data }

  ASet := GX_Connector.GetDataSet( 'SELECT FID, FVertexData, FNormalData, FTexcoordData, FColorData FROM tbModel WHERE FID = ' + IntToStr( UniqueID ) + ';' );

  GX_Connector.SaveArrayToBlob( ASet[ 'FVertexData' ],   Vertices );
  GX_Connector.SaveArrayToBlob( ASet[ 'FNormalData' ],   Normals );
  GX_Connector.SaveArrayToBlob( ASet[ 'FTexcoordData' ], Texcoords );
  GX_Connector.SaveArrayToBlob( ASet[ 'FColorData' ],    Colors );

  SafeFree( ASet );

  { save material }

  if( Materials.Count > 0 ) then
    for i := 0 to Materials.Count - 1 do
      Materials[ i ].Save( UniqueID );

  { save meshes }

  GX_Connector.Execute( 'DELETE * FROM tbMesh WHERE ( FModelID = ' + GX_IntToStr( UniqueID ) + ' );' );

  if( Meshes.Count > 0 ) then
    for i := 0 to Meshes.Count - 1 do
      Meshes[ i ].Save( UniqueID );
  *)
end;

procedure TModel.UpdateSize();
var
  i, v: Integer;
  Vertex: TVector3;
begin
  FMinSize := TVector3.Create(0.0, 0.0, 0.0);
  FMaxSize := TVector3.Create(0.0, 0.0, 0.0);

  if Vertices.RowCount > 0 then
  begin
    FMinSize := Vertices[0].AsFloat3[0];
    FMaxSize := Vertices[0].AsFloat3[0];

    for i := 0 to Vertices.RowCount - 1 do
    begin
      Vertex := Vertices[0].AsFloat3[i];

      for v := 0 to 3 - 1 do
      begin
        if (Vertex.V[v] > FMaxSize.V[v]) then FMaxSize.V[v] := Vertex.V[v];
        if (Vertex.V[v] < FMinSize.V[v]) then FMinSize.V[v] := Vertex.V[v];
      end;
    end;
  end;

  FSize := MaxSize - MinSize;

  { update bounds }

  FBounds[0] := TVector3.Create(MinSize.X, MinSize.Y, MinSize.Z);
  FBounds[1] := TVector3.Create(Minsize.X, MinSize.Y, MaxSize.Z);
  FBounds[2] := TVector3.Create(MaxSize.X, MinSize.Y, MaxSize.Z);
  FBounds[3] := TVector3.Create(MaxSize.X, Minsize.Y, MinSize.Z);
  FBounds[4] := TVector3.Create(MinSize.X, MaxSize.Y, MinSize.Z);
  FBounds[5] := TVector3.Create(Minsize.X, MaxSize.Y, MaxSize.Z);
  FBounds[6] := TVector3.Create(MaxSize.X, MaxSize.Y, MaxSize.Z);
  FBounds[7] := TVector3.Create(MaxSize.X, Maxsize.Y, MinSize.Z);
end;
end.
