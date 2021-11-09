// Copyright (c) 2021 Arsanias (arsaniasbb@gmail.com)
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.Geometry;

interface

uses
  System.Variants, System.Math, System.Classes, Vcl.Dialogs, System.SysUtils,
  Core.Types, Core.Utils, Core.Arrays, Core.Mesh, Core.Model, Core.Shader;

type
  TGeometry = class
    class procedure InitObject(var AModel: TModel; AShapeType: TShapeType ; ASize: TVector3 ; AResolution: Integer);
    class procedure InitCube(var AModel: TModel; CubeSize: TVector3);
    class procedure InitCone(var AModel: TModel; ConeSize: TVector3; Resolution: Integer);
    class procedure InitCylindar(var AModel: TModel ; ASize: TVector3; Resolution: Integer);
    class procedure InitGrid(var AModel: TModel ; ASize: TVector2; AResolution: Integer);
    class procedure InitGridNet(var AModel: TModel ; ASize: TVector3; AResolution: Integer);
    class procedure InitSpiderNet(var AModel: TModel ; Radius: Single; TileCount, LevelCount: Integer);
    class procedure InitTestCross(var AModel: TModel);
    class procedure RecalcNormals(AModel: TModel);
    class function  ProjectPointToPlane(APoint, ANormal: TVector3 ; APlane: TTriangle): TVector3;
    class function  RayInTriangle(ARay: TLine ; V0, V1, V2: TVector3 ; var AWorldPos: TVector3): Boolean; overload;
    class function  RayInTriangle(AOrigin, ADirection: TVector3 ; V0, V1, V2: TVector3; var ATexcoord: TVector2 ; var ADistance: Single): Boolean; overload;
    class procedure AddLine(AModel: TModel ; AMesh: TMesh; V1, V2: TVector3; AColorIndex: Integer);
  end;

implementation

class procedure TGeometry.InitObject(var AModel: TModel; AShapeType: TShapeType ; ASize: TVector3 ; AResolution: Integer);
begin
  case AShapeType of
    stGrid:       InitGrid(     AModel, TVector2.Create(12.0, 12.0), 24);
    stCube:       InitCube(     AModel, ASize);
    stCylindar:   InitCylindar( AModel, ASize, 16);
    stCone:       InitCone(     AModel, ASize, 12);
    stGridNet:    InitGridNet(  AModel, ASize, AResolution);
    stSpiderNet:  InitSpiderNet(AModel, 12, 60, 36);
    stTest:       InitTestCross(AModel);
  end;
end;

class procedure TGeometry.InitCube(var AModel: TModel ; CubeSize: TVector3);
var
  Xdiv2:  Single;
  Zdiv2:  Single;
  Ydiv2:  Single;
  AMesh:  TMesh;
begin
	Xdiv2 := CubeSize.X / 2;
	Zdiv2 := CubeSize.Z / 2;
  Ydiv2 := CubeSize.Y / 2;

  { add vertices }

  AModel.Vertices.RowCount := 8;
  AModel.Vertices[0].AsFloat3[0] := TVector3.Create(-Xdiv2,  Ydiv2, -Zdiv2); // 0 rear left   - upper
  AModel.Vertices[0].AsFloat3[1] := TVector3.Create(-Xdiv2,  Ydiv2,  Zdiv2); // 1 front left  - upper
  AModel.Vertices[0].AsFloat3[2] := TVector3.Create( Xdiv2,  Ydiv2,  Zdiv2); // 2 front right - upper
  AModel.Vertices[0].AsFloat3[3] := TVector3.Create( Xdiv2,  Ydiv2, -Zdiv2); // 3 rear right  - upper
  AModel.Vertices[0].AsFloat3[4] := TVector3.Create(-Xdiv2, -Ydiv2, -Zdiv2); // 4 rear left   - lower
  AModel.Vertices[0].AsFloat3[5] := TVector3.Create(-Xdiv2, -Ydiv2,  Zdiv2); // 5 front left  - lower
  AModel.Vertices[0].AsFloat3[6] := TVector3.Create( Xdiv2, -Ydiv2,  Zdiv2); // 6 front right - lower
  AModel.Vertices[0].AsFloat3[7] := TVector3.Create( Xdiv2, -Ydiv2, -Zdiv2); // 7 rear right  - lower

  { add face indices whereby the 1st value is the position index and the 2nd is the normal index  }

  AMesh := TMesh.Create(ptTriangles, smFlat, [asPosition, asNormal]);
  AModel.Meshes.Add(AMesh);
  AMesh.AddFace(VarArrayOf([0, 0, 1, 0, 2, 0, 0, 0, 2, 0, 3, 0]));  // top
  AMesh.AddFace(VarArrayOf([5, 0, 4, 0, 7, 0, 5, 0, 7, 0, 6, 0]));  // bottom
  AMesh.AddFace(VarArrayOf([5, 0, 1, 0, 0, 0, 5, 0, 0, 0, 4, 0]));  // left
  AMesh.AddFace(VarArrayOf([7, 0, 3, 0, 2, 0, 7, 0, 2, 0, 6, 0]));  // right
  AMesh.AddFace(VarArrayOf([4, 0, 0, 0, 3, 0, 4, 0, 3, 0, 7, 0]));  // front
  AMesh.AddFace(VarArrayOf([6, 0, 2, 0, 1, 0, 6, 0, 1, 0, 5, 0]));  // rear

  AModel.Center := TVector3.Create(0, Ydiv2, 0);
  AModel.Size   := CubeSize;

  RecalcNormals(AModel);
