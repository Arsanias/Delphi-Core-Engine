// Copyright (c) 2021 Arsanias (arsaniasbb@gmail.com)
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.Types;

interface

uses
  System.Types, System.Variants, System.Math, System.SysUtils, System.StrUtils, System.DateUtils,
  System.UITypes, System.Generics.Collections;

const
  PIDIV2 = PI / 2;
  PI2 = PI * 2;

  DEG2RAD    = Pi / 180;
  RAD2DEG    = 180 / Pi;
  RGB2COL    = 1 / 255;
  COL2RGB    = 255 / 1;

type
  TDateOrder = (doMDY, doDMY, doYMD );
  TSortStatus = (stNone, stUp, stDown );

  TDynamicVariantArray = array of OLEVariant;
  PDynamicVariantArray = ^TDynamicVariantArray;
  TVariantArray = array of Variant;

  TIntegerList = TList<Integer>;
  TCardinalList = TList<Cardinal>;
  TInt64List = TList<Int64>;
  TUInt64List = TList<UInt64>;
  TSingleList = TList<Single>;
  TWordList = TList<Word>;

  TVector2 = record
    constructor Create(const X, Y: Single);
    case Integer of
      0: (_: array[ 0..1 ] of Single);
      1: (X: Single;
          Y: Single );
      2: (U: Single;
          V: Single );
  end;
  PVector2 = ^TVector2;

  TVector3 = record
    constructor Create(const X, Y, Z: Single);
    class operator Add(const V1, V2: TVector3): TVector3;
    class operator Divide(const AVector: TVector3; const AScalar: Single): TVector3;
    class operator Multiply(const AVector: TVector3; const AFactor: Single): TVector3;
    class operator Subtract(const V1, V2: TVector3): TVector3;
    class operator Equal(const V1, V2: TVector3): Boolean;
    function Invert: TVector3;
    function Magnitude: Single;
    function Normalize: TVector3;
    function CrossProduct(const AVector: TVector3): TVector3;
    function DotProduct(const AVector: TVector3): Single;
    function Project(const AVector: TVector3; const ADistance: Single): TVector3;
    function ToString2: string;
    function ToHex: string;
    case Integer of
      0: (V: array[0..2] of Single);
      1: (X: Single;
          Y: Single;
          Z: Single);
      2: (R: Single;
          G: Single;
          B: Single);
  end;
  PVector3 = ^TVector3;
  TVector3Constants = record helper for TVector3
    const XAxis: TVector3 = (V:(1.0, 0.0, 0.0));
    const YAxis: TVector3 = (V:(0.0, 1.0, 0.0));
    const ZAxis: TVector3 = (V:(0.0, 0.0, 1.0));
  end;
  TVector3DynArray = array of TVector3;

  TVector4 = record
    constructor Create(const Vector: TVector3; const Value: Single); overload;
    constructor Create(const Vector: TVector3); overload;
    constructor Create(const X, Y, Z, W: Single); overload;
    class operator Equal(const V1, V2: TVector4): Boolean;
    function Normalize: TVector4;
    function ToVector3: TVector3;
    case Integer of
      0: (V: array[ 0..3 ] of Single);
      1: (X: Single;
          Y: Single;
          Z: Single;
          W: Single );
      2: (R: Single;
          G: Single;
          B: Single;
          A: Single );
  end;
  PVector4 = ^TVector4;
  TVector4DynArray = array of TVector4;
  TVector4Constants = record helper for TVector4
    const Identity: TVector4 = (X:0; Y:0; Z:0; W:1);
  end;

  TSpheric = record
    Theta: Single;
    Phi: Single;
    Radius: Single;
    constructor Create(const Theta, Phi, Radius: Single); overload;
    constructor Create(const Vector: TVector3); overload;
    function ToVector: TVector3;
  end;
  PSpheric = ^TSpheric;

  TMatrix = record
    constructor Create(const m11, m12, m13, m14, m21, m22, m23, m24, m31, m32, m33, m34, m41, m42, m43, m44: Single);
    class operator Multiply(const M1, M2: TMatrix ): TMatrix;
    class function Rotation(const AnAxis: TVector3; Angle: Single): TMatrix; static;
    class function Scaling(const AFactor: TVector3): TMatrix; static;
    class function Translation(const AVector: TVector3): TMatrix; static;
    class function LookAtLH(const Eye, At, Up: TVector3): TMatrix; static;
    class function YawPitchRoll(const AYaw, APitch, ARoll: Single): TMatrix; static;
    class function PerspectiveFovLH(const flovy, aspect, zn, zf: Single): TMatrix; static;
    class function PerspectiveFovRH(const flovy, aspect, zn, zf: Single): TMatrix; static;
    class function OrthoLH(const W, h, zn, zf: Single): TMatrix; static;
    class function OrthoOffCenterLH(const l, R, b, t, zn, zf: Single): TMatrix; static;
    class function OrthoOffCenterRH(const l, R, b, t, zn, zf: Single): TMatrix; static;
    function Transform(const Vector: TVector3): TVector3; overload;
    function Transform(const Vector: TVector4): TVector4; overload;
    function Transpose: TMatrix;
    function Invert: TMatrix;
    case Integer of
      0: (M: array[ 0..3 ] of TVector4);
      1: (m11, m12, m13, m14: Single;
          m21, m22, m23, m24: Single;
          m31, m32, m33, m34: Single;
          m41, m42, m43, m44: Single);
      2: (XX,  XY,  XZ,  XW: Single;
          YX,  YY,  YZ,  YW: Single;
          ZX,  ZY,  ZZ,  ZW: Single;
          WX,  WY,  WZ,  WW: Single);
      3: (V: array[0..15] of Single);
  end;
  PMatrix = ^TMatrix;
  TMatrixConstants = record helper for TMatrix
    const Identity: TMatrix = (
      m11: 1.0; m12: 0.0; m13: 0.0; m14: 0.0;
      m21: 0.0; m22: 1.0; m23: 0.0; m24: 0.0;
      m31: 0.0; m32: 0.0; m33: 1.0; m34: 0.0;
      m41: 0.0; m42: 0.0; m43: 0.0; m44: 1.0;);
  end;

  TQuaternion = record
    constructor Create(const X, Y, Z, W: Single); overload;
    constructor Create(const AVector: TVector3); overload;
    class operator Multiply(const Q1, Q2: TQuaternion): TQuaternion;
    class function Rotation(const Axis: TVector3; Angle: Single): TQuaternion; static;
    class function YawPitchRoll(AYaw, APitch, ARoll: Single): TQuaternion; static;
    function Inverse: TQuaternion;
    function Normalize: TQuaternion;
    function Transform(const AVector: TVector3): TVector3;
    function ToMatrix: TMatrix;
    procedure ToAxisAngle(var AAxis: TVector3; var AAngle: Single);
    function ToYawPitchRoll: TVector3;
    case Integer of
      0: (W: Single;
          X: Single;
          Y: Single;
          Z: Single);
      1: (_: array[0..3] of Single);
  end;
  PQuaternion = ^TQuaternion;

  TLine = record
    constructor Create(const V1, V2: TVector3);
    case Integer of
      0: (V: array[0..1] of TVector3);
      1: (V1, V2: TVector3);
  end;

  TTriangle = record
    constructor Create(const V1, V2, V3: TVector3);
    class function GetNormal(const V1, V2, V3: TVector3): TVector3; overload; static;
    function GetNormal: TVector3; overload;
    case Integer of
      0: (V: array[0..2] of TVector3);
      1: (V1, V2, V3: TVector3);
  end;
  PTriangle = ^TTriangle;

  TBoundingBox = record
    MinCorner: TVector3;
    MaxCorner: TVector3;
  end;

  function CreateIntegerList(Capacity: Integer): TIntegerList;
  function CreateSingleList(Capacity: Integer): TSingleList;
  function CreateUInt64List(Capacity: Integer): TUInt64List;

  function ByteToHex(AByte: Byte): string;
  function NormalizeAngle(const Angle: Single): Single;

