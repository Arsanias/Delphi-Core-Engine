// Copyright (c) 2021 Arsanias (arsaniasbb@gmail.com)
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.RenderDeviceGL;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.Types, System.SysUtils, System.StrUtils,
  Vcl.Forms, Vcl.Dialogs,
  dglOpenGL,
  Core.Types, Core.Utils, Core.Arrays, Core.RenderDevice, Core.Material, Core.Model,
  Core.Cast, Core.Camera, Core.Shader, Core.ShaderGL;

type
  PVertexBufferGL = ^TVertexBufferGL;
  TVertexBufferGL = record
    Data: GLuint;
    Name: string;
    Size: Cardinal;
    Stride: GLsizei;
    VertexCount: Cardinal;
  end;

  PIndexBufferGL = ^TIndexBufferGL;
  TIndexBufferGL = record
    Data: GLuint;
    Size: Cardinal;
    Name: string;
    IndexCount: Cardinal;
    IndexSize: Cardinal;
  end;

  PResourceBufferGL = ^TResourceBufferGL;
  TResourceBufferGL = record
    Data: GLuint;
    Name: string;
    Size: Cardinal;
  end;

  TRenderDeviceGL = class(TRenderDevice)
  private
    { opengl }
    FDC: HDC;
    FRC: HGLRC;
    FDeviceFlags: TRenderDeviceFlags;
    FDeviceInfo: TRenderDeviceInfo;
    FDrawMode: GLenum;
    FShaders: array[0..6] of TShaderGL;
    FSampler: GLuint;
    FMainBufferID: GLuint;
    FCastBufferID: GLuint;
    FVertexBuffers: TNodeList<PVertexBufferGL>;
    FIndexBuffers: TNodeList<PIndexBufferGL>;
    FResourceBuffers: TNodeList<PResourceBufferGL>;
    procedure Clear;
    procedure Start;
    procedure CreateConstantBuffers;
    procedure CreateSampler;
    function GetBuffer(ASize: Cardinal; AData: Pointer; ATarget: GLenum): GLuint;
    procedure SetRasterMode(ARasterMode: TRasterMode); override;
  public
    { derived from device }
    constructor Create(Windowed: Boolean; AWindowHandle: HWND; AViewRect: TRect); override;
    destructor Destroy; override;
  public
    procedure ClearScene; override;
    function CreateIndexBuffer(AIndexArray: TShaderArray): Integer; override;
    function CreateResourceBuffer(ATexture: TTexture): Integer; override;
    function CreateVertexBuffer(AVertexArray: TShaderArray): Integer; override;
    procedure Draw(ACount: Integer; AVBufferIndex, AIBufferIndex: Integer; Instances: TInstanceArray); override;
    procedure GetDeviceInfo; override;
    function GetShaderIndex(var ASemantics: TShaderSemantics ; ATexture: TTexture): Integer; override;
    procedure SetBlendState(ABlendState: TBlendState); override;
    procedure SetFullScreen(GoFullScreen: Boolean); override;
    procedure SetResources(ATexture: TTexture); override;
    procedure SetViewRect(AViewRect: TRect); override;
    procedure SetShaders(AShaderIndex: Integer ; ABufferIndex: Integer); override;
    procedure SetTopology(ATopology: TVertexTopology); override;
    procedure Show; override;
    procedure UpdateCastBuffer(AShaderIndex: Integer); override;
    procedure UpdateMainBuffer(AShaderIndex: Integer); override;
    procedure UpdateVertexBuffer(AVBufferIndex: Integer ; AVertexArray: TShaderArray); override;
  end;

implementation

constructor TRenderDeviceGL.Create(Windowed : Boolean ; AWindowHandle: HWND ; AViewRect: TRect) ;
begin
  inherited Create(Windowed, AWindowHandle, AViewRect);

  FDeviceType := dtOpenGL;

  // create vertex and index buffer list

  FVertexBuffers := TNodeList<PVertexBufferGL>.Create;
  FIndexBuffers  := TNodeList<PIndexBufferGL>.Create;
  FResourceBuffers := TNodeList<PResourceBufferGL>.Create;

  Start;
end;