end;

class procedure TGeometry.InitCone(var AModel: TModel ; ConeSize: TVector3; Resolution: Integer);
var
  i, n, j: Integer;
  Y: Single;
  PI2divN:  Single;
  Xdiv2: Single;
  Ydiv2: Single;
  Zdiv2: Single;
  VI: array[0..2] of Integer;
  p_BaseMesh: TMesh;
  p_CoverMesh: TMesh;
begin
	PI2divN := PI2 / Resolution;
  Xdiv2   := ConeSize.X / 2;
  Ydiv2   := ConeSize.Y / 2;
  Zdiv2   := ConeSize.Z / 2;
  Y       := ConeSize.Y;
  n       := Resolution + 2;

  { add vertices }

  AModel.Vertices.RowCount := n;

  p_BaseMesh := TMesh.Create(ptTriangles, smFlat, [asPosition, asNormal]);
  AModel.Meshes.Add(p_BaseMesh);
  p_CoverMesh := TMesh.Create(ptTriangles, smGouraud, [asPosition, asNormal]);
  AModel.Meshes.Add(p_CoverMesh);

	AModel.Vertices[0].AsFloat3[0]     := TVector3.Create(0.00, 0.00,  0.00);  // center at bottom
  AModel.Vertices[0].AsFloat3[n - 1] := TVector3.Create(0.00, Y,     0.00);  // center at top

	for i := 0 to Resolution - 1 do
	begin
		AModel.Vertices[0].AsFloat3[1 + i] := TVector3.Create(Cos(i * PI2divN) * -Xdiv2, 0.00, Sin(i * PI2divN) *  Zdiv2);

		if(i < Resolution) then
		begin
      if((i + 2) >= n - 1) then j := 1 else j := i + 2;

      p_BaseMesh.AddFace( VarArrayOf([0,     0, j,     0, i + 1, 0]));
			p_CoverMesh.AddFace(VarArrayOf([n - 1, 0, i + 1, 0, j,     0]));
		end;
	end;

  RecalcNormals(AModel);

  AModel.Center := TVector3.Create(0, ConeSize.Y/2, 0);
  AModel.Size := ConeSize;
end;

class procedure TGeometry.InitCylindar(var AModel: TModel ; ASize: TVector3; Resolution: Integer);
var
  PI2divN:  Single;
  colDiv:   Single;
  Xdiv2:    Single;
  Zdiv2:    Single;
  AHigh:    Integer;
  i: Integer;
  ALowerMesh: TMesh;
  AUpperMesh: TMesh;
  AOuterMesh:  TMesh;
  v1, v2, v3:  Integer;
  function WrapLower(AValue: Integer): Integer;
  begin
    if(AValue < 1) then Result := Resolution else if(AValue > Resolution) then Result := 1 else Result := AValue;
  end;
  function WrapUpper(AValue: Integer): Integer;
  begin
    if(AValue < Resolution + 1) then Result := AHigh - 1 else if(AValue > AHigh - 1) then Result := Resolution + 1 else Result := AValue;
  end;