const
  DefaultColors: array[0..30-1] of TVector4 = (
    (R:0.9;  G:0.1;  B:0.1; A:1.0), (R:0.1;  G:0.9;  B:0.1; A:1.0), (R:0.1;  G:0.1;  B:0.9; A:1.0),
    (R:0.7;  G:0.7;  B:0.1; A:1.0), (R:0.1;  G:0.7;  B:0.7; A:1.0), (R:0.7;  G:0.1;  B:0.7; A:1.0),
    (R:0.9;  G:0.5;  B:0.7; A:1.0), (R:0.5;  G:0.9;  B:0.5; A:1.0), (R:0.9;  G:0.5;  B:0.5; A:1.0),
    (R:0.2;  G:0.5;  B:0.8; A:1.0), (R:0.5;  G:0.2;  B:0.7; A:1.0), (R:0.2;  G:0.7;  B:0.5; A:1.0),
    (R:0.5;  G:0.5;  B:0.2; A:1.0), (R:0.5;  G:0.5;  B:0.9; A:1.0), (R:0.5;  G:0.9;  B:0.5; A:1.0),
    (R:0.7;  G:0.5;  B:0.5; A:1.0), (R:0.5;  G:0.7;  B:0.2; A:1.0), (R:0.7;  G:0.2;  B:0.5; A:1.0),
    (R:0.9;  G:0.5;  B:0.7; A:1.0), (R:0.5;  G:0.9;  B:0.5; A:1.0), (R:0.9;  G:0.5;  B:0.5; A:1.0),
    (R:0.2;  G:0.5;  B:0.9; A:1.0), (R:0.5;  G:0.2;  B:0.7; A:1.0), (R:0.2;  G:0.7;  B:0.5; A:1.0),
    (R:0.5;  G:0.5;  B:0.2; A:1.0), (R:0.5;  G:0.5;  B:0.9; A:1.0), (R:0.5;  G:0.9;  B:0.5; A:1.0),
    (R:0.7;  G:0.5;  B:0.5; A:1.0), (R:0.5;  G:0.7;  B:0.2; A:1.0), (R:0.7;  G:0.2;  B:0.5; A:1.0)
  );