destructor TRenderDeviceGL.Destroy;
begin
  Clear;

  inherited Destroy;
end;

function TRenderDeviceGL.GetBuffer(ASize: Cardinal; AData: Pointer ; ATarget: GLenum): GLuint;
begin
  glGenBuffers(1, @Result);
  glBindBuffer(ATarget, Result);
  glBufferData(ATarget, ASize, AData, GL_STATIC_DRAW);
  glBindBuffer(ATarget, 0);
end;

procedure TRenderDeviceGL.GetDeviceInfo;
var
  AString: string;
  AMajor: GLint;
  AMinor: GLint;
  AArray: TStringDynArray;
begin
  { get version }

  glGetIntegerv(GL_MAJOR_VERSION, @AMajor);
  glGetIntegerv(GL_MINOR_VERSION, @AMinor);

  FVersion := AMajor + AMinor / 10;

  if (Version < 3.1) then
    FDeviceInfo.ShaderVersion := 120
  else
    FDeviceInfo.ShaderVersion := 330;

  { set device capabilities based on version }

  FDeviceInfo.UseConstBuffer := Version >= 3.3;
end;

procedure TRenderDeviceGL.CreateConstantBuffers;
var
  MaxBindings: PGLint;
begin
  if (FDeviceInfo.UseConstBuffer) then
  begin
    { create main buffer }

    glGenBuffers(1, @FMainBufferID);
    glBindBuffer(GL_UNIFORM_BUFFER, FMainBufferID);
    glBufferData(GL_UNIFORM_BUFFER, SizeOf(TRenderDeviceMainConst), @MainConst, GL_DYNAMIC_DRAW);

    { create cast buffer }

    glGenBuffers(1, @FCastBufferID);
    glBindBuffer(GL_UNIFORM_BUFFER, FCastBufferID);
    glBufferData(GL_UNIFORM_BUFFER, SizeOf(TRenderDeviceCastConst), @CastConst, GL_DYNAMIC_DRAW);
  end;
end;

procedure TRenderDeviceGL.Start;
var
  ABlockIndex, ABufferIndex: GLuint;
  ABindingLocation: GLuint;
  AOffset: GLintPtr;
  ASize: GLsizeiptr;
  Avalue1, AValue2: GLint;
  GAGA: PAnsiChar;
  ABufferName: AnsiString;
  AVector: array[0..3] of Integer;
begin
  { initialize and open device }

  if (not InitOpenGL) then Exit;

  { create and activate rendering context }

  FDC := GetDC(FWindowHandle);
  FRC := CreateRenderingContext(FDC, [opDoubleBuffered], 32, 24, 0, 0, 0, 0);
  ActivateRenderingContext(FDC, FRC);

  GetDeviceInfo;

  { activate depth buffer }

  glEnable(GL_DEPTH_TEST);

  { set display modes }

  glEnable(GL_CULL_FACE);
  glFrontFace(GL_CW);
  glCullFace(GL_BACK);

	{ create shaders }

  FShaders[0] := TShaderGL.Create([asPosition], [], Version);
  FShaders[1] := TShaderGL.Create([asPosition, asNormal], [], Version);
  FShaders[2] := TShaderGL.Create([asPosition, asTexcoord], [], Version);
  FShaders[3] := TShaderGL.Create([asPosition, asColor], [], Version);
  FShaders[4] := TShaderGL.Create([asPosition, asNormal, asTexcoord], [], Version);
  FShaders[5] := TShaderGL.Create([asPosition, asNormal], [stMipMap], Version);
  FShaders[6] := TShaderGL.Create([asPosition, asTexcoord], [stOpaqueColor], Version);

  CreateConstantBuffers;
  CreateSampler;

  FActive := True;
end;

procedure TRenderDeviceGL.Clear;
var
  i: Integer;
  AVertexBuffer, AVertexBufferTemp: PVertexBufferGL;
