// Copyright (c) 2021 Arsanias (arsaniasbb@gmail.com)
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.ShaderGL;

interface

uses
  Winapi.Windows, Winapi.Messages, System.Classes, System.SysUtils,
  Vcl.Forms, System.Types, System.IOUtils,
  dglOpenGL,
  Core.Types, Core.Utils, Core.Shader;

type
  TUniformLocations = record
    TransView:  GLint;
    TransProj:  GLint;
    TransWrld:  GLint;
    ColorAmb:   GLint;
	  ColorDiff:  GLint;
    ColorSpc:   GLint;
	  LightDir:   GLint;
	  CameraPos:  GLint;
    CastPos:    GLint;
  end;

  TShaderGL = class(TShader)
  private
    FVertexShader: GLhandle;
    FPixelShader: GLhandle;
    FProgramObject: GLhandle;
    FSemantics: TShaderSemantics;
    FStringList: TStringList;
    FIndex: Integer;
    FUseCB: Boolean;
    FVersion: Single;
    FUniformLocations: TUniformLocations;
    FMipMapped: Boolean;
    FTags: TShaderFlags;
    procedure CheckShaderError( AShader: GLhandle );
    procedure CheckProgramError();
    procedure CompileShader();
  public
    constructor Create(ASemantics: TShaderSemantics; ATags: TShaderFlags; Version: Single);
    destructor Destroy(); override;
    property Shader: GLhandle read FProgramObject;
    property Semantics: TShaderSemantics read FSemantics;
    property ProgramObject: GLhandle read FProgramObject;
    property UniformLocations: TUniformLocations read FUniformlocations;
    function ReadVertexFunc(): string;
    function ReadPixelFunc(): string;
    function ReadVertexCode(): string;
    function ReadPixelCode(): string;
    function ReadInputLayout(): string;
    function ReadConstants(): string;
    function ReadVariables(): string;
    function ReadVersion(): string;
    procedure ResetText();
    procedure AddText( AText: string ; AIncrement, ACondition: Boolean );
  end;

implementation

constructor TShaderGL.Create(ASemantics: TShaderSemantics; ATags: TShaderFlags; Version: Single);
var
  numElements: Cardinal;
  Result: GLhandle;
  fs: TFileStream;
  ABlockIndex: GLuint;
  ABufferName: AnsiString;
  AValueLocation: GLint;
  myarray: array[0..15] of Single;
begin
  inherited Create();

  FIndex      := 0;
  FVersion    := Version;
  FUseCB      := (Version >= 3.1);
  FStringList := TStringList.Create();
  FSemantics := ASemantics;
  FMipMapped := ( stMipMap in ATags );

  { create shaders }

  CompileShader();

  { create program and attach shaders }

  FProgramObject := glCreateProgram();
  glAttachShader( FProgramObject, FVertexShader );
  glAttachShader( FProgramObject, FPixelShader );
  glLinkProgram( FProgramObject );

  CheckProgramError();

  { bind buffers to program }

  if( FUseCB ) then
  begin
    ABufferName := AnsiString( 'GX_MainConst' );
    ABlockIndex := glGetUniformBlockIndex( FProgramObject , PGLChar( ABufferName ));
    glUniformBlockBinding( FProgramObject, ABlockIndex, 3 );

    ABufferName := AnsiString( 'GX_CastConst' );
    ABlockIndex := glGetUniformBlockIndex( FProgramObject , PGLChar( ABufferName ));
    glUniformBlockBinding( FProgramObject, ABlockIndex, 4 );
  end
  else
  begin
    FUniformLocations.TransView   := glGetUniformLocation( FProgramObject, 'TransView' );
    FUniformLocations.TransProj   := glGetUniformLocation( FProgramObject, 'TransProj' );
    FUniformLocations.TransWrld   := glGetUniformLocation( FProgramObject, 'TransWrld' );
    FUniformLocations.ColorAmb    := glGetUniformLocation( FProgramObject, 'ColorAmb' );
    FUniformLocations.ColorDiff   := glGetUniformLocation( FProgramObject, 'ColorDiff' );
    FUniformLocations.ColorSpc    := glGetUniformLocation( FProgramObject, 'ColorSpc' );
    FUniformLocations.LightDir    := glGetUniformLocation( FProgramObject, 'LightDir' );
    FUniformLocations.CameraPos   := glGetUniformLocation( FProgramObject, 'CameraPos' );
    FUniformLocations.CastPos     := glGetUniformLocation( FProgramObject, 'CastPos' );
  end;