implementation

function ByteToHex(AByte: Byte): string;
const
  HexArray : array[0..255] of array[0..1] of Char =
    ('00','01','02','03','04','05','06','07','08','09','0A','0B','0C','0D','0E','0F',
    '10','11','12','13','14','15','16','17','18','19','1A','1B','1C','1D','1E','1F',
    '20','21','22','23','24','25','26','27','28','29','2A','2B','2C','2D','2E','2F',
    '30','31','32','33','34','35','36','37','38','39','3A','3B','3C','3D','3E','3F',
    '40','41','42','43','44','45','46','47','48','49','4A','4B','4C','4D','4E','4F',
    '50','51','52','53','54','55','56','57','58','59','5A','5B','5C','5D','5E','5F',
    '60','61','62','63','64','65','66','67','68','69','6A','6B','6C','6D','6E','6F',
    '70','71','72','73','74','75','76','77','78','79','7A','7B','7C','7D','7E','7F',
    '80','81','82','83','84','85','86','87','88','89','8A','8B','8C','8D','8E','8F',
    '90','91','92','93','94','95','96','97','98','99','9A','9B','9C','9D','9E','9F',
    'A0','A1','A2','A3','A4','A5','A6','A7','A8','A9','AA','AB','AC','AD','AE','AF',
    'B0','B1','B2','B3','B4','B5','B6','B7','B8','B9','BA','BB','BC','BD','BE','BF',
    'C0','C1','C2','C3','C4','C5','C6','C7','C8','C9','CA','CB','CC','CD','CE','CF',
    'D0','D1','D2','D3','D4','D5','D6','D7','D8','D9','DA','DB','DC','DD','DE','DF',
    'E0','E1','E2','E3','E4','E5','E6','E7','E8','E9','EA','EB','EC','ED','EE','EF',
    'F0','F1','F2','F3','F4','F5','F6','F7','F8','F9','FA','FB','FC','FD','FE','FF');
begin
  Result := HexArray[AByte][0] + HexArray[AByte][1];
end;

function NormalizeAngle(const Angle: Single): Single;
const
  ONEDIV360 = 1 / 360;
begin
  Result := Angle - Int(Angle * ONEDIV360) * 360.0;
  if Result < -180.0 then
    Result := Result + 360.0;
end;

{$EXCESSPRECISION OFF}

//==============================================================================

constructor TVector2.Create(const X, Y: Single);
begin
  Self.X := X;
  Self.Y := Y;
end;

//==============================================================================

constructor TVector3.Create(const X, Y, Z: Single);
begin
  Self.X := X;
  Self.Y := Y;
  Self.Z := Z;
end;

class operator TVector3.Add(const V1, V2: TVector3): TVector3;
begin
  Result.X := V1.X + V2.X;
  Result.Y := V1.Y + V2.Y;
  Result.Z := V1.Z + V2.Z;
end;

class operator TVector3.Divide(const AVector: TVector3; const AScalar: Single): TVector3;
begin
  Result := TVector3.Create(AVector.X / AScalar, AVector.Y / AScalar, AVector.Z / AScalar);
end;

class operator TVector3.Multiply(const AVector: TVector3; const AFactor: Single): TVector3;
begin
  Result.X := AVector.X * AFactor;
  Result.Y := AVector.Y * AFactor;
  Result.Z := AVector.Z * AFactor;
end;

class operator TVector3.Subtract(const V1, V2: TVector3): TVector3;
begin
  Result.X := V1.X - V2.X;
  Result.Y := V1.Y - V2.Y;
  Result.Z := V1.Z - V2.Z;
end;

class operator TVector3.Equal(const V1, V2: TVector3): Boolean;
begin
  Result := ((V1.X = V2.X) and (V1.Y = V2.Y) and (V1.Z = V2.Z));
end;

function TVector3.Invert: TVector3;
begin
  Result := TVector3.Create(-Self.X, -Self.Y, -Self.Z);
end;

function TVector3.Magnitude: Single;
begin
  Result := Sqrt(X * X + Y * Y + Z * Z);
end;

function TVector3.Normalize: TVector3;
var
  AMagnitude: Single;
begin
  AMagnitude := Self.Magnitude;
  Result.X := Self.X / AMagnitude;
  Result.Y := Self.Y / AMagnitude;
  Result.Z := Self.Z / AMagnitude;
end;

function TVector3.CrossProduct(const AVector: TVector3): TVector3;
begin
  Result.X := Self.Y * AVector.Z - Self.Z * AVector.Y;
  Result.Y := Self.Z * AVector.X - Self.X * AVector.Z;
  Result.Z := Self.X * AVector.Y - Self.Y * AVector.X;
end;

function TVector3.DotProduct(const AVector: TVector3): Single;
begin
  Result := Self.X * AVector.X + Self.Y * AVector.Y + Self.Z * AVector.Z;
end;

function TVector3.Project(const AVector: TVector3; const ADistance: Single): TVector3;
var
  AMagnitude: Single;