begin
  { hold engine and wait }

  FActive := False;
  Sleep(250);

  { shut down device }

  DeactivateRenderingContext;
  wglDeleteContext(FRC);
  ReleaseDC(FWindowHandle, FDC);
  ChangeDisplaySettings(devmode(nil^), 0);

  { delete samplers }

  glDeleteSamplers(1, @FSampler);

  { free shaders }

  if (Length(FShaders) > 0) then
    for i := 0 to 6 do
      SafeFree(FShaders[i]);

  { delete vertex buffer }

  if ((FVertexBuffers <> nil) and (FVertexBuffers.Count > 0)) then
  begin
    for i := 0 to FVertexBuffers.Count - 1 do
    begin
      glDeleteBuffers(1, @FVertexBuffers[i].Data);
      Dispose(FVertexBuffers[i]);
    end;
  end;
  SafeFree(FVertexBuffers);

  { delete index buffers }

  if ((FIndexBuffers <> nil) and (FIndexBuffers.Count > 0)) then
  begin
    for i := 0 to FIndexBuffers.Count - 1 do
    begin
      glDeleteBuffers(1, @FIndexBuffers[i].Data);
      Dispose(FIndexBuffers[i]);
    end;
  end;
  SafeFree(FIndexBuffers);

  { delete resource buffers }

  if ((FResourceBuffers <> nil) and (FResourceBuffers.Count > 0)) then
  begin
    for i := 0 to FResourceBuffers.Count - 1 do
    begin
      glDeleteBuffers(1, @FResourceBuffers[i].Data);
      Dispose(FResourceBuffers[i]);
    end;
  end;
  SafeFree(FResourceBuffers);

  { delete constant buffers }

  glDeleteBuffers(1, @FMainBufferID);
  glDeleteBuffers(1, @FCastBufferID);

  FRC := 0;
  FDC := 0;
end;

procedure TRenderDeviceGL.SetBlendState(ABlendState: TBlendState);
begin
  case ABlendState of
    bsSolid:
      begin
        glDisable(GL_BLEND);
        glDisable(GL_SAMPLE_ALPHA_TO_COVERAGE);
      end;
    bsTransparent:
      begin
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glEnable(GL_SAMPLE_ALPHA_TO_COVERAGE);
      end;
  end;
end;

procedure TRenderDeviceGL.SetRasterMode(ARasterMode: TRasterMode);
begin
  case ARasterMode of
    rmDefault:
      begin
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
        glDisable(GL_POLYGON_OFFSET_LINE);
      end
    else
      begin
        glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
        glEnable(GL_POLYGON_OFFSET_LINE);
        glPolygonOffset(1.0, 2.0);
      end;
  end;
end;

procedure TRenderDeviceGL.SetViewRect(AViewRect: TRect);
begin
  FViewRect := AViewRect;

  glViewPort(AViewRect.Left, AViewRect.Top, ViewWidth, ViewHeight);
  gluPerspective(PI * 0.25, ViewWidth / ViewHeight, 1.0, 1000);

  UpdateMatrix;
end;

procedure TRenderDeviceGL.ClearScene;
var
  AClearColor: TVector4;
begin
  AClearColor := TVector4.Create(0.20, 0.40, 0.40, 1.00);

  glClearColor(AClearColor.R, AClearColor.G, AClearcolor.B, AClearColor.A);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
end;

procedure TRenderDeviceGL.SetFullScreen(GoFullScreen: Boolean);
begin
  //FSwapChain.SetFullscreenState(GoFullScreen, nil);
end;

procedure TRenderDeviceGL.UpdateMainBuffer(AShaderIndex: Integer);
var
  AShader: TShaderGL;
begin
  if (FDeviceInfo.UseConstBuffer) then
  begin
    glBindBuffer(GL_UNIFORM_BUFFER, FMainBufferID);
    glBufferSubData(GL_UNIFORM_BUFFER, 0, SizeOf(TRenderDeviceMainConst), @MainConst);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
    glBindBufferBase(GL_UNIFORM_BUFFER, 3, FMainBufferID);
  end
  else
  if (AShaderIndex >= 0) then
  begin
    AShader := FShaders[AShaderIndex];
    glUniformMatrix4fv(AShader.UniformLocations.TransView, 1, False, @MainConst.FViewMatrix);
    glUniformMatrix4fv(AShader.UniformLocations.TransProj, 1, False, @MainConst.FProjMatrix);
    glUniform4fv(AShader.UniformLocations.LightDir, 1, @MainConst.FLightDir);
    glUniform4fv(AShader.UniformLocations.CameraPos, 1, @MainConst.FCameraPos);
  end;