end;

destructor TShaderGL.Destroy();
begin
  glDetachShader( FProgramObject, FVertexShader );
  glDetachShader( FProgramObject, FPixelShader );

  glDeleteShader( FVertexShader );
  glDeleteShader( FPixelShader );

  SafeFree( FStringList );

  inherited Destroy();
end;

procedure TShaderGL.ResetText();
begin
  FStringList.Clear();
end;

procedure TShaderGL.AddText( AText: string ; AIncrement, ACondition: Boolean );
begin
  if( FStringList = nil ) then Exit;

  if( ACondition = False )  then Exit;
  if( AIncrement = True )   then FIndex := FIndex + 1;

  FStringList.Add( AText );
end;

procedure TShaderGL.CompileShader();
var
  ShaderText: AnsiString;
  BufferSize: Cardinal;
begin
  { create and compile vertex shader }

  ShaderText := AnsiString( ReadVertexCode());
  BufferSize := Length( ShaderText );

  FVertexShader := glCreateShader( GL_VERTEX_SHADER );
  glShaderSource( FVertexShader, 1, @ShaderText, @BufferSize );
  glCompileShader( FVertexShader );

  CheckShaderError( FVertexShader );

  { create and compile pixel shader }

  ShaderText := ReadPixelCode();
  BufferSize := Length( ShaderText );

  FPixelShader := glCreateShader( GL_FRAGMENT_SHADER );
  glShaderSource( FPixelShader, 1, @ShaderText, @BufferSize );
  glCompileShader( FPixelShader );

  CheckShaderError( FPixelShader );
end;

procedure TShaderGL.CheckShaderError(AShader: GLhandle);
var
  blen, slen: GLInt;
  InfoLog: PGLChar;
  AMessage: Ansistring;
  AResult: GLint;
begin
  glGetShaderiv( AShader, GL_COMPILE_STATUS, @AResult );
  if( AResult = GL_FALSE ) then
  begin
    glGetShaderiv( AShader, GL_INFO_LOG_LENGTH , @blen );
    if( blen > 1 ) then
    begin
      GetMem(InfoLog, blen * SizeOf(GLCharARB));
      glGetShaderInfoLog( AShader, blen, slen, InfoLog );
      AMessage := PAnsiChar( InfoLog );
      AMessage := AMessage + AnsiString( FStringList.Text );
      MessageBoxA( 0, PAnsiChar( AMessage ), PAnsiChar( ''), MB_OK );
      Dispose( InfoLog );
    end;
  end;
end;

procedure TShaderGL.CheckProgramError();
var
  blen, slen: GLInt;
  InfoLog: PGLCharARB;
  AMessage: Ansistring;
  AResult: GLint;
begin
  glGetProgramiv( FProgramObject, GL_LINK_STATUS, @AResult );
  if( AResult = GL_FALSE ) then
  begin
    glGetProgramiv( FProgramObject, GL_INFO_LOG_LENGTH , @blen );
    if( blen > 1 ) then
    begin
      GetMem( InfoLog, blen * SizeOf( GLCharARB ));
      glGetProgramInfoLog( FProgramObject, blen, slen, InfoLog );
      AMessage := PAnsiChar( InfoLog );
      AMessage := AMessage + AnsiString( FStringList.Text );
      MessageBoxA( 0, PAnsiChar( AMessage ), PAnsiChar( ''), MB_OK );
      Dispose( InfoLog );
    end;
  end;
end;

function TShaderGL.ReadVersion(): string;
begin
  //AddText( '#version ' + IntToStr(FVersion),                                                    False, True );
  //AddText( '',                                                                                    False, True );
end;