begin
  AMagnitude := AVector.Magnitude - Magnitude;
  Result.X := X / AMagnitude * (AMagnitude + ADistance);
  Result.Y := Y / AMagnitude * (AMagnitude + ADistance);
  Result.Z := Z / AMagnitude * (AMagnitude + ADistance);
end;

function TVector3.ToString2: string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to 2 do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + FloatToStrF(V[i], ffFixed, 4, 3);
  end;
end;

function TVector3.ToHex: string;
var
  AByte: PByte;
  i: Integer;
begin
  Result := '';
  AByte := Pointer(@Self);

  for i := SizeOf(Self) - 1 downto 0 do
    Result := Result + ByteToHex(PByte(Cardinal(AByte) + i)^);
end;

//==============================================================================

constructor TVector4.Create(const Vector: TVector3; const Value: Single);
begin
  Self.X := Vector.X;
  Self.Y := Vector.Y;
  Self.Z := Vector.Z;
  Self.W := Value;
end;

constructor TVector4.Create(const Vector: TVector3);
begin
  Create(Vector, 1.0);
end;

constructor TVector4.Create(const X, Y, Z, W: Single);
begin
  Self.X := X;
  Self.Y := Y;
  Self.Z := Z;
  Self.W := W;
end;

class operator TVector4.Equal(const V1, V2: TVector4): Boolean;
begin
  Result := ((V1.X = V2.X) and (V1.Y = V2.Y) and (V1.Z = V2.Z) and (V1.W = V2.W));
end;

function TVector4.Normalize: TVector4;
begin
  Result := TVector4.Create(TVector3.Create(X, Y, Z).Normalize, 1.0);
end;

function TVector4.ToVector3: TVector3;
begin
  Result := TVector3.Create(X, Y, Z);
end;

//==============================================================================

constructor TSpheric.Create(const Theta, Phi, Radius: Single);
begin
  Self.Theta  := Theta;
  Self.Phi    := Phi;
  Self.Radius := Radius;
end;

constructor TSpheric.Create(const Vector: TVector3);
begin
  Radius := Vector.Magnitude;
  if (Vector.X <> 0) or (Vector.Z <> 0) then Theta := ArcTan2(Vector.Z, Vector.X);
  if (Radius <> 0) then Phi := ArcCos(Vector.Y / Radius);
end;

function TSpheric.ToVector: TVector3;
begin
  Result.X := Radius * Cos(Theta) * Sin(Phi);
  Result.Y := Radius * Cos(Phi);
  Result.Z := Radius * Sin(Theta) * Sin(Phi);
end;

//==============================================================================

constructor TMatrix.Create(const m11, m12, m13, m14, m21, m22, m23, m24, m31, m32, m33, m34, m41, m42, m43, m44: Single);
begin
  Self.m11 := m11;  Self.m12 := m12;  Self.m13 := m13;  Self.m14 := m14;
  Self.m11 := m21;  Self.m22 := m22;  Self.m23 := m23;  Self.m24 := m24;
  Self.m11 := m31;  Self.m32 := m32;  Self.m33 := m33;  Self.m34 := m34;
  Self.m11 := m41;  Self.m42 := m42;  Self.m43 := m43;  Self.m44 := m44;
end;

class operator TMatrix.Multiply(const M1, M2: TMatrix ): TMatrix;
begin
  Result.XX := M1.XX * M2.XX + M1.XY * M2.YX + M1.XZ * M2.ZX + M1.XW * M2.WX;
  Result.XY := M1.XX * M2.XY + M1.XY * M2.YY + M1.XZ * M2.ZY + M1.XW * M2.WY;
  Result.XZ := M1.XX * M2.XZ + M1.XY * M2.YZ + M1.XZ * M2.ZZ + M1.XW * M2.WZ;
  Result.XW := M1.XX * M2.XW + M1.XY * M2.YW + M1.XZ * M2.ZW + M1.XW * M2.WW;
  Result.YX := M1.YX * M2.XX + M1.YY * M2.YX + M1.YZ * M2.ZX + M1.YW * M2.WX;
  Result.YY := M1.YX * M2.XY + M1.YY * M2.YY + M1.YZ * M2.ZY + M1.YW * M2.WY;
  Result.YZ := M1.YX * M2.XZ + M1.YY * M2.YZ + M1.YZ * M2.ZZ + M1.YW * M2.WZ;
  Result.YW := M1.YX * M2.XW + M1.YY * M2.YW + M1.YZ * M2.ZW + M1.YW * M2.WW;
  Result.ZX := M1.ZX * M2.XX + M1.ZY * M2.YX + M1.ZZ * M2.ZX + M1.ZW * M2.WX;
  Result.ZY := M1.ZX * M2.XY + M1.ZY * M2.YY + M1.ZZ * M2.ZY + M1.ZW * M2.WY;
  Result.ZZ := M1.ZX * M2.XZ + M1.ZY * M2.YZ + M1.ZZ * M2.ZZ + M1.ZW * M2.WZ;
  Result.ZW := M1.ZX * M2.XW + M1.ZY * M2.YW + M1.ZZ * M2.ZW + M1.ZW * M2.WW;
  Result.WX := M1.WX * M2.XX + M1.WY * M2.YX + M1.WZ * M2.ZX + M1.WW * M2.WX;
  Result.WY := M1.WX * M2.XY + M1.WY * M2.YY + M1.WZ * M2.ZY + M1.WW * M2.WY;
  Result.WZ := M1.WX * M2.XZ + M1.WY * M2.YZ + M1.WZ * M2.ZZ + M1.WW * M2.WZ;
  Result.WW := M1.WX * M2.XW + M1.WY * M2.YW + M1.WZ * M2.ZW + M1.WW * M2.WW;