end;

procedure TRenderDeviceGL.UpdateCastBuffer(AShaderIndex: Integer);
begin
  glBindBuffer(GL_UNIFORM_BUFFER, FCastBufferID);
  glBufferSubData(GL_UNIFORM_BUFFER, 0, SizeOf(TRenderDeviceCastConst), @CastConst);
  glBindBuffer(GL_UNIFORM_BUFFER, 0);
  glBindBufferBase(GL_UNIFORM_BUFFER, 4, FCastBufferID);
end;

function TRenderDeviceGL.CreateVertexBuffer(AVertexArray: TShaderArray): Integer;
var
  AVertexBuffer: PVertexBufferGL;
begin
  AVertexBuffer := New(PVertexBufferGL);

  AVertexBuffer.Size   := AVertexArray.Size;
  AVertexBuffer.Stride := AVertexArray.Stride;
  AVertexBuffer.VertexCount := AVertexArray.RowCount;
  AVertexBuffer.Data := GetBuffer(AVertexBuffer.Size, AVertexArray.Data, GL_ARRAY_BUFFER);

  Result := FVertexBuffers.Add(AVertexBuffer);
end;

procedure TRenderDeviceGL.UpdateVertexBuffer(AVBufferIndex: Integer ; AVertexArray: TShaderArray);
var
  AVertexBuffer: PVertexBufferGL;
begin
  AVertexBuffer := FVertexBuffers[AVBufferIndex];

  glBindBuffer(GL_ARRAY_BUFFER, FMainBufferID);
  glBufferSubData(GL_ARRAY_BUFFER, 0, AVertexBuffer.Size, AVertexArray.Data);
  glBindBuffer(GL_ARRAY_BUFFER, 0);
end;

function TRenderDeviceGL.CreateIndexBuffer(AIndexArray: TShaderArray): Integer;
var
  AIndexBuffer: PIndexBufferGL;
begin
  AIndexBuffer := New(PIndexBufferGL);

  AIndexBuffer.IndexCount := AIndexArray.RowCount;
  AIndexBuffer.Size := AIndexArray.Size;
  AIndexBuffer.IndexSize := 4;
  AIndexBuffer.Data := GetBuffer(AIndexBuffer.Size, AIndexArray.Data, GL_ELEMENT_ARRAY_BUFFER);

  Result := FIndexBuffers.Add(AIndexBuffer);
end;

function TRenderDeviceGL.CreateResourceBuffer(ATexture: TTexture): Integer;
var
  AResourceBuffer: PResourceBufferGL;
begin
  if (ATexture = nil) then Exit(-1);

  AResourceBuffer := New(PResourceBufferGL);

  glGenTextures(1, @AResourceBuffer.Data);
  glBindTexture(GL_TEXTURE_2D, AResourceBuffer.Data);
  glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, ATexture.Width, ATexture.Height, 0, GL_RGBA, GL_UNSIGNED_BYTE, ATexture.Data);

  if (AResourceBuffer.Data = 0) then
  begin
    Dispose(AResourceBuffer);
    Exit(-1);
  end;
  AResourceBuffer.Size := ATexture.Size;

  Result := FResourceBuffers.Add(AResourceBuffer);
end;