begin
	PI2divN := PI2 / Resolution;
	colDiv  := 0.5 / Resolution;
  Xdiv2   := ASize.X / 2;
  Zdiv2   := ASize.Z / 2;
  AHigh   := Resolution * 2 + 2 - 1;

  { add vertices }

  AModel.Vertices.RowCount := Resolution * 2 + 2;
  AHigh := AModel.Vertices.RowCount - 1;

  AModel.Vertices[0].AsFloat3[0]     := TVector3.Create(0.0, 0.0,     0.0);  // bottom center point
	AModel.Vertices[0].AsFloat3[AHigh] := TVector3.Create(0.0, ASize.Y, 0.0);  // top center point

	for i := 0 to Resolution - 1 do
	begin
  	AModel.Vertices[0].AsFloat3[i + 1]              := TVector3.Create(Cos(i * PI2divN) * -Xdiv2, 0.0,     Sin(i * PI2divN) * Zdiv2);
  	AModel.Vertices[0].AsFloat3[i + 1 + Resolution] := TVector3.Create(Cos(i * PI2divN) * -Xdiv2, ASize.Y, Sin(i * PI2divN) * Zdiv2);
	end;

  { add faces }

  ALowerMesh := TMesh.Create(ptTriangles, smGouraud, [asPosition, asNormal]);
  AUpperMesh := TMesh.Create(ptTriangles, smGouraud, [asPosition, asNormal]);
  AOuterMesh := TMesh.Create(ptTriangles, smGouraud, [asPosition, asNormal]);

  AModel.Meshes.Add(ALowerMesh);
  AModel.Meshes.Add(AUpperMesh);
  AModel.Meshes.Add(AOuterMesh);

	for i := 0 to Resolution - 1 do
	begin
    ALowerMesh.AddFace(VarArrayOf([0,                  0, WrapLower(i + 2),              0, WrapLower(i + 1),              0]));
    AUpperMesh.AddFace(VarArrayOf([AHigh,              0, WrapUpper(i + Resolution + 1), 0, WrapUpper(i + Resolution + 2), 0]));

    AOuterMesh.AddFace(VarArrayOf([WrapLower(i + 2), 0, WrapUpper(i + Resolution + 2), 0, WrapUpper(i + Resolution + 1), 0]));
    AOuterMesh.AddFace(VarArrayOf([WrapLower(i + 2), 0, WrapUpper(i + Resolution + 1), 0, WrapLower(i + 1),              0]));
  end;

  AModel.Center := TVector3.Create(0, 0, 0);
  RecalcNormals(AModel);
end;

class procedure TGeometry.InitGrid(var AModel: TModel ; ASize: TVector2; AResolution: Integer);
var
  Xdiv2, Y, Zdiv2: Single;
  XdivN, ZdivN: Single;
  i:      Integer;
  c:      Integer;
  v1, v2: Integer;
  p_Mesh: TMesh;
begin
	Xdiv2 := ASize.X / 2;
	Zdiv2 := ASize.Y / 2;
	XdivN := ASize.X / AResolution;
	ZdivN := ASize.Y / AResolution;

  p_Mesh := TMesh.Create(ptLines, smFlat, [asPosition, asColor]);
  AModel.Meshes.Add(p_Mesh);

  AModel.AddColor(TVector4.Create(0.5, 0.5, 0.5, 1.0)); // grey
  AModel.AddColor(TVector4.Create(0.0, 0.0, 0.0, 1.0)); // black
  AModel.AddColor(TVector4.Create(0.9, 0.0, 0.0, 1.0)); // red
  AModel.AddColor(TVector4.Create(0.0, 0.0, 0.9, 1.0)); // blue

	for i := 0 to AResolution do
	begin
		if(i <> (AResolution / 2)) then
    begin
      AddLine(AModel, p_Mesh, TVector3.Create(-Xdiv2, 0.0, -Zdiv2 + i * ZdivN), TVector3.Create( Xdiv2, 0.0, -Zdiv2 + i * ZdivN), 0); // x axis
      AddLine(AModel, p_Mesh, TVector3.Create(-Xdiv2 + i * XdivN, 0.0, -Zdiv2), TVector3.Create(-Xdiv2 + i * XdivN, 0.0,  Zdiv2), 0); // z axis
    end;
	end;

  { draw colored axis }

  AddLine(AModel, p_Mesh, TVector3.Create(0.0,   0.0, 0.0), TVector3.Create(-Xdiv2, 0.0, 0.0), 1); // x axis
  AddLine(AModel, p_Mesh, TVector3.Create(0.0,   0.0, 0.0), TVector3.Create(Xdiv2, 0.0, 0.0), 2); // x axis
  AddLine(AModel, p_Mesh, TVector3.Create(0.0,   0.0, 0.0), TVector3.Create(0.0, 0.0,-Zdiv2), 1); // z axis
  AddLine(AModel, p_Mesh, TVector3.Create(0.0,   0.0, 0.0), TVector3.Create(0.0, 0.0, Zdiv2), 3); // z axis

  AModel.Center := TVector3.Create(0, 0, 0);
  AModel.Size  := TVector3.Create(ASize.X, 0.0, ASize.Y);
