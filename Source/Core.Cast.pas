unit
  Core.Cast;

interface

uses
  System.Classes, System.SysUtils, System.StrUtils,
  Core.Types, Core.Utils, Core.Arrays, Core.Messages, Core.Material, Core.Mesh, Core.Model,
  Core.RenderDevice, unCamera;

type
  TCastType = (ctUnknown, ctModel, ctTerrain, ctFont);

  TCast = class
  private
    FUniqueID: Cardinal;
    FStatus: TGX_Status;
    FModel: TModel;
    FText: string;
    FName: string;
    FParent: TCast;
    FParentMatrix: TMatrix;
    FPosition: TVector3;
    FRotation: TVector3;
    FScale: TVector3;
    FStartPosition: TVector3;
    FStartRotation: TVector3;
    FStartScale: TVector3;
    FWorldMatrix: TMatrix;
    FNormalMatrix: TMatrix;
    FViewMode: TGX_ViewMode;
    FCastType: TCastType;
    FVisible: Boolean;
    FChilds: TGX_NodeList<TCast>;
    procedure Clear();
    function GetIBufferIndex(): Integer;
    function GetVBufferIndex(): Integer;
    procedure SetModel(AModel: TModel );
    procedure SetPosition( V: TVector3 );
    procedure SetRotation( V: TVector3 );
    procedure SetScale( V: TVector3 );
    procedure SetStartPosition( V: TVector3 );
    procedure SetStartRotation( V: TVector3 );
    procedure SetStartScale( V: TVector3 );
  public
    constructor Create(AModel: TModel; AName: string);
    destructor Destroy; override;
    function Load( AUniqueID: Cardinal ; AObjectList: TModelList ): Boolean;
    function Prepare( ADevice: TRenderDevice): Boolean;
    procedure Render( ADevice: TRenderDevice ; ACamera: TCamera );
    function Save( ASceneID: Cardinal ): Boolean;
    procedure Uncast();
    procedure UpdateMatrix();
  public
    property Childs:         TGX_NodeList<TCast>  read FChilds;
    property Name:           string                  read FName              write FName;
    property Parent:         TCast                read FParent write FParent;
    property Position:       TVector3              read FPosition          write SetPosition;
    property Rotation:       TVector3              read FRotation          write SetRotation;
    property Scale:          TVector3              read FScale             write SetScale;
    property StartPosition:  TVector3              read FStartPosition     write SetStartPosition;
    property StartRotation:  TVector3              read FStartRotation     write SetStartRotation;
    property StartScale:     TVector3              read FStartScale        write SetStartScale;
    property VertexMatrix:   TMatrix              read FWorldMatrix;
    property VBufferIndex:   Integer                 read GetVBufferIndex;
    property IBUfferIndex:   Integer                 read GetIBufferIndex;
    property NormalMatrix:   TMatrix              read FNormalMatrix;
    property Model:          TModel                  read FModel             write SetModel;
    property Text:           string                  read FText              write FText;
    property CastType:       TCastType            read FCastType;
    property UniqueID:       Cardinal                read FUniqueID;
    property ViewMode:       TGX_ViewMode            read FViewMode          write FViewMode;
    property Visible:        Boolean                 read FVisible           write FVisible;
  end;
  TCastList = TGX_NodeList<TCast>;

implementation

constructor TCast.Create(AModel: TModel; AName: string);
begin
  inherited Create();

  FName     := AName;
  FVisible  := True;
  FCastType := ctUnknown;

  FChilds := TCastList.Create();

  { initialize space }

  FPosition := TVector3.Create( 0.0, 0.0, 0.0 );
  FRotation := TVector3.Create( 0.0, 0.0, 0.0 );
  FScale    := TVector3.Create( 1.0, 1.0, 1.0 );

  UpdateMatrix();

  FUniqueID     := 0;
  FVisible      := True;
  FStatus       := stCreated;

  SetModel(AModel);
end;

destructor TCast.Destroy();
begin
  Clear();

  SafeFree(FChilds);

  inherited Destroy();
end;

procedure TCast.Clear();
begin
  FChilds.Clear();
end;

function TCast.GetIBufferIndex(): Integer;
begin
  Result := FModel.IBufferIndex;
end;

function TCast.GetVBufferIndex(): Integer;
begin
  Result := FModel.VBufferIndex;