function TShaderGL.ReadConstants(): string;
begin
  AddText( 'struct CGX_MainConst',                                                                False, ( FUseCB = False ));
  AddText( 'layout (std140) uniform GX_MainConst',                                                False, ( FUseCB = True ));
  AddText( '{',                                                                                   False, True );
  AddText( '    mat4 TransView;',                                                                 False, True );
  AddText( '    mat4 TransProj;',                                                                 False, True );
  AddText( '    mat4 TransViewProj;',                                                             False, True );
  AddText( '',                                                                                    False, True );
  AddText( '    vec4 LightDir;',                                                                  False, True );
  AddText( '    vec4 CameraPos;',                                                                 False, True );
  AddText( '};',                                                                                  False, True );
  AddText( 'uniform CGX_MainConst GX_MainConst;',                                                 False, ( FUseCB = False ));
  AddText( '',                                                                                    False, True );
  AddText( 'struct CGX_CastConst',                                                                False, ( FUseCB = False ));
  AddText( 'layout (std140) uniform GX_CastConst',                                                False, ( FUseCB = True ));
  AddText( '{',                                                                                   False, True );
  AddText( '    mat4 VertexMtx;',                                                                 False, True );
  AddText( '    mat4 NormalMtx;',                                                                 False, True );
  AddText( '    mat4 VertexViewProjMtx;',                                                         False, True );
  AddText( '',                                                                                    False, True );
  AddText( '    vec4 CastPos;',                                                                   False, True );
  AddText( '',                                                                                    False, True );
  AddText( '    vec4 ColorAmb;',                                                                  False, True );
  AddText( '    vec4 ColorDiff;',                                                                 False, True );
  AddText( '    vec4 ColorSpc;',                                                                  False, True );
  AddText( '};',                                                                                  False, True );
  AddText( 'uniform CGX_CastConst GX_CastConst;',                                                 False, ( FUseCB = False ));
  AddText( '',                                                                                    False, True );
end;

function TShaderGL.ReadVariables(): string;
begin
  AddText( '',                                                                                    False, True );
end;

function TShaderGL.ReadInputLayout(): string;
begin
  FIndex := 0;

  AddText( 'attribute vec4 VS_POS;',                                                              False, ( FUseCB = False ));
  AddText( 'attribute vec3 VS_NORM;',                                                             False, ( FUseCB = False ) and ( asNormal in FSemantics ));
  AddText( 'attribute vec2 VS_TEX;',                                                              False, ( FUseCB = False ) and ( asTexcoord in FSemantics ));
  AddText( 'attribute vec4 VS_COL;',                                                              False, ( FUseCB = False ) and ( asColor in FSemantics ));

  AddText( 'layout(location = ' + IntToStr( FIndex ) + ') in vec3 VS_POS;',                       True,  ( FUseCB = True ));
  AddText( 'layout(location = ' + IntToStr( FIndex ) + ') in vec3 VS_NORM;',                      True,  ( FUseCB = True ) and ( asNormal in FSemantics ));
  AddText( 'layout(location = ' + IntToStr( FIndex ) + ') in vec2 VS_TEX;',                       True,  ( FUseCB = True ) and ( asTexcoord in FSemantics ));
  AddText( 'layout(location = ' + IntToStr( FIndex ) + ') in vec4 VS_COL;',                       True,  ( FUseCB = True ) and ( asColor in FSemantics ));
  AddText( 'layout(location = ' + IntToStr( FIndex ) + ') in float VS_BONE;',                     True,  ( FUseCB = True ) and ( asBoneIndex in FSemantics ));
  AddText( '',                                                                                    False, ( FUseCB = True ));
end;

function TShaderGL.ReadVertexFunc(): string;
begin
  ReadInputLayout();

  AddText( 'vec4 PS_POS;',                                                                        False, True );
  AddText( 'out vec4 PS_NORM;',                                                                   False, ( asNormal in FSemantics ));
  AddText( 'out vec2 PS_TEX;',                                                                    False, ( asTexcoord in FSemantics ) or ( FMipMapped = True ));
  AddText( 'out vec4 PS_COL;',                                                                    False, ( asColor in FSemantics ));
  AddText( '',                                                                                    False, True );
  AddText( 'void main()',                                                                         False, True );
  AddText( '{',                                                                                   False, True );
  AddText( '    PS_POS = vec4( VS_POS, 1.0 );',                                                   False, True );
  AddText( '    PS_POS = VertexMtx * PS_POS;',                                                    False, True );
  AddText( '    PS_POS = TransView * PS_POS;',                                                    False, True );
  AddText( '    PS_POS = TransProj * PS_POS; ',                                                   False, True );
  AddText( '',                                                                                    False, ( asNormal in FSemantics ));
  AddText( '    PS_NORM = vec4( VS_NORM, 1.0 );',                                                 False, ( asNormal in FSemantics ));
  AddText( '    PS_NORM = NormalMtx * PS_NORM;',                                                  False, ( asNormal in FSemantics ));
  AddText( '    PS_TEX = VS_TEX;',                                                                False, ( asTexcoord in FSemantics ) and ( FMipMapped = False ));
  AddText( '    PS_COL = VS_COL;',                                                                False, ( asColor in FSemantics ));
  AddText( '',                                                                                    False, True );
  AddText( '    PS_TEX.x = VS_POS.x * 0.4;',                                                      False, ( FMipMapped = True ));
  AddText( '    PS_TEX.y = VS_POS.z * 0.4;',                                                      False, ( FMipMapped = True ));
  AddText( '',                                                                                    False, True );
  AddText( '    gl_Position = PS_POS;',                                                           False, True );
  AddText( '}',                                                                                   False, True );