end;

class procedure TGeometry.InitGridNet(var AModel: TModel ; ASize: TVector3; AResolution: Integer);
var
  grdX, grdZ: Single;
  iX, iZ, iV: Integer;
  i: Integer;
  AMesh: TMesh;
begin
  if(AModel = nil) then Exit;

  AModel.Vertices.RowCount := (AResolution + 1) * (AResolution + 1);

  AMesh := TMesh.Create(ptTriangles, smGouraud, [asPosition, asNormal]);
  AModel.Meshes.Add(AMesh);
  AMesh.Faces.RowCount := AResolution * AResolution * 6;

  grdX := ASize.X / AResolution;
	grdZ := ASize.Z / AResolution;

  iV := 0;
	for iZ := 0 to AResolution do
	begin
		for iX := 0 to AResolution do
		begin
      AModel.Vertices[0].AsFloat3[iV] := TVector3.Create(iX * grdX, 0.00, iZ * grdZ);
			Inc(iV);

			if((iX < AResolution) and (iZ < AResolution)) then
      begin
				i := iX * 6 + iZ * AResolution * 6;

        AMesh.Faces[0].AsInteger[i + 0] := iX					       +		      iZ * (AResolution + 1);	// bottom left
				AMesh.Faces[0].AsInteger[i + 1] := iX + AResolution  + 1	+		  iZ * (AResolution + 1);	// upper left
				AMesh.Faces[0].AsInteger[i + 2] := iX + AResolution  + 1	+ 1	+	iZ * (AResolution + 1);	// upper right
				AMesh.Faces[0].AsInteger[i + 3] := iX					       + 1	+	    iZ * (AResolution + 1);	// bottom right
				AMesh.Faces[0].AsInteger[i + 4] := iX					       +		      iZ * (AResolution + 1);	// bottom left
				AMesh.Faces[0].AsInteger[i + 5] := iX + AResolution  + 1	+ 1	+	iZ * (AResolution + 1);	// upper right
			end;
		end;
	end;

  RecalcNormals(AModel);

  AModel.Center  := TVector3.Create(0.00, 0.00, 0.00);
  AModel.Size    := ASize;
end;

// resolution ist die anzahl an quadrat ringen. 1 ist die kleinste einheit und bedeutet
// dass nur ein einziges quadrat existiert. Eine 2 bedeutet, dass ein weiterer ring um
// den ersten quadrat erzeugt werden, also 8 weitere quadrate mit 24 weieren faces.

class procedure TGeometry.InitSpiderNet(var AModel: TModel ; Radius: Single; TileCount, LevelCount: Integer);
var
  I,V,X,Z,L:     Integer;
  iTile:         Integer;
  iLevel:        Integer;
  rTile:         Single;
  Levels:        array of Single;
  rootValue:     Single;
  AMesh:         TMesh;
