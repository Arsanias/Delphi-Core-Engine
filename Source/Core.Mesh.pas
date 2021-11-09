// Copyright (c) 2021 Arsanias (arsaniasbb@gmail.com)
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.Mesh;

interface

uses
  System.Types, System.Variants, System.Math, System.Classes, System.SysUtils,
  Vcl.Forms, Vcl.Dialogs, Vcl.Graphics,
  Core.Types, Core.Arrays, Core.Material, Core.RenderDevice, Core.Shader;

type
  TMesh = class
  private
    FMaterial: TMaterial;
    FBlendState: TBlendState;
    FFaces: TShaderArray;
    FFaceIndex: Integer;
    FPolyCount: Integer;
    FTopology: TVertexTopology;
    FIndexed: Boolean;
    FShaderIndex: Integer;
    FSemantics: TShaderSemantics;
    FVisible: LongBool;
    FShadeMode: TShadeMode;
    function GetFaceCount: Integer;
    function GetFieldCount: Integer;
    function GetFieldOffset(ASemantic: TShaderSemantic): Integer;
  public
    IndexSize: Integer;
    property Topology: TVertexTopology read FTopology;
    property FaceCount: Integer read GetFaceCount;
    property FieldCount: Integer read GetFieldCount;
    property ShaderIndex: Integer read FShaderIndex write FShaderIndex;
    property PolyCount: Integer read FPolyCount;
    property Semantics: TShaderSemantics read FSemantics;
    property Faces: TShaderArray read FFaces;
    function GetFaceIndex(AFace, APolygon: Integer; ASemantic: TShaderSemantic): Integer;
    function GetStride: Integer;
    procedure SetFaceIndex(AFace, APolygon: Integer; ASemantic: TShaderSemantic; AIndex: Integer);
  public
    VBufferIndex: Integer;
    IBufferIndex: Integer;
    Stripes: TInstanceArray;
    constructor Create(ATopology: TVertexTopology; AShadeMode: TShadeMode; ASemantics: TShaderSemantics);
    destructor Destroy; override;
    procedure AddFace(AElements: Variant);
    function AddSemantic(ASemantic: TShaderSemantic): LongBool;
  public
    property BlendState: TBlendState read FBlendState write FBlendState;
    property Indexed: Boolean read FIndexed write FIndexed;
    property Stride: Integer read GetStride;
    property Material: TMaterial read FMaterial write FMaterial;
    property ShadeMode: TShadeMode read FShadeMode write FShadeMode;
    property Visible: LongBool read FVisible write FVisible;
  end;

implementation

constructor TMesh.Create(ATopology: TVertexTopology; AShadeMode: TShadeMode; ASemantics: TShaderSemantics);
begin
  inherited Create;

  FShadeMode    := AShadeMode;
  FFaceIndex    := 0;
  FIndexed      := False;
  FTopology     := ATopology;
  FFaces        := TShaderArray.Create();
  FVisible      := True;
  VBufferIndex  := -1;
  IBufferIndex  := -1;

  { add field semantics - position is the minimum required semantic }

  AddSemantic(asPosition);

  if (asNormal    in ASemantics) then AddSemantic(asNormal);
  if (asTexcoord  in ASemantics) then AddSemantic(asTexcoord);
  if (asColor     in ASemantics) then AddSemantic(asColor);
  if (asBoneIndex in ASemantics) then AddSemantic(asBoneIndex);
end;

destructor TMesh.Destroy();
begin
  FFaces.Free;
  inherited Destroy();
end;

function TMesh.AddSemantic(ASemantic: TShaderSemantic): LongBool;
var
  F: TShaderArrayField;
begin
  if (ASemantic in FSemantics) then Exit;
  try
    F := FFaces.AddField(ASemantic, '', SizeOf(Integer));
  except
    Exit(False);
  end;
  Result := (F <> nil);
  FSemantics := FSemantics + [ASemantic];
end;

procedure TMesh.AddFace(AElements: Variant);
var
  iField, iRow: Integer;
  StartIndex: Integer;
  DataCount:  Integer;
  nRow: Integer;
begin
  if (FFaces = nil) then Exit;

  StartIndex := FFaces.RowCount;
  DataCount  := (VarArrayHighBound(AElements, 1) + 1);

  { count of data must be dividable through column count of mesh }

  if ((DataCount mod FieldCount) > 0) then Exit;

  nRow := DataCount div FieldCount;
  FFaces.RowCount := FFaces.RowCount + nRow;

  for iRow := 0 to nRow - 1 do
    for iField := 0 to FieldCount - 1 do
      FFaces[iField].AsInteger[StartIndex + iRow] := Integer(AElements[iRow * FieldCount + iField]);
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

function TMesh.GetFaceIndex(AFace, APolygon: Integer ; ASemantic: TShaderSemantic): Integer;
var
  n: Integer;
begin
  n := FFaces.FieldIndex(ASemantic);
  Result := FFaces[n].AsInteger[AFace * FPolycount + APolygon];
end;

procedure TMesh.SetFaceIndex(AFace, APolygon: Integer ; ASemantic: TShaderSemantic; AIndex: Integer);
var
  n: Integer;
begin
  n := FFaces.FieldIndex(ASemantic);
  FFaces[n].AsInteger[AFace * FPolyCount + APolygon];
end;

function TMesh.GetFieldCount(): Integer;
begin
  Result := FFaces.FieldCount;
end;

function TMesh.GetFieldOffset(ASemantic: TShaderSemantic): Integer;
begin
  Result := FFaces.FieldIndex(ASemantic);
end;

end.