end;

class function TMatrix.Rotation(const AnAxis: TVector3; Angle: Single): TMatrix;
var
  Axis: TVector3;
  Cos, Sin, OneMinusCos: Extended;
begin
  SinCos(NormalizeAngle(Angle), Sin, Cos);
  OneMinusCos := 1 - Cos;
  Axis := AnAxis.Normalize;

  FillChar( Result, SizeOf( Result ), 0 );

  Result.XX := ( OneMinusCos * Axis.V[0] * Axis.V[0] ) + Cos;
  Result.XY := ( OneMinusCos * Axis.V[0] * Axis.V[1] ) - (Axis.V[2] * Sin);
  Result.XZ := ( OneMinusCos * Axis.V[2] * Axis.V[0] ) + (Axis.V[1] * Sin);

  Result.YX := ( OneMinusCos * Axis.V[0] * Axis.V[1] ) + (Axis.V[2] * Sin);
  Result.YY := ( OneMinusCos * Axis.V[1] * Axis.V[1] ) + Cos;
  Result.YZ := ( OneMinusCos * Axis.V[1] * Axis.V[2] ) - (Axis.V[0] * Sin);

  Result.ZX := ( OneMinusCos * Axis.V[2] * Axis.V[0] ) - (Axis.V[1] * Sin);
  Result.ZY := ( OneMinusCos * Axis.V[1] * Axis.V[2] ) + (Axis.V[0] * Sin);
  Result.ZZ := ( OneMinusCos * Axis.V[2] * Axis.V[2] ) + Cos;

  Result.WW := 1.0;
end;

class function TMatrix.Scaling(const AFactor: TVector3): TMatrix;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.M11 := AFactor.X;
  Result.M22 := AFactor.Y;
  Result.M33 := AFactor.Z;
  Result.M44 := 1.0;
end;

class function TMatrix.Translation(const AVector: TVector3): TMatrix;
begin
  Result := TMatrix.Identity;
  Result.M41 := AVector.X;
  Result.M42 := AVector.Y;
  Result.M43 := AVector.Z;
end;

class function TMatrix.LookAtLH(const Eye, At, Up: TVector3): TMatrix;
var
  zaxis, xaxis, yaxis: TVector3;
begin
  zaxis := (At - Eye).Normalize;
  xaxis := Up.CrossProduct(zaxis).Normalize;
  yaxis := zaxis.CrossProduct(xaxis);

  Result := TMatrix.Identity;

  Result.XX := xaxis.X;
  Result.XY := yaxis.X;
  Result.XZ := zaxis.X;
  Result.YX := xaxis.Y;
  Result.YY := yaxis.Y;
  Result.YZ := zaxis.Y;
  Result.ZX := xaxis.Z;
  Result.ZY := yaxis.Z;
  Result.ZZ := zaxis.Z;
  Result.WX := -(xaxis.DotProduct(Eye));
  Result.WY := -(yaxis.DotProduct(Eye));
  Result.WZ := -(zaxis.DotProduct(Eye));
end;

class function TMatrix.YawPitchRoll(const AYaw, APitch, ARoll: Single): TMatrix;
begin
  Result := TMatrix.Identity;
  if( AYaw <> 0 ) then
    Result := Result * TMatrix.Rotation(TVector3.Create(0, 1, 0), AYaw);
  if( APitch <> 0 ) then
    Result := Result * TMatrix.Rotation(TVector3.Create(1, 0, 0), APitch);
  if( ARoll <> 0 ) then
    Result := Result * TMatrix.Rotation(TVector3.Create(0, 0, 1), ARoll);
end;

class function TMatrix.PerspectiveFovLH(const flovy, aspect, zn, zf: Single): TMatrix;
var
  yScale, xScale: Single;
begin
  yScale := cot( flovy / 2.0 );
  xScale := yScale / aspect;
  Result := TMatrix.Identity;
  Result.m11 := xScale;
  Result.m22 := yScale;
  Result.m33 := ( zf / ( zf - zn ));
  Result.m34 := 1;
  Result.m43 := -zn * zf / ( zf - zn );
  Result.m44 := 0;
end;

class function TMatrix.PerspectiveFovRH(const flovy, aspect, zn, zf: Single): TMatrix;
var
  yScale, xScale: Single;