end;

function TShaderGL.ReadPixelFunc(): string;
begin
  AddText( 'uniform sampler2D texSampler;',                                                       False, ( asTexcoord in FSemantics ) or ( FMipMapped = True ));
  AddText( '',                                                                                    False, ( asTexcoord in FSemantics ) or ( FMipMapped = True ));
  AddText( 'in  vec4 PS_NORM;',                                                                   False, ( asNormal in FSemantics ));
  AddText( 'in  vec2 PS_TEX;',                                                                    False, ( asTexcoord in FSemantics ) or ( FMipMapped = True ));
  AddText( 'in  vec4 PS_COL;',                                                                    False, ( asColor in FSemantics ));
  AddText( 'out vec4 RESULT;',                                                                    False, ( FUseCB = True ));
  AddText( 'vec4 RESULT;',                                                                        False, ( FUseCB = False ));
  AddText( '',                                                                                    False, True );
  AddText( 'void main()',                                                                         False, True );
  AddText( '{',                                                                                   False, True );
  AddText( '    RESULT = texture2D( texSampler, PS_TEX );',                                       False, ( asTexcoord in FSemantics ) or ( FMipMapped = True ));
  AddText( '    RESULT = PS_COL;',                                                                False, ( asColor in FSemantics ));
  AddText( '    RESULT = ColorAmb + ColorDiff;',                                                  False, ( not( asTexcoord in FSemantics )) and ( not( asColor in FSemantics )));
  AddText( '',                                                                                    False, True );
  AddText( '    RESULT = dot( LightDir, normalize(PS_NORM)) * RESULT;',                           False, ( asNormal in FSemantics ));
  AddText( '    float ATransparency = RESULT.xyz * 1.0f;      ',                                  False, ( stOpaqueColor in FTags ));
  AddText( '    RESULT.a = ATransparency;',                                                       False, ( stOpaqueColor in FTags ));
  AddText( '    gl_FragColor = RESULT;',                                                          False, ( FUseCB = False ));
  AddText( '}',                                                                                   False, True );
end;

function TShaderGL.ReadVertexCode(): string;
begin
  ResetText();

  ReadVersion();

  AddText( '//---------------------------------------------------------------------------------', False, True );
  AddText( '// Buffers',                                                                          False, True );
  AddText( '//---------------------------------------------------------------------------------', False, True );

  ReadConstants();

  AddText( '//---------------------------------------------------------------------------------', False, True );
  AddText( '// Variables',                                                                        False, True );
  AddText( '//---------------------------------------------------------------------------------', False, True );

  ReadVariables();

  AddText( '//---------------------------------------------------------------------------------', False, True );
  AddText( '// function',                                                                         False, True );
  AddText( '//---------------------------------------------------------------------------------', False, True );

  ReadVertexFunc();

  Result := FStringList.Text;
  //if (FMipMapped) then
    //FStringlist.SaveToFile('C:\Users\akaragm\Documents\RAD Studio\Projekte\GameMachine\testing\Shader\VertexShader.glsl');
end;

function TShaderGL.ReadPixelCode(): string;
begin
  ResetText();

  ReadVersion();

  AddText( '//---------------------------------------------------------------------------------', False, True );
  AddText( '// Buffers',                                                                          False, True );
  AddText( '//---------------------------------------------------------------------------------', False, True );

  ReadConstants();

  AddText( '//---------------------------------------------------------------------------------', False, True );
  AddText( '// Variables',                                                                        False, True );
  AddText( '//---------------------------------------------------------------------------------', False, True );

  ReadVariables();

  AddText( '//---------------------------------------------------------------------------------', False, True );
  AddText( '// function',                                                                         False, True );
  AddText( '//---------------------------------------------------------------------------------', False, True );


  ReadPixelFunc();

  Result := FStringList.Text;
  //if (FMipMapped ) then
    //FStringlist.SaveToFile( 'C:\Users\akaragm\Documents\RAD Studio\Projekte\GameMachine\testing\Shader\PixelShader.glsl' );
end;

end.
