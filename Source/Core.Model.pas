// Copyright (c) 2021 Arsanias (arsaniasbb@gmail.com)
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.Model;

interface

uses
  System.Types, System.Variants, System.Math, System.Classes, System.SysUtils,
  Vcl.Forms, Vcl.Dialogs, Vcl.Graphics,
  Core.Types, Core.Utils, Core.Arrays, Core.Material, Core.Mesh, Core.Shader;

type
  TShapeType = (stUnknown, stTest, stGrid, stGridNet, stCube, stCone, stCylindar, stSphere, stTorus, stPyramide, stSpiderNet, stModel);

  TModel = class
  private
    FDirection: TVector3;
    FBounds: array[0..7] of TVector3;
    FShapeType: TShapeType;
  protected
    FCenter: TVector3;
    FVertices: TShaderArray;
    FNormals: TShaderArray;
    FTexcoords: TShaderArray;
    FColors: TShaderArray;
    FVertexArray: TShaderArray;
    FIndexArray: TShaderArray;
    FMeshes: TNodeList<TMesh>;
    FMaterials: TNodeList<TMaterial>;
    FSize: TVector3;
    FVBufferIndex: Integer;
    FIBufferIndex: Integer;
    FMinSize: TVector3;
    FMaxSize: TVector3;
  public
    constructor Create(ADefaultMaterial: LongBool);
    destructor Destroy; override;
    procedure Clear;
    function AddVertex(AVertex: TVector3): DWord;
    function AddNormal(ANormal: TVector3): DWord;
    function AddTexcoord(ATexcoord: TVector2): DWord;
    function AddColor(AColor: TVector4): DWord;
    procedure GetBuffer(AMesh: TMesh; AVertexArray, AIndexArray: TShaderArray; AIndexList: TStringList);
    function Load(AUniqueID: Cardinal): Boolean; virtual; abstract;
    function Save: Boolean; virtual; abstract;
    property Direction: TVector3 read FDirection;
    property ShapeType: TShapeType read FShapeType;
    //property Skeleton: TGX_Skeleton read FSkeleton write FSkeleton;
    procedure UpdateSize;
  public
    property Center: TVector3 read FCenter write FCenter;
    property VertexArray: TShaderArray read FVertexArray;
    property IndexArray: TShaderArray read FIndexArray;
    property Vertices: TShaderArray read FVertices;
    property Normals: TShaderArray read FNormals;
    property Texcoords: TShaderArray read FTexcoords write FTexcoords;
    property Colors: TShaderArray read FColors;
    property Meshes: TNodeList<TMesh> read FMeshes;
    property Materials: TMaterialList  read FMaterials;
    property Size: TVector3 read FSize write FSize;
    property IBufferIndex: Integer read FIBufferIndex write FIBufferIndex;
    property VBufferIndex: Integer read FVBufferIndex write FVBufferIndex;
    property MinSize: TVector3 read FMinSize;
    property MaxSize: TVector3 read FMaxSize;
  end;

implementation

constructor TModel.Create(ADefaultMaterial: LongBool);
var
  AMaterial: TMaterial;
begin
  inherited Create();

  { set basic values }

  FVBufferIndex := -1;

  FMaterials := TMaterialList.Create();
  FMeshes := TNodeList<TMesh>.Create();

  { create arrays }

  FVertices := TShaderArray.Create([asPosition]);
  FNormals := TShaderArray.Create([asNormal]);
  FColors := TShaderArray.Create([asColor]);
  FTexcoords := TShaderArray.Create([asTexcoord]);

  { create default material }

  if (ADefaultMaterial = True) then
  begin
    AMaterial := TMaterial.Create();
    FMaterials.Add(AMaterial);
  end;
end;

destructor TModel.Destroy();
begin
  Clear;

  SafeFree(FVertices);
  SafeFree(FNormals);
  SafeFree(FColors);
  SafeFree(FTexcoords);
  SafeFree(FMaterials);

  inherited Destroy;
end;

procedure TModel.Clear();
var
  i: Integer;
  AMaterial: TMaterial;