begin
  yScale := cot(flovy / 2.0);
  xScale := yScale / aspect;
  Result := TMatrix.Identity;
  Result.m11 := xScale;
  Result.m22 := yScale;
  Result.m33 := (zf / (zn - zf));
  Result.m34 := -1;
  Result.m43 := zn * zf / (zn - zf);
  Result.m44 := 0;
end;

class function TMatrix.OrthoLH(const W, h, zn, zf: Single): TMatrix;
begin
  Result := TMatrix.Identity;
  Result.m11 := 2 / W;
  Result.m22 := 2 / h;
  Result.m33 := 1 / (zf - zn);
  Result.m42 := zn / (zn - zf);
end;

class function TMatrix.OrthoOffCenterLH(const l, R, b, t, zn, zf: Single): TMatrix;
begin
  Result := TMatrix.Identity;
  Result.m11 := 2 / (R - l);
  Result.m22 := 2 / (t - b);
  Result.m33 := 1 / (zf - zn);
  Result.m41 := (l + R) / (l - R);
  Result.m42 := (t + b) / (b - t);
  Result.m43 := zn / (zn - zf);
end;

class function TMatrix.OrthoOffCenterRH(const l, R, b, t, zn, zf: Single): TMatrix;
begin
  Result := TMatrix.Identity;
  Result.m11 := 2 / (R - l);
  Result.m22 := 2 / (t - b);
  Result.m33 := 1 / (zn - zf);
  Result.m41 := (l + R) / (l - R);
  Result.m42 := (t + b) / (b - t);
  Result.m43 := zn / (zn - zf);
end;

function TMatrix.Invert: TMatrix;
var
  i: Integer;
  det: Single;
begin
  Result.V[0] :=  V[5] * V[10] * V[15] - V[5]  * V[11] * V[14] - V[9]  * V[6] * V[15] + V[9]  * V[7] * V[14] + V[13] * V[6] * V[11] - V[13] * V[7] * V[10];
  Result.V[4] := -V[4] * V[10] * V[15] + V[4]  * V[11] * V[14] + V[8]  * V[6] * V[15] - V[8]  * V[7] * V[14] - V[12] * V[6] * V[11] + V[12] * V[7] * V[10];
  Result.V[8] :=  V[4] * V[9]  * V[15] - V[4]  * V[11] * V[13] - V[8]  * V[5] * V[15] + V[8]  * V[7] * V[13] + V[12] * V[5] * V[11] - V[12] * V[7] * V[9];
  Result.V[12]:= -V[4] * V[9]  * V[14] + V[4]  * V[10] * V[13] + V[8]  * V[5] * V[14] - V[8]  * V[6] * V[13] - V[12] * V[5] * V[10] + V[12] * V[6] * V[9];
  Result.V[1] := -V[1] * V[10] * V[15] + V[1]  * V[11] * V[14] + V[9]  * V[2] * V[15] - V[9]  * V[3] * V[14] - V[13] * V[2] * V[11] + V[13] * V[3] * V[10];
  Result.V[5] :=  V[0] * V[10] * V[15] - V[0]  * V[11] * V[14] - V[8]  * V[2] * V[15] + V[8]  * V[3] * V[14] + V[12] * V[2] * V[11] - V[12] * V[3] * V[10];
  Result.V[9] := -V[0] * V[9]  * V[15] + V[0]  * V[11] * V[13] + V[8]  * V[1] * V[15] - V[8]  * V[3] * V[13] - V[12] * V[1] * V[11] + V[12] * V[3] * V[9];
  Result.V[13]:=  V[0] * V[9]  * V[14] - V[0]  * V[10] * V[13] - V[8]  * V[1] * V[14] + V[8]  * V[2] * V[13] + V[12] * V[1] * V[10] - V[12] * V[2] * V[9];
  Result.V[2] :=  V[1] * V[6]  * V[15] - V[1]  * V[7]  * V[14] - V[5]  * V[2] * V[15] + V[5]  * V[3] * V[14] + V[13] * V[2] * V[7]  - V[13] * V[3] * V[6];
  Result.V[6] := -V[0] * V[6]  * V[15] + V[0]  * V[7]  * V[14] + V[4]  * V[2] * V[15] - V[4]  * V[3] * V[14] - V[12] * V[2] * V[7]  + V[12] * V[3] * V[6];
  Result.V[10]:=  V[0] * V[5]  * V[15] - V[0]  * V[7]  * V[13] - V[4]  * V[1] * V[15] + V[4]  * V[3] * V[13] + V[12] * V[1] * V[7]  - V[12] * V[3] * V[5];
  Result.V[14]:= -V[0] * V[5]  * V[14] + V[0]  * V[6]  * V[13] + V[4]  * V[1] * V[14] - V[4]  * V[2] * V[13] - V[12] * V[1] * V[6]  + V[12] * V[2] * V[5];
  Result.V[3] := -V[1] * V[6]  * V[11] + V[1]  * V[7]  * V[10] + V[5]  * V[2] * V[11] - V[5]  * V[3] * V[10] - V[9]  * V[2] * V[7]  + V[9]  * V[3] * V[6];
  Result.V[7] :=  V[0] * V[6]  * V[11] - V[0]  * V[7]  * V[10] - V[4]  * V[2] * V[11] + V[4]  * V[3] * V[10] + V[8]  * V[2] * V[7]  - V[8]  * V[3] * V[6];
  Result.V[11]:= -V[0] * V[5]  * V[11] + V[0]  * V[7]  * V[9]  + V[4]  * V[1] * V[11] - V[4]  * V[3] * V[9]  - V[8]  * V[1] * V[7]  + V[8]  * V[3] * V[5];
  Result.V[15]:=  V[0] * V[5]  * V[10] - V[0]  * V[6]  * V[9]  - V[4]  * V[1] * V[10] + V[4]  * V[2] * V[9]  + V[8]  * V[1] * V[6]  - V[8]  * V[2] * V[5];

  det := V[0] * Result.V[0] + V[1] * Result.V[4] + V[2] * Result.V[8] + V[3] * Result.V[12];
  if( det = 0 ) then
    Exit(TMatrix.Identity);

  det := 1.0 / det;
  for i := 0 to 15 do
    Result.V[i] := Result.V[i] * det;