end;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Ein Cast kann nur in einer Scene existieren. Es macht keinen Sinn, einzelne Casts abzuspeichern, weil sie abhängig
// von einer Scene, der Position und Lage und dem Zustand dort sind. Daher sollte das Laden eines Casts aus einem
// Projekt und einer Scene heraus geschehen. Objekte, die bereits im Projekt vorhanden ( oder geladen ) sind, werden den
// einzelnen Casts und somit auch der Scene zugeordnet. Deshalb muss diese Objekt-Liste mitgegeben werden.
//
function TCast.Load( AUniqueID: Cardinal; AObjectList: TModelList): Boolean;
var
  //ASet: TGX_DataSet;
  i:    Integer;
begin
  (*
  if(( GX_Connector = nil ) or ( AUniqueID = 0 ) or ( AObjectList = nil )) then Exit( False );

  { suche nach dem Objekt in der Liste doch verlasse die Funktion, wenn keins gefunden }

  ASet := GX_Connector.GetDataSet( 'SELECT * FROM tbCast WHERE ( FID = ' + IntToStr( AUniqueID ) + ' );' );
  try
    FName := ASet[ 'FName' ].AsString;

    StartPosition := GX_Connector.GetFloat3( ASet, 'FPosition' );
    StartRotation := GX_Connector.GetFloat3( ASet, 'FRotation' );
    StartScale    := GX_Connector.GetFloat3( ASet, 'FScale' );

    { link object to cast }

    for i := 0 to AObjectList.Count - 1 do
    if( AObjectList[ i ].UniqueID = ASet[ 'FObjectID' ].AsInteger ) then
    begin
      SetObject( AObjectList[ i ]);
      Break;
    end;
    UpdateMatrix();
  except
    SafeFree( ASet );
    FUniqueID := 0;
    FStatus   := stCreated;
    Exit( False );
  end;
  SafeFree( ASet );

  FUniqueID := AUniqueID;
  FStatus   := stLoaded;
  *)
end;

function TCast.Prepare(ADevice: TRenderDevice): Boolean;
var
  i: Integer;
  ACastVertexArray: TGX_Array;
  AVertexArray: TGX_Array;
  AIndexArray: TGX_Array;
  AIndexList: TStringList;
  AMaterial: TGX_Material;
  ASemantics: TGX_Semantics;
  AMesh: TMesh;
begin
  { do not continue if object is corrupt }

  if( FModel = nil ) then Exit( False );

  (* TODO - Cast Unit should be independant, to not crosslink too much units
     Removeed the Font-Unit... need to find another solution here to identify
     a Font-Model

  if( CastType = ctFont ) then
  begin
    TGX_Font( FModel ).Print( Position, Rotation, Text );

    if( VBufferIndex < 0 ) then
      FModel.VBufferIndex := ADevice.CreateVertexBuffer( FModel.VertexArray )
    else
      ADevice.UpdateVertexBuffer( VBufferIndex, FModel.VertexArray );

    if (IBUfferIndex < 0) then
      FModel.IBufferIndex := ADevice.CreateIndexBuffer(FModel.IndexArray);

    if( FModel.Materials[ 0 ].DiffuseMap.RBufferIndex < 0 ) then
      FModel.Materials[ 0 ].DiffuseMap.RBufferIndex := ADevice.CreateResourceBuffer( FModel.Materials[ 0 ].DiffuseMap );

    Exit( True );
  end;
  *)

  if( VBufferIndex >= 0 ) then Exit( False );

  { create resources and cast object }

  ACastVertexArray  := nil;
  AVertexArray      := nil;
  AIndexArray       := nil;
  AIndexList        := TStringList.Create();
  AIndexList.Sorted := True;

  if( FModel.Meshes.Count > 0 ) then
  begin
    { store the semantics of the first mesh }

    ASemantics := FModel.Meshes[ 0 ].Semantics;
    ACastVertexArray := TGX_Array.Create( ASemantics );

    for i := 0 to FModel.Meshes.Count - 1 do
    begin
      AMesh := FModel.Meshes[i];

      if(( AMesh.Indexed = True ) and ( AMesh.Semantics = ASemantics )) then
      begin
        {  add mesh data to existing vertex array and use index }

        SafeFree( AIndexArray );
        AIndexArray := TGX_Array.Create([ asIndex ]);
        FModel.GetBuffer(AMesh, ACastVertexArray, AIndexArray, AIndexList);
        FModel.Meshes[i].IBufferIndex := ADevice.CreateIndexBuffer( AIndexArray );
      end
      else
      begin
        { create new vertex array and add non-indexed mesh data }

        SafeFree( AVertexArray );
        AVertexArray := TGX_Array.Create( AMesh.Semantics );
        FModel.GetBuffer(AMesh, AVertexArray, nil, nil );
        FModel.Meshes[i].VBufferIndex := ADevice.CreateVertexBuffer( AVertexArray );
      end;
    end;
  end;

  { create vertex buffer }

  if( ACastVertexArray.RowCount > 0 ) then
    FModel.VBufferIndex := ADevice.CreateVertexBuffer( ACastVertexArray );

  { create material resources }

  if( FModel.Materials.Count > 0 ) then
  begin
    for i := 0 to FModel.Materials.Count - 1 do
    begin
      AMaterial := FModel.Materials[ i ];
      if( FModel.Materials[ i ].DiffuseMap <> nil ) then
        AMaterial.DiffuseMap.RBufferIndex := ADevice.CreateResourceBuffer( AMaterial.DiffuseMap );
    end;
  end;

  { free temporary data }

  SafeFree( ACastVertexArray );
  SafeFree( AVertexArray );
  SafeFree( AIndexArray );
  SafeFree( AIndexList );

  Result := True;
