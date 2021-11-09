// Copyright (c) 2021 Arsanias (arsaniasbb@gmail.com)
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.RenderDevice;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Types, System.Classes,
  Vcl.Forms,
  Core.Types, Core.Utils, Core.Arrays, Core.Material, Core.Shader;

type
  TInstance = record
    Count: Integer;
    StartLocation: Cardinal;
  end;
  TInstanceArray = array of TInstance;

  TRenderDeviceMainConst = record
    FViewMatrix: TMatrix;
    FProjMatrix: TMatrix;
    FViewProjMatrix: TMatrix;
	  FLightDir: TVector4;
	  FCameraPos: TVector4;
  end;

  TRenderDeviceCastConst = record
    FWorldMtx: TMatrix;
    FNormalMtx: TMatrix;
    FWorldViewProjMatrix: TMatrix;
    FCastPos: TVector4;
    FColorAmb: TVector4;
    FColorDiff: TVector4;
	  FColorSpc: TVector4;
  end;

  TRenderDeviceInfo = record
    ShaderVersion: Integer;
    UseConstBuffer: Boolean;
  end;

  TRasterMode = (rmDefault, rmWireframe);
  TShaderMode = (smBlank, smTest, smColor);
  TRenderDeviceFlag = (gmWindowed);
  TRenderDeviceFlags = set of TRenderDeviceFlag;

  TProjectionMode = (pmCamera, pmScreen);

  TGraphicsDeviceType = (dtOpenGL, dtDirectX);
  TDepthStencilMode = (dmTest, dmOff);

  TRenderDevice = class
  protected
    FActive: Boolean;
    FDeviceFlags: TRenderDeviceFlags;
    FRasterMode: TRasterMode;
    FShaderMode: TShaderMode;
    FDeviceType: TGraphicsDeviceType;
    FError: LongBool;
    FPerspMatrix: TMatrix;
    FViewRect: TRect;
    FWindowHandle: HWND;
    FMBufferModified: Boolean;
    FCBufferModified: Boolean;
    FVersion: Single;
    procedure UpdateMainBuffer(AShaderIndex: Integer); virtual; abstract;
    procedure UpdateCastBuffer(AShaderIndex: Integer); virtual; abstract;
    function GetViewWidth: Integer;
    function GetViewHeight: Integer;
    procedure SetShaders(AShaderIndex: Integer ; ABufferIndex: Integer); virtual; abstract;
    procedure SetRasterMode(ARasterMode: TRasterMode); virtual; abstract;
    procedure SetResources(ATexture: TTexture); virtual; abstract;
    procedure SetViewRect(AViewRect: TRect); virtual; abstract;
    procedure Start; virtual; abstract;
    procedure UpdateMatrix;
  public
    MainConst: TRenderDeviceMainConst;
    CastConst: TRenderDeviceCastConst;
    constructor Create(Windowed: Boolean; AWindowHandle: HWND; AViewRect: TRect); virtual;
    destructor Destroy; override;
    procedure ClearScene; virtual; abstract;
    function CreateIndexBuffer(AIndexArray: TShaderArray): Integer; virtual; abstract;
    function CreateVertexBuffer(AVertexArray: TShaderArray): Integer; virtual; abstract;
    function CreateResourceBuffer(ATexture: TTexture): Integer; virtual; abstract;
    procedure Draw(ACount: Integer; AVBufferIndex, AIBufferIndex: Integer; Instances: TInstanceArray); virtual; abstract;
    procedure GetDeviceInfo; virtual; abstract;
    function GetRay(AMouseX, AMouseY: Integer ; AWorldMatrix, AViewMatrix: TMatrix): TLine;
    function GetShaderIndex(var ASemantics: TShaderSemantics ; ATexture: TTexture): Integer; virtual; abstract;
    procedure Render(AMaterial: TMaterial ; AShaderIndex: Integer ; ATopology: TVertexTopology; AVBIndex, AIBIndex, ACount: Integer); overload;
    procedure Render(AMaterial: TMaterial ; AShaderIndex: Integer ; ATopology: TVertexTopology; AVBIndex, AIBIndex, ACount: Integer; Instances: TInstanceArray); overload;
    procedure SetBlendState(ABlendState: TBlendState); virtual; abstract;
    procedure SetTopology(AToplogy: TVertexTopology); virtual; abstract;
    procedure SetFullScreen(GoFullScreen: Boolean); virtual; abstract;
    procedure SetLight(ADirection: TVector4);
    procedure SetMainMatrix(const AViewMatrix, AProjMatrix: TMatrix);
    procedure SetCastMatrix(const APos: TVector3 ; const AWorldMatrix, ANormalMatrix: TMatrix);
    procedure Show; virtual; abstract;
    procedure UpdateVertexBuffer(AVBufferIndex: Integer ; AVertexArray: TShaderArray); virtual; abstract;
    procedure SetColors(const AAmbient, ADiffuse, ASpecular: TVector4);
  public
    property Active: Boolean read FActive write FActive;
    property ViewRect: TRect read FViewRect write SetViewRect;
    property PerspMatrix: TMatrix read FPerspMatrix;
    property RasterMode: TRasterMode read FRasterMode write SetRasterMode;
    property ShaderMode: TShaderMode read FShaderMode write FShaderMode;
    property DeviceType: TGraphicsDeviceType read FDeviceType;
    property ViewWidth: Integer read GetViewWidth;
    property ViewHeight: Integer read GetViewHeight;
    property Version: Single read FVersion;
  end;

implementation

