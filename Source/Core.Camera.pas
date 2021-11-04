unit
  Core.Camera;

interface

uses
  System.Types,
  Core.Types, Core.Arrays;

type
  TCamera = class(TInterfacedObject, IParameter)
  private
    FUniqueID: Cardinal;
    FStatus: TGX_Status;
    FName: string;
    FRotation: TVector3;
    FDistance: Single;
    FTarget: TVector3;
    FPosition: TVector3;
    FMatrix: TMatrix;
    FMouseSense: Single;
    procedure SetPosition(const APosition: TVector3);
    procedure SetRotation(const ARotation: TVector3);
    procedure SetDistance(const ADistance: Single);
    procedure SetTarget(const ATarget: TVector3);
    function GetDirection(): TVector3;
    procedure UpdateMatrix();
    function GetParameters: TParameterDynArray;
    procedure SetParameters(Parameters: TParameterDynArray);
  public
    constructor Create();
    function Load( AUniqueID: Cardinal ): Boolean;
    procedure Move( const ADir: TVector3 );
    procedure Rotate( const rX, rY, rZ: Single );
    function Save( ASceneID: Cardinal ): Boolean;
    procedure Zoom( const ADelta: Single );
  public
    property UniqueID: Cardinal read FUniqueID;
    property Position: TVector3 read FPosition write SetPosition;
    property Distance: Single read FDistance write SetDistance;
    property Rotation: TVector3 read FRotation write SetRotation;
    property Target: TVector3 read FTarget write SetTarget;
    property Direction:  TVector3 read GetDirection;
    property Matrix: TMatrix read FMatrix;
    property MouseSense: Single read FMouseSense;
  end;
  TCameraList = TGX_NodeList<TCamera>;

implementation

constructor TCamera.Create();
begin
  inherited Create;

  FStatus := stCreated;

	FPosition := TVector3.Create(0.0, 3.0, -3.0);
	FTarget := TVector3.Create(0.0, 0.0,  0.0);
	FRotation := TVector3.Create(0.0, 0.0,  0.0);
	FDistance := (FTarget - FPosition ).Magnitude;
  FMouseSense := 0.003;

  UpdateMatrix;
end;

function TCamera.Load(AUniqueID: Cardinal): Boolean;
var
  ASQL: string;
  i:    Integer;
begin
  (*
  if(( GX_Connector = nil ) or ( AUniqueID = 0 )) then Exit( False );

  ASQL := 'SELECT * FROM tbCamera WHERE ( FID = ' + GX_IntToStr( AUniqueID ) + ' );';

  ASet := GX_Connector.GetDataSet( ASQL );
  try
    FName     := ASet[ 'FName' ].AsString;
    FPosition := GX_Connector.GetFloat3( ASet, 'FPosition' );
    FTarget   := GX_Connector.GetFloat3( ASet, 'FTarget' );
  except
    GX_SafeFree( ASet );
    Exit( False );
  end;

  UpdateMatrix();

  GX_SafeFree( ASet );

  FUniqueID := AUniqueID;
  FStatus   := stLoaded;
  *)
end;

function TCamera.GetParameters: TParameterDynArray;
begin
  SetLength(Result, 3);
  Result[0] := TParameter.Create(0, 'FName', FName);
  //Result[1] := TParameter.Create(1, 'FPosition', FPosition);
  //Result[2] := TParameter.Create(2, 'FTarget',  FTarget);
end;

procedure TCamera.SetParameters(Parameters: TParameterDynArray);
begin
  FName := Parameters[0].Value;
  //FPosition := Parameters[1].Value;
  //FTarget := Parameters[2].Value;
end;

function TCamera.GetDirection(): TVector3;
begin
  Result := (Position - Target).Normalize;
end;

function TCamera.Save( ASceneID: Cardinal ): Boolean;
var
  i: Integer;
  ASQL: string;
begin
  (*
  if(( GX_Connector = nil ) or ( ASceneID = 0 )) then Exit( False );

  { create database record }

  if( FUniqueID = 0 ) then
  begin
    GX_Connector.Execute( 'INSERT INTO tbCamera ( FSceneID ) VALUES ( 0 );' );
    FUniqueID := GX_Connector.GetLastAutoValue();
  end;

  { save data }

  ASQL := 'UPDATE tbCamera SET ' +
            GX_Connector.SetInteger( 'FSceneID',  ASceneID,   True )  +
            GX_Connector.SetString( 'FName',      FName,      True )  +
            GX_Connector.SetVector( 'FPosition',  FPosition,  True )  +
            GX_Connector.SetVector( 'FTarget',    FTarget,    False ) +
          'WHERE ( ' +
            'FID = ' + GX_IntToStr( UniqueID ) + ' );';

  GX_Connector.Execute( ASQL );
  GX_SafeFree( ASet );

  FStatus := stLoaded;
  *)
end;

procedure TCamera.SetPosition( const APosition: TVector3 );
begin
  FPosition := APosition;
  FDistance := (FTarget - FPosition).Magnitude;
  UpdateMatrix();

  if( FStatus = stLoaded ) then FStatus := stModified;
end;

procedure TCamera.SetRotation( const ARotation: TVector3 );
begin
  FRotation := ARotation;
  UpdateMatrix();

  if( FStatus = stLoaded ) then FStatus := stModified;
end;

procedure TCamera.SetDistance( const ADistance: Single);
var
  Delta: Single;
begin
  Delta := ADistance - FDistance;

  if(( FDistance + Delta ) < 0 ) then Delta := 1 - FDistance;

  FPosition := FPosition.Project(FTarget, Delta);
  FDistance := Abs((FTarget - FPosition ).Magnitude);

  if( FStatus = stLoaded ) then FStatus := stModified;
end;

procedure TCamera.SetTarget( const ATarget: TVector3 );
begin
  FTarget := ATarget;
  UpdateMatrix();

  if( FStatus = stLoaded ) then FStatus := stModified;
end;

procedure TCamera.Move( const ADir: TVector3 );
begin
  FPosition := FPosition + ADir;
  FTarget := FTarget + ADir;
  UpdateMatrix();

  if (FStatus = stLoaded) then FStatus := stModified;
end;

procedure TCamera.Rotate( const rX, rY, rZ: Single );
begin
  Rotation := TVector3.Create( FRotation.X + rX,  FRotation.Y + rY, FRotation.Z + rZ );
end;

procedure TCamera.Zoom( const ADelta: Single );
begin
  Distance := Distance + ADelta;
end;

procedure TCamera.UpdateMatrix();
var
  AEye, AFocus, AUp: TVector3;
begin
  AEye      := FPosition;
	AFocus    := FTarget;
	AUp       := TVector3.YAxis;

  FMatrix   := TMatrix.LookAtLH(AEye, AFocus, AUp);
end;

end.

