// Copyright (c) 2021 Arsanias (arsaniasbb@gmail.com)
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.Camera;

interface

uses
  System.Types,
  Core.Types;

type
  TCamera = class
  private
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
    function GetDirection: TVector3;
    procedure UpdateMatrix;
  public
    constructor Create;
    procedure Move(const ADir: TVector3);
    procedure Rotate(const rX, rY, rZ: Single);
    procedure Zoom(const ADelta: Single);
  public
    property Position: TVector3 read FPosition write SetPosition;
    property Distance: Single read FDistance write SetDistance;
    property Rotation: TVector3 read FRotation write SetRotation;
    property Target: TVector3 read FTarget write SetTarget;
    property Direction:  TVector3 read GetDirection;
    property Matrix: TMatrix read FMatrix;
    property MouseSense: Single read FMouseSense;
  end;

implementation

constructor TCamera.Create;
begin
  inherited Create;

	FPosition := TVector3.Create(0.0, 3.0, -3.0);
	FTarget := TVector3.Create(0.0, 0.0, 0.0);
	FRotation := TVector3.Create(0.0, 0.0, 0.0);
	FDistance := (FTarget - FPosition).Magnitude;
  FMouseSense := 0.003;

  UpdateMatrix;
end;

function TCamera.GetDirection: TVector3;
begin
  Result := (Position - Target).Normalize;
end;

procedure TCamera.SetPosition(const APosition: TVector3);
begin
  FPosition := APosition;
  FDistance := (FTarget - FPosition).Magnitude;
  UpdateMatrix;
end;

procedure TCamera.SetRotation(const ARotation: TVector3);
begin
  FRotation := ARotation;
  UpdateMatrix;
end;

procedure TCamera.SetDistance( const ADistance: Single);
var
  Delta: Single;
begin
  Delta := ADistance - FDistance;

  if ((FDistance + Delta ) < 0) then Delta := 1 - FDistance;

  FPosition := FPosition.Project(FTarget, Delta);
  FDistance := Abs((FTarget - FPosition ).Magnitude);
end;

procedure TCamera.SetTarget(const ATarget: TVector3);
begin
  FTarget := ATarget;
  UpdateMatrix();
end;

procedure TCamera.Move(const ADir: TVector3);
begin
  FPosition := FPosition + ADir;
  FTarget := FTarget + ADir;
  UpdateMatrix;
end;

procedure TCamera.Rotate(const rX, rY, rZ: Single);
begin
  Rotation := TVector3.Create( FRotation.X + rX,  FRotation.Y + rY, FRotation.Z + rZ );
end;

procedure TCamera.Zoom(const ADelta: Single);
begin
  Distance := Distance + ADelta;
end;

procedure TCamera.UpdateMatrix;
var
  AEye, AFocus, AUp: TVector3;
begin
  AEye := FPosition;
	AFocus := FTarget;
	AUp := TVector3.YAxis;

  FMatrix := TMatrix.LookAtLH(AEye, AFocus, AUp);
end;

end.