begin
  { clear vector arrays }

  FVertices.Clear();
  FNormals.Clear();
  FTexcoords.Clear();
  FColors.Clear();

  { clear meshes }

  if (Meshes.Count > 0) then
    for i := 0 to Meshes.Count - 1 do
      FMeshes[i].Free;
  Meshes.Clear();

  { clear materials }

  if (FMaterials.Count > 0) then
    for i := 0 to FMaterials.Count - 1 do
      FMaterials[i].Free;
  FMaterials.Clear;
end;

function TModel.AddVertex(AVertex: TVector3): DWord;
var
  i: Integer;
begin
  if (Vertices.RowCount > 0) then
    for i := 0 to Vertices.RowCount - 1 do
      if (FVertices[0].AsFloat3[i] = AVertex) then Exit(i);

  Result := FVertices.RowCount;
  FVertices.RowCount := FVertices.RowCount + 1;
  FVertices[0].AsFloat3[Result] := AVertex;
end;

function TModel.AddNormal(ANormal: TVector3): DWord;
begin
  Result := FNormals.RowCount;
  FNormals.RowCount := FNormals.RowCount + 1;
  FNormals[0].AsFloat3[Result] := ANormal;
end;

function TModel.AddTexcoord(ATexcoord: TVector2): DWord;
begin
  Result := FTexcoords.RowCount;
  FTexcoords.RowCount := FTexcoords.RowCount + 1;
  FTexcoords[0].AsFloat2[Result] := ATexcoord;
end;

function TModel.AddColor(AColor: TVector4): DWord;
begin
  Result := FColors.RowCount;
  FColors.RowCount := FColors.RowCount + 1;
  FColors[0].AsFloat4[Result] := AColor;
end;

procedure TModel.GetBuffer(AMesh: TMesh; AVertexArray, AIndexArray: TShaderArray ; AIndexList: TStringList);
var
  ACol, iFace: Integer;
  AIndex: Integer;
  AKeyIndex: Integer;
  AHex: string;
begin
  if ((AMesh.Faces = nil) or (AMesh.Faces.FieldCount = 0) or (AMesh.Faces.RowCount = 0)) then Exit;
  if (AVertexArray = nil) then Exit;

  { fill vertex buffer }

  for iFace := 0 to AMesh.Faces.RowCount - 1 do
  begin
    if (AMesh.Indexed) then
    begin
      if ((AIndexArray = nil) or (AIndexList = nil)) then Exit;

      if (AIndexArray.FieldCount = 0) then
        AIndexArray.AddField(asUnknown, '', 4);

      AHex := AMesh.Faces.AsHex(iFace);
      if (not AIndexList.Find(AHex, AKeyIndex)) then
      begin
        AKeyIndex := AVertexArray.RowCount;
        AIndexList.AddObject(AHex, Pointer(AKeyIndex));
        AVertexArray.RowCount := AVertexArray.RowCount + 1;

        for ACol := 0 to AMesh.Faces.FieldCount - 1 do
        begin
          AIndex := AMesh.Faces.Fields[ACol].AsInteger[iFace];
          case AMesh.Faces[ACol].Semantic of
            asPosition: AVertexArray[asPosition].AsFloat3[AKeyIndex] := Vertices[0].AsFloat3[AIndex];
            asNormal: AVertexArray[asNormal].AsFloat3[AKeyIndex] := Normals[0].AsFloat3[AIndex];
            asColor: AVertexArray[asColor].AsFloat4[AKeyIndex] := Colors[0].AsFloat4[AIndex];
            asTexcoord: AVertexArray[asTexcoord].AsFloat2[AKeyIndex] := Texcoords[0].AsFloat2[AIndex];
          end;
        end;
      end
      else
        AKeyIndex := Integer(AIndexList.Objects[AKeyIndex]);

      AIndex := AIndexArray.RowCount;
      AIndexArray.RowCount := AIndexArray.RowCount + 1;
      AIndexArray[0].AsInteger[AIndex] := AKeyIndex;
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

procedure TModel.UpdateSize;
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