procedure TRenderDeviceGL.CreateSampler;
begin
  glGenSamplers(1, @FSampler);

  glSamplerParameteri(FSampler, GL_TEXTURE_WRAP_S,  GL_REPEAT);
  glSamplerParameteri(FSampler, GL_TEXTURE_WRAP_T,  GL_REPEAT);
  glSamplerParameteri(FSampler, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glSamplerParameteri(FSampler, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
  glSamplerParameterf(FSampler, GL_TEXTURE_MAX_ANISOTROPY_EXT, 16.0);
end;

function TRenderDeviceGL.GetShaderIndex(var ASemantics: TShaderSemantics; ATexture: TTexture): Integer;
var
  i: Integer;
begin
  { remove texcoord semantic if material does not have a texture resource }

  if ((asTexcoord in ASemantics) and ((ATexture = nil) or (ATexture.RBufferIndex < 0))) then
    ASemantics := ASemantics - [asTexcoord];

  for i := 0 to 6 - 1 do
    if (FShaders[i].Semantics = ASemantics) then
    begin
      Result := i;
      Break;
    end;
end;

procedure TRenderDeviceGL.SetShaders(AShaderIndex: Integer ; ABufferIndex: Integer);
var
  AIndex, AOffset: LONGWORD;
  AShader: TShaderGL;
begin
  AShader := FShaders[AShaderIndex];

  glUseProgram(AShader.ProgramObject);

  glBindBuffer(GL_ARRAY_BUFFER, FVertexBuffers[ABufferIndex].Data);

  AOffset := 0;
  AIndex  := 0;

  if (asPosition in AShader.Semantics) then
  begin
    glEnableVertexAttribArray(AIndex);
    glVertexAttribPointer(AIndex, 3, GL_FLOAT, GLboolean(GL_FALSE), FVertexBuffers[ABufferIndex].Stride, Pointer(AOffset));
    Inc(AIndex);
    Inc(AOffset, 12);
  end;

  if (asNormal in AShader.Semantics) then
  begin
    glEnableVertexAttribArray(AIndex);
    glVertexAttribPointer(AIndex, 3, GL_FLOAT, GLboolean(GL_FALSE), FVertexBuffers[ABufferIndex].Stride, Pointer(AOffset));
    Inc(AIndex);
    Inc(AOffset, 12);
  end;

  if (asTexcoord in AShader.Semantics) then
  begin
    glEnableVertexAttribArray(AIndex);
    glVertexAttribPointer(AIndex, 2, GL_FLOAT, GLboolean(GL_FALSE), FVertexBuffers[ABufferIndex].Stride, Pointer(AOffset));
    Inc(AIndex);
    Inc(AOffset,  8);
  end;

  if (asColor in AShader.Semantics) then
  begin
    glEnableVertexAttribArray(AIndex);
    glVertexAttribPointer(AIndex, 4, GL_FLOAT, GLboolean(GL_FALSE), FVertexBuffers[ABufferIndex].Stride, Pointer(AOffset));
    Inc(AIndex);
    Inc(AOffset,  16);
  end;
end;

procedure TRenderDeviceGL.SetResources(ATexture: TTexture);
begin
  if ((ATexture <> nil) and (ATexture.RBufferIndex >= 0)) then
  begin
    glBindSampler(0, FSampler);
    glBindTexture(GL_TEXTURE_2D, FResourceBuffers[ATexture.RBufferIndex].Data);
  end
  else
    glBindSampler(0, 0);
end;

procedure TRenderDeviceGL.SetTopology(ATopology: TVertexTopology);
begin
  case ATopology of
    ptPoints: FDrawMode := GL_POINTS;
    ptLines: FDrawMode := GL_LINES;
    ptTriangles: FDrawMode := GL_TRIANGLES;
    else
      FDrawMode := GL_TRIANGLES;
  end;
end;

procedure TRenderDeviceGL.Draw(ACount: Integer; AVBufferIndex, AIBufferIndex: Integer; Instances: TInstanceArray);
var
  i: Integer;
  AVertexBuffer: PVertexBufferGL;
begin
  AVertexBuffer := FVertexBuffers[AVBufferIndex];

  if (AIBufferIndex >= 0) then
  begin
    if (ACount = 0) then ACount := FIndexBuffers[AIBufferIndex].IndexCount;
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, FIndexBuffers[AIBufferIndex].Data);
    glDrawElements(FDrawMode, ACount, GL_UNSIGNED_INT, @FIndexBuffers[AIBufferIndex].Data);
    glDisableClientState(GL_VERTEX_ARRAY);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
  end
  else
  begin
    if (ACount = 0) then ACount := AVertexBuffer.VertexCount;
    glDrawArrays(FDrawMode, 0, ACount);
  end;

  glBindBuffer(GL_ARRAY_BUFFER, 0);
  for i := 0 to 3 - 1 do
    glDisableVertexAttribArray(i);
end;

procedure TRenderDeviceGL.Show;
begin
  SwapBuffers(FDC);
end;


end.