end;

procedure TCast.Render( ADevice: TRenderDevice ; ACamera: TCamera );
var
  AModel: TModel;
  i: Integer;
  AMesh: TMesh;
  ASemantics: TGX_Semantics;
  AMaterial: TGX_Material;
  AShaderIndex: Integer;
  AVBufferIndex: Integer;
begin
  { set projection mode }

  if (ViewMode = vmCamera) then
    ADevice.SetMainMatrix(ACamera.Matrix, ADevice.PerspMatrix)
  else
    ADevice.SetMainMatrix(TMatrix.Identity, ADevice.PerspMatrix);

  ADevice.SetCastMatrix( Position, FWorldMatrix, FNormalMatrix );

  case CastType of
    //ctFont: // TODO - See previous comment - need to identify a Font differerently
    //  ADevice.Render( FModel.Materials[ 0 ], 6, ptTriangles, FModel.VBufferIndex, FModel.IBufferIndex, TGX_Font( FModel ).PrintCount * 6 );
    ctModel:
      begin
        AModel := Model;

        for i := 0 to AModel.Meshes.Count - 1 do
        begin
          AMesh := AModel.Meshes[ i ];

          if( AMesh.Visible = True ) then
          begin
            if( AMesh.Material = nil ) then AMaterial := AModel.Materials[ 0 ] else AMaterial := AMesh.Material;

            ASemantics := AMesh.Semantics;
            if( ADevice.RasterMode = rmWireframe ) then
              ASemantics := ASemantics - [ asNormal ];
            if(( ADevice.ShaderMode = smBlank ) or ( ADevice.RasterMode = rmWireframe )) then
            begin
              ASemantics := ASemantics - [ asTexcoord ];
              ADevice.SetColors(TVector4.Create( 0.0, 0.0, 0.0, 1 ), TVector4.Create( 0.0, 0.0, 0.0, 1.0 ), TVector4.Create( 1, 1, 1, 1 ));
            end;

            if( AModel.ShapeType <> stGridNet ) then
              AShaderIndex  := ADevice.GetShaderIndex( ASemantics, AMaterial.DiffuseMap )
            else
            begin
              if( AModel.Materials[ 0 ].DiffuseMap <> nil ) then
                AShaderIndex := 5
              else
                AShaderIndex := 1;
            end;

            ADevice.SetCastMatrix( Position, FWorldMatrix, FNormalMatrix );

            if( VBufferIndex >= 0 ) then
              AVBufferIndex := VBufferIndex
            else
              AVBufferIndex := AMesh.VBufferIndex;

            ADevice.Render(AMaterial, AShaderIndex, AMesh.Topology, AVBufferIndex, AMesh.IBufferIndex, 0, AMesh.Stripes);
          end;
        end;
      end;
  end;
end;

function TCast.Save( ASceneID: Cardinal ): Boolean;
var
  i: Integer;
  ASQL: string;
  //ASet: TGX_DataSet;