begin
  AModel.Vertices.RowCount := 1 + (TileCount * LevelCount);

  AMesh := TMesh.Create(ptTriangles, smFlat, [asPosition, asNormal]);
  AModel.Meshes.Add(AMesh);
  AMesh.Faces.RowCount := (TileCount * 3) + (TileCount * (LevelCount - 1) * 6);

  { set distances to center point for each level }

  rootValue := Power(Radius , (1 / LevelCount));
  SetLength(Levels, LevelCount);
  for iLevel := 0 to LevelCount - 1 do
    Levels[iLevel] := Power(rootValue , (iLevel + 1)) - 1;

  { set middle point of spider net }
  AModel.Vertices[0].AsFloat3[0] := TVector3.Create(0.0, 0.0, 0.0);

  { get the degree in radiant per tile }
  rTile := PI2 / TileCount;

  { add vertices and indices for center point }
  V := 1;
  I := 0;
  L := 0;
  for iTile := 0 to TileCount - 1 do
  begin
    AModel.Vertices[0].AsFloat3[V] := TVector3.Create(Cos(iTile * rTile) * Levels[L], 0.00, Sin(iTile * rTile) * -Levels[L]);

    AMesh.Faces[0].AsInteger[I + 0] := 0;
    AMesh.Faces[0].AsInteger[I + 1] := iTile+1;
    AMesh.Faces[0].AsInteger[I + 2] := iTile+2;
    Inc(V);
    Inc(I , 3);
  end;
  Inc(L);
  AMesh.Faces[0].AsInteger[I - 1] := AMesh.Faces[0].AsInteger[I - 1] - TileCount;

  if(LevelCount > 1) then
  begin
    for iLevel := 1 to LevelCount - 1 do
    begin
      { add vertices and indices for outer leves }
      for iTile := 0 to TileCount - 1 do
      begin
        AModel.Vertices[0].AsFloat3[V] := TVector3.Create(Cos(iTile * rTile) * Levels[L], 0.00, Sin(iTile * rTile) * -Levels[L]);

        AMesh.Faces[0].AsInteger[I + 0] := V - TileCount;
        AMesh.Faces[0].AsInteger[I + 1] := V;
        AMesh.Faces[0].AsInteger[I + 2] := V + 1;
        AMesh.Faces[0].AsInteger[I + 3] := V - TileCount;
        AMesh.Faces[0].AsInteger[I + 4] := V + 1;
        AMesh.Faces[0].AsInteger[I + 5] := V + 1 - TileCount;
        Inc(V);
        Inc(I , 6);
      end;
      Inc(L);
      AMesh.Faces[0].AsInteger[I - 2] := AMesh.Faces[0].AsInteger[I - 2] - TileCount * 2;
      AMesh.Faces[0].AsInteger[I - 4] := AMesh.Faces[0].AsInteger[I - 4] - TileCount;
    end;
  end;

  AModel.Center := TVector3.Create(0, 0, 0);

  RecalcNormals(AModel);
end;

class procedure TGeometry.InitTestCross(var AModel: TModel);
var
  AMesh: TMesh;
begin
  AModel.AddVertex(TVector3.Create(-0.9, -0.9, 0.0)); // left lower corner
  AModel.AddVertex(TVector3.Create(0.9,  0.9, 0.0)); // right upper corner
  AModel.AddVertex(TVector3.Create(-0.9,  0.9, 0.0)); // left upper corner
  AModel.AddVertex(TVector3.Create(0.9, -0.9, 0.0)); // left lower corner

  AMesh := TMesh.Create(ptLines, smFlat, [asPosition]);
  AModel.Meshes.Add(AMesh);

  { add face indices whereby the 1st value is the position index and the 2nd is the normal index  }

  AMesh.AddFace(VarArrayOf([0, 1, 2, 3]));  // top

  AModel.Center := TVector3.Create(0, 0, 0);
end;

class procedure TGeometry.AddLine(AModel: TModel ; AMesh: TMesh ; V1, V2: TVector3 ; AColorIndex: Integer);
var
  Vi1, Vi2: Integer;
begin
  Vi1 := AModel.AddVertex(V1);
  vI2 := AModel.AddVertex(V2);

  AMesh.AddFace(VarArrayOf([Vi1, AColorIndex, Vi2, AColorIndex]));
end;

class procedure TGeometry.RecalcNormals(AModel: TModel);
var
  AMesh: TMesh;
  AFaceNormals:   TArray<TVector3>;
  AVertexNormals: TArray<TVector3>;
  AVertexNCounts: TArray<Integer>;
  AVIndex1, AVIndex2, AVIndex3: Integer;
  AVertex1, AVertex2, AVertex3: TVector3;
  AIndexList: TStringList;
  AHex: string;
  i, i_Mesh: Integer;