end;

function TMatrix.Transform(const Vector: TVector3): TVector3;
begin
  Result.X := Vector.X * Self.XX + Vector.Y * Self.YX + Vector.Z * Self.ZX + 1.0 * Self.WX;
  Result.Y := Vector.X * Self.XY + Vector.Y * Self.YY + Vector.Z * Self.ZY + 1.0 * Self.WY;
  Result.Z := Vector.X * Self.XZ + Vector.Y * Self.YZ + Vector.Z * Self.ZZ + 1.0 * Self.WZ;
end;

function TMatrix.Transform(const Vector: TVector4): TVector4;
begin
  Result.X := Vector.X * Self.XX + Vector.Y * Self.YX + Vector.Z * Self.ZX + Vector.W * Self.WX;
  Result.Y := Vector.X * Self.XY + Vector.Y * Self.YY + Vector.Z * Self.ZY + Vector.W * Self.WY;
  Result.Z := Vector.X * Self.XZ + Vector.Y * Self.YZ + Vector.Z * Self.ZZ + Vector.W * Self.WZ;
  Result.W := 1.0;
end;

function TMatrix.Transpose: TMatrix;
begin
  Result.V[0]   := V[0];
  Result.V[1]   := V[4];
  Result.V[2]   := V[8];
  Result.V[3]   := V[12];
  Result.V[4]   := V[1];
  Result.V[5]   := V[5];
  Result.V[6]   := V[9];
  Result.V[7]   := V[13];
  Result.V[8]   := V[2];
  Result.V[9]   := V[6];
  Result.V[10]  := V[10];
  Result.V[11]  := V[14];
  Result.V[12]  := V[3];
  Result.V[13]  := V[7];
  Result.V[14]  := V[11];
  Result.V[15]  := V[15];
end;

//==============================================================================

// http://content.gpwiki.org/index.php/OpenGL:Tutorials:Using_Quaternions_to_represent_rotation
//
constructor TQuaternion.Create(const X, Y, Z, W: Single);
begin
  Self.X := X;
  Self.Y := Y;
  Self.Z := Z;
  Self.W := W;
end;

constructor TQuaternion.Create(const AVector: TVector3);
begin
  Self.X := AVector.X;
  Self.Y := AVector.Y;
  Self.Z := AVector.Z;
  Self.W := 0.0;
end;

class operator TQuaternion.Multiply(const Q1, Q2: TQuaternion): TQuaternion;
begin
  Result :=
    TQuaternion.Create(
      Q1.W * Q2.X + Q1.X * Q2.W + Q1.Y * Q2.Z - Q1.Z * Q2.Y,
      Q1.W * Q2.Y + Q1.Y * Q2.W + Q1.Z * Q2.X - Q1.X * Q2.Z,
      Q1.W * Q2.Z + Q1.Z * Q2.W + Q1.X * Q2.Y - Q1.Y * Q2.X,
      Q1.W * Q2.W - Q1.X * Q2.X - Q1.Y * Q2.Y - Q1.Z * Q2.Z);
end;

class function TQuaternion.Rotation(const Axis: TVector3; Angle: Single): TQuaternion;
var
  ASinAngle: Single;
  AVector:   TVector3;
begin
	Angle := Angle * 0.5;
  AVector := Axis.Normalize;
	ASinAngle := Sin(Angle);

	Result.X := (AVector.X * ASinAngle);
	Result.Y := (AVector.Y * ASinAngle);
	Result.Z := (AVector.Z * ASinAngle);
	Result.W := Cos(Angle);
end;

//http://en.wikipedia.org/wiki/Conversion_between_quaternions_and_Euler_angles
class function TQuaternion.YawPitchRoll(AYaw, APitch, ARoll: Single): TQuaternion;
var
  ASinYaw, ASinPitch, ASinRoll: Single;
  ACosYaw, ACosPitch, ACosRoll: Single;