begin
  (*
  if( GX_Connector = nil ) then Exit( False );

  { save object first }

  if( FModel <> nil ) then FModel.Save();

  { create database record if none exists }

  if( UniqueID = 0 ) then
  begin
    GX_Connector.Execute( 'INSERT INTO tbCast ( FSceneID, FModelID, FName ) VALUES ( 0, 0, '''' );' );
    FUniqueID := GX_Connector.GetLastAutoValue();
  end;

  { save cast }

  ASQL := 'UPDATE tbCast SET ' +
            GX_Connector.SetInteger(  'FSceneID',   ASceneID,           True )  +
            GX_Connector.SetInteger(  'FModelID',  FModel.UniqueID,   True )  +
            GX_Connector.SetString(   'FName',      FName,              True )  +
            GX_Connector.SetVector(   'FPosition',  FPosition,          True )  +
            GX_Connector.SetVector(   'FRotation',  FRotation,          True )  +
            GX_Connector.SetVector(   'FScale',     FScale,             False ) +
          'WHERE ( FID = ' + GX_IntToStr( UniqueID ) + ' );';
  GX_Connector.Execute( ASQL );

  SafeFree( ASet );

  FStatus := stLoaded;
  *)
end;

procedure TCast.SetModel(AModel: TModel);
begin
  FModel := AModel;
  UpdateMatrix();

  if( AModel = nil ) then
    FCastType := ctUnknown
  else
  if( AModel.ClassType = TModel ) then
    FCastType := ctModel
  else

  // TODO - See previous comments - need to Identify a Font differently

  //if( AModel.ClassType = TGX_Font ) then
  //  FCastType := ctFont
  //else
    FCastType := ctUnknown;
end;

procedure TCast.SetPosition( V: TVector3 );
begin
  FPosition := V;
  UpdateMatrix();
end;

procedure TCast.SetStartPosition( V: TVector3 );
begin
  FStartPosition := V;
  Position := V;
end;

procedure TCast.SetStartRotation( V: TVector3 );
begin
  FStartRotation := V;
  Rotation := V;
end;

procedure TCast.SetStartScale( V: TVector3 );
begin
  FStartScale := V;
  Scale := V;
end;

procedure TCast.SetRotation( V: TVector3 );
begin
  FRotation := V;
  UpdateMatrix();
end;

procedure TCast.SetScale( V: TVector3 );
begin
  FScale := V;
  UpdateMatrix();
end;

procedure TCast.Uncast();
var
  i: Integer;
begin
  with Model do
  begin
    VBufferIndex := -1;

    if (Meshes.Count > 0) then
      for i := 0 to Meshes.Count - 1 do
      begin
        Meshes[0].VBufferIndex := -1;
        Meshes[0].IBufferIndex := -1;
      end;

    if (Materials.Count > 0 ) then
      for i := 0 to Model.Materials.Count - 1 do
      begin
        if (Materials[i].AmbientMap <> nil) then Materials[i].AmbientMap.RBufferIndex := -1;
        if (Materials[i].DiffuseMap <> nil) then Materials[i].DiffuseMap.RBufferIndex := -1;
        if (Materials[i].SpecularMap <> nil) then Materials[i].SpecularMap.RBufferIndex := -1;
        if (Materials[i].NormalMap <> nil) then Materials[i].NormalMap.RBufferIndex := -1;
      end;
  end;
end;

procedure TCast.UpdateMatrix();
var
  AVertexMatrix: TMatrix;
  ANormalMatrix: TMatrix;
  i: Integer;
begin
  AVertexMatrix := TMatrix.Identity;
  if( Model = nil ) then Exit;

  { before rotating, translate shape to its mass point }

  AVertexMatrix := AVertexMatrix * TMatrix.Translation(TVector3.Create(-FModel.Center.X, -FModel.Center.Y, -FModel.Center.Z));
  ANormalMatrix := AVertexMatrix;

  { scale shape if scaling factors available - but do not scale normal matrix !! }

  AVertexMatrix := AVertexMatrix * TMatrix.Scaling(FScale);

  { rotate shape in order Y, X and Z and around its mass point }

  AVertexMatrix := AVertexMatrix * TMatrix.YawPitchRoll(Rotation.Y, Rotation.X, Rotation.Z);
  ANormalMatrix := ANormalMatrix * TMatrix.YawPitchRoll(Rotation.Y, Rotation.X, Rotation.Z);

  { after rotating, translate shape back to its zero point }

  AVertexMatrix := AVertexMatrix * TMatrix.Translation(FModel.Center);
  ANormalMatrix := ANormalMatrix * TMatrix.Translation(FModel.Center);

  { translate shape to its intended position }

  AVertexMatrix := AVertexMatrix * TMatrix.Translation(Position);
  ANormalMatrix := ANormalMatrix * TMatrix.Translation(Position);

  FWorldMatrix  := AVertexMatrix;
  FNormalMatrix := ANormalMatrix;

  { update this matrix with parent and child matrices }

  if (FParent <> nil) then FWorldMatrix := FWorldMatrix * FParent.VertexMatrix;

  if( Childs.Count > 0 ) then
    for i := 0 to Childs.Count - 1 do
      Childs[ i ].UpdateMatrix();
end;

end.