begin
  if(AModel.Meshes.Count = 0) then Exit;

  for i_Mesh := 0 to AModel.Meshes.Count - 1 do
  begin
    AMesh := AModel.Meshes[i_Mesh];

    if(AMesh.Faces.RowCount > 0) then
    begin
      { create index list to prevent doubles }

      AIndexList := TStringList.Create();
      AIndexList.Sorted := True;

      { set size of temporary normal arrays }

      SetLength(AFaceNormals,   AMesh.FaceCount);
      for i := 0 to High(AFaceNormals)  do AFaceNormals[i] := TVector3.Create(0, 0, 0);

      if(AMesh.ShadeMode = smGouraud) then
      begin
        SetLength(AVertexNormals, AModel.Vertices.RowCount);  for i := 0 to High(AVertexNormals)  do AVertexNormals[i]  := TVector3.Create(0, 0, 0);
        SetLength(AVertexNCounts, AModel.Vertices.RowCount);  for i := 0 to High(AVertexNCounts)  do AVertexNCounts[i]  := 0;
      end;

      for i := 0 to AMesh.FaceCount - 1 do
      begin
        { calculate face normals }

        AVIndex1 := AMesh.Faces[asPosition].AsInteger[i * 3 + 0];
        AVIndex2 := AMesh.Faces[asPosition].AsInteger[i * 3 + 1];
        AVIndex3 := AMesh.Faces[asPosition].AsInteger[i * 3 + 2];

        AVertex1 := AModel.Vertices[0].AsFloat3[AVIndex1];
        AVertex2 := AModel.Vertices[0].AsFloat3[AVIndex2];
        AVertex3 := AModel.Vertices[0].AsFloat3[AVIndex3];

        AFaceNormals[i] := TTriangle.GetNormal(AVertex1, AVertex2, AVertex3);

        { add face normal to vertex and increase counter if smooth shading is set }

        if(AMesh.ShadeMode = smGouraud) then
        begin
          AVertexNormals[AVIndex1] := AVertexNormals[AVIndex1] + AFaceNormals[i];
          AVertexNormals[AVIndex2] := AVertexNormals[AVIndex2] + AFaceNormals[i];
          AVertexNormals[AVIndex3] := AVertexNormals[AVIndex3] + AFaceNormals[i];

          Inc(AVertexNCounts[AVIndex1]);
          Inc(AVertexNCounts[AVIndex2]);
          Inc(AVertexNCounts[AVIndex3]);
        end;
      end;

      { normalize vertex normals if smooth shading is set }

      if(AMesh.ShadeMode = smGouraud) then
        for i := 0 to High(AVertexNormals) do
        begin
          if (AVertexNCounts[i] > 1) then
            AVertexNormals[i] := AVertexNormals[i] / AVertexNCounts[i];
          AVertexNormals[i] := AVertexNormals[i].Normalize;
        end;

      { create normal array }

      AModel.Normals.RowCount := 0;

      case AMesh.ShadeMode of
        smGouraud:
          for i := 0 to AMesh.Faces.RowCount - 1 do
          begin
            AVIndex1 := AMesh.Faces[asPosition].AsInteger[i];
            AHex := AVertexNormals[AVIndex1].ToHex;
            if(not AIndexList.Find(AHex, AVIndex2)) then
            begin
              AVIndex3 := AModel.Normals.RowCount;
              AModel.AddNormal(AVertexNormals[AVIndex1]);
              AIndexList.AddObject(AHex, Pointer(AVIndex3));
            end
            else
              AVIndex3 := UInt32(AIndexList.Objects[AVIndex2]);
            AMesh.Faces[asNormal].AsInteger[i] := AVIndex3;
          end;
        smFlat:
          for i := 0 to AMesh.FaceCount - 1 do
          begin
            AHex := AFaceNormals[i].ToHex;
            if(not AIndexList.Find(AHex, AVIndex2)) then
            begin
              AVIndex3 := AModel.Normals.RowCount;
              AModel.AddNormal(AFaceNormals[i]);
              AIndexList.AddObject(AHex, Pointer(AVIndex3));
            end
            else
              AVIndex3 := UInt32(AIndexList.Objects[AVIndex2]);
            AMesh.Faces[asNormal].AsInteger[i * 3 + 0] := AVIndex3;
            AMesh.Faces[asNormal].AsInteger[i * 3 + 1] := AVIndex3;
            AMesh.Faces[asNormal].AsInteger[i * 3 + 2] := AVIndex3;
          end;
      end;

      SetLength(AFaceNormals,    0);
      SetLength(AVertexNormals,  0);
      SetLength(AVertexNCounts,  0);

      SafeFree(AIndexList);
    end;
  end;