begin
  AYaw      := AYaw   * (180 / PI) / 2.0;
	APitch    := APitch * (180 / PI) / 2.0;
	ARoll     := ARoll  * (180 / PI) / 2.0;

	ASinYaw   := Sin( AYaw );
	ASinPitch := Sin( APitch );
	ASinRoll  := Sin( ARoll );
	ACosYaw   := Cos( AYaw );
	ACosPitch := Cos( APitch );
	ACosRoll  := Cos( ARoll );

	Result._[0]  := ACosRoll * ACosPitch * ACosYaw + ASinRoll * ASinPitch * ASinYaw;
  Result._[1]  := ASinRoll * ACosPitch * ACosYaw - ACosRoll * ASinPitch * ASinYaw;
	Result._[2]  := ACosRoll * ASinPitch * ACosYaw + ASinRoll * ACosPitch * ASinYaw;
	Result._[3]  := ACosRoll * ACosPitch * ASinYaw - ASinRoll * ASinPitch * ACosYaw;

	Result := Result.Normalize;
end;

function TQuaternion.Inverse: TQuaternion;
begin
  Result := TQuaternion.Create(-X, -Y, -Z, W);
end;

function TQuaternion.Normalize;
var
  AMagnitude: Single;
begin
	AMagnitude := Sqrt(W * W + X * X + Y * Y + Z * Z );


	Result.W := W / AMagnitude;
	Result.X := X / AMagnitude;
	Result.Y := Y / AMagnitude;
	Result.Z := Z / AMagnitude;
end;

function TQuaternion.Transform(const AVector: TVector3): TVector3;
var
  AVecQuat, AResQuat: TQuaternion;
begin
  AVecQuat := TQuaternion.Create(AVector.Normalize);

	AResQuat := AVecQuat * Self.Inverse;
	AResQuat := Self * AResQuat;

	Result := TVector3.Create(AResQuat.X, AResQuat.Y, AResQuat.Z);
end;

function TQuaternion.ToMatrix;
var
  X2, Y2, Z2, XY, XZ, YZ, WX, WY, WZ: Single;
begin
	X2 := X * X;
	Y2 := Y * Y;
	Z2 := Z * Z;
	XY := X * Y;
	XZ := X * Z;
	YZ := Y * Z;
	WX := W * X;
	WY := W * Y;
	WZ := W * Z;

	Result := TMatrix.Create(
    1.0 - 2.0 * ( y2 + z2 ),  2.0 * ( xy - wz ),        2.0 * ( xz + wy ),        0.0,
    2.0 * ( xy + wz ),        1.0 - 2.0 * ( x2 + z2 ),  2.0 * ( yz - wx ),        0.0,
		2.0 * ( xz - wy ),        2.0 * ( yz + wx ),        1.0 - 2.0 * ( x2 + y2 ),  0.0,
		0.0,                      0.0,                      0.0,                      1.0);
end;

procedure TQuaternion.ToAxisAngle(var AAxis: TVector3; var AAngle: Single);
var
  AMagnitude: Single;
begin
	AMagnitude := AAxis.Magnitude;

	AAxis.X := X / AMagnitude;
	AAxis.Y := Y / AMagnitude;
	AAxis.Z := Z / AMagnitude;

	AAngle  := ArcCos(W) * 2.0;
end;

//http://en.wikipedia.org/wiki/Conversion_between_quaternions_and_Euler_angles
function TQuaternion.ToYawPitchRoll: TVector3;
var
  AYaw, APitch, ARoll: Single;
begin
  AYaw   := ArcTan2(2 * (W * Z + X * Y), 1 - 2 * (Y * Y + Z * Z));
  APitch := ArcSin( 2 * (W * Y - Z * X));
  ARoll  := ArcTan2(2 * (W * X + Y * Z), 1 - 2 * (X * X + Y * Y));

  Result.Y := AYaw;
  Result.X := APitch;
  Result.Z := ARoll;
end;

//==============================================================================

constructor TLine.Create(const V1, V2: TVector3);
begin
  Self.V1 := V1;
  Self.V2 := V2;
end;

//==============================================================================

constructor TTriangle.Create(const V1, V2, V3: TVector3);
begin
  Self.V1 := V1;
  Self.V2 := V2;
  Self.V3 := V3;
end;

class function TTriangle.GetNormal(const V1, V2, V3: TVector3): TVector3;
var
  U, V: TVector3;
begin
  U := V2 - V1;
  V := V3 - V1;
  Result := U.CrossProduct(V).Normalize;
end;

function TTriangle.GetNormal: TVector3;
begin
  Result := GetNormal(V1, V2, V3);
end;

//==============================================================================

{$EXCESSPRECISION ON}

function CreateIntegerList(Capacity: Integer): TIntegerList;
begin
  Result := TIntegerList.Create;
  if (Capacity > 0) then
    Result.Capacity := Capacity;
end;

function CreateSingleList(Capacity: Integer): TSingleList;
begin
  Result := TSingleList.Create;
  if (Capacity > 0) then
    Result.Capacity := Capacity;
end;

function CreateUInt64List(Capacity: Integer): TUInt64List;
begin
  Result := TUInt64List.Create;
  if (Capacity > 0) then
    Result.Capacity := Capacity;
end;

end.