constructor TRenderDevice.Create(Windowed: Boolean ; AWindowHandle: HWND ; AViewRect: TRect);
begin
  inherited Create;

  FWindowHandle := AWindowHandle;

  FDeviceFlags  := [];
  FRasterMode   := rmDefault;
  FShaderMode   := smColor;

  if (Windowed) then
  begin
    FViewRect     := AViewRect;
    FDeviceFlags  := FDeviceFlags + [gmWindowed];
  end
  else
    FViewRect := Rect(0, 0, 800, 600);

  UpdateMatrix;

  FMBufferModified := False;
  FCBufferModified := False;
end;

destructor TRenderDevice.Destroy();
begin
  inherited Destroy();
end;

procedure TRenderDevice.SetMainMatrix(const AViewMatrix, AProjMatrix: TMatrix);
begin
  MainConst.FViewMatrix := AViewMatrix;
  MainConst.FProjMatrix := AProjMatrix;
  MainConst.FViewProjMatrix := MainConst.FViewMatrix * MainConst.FProjMatrix;

  FMBufferModified := True;
end;

procedure TRenderDevice.SetCastMatrix(const APos: TVector3; const AWorldMatrix, ANormalMatrix: TMatrix);
begin
  CastConst.FCastPos   := TVector4.Create(APos);
  CastConst.FWorldMtx  := AWorldMatrix;
  CastConst.FNormalMtx := ANormalMatrix;
  CastConst.FWorldViewProjMatrix := AWorldMatrix * MainConst.FViewProjMatrix;

  FCBufferModified := True;
end;

procedure TRenderDevice.SetColors(const AAmbient, ADiffuse, ASpecular: TVector4);
begin
  CastConst.FColorAmb  := AAmbient;
  CastConst.FColorDiff := ADiffuse;
  CastConst.FColorSpc  := ASpecular;

  FCBufferModified := True;
end;

procedure TRenderDevice.SetLight(ADirection: TVector4);
begin
  if (not (ADirection = MainConst.FLightDir)) then
  begin
    MainConst.FLightDir := ADirection;
    FMBufferModified := True;
  end;
end;

function TRenderDevice.GetViewWidth(): Integer;
begin
  Result := ViewRect.Right - ViewRect.Left;
end;

function TRenderDevice.GetViewHeight(): Integer;
begin
  Result := ViewRect.Bottom - ViewRect.Top;
end;

////////////////////////////////////////////////////////////////////////////////
// Example from the DX 11 SDK - PICK
// Projection Matrix is the current Viewport Matrix
//
function TRenderDevice.GetRay(AMouseX, AMouseY: Integer; AWorldMatrix, AViewMatrix: TMatrix): TLine;
var
  AMousePos:    TVector3;
  AMatrix:      TMatrix;
begin
  AMousePos.X :=  (2.0 * AMouseX / ViewWidth - 1) / FPerspMatrix.XX;
  AMousePos.Y := -(2.0 * AMouseY / ViewHeight - 1) / FPerspMatrix.YY;
  AMousePos.Z := 1.0;

  AMatrix := AWorldMatrix * AViewMatrix;
  AMatrix := AMatrix.Invert;

  Result.V1.X := AMatrix.WX;
  Result.V1.Y := AMatrix.WY;
  Result.V1.Z := AMatrix.WZ;

  Result.V2.X := AMousePos.X * AMatrix.XX + AMousePos.Y * AMatrix.YX + AMousePos.Z * AMatrix.ZX;
  Result.V2.Y := AMousePos.X * AMatrix.XY + AMousePos.Y * AMatrix.YY + AMousePos.Z * AMatrix.ZY;
  Result.V2.Z := AMousePos.X * AMatrix.XZ + AMousePos.Y * AMatrix.YZ + AMousePos.Z * AMatrix.ZZ;
end;
////////////////////////////////////////////////////////////////////////////////

procedure TRenderDevice.Render(AMaterial: TMaterial ; AShaderIndex: Integer ; ATopology: TVertexTopology; AVBIndex, AIBIndex, ACount: Integer);
begin
  if (RasterMode <> rmWireframe) then
    SetColors(AMaterial.AmbientColor, AMaterial.DiffuseColor, AMaterial.SpecularColor);

  SetBlendState(AMaterial.BlendState);
  SetShaders(AShaderIndex, AVBIndex);
  SetResources(AMaterial.DiffuseMap);
  SetTopology(ATopology);

  UpdateMainBuffer(AShaderIndex);
  UpdateCastBuffer(AShaderIndex);

  Draw(ACount, AVBIndex, AIBIndex, nil);
end;

procedure TRenderDevice.Render(AMaterial: TMaterial ; AShaderIndex: Integer ; ATopology: TVertexTopology; AVBIndex, AIBIndex, ACount: Integer; Instances: TInstanceArray);
begin
  if (RasterMode <> rmWireframe) then
    SetColors(AMaterial.AmbientColor, AMaterial.DiffuseColor, AMaterial.SpecularColor);

  SetBlendState(AMaterial.BlendState);
  SetShaders(AShaderIndex, AVBIndex);
  SetResources(AMaterial.DiffuseMap);
  SetTopology(ATopology);

  UpdateMainBuffer(AShaderIndex);
  UpdateCastBuffer(AShaderIndex);

  Draw(ACount, AVBIndex, AIBIndex, Instances);
end;

procedure TRenderDevice.UpdateMatrix();
begin
  FPerspMatrix := TMatrix.PerspectiveFovLH(PI * 0.25, ViewWidth / ViewHeight, 0.05, 1000);
end;

end.