end;

class function TGeometry.ProjectPointToPlane(APoint, ANormal: TVector3 ; APlane: TTriangle): TVector3;
begin
  //Result := APoint - GX_VectorDotProduct(APoint - APlane, ANormal) * ANormal;
end;

class function TGeometry.RayInTriangle(ARay: TLine ; V0, V1, V2: TVector3 ; var AWorldPos: TVector3): Boolean;
var
  ANormal, AIntersectPos, vTest: TVector3;
  Dist1, Dist2: Single;
begin
   // Find Triangle Normal
   ANormal := TTriangle.GetNormal(V0, V1, V2);

   // Find distance from LP1 and LP2 to the plane defined by the triangle
   Dist1 := (ARay.V1 - V0).DotProduct(ANormal);
   Dist2 := (ARay.V2 - V0).DotProduct(ANormal);

   if((Dist1 * Dist2) >= 0.0) then Exit(False);  // line doesn't cross the triangle.
   if (Dist1 = Dist2)           then Exit(False);  // line and plane are parallel

   // Find point on the line that intersects with the plane
   AIntersectPos := (ARay.V1 + (ARay.V2 - ARay.V1)) * (-Dist1 / (Dist2 - Dist1));

   // Find if the interesection point lies inside the triangle by testing it against all edges
   vTest := ANormal.CrossProduct(V1 - V0);
   if (vTest.DotProduct(AIntersectPos - V0) < 0.0) then Exit(False);

   vTest := ANormal.CrossProduct(V2 - V1);
   if (vTest.DotProduct(AIntersectPos - V1) < 0.0) then Exit(False);

   vTest := ANormal.CrossProduct(V0 - V2);
   if (vTest.DotProduct(AIntersectPos - V0) < 0.0) then Exit(False);

   AWorldPos  := AIntersectPos;
   Result     := True;
end;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// checks for interesection between a ray and a triangle
// example is based on the Microsoft DirectX SDK, "PICK10" sample
//
class function TGeometry.RayInTriangle(AOrigin, ADirection: TVector3 ; V0, V1, V2: TVector3 ; var ATexcoord: TVector2 ; var ADistance: Single): Boolean;
var
  edge1, edge2: TVector3;
  pvec, tvec, qvec: TVector3;
  det, finvdet: Single;
begin
  // Find vectors for two edges sharing vert0
  edge1 := v1 - v0;
  edge2 := v2 - v0;

  // Begin calculating determinant - also used to calculate U parameter
  pvec := ADirection.CrossProduct(edge2);

  // If determinant is near zero, ray lies in plane of triangle
  det := edge1.DotProduct(pvec);

  if(det > 0) then
      tvec := AOrigin - v0
  else
  begin
      tvec := v0 - AOrigin;
      det  := -det;
  end;

  if(det < 0.0001) then Exit(False);

  // Calculate U parameter and test bounds
  ATexcoord.U := tvec.DotProduct(pvec);
  if((ATexcoord.U < 0.0) or (ATexcoord.U > det)) then Exit(False);

  // Prepare to test V parameter
  qvec := tvec.CrossProduct(edge1);

  // Calculate V parameter and test bounds
  ATexcoord.V := ADirection.DotProduct(qvec);
  if((ATexcoord.V < 0.0) or (ATexcoord.U + ATexcoord.V > det)) then Exit(False);

  // Calculate t, scale parameters, ray intersects triangle
  ADistance   := edge2.DotProduct(qvec);
  fInvDet     := 1.0 / det;
  ADistance   := ADistance   * fInvDet;
  ATexcoord.U := ATexcoord.U * fInvDet;
  ATexcoord.V := ATexcoord.V * fInvDet;

  Result := True;
end;

end.
