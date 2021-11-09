// Copyright (c) 2021 Arsanias (arsaniasbb@gmail.com)
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.ShaderDX;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Types, System.Classes, System.IOUtils,
  Vcl.Forms, Vcl.Dialogs,
  DXTypes_JSB, DXGI_JSB, D3DCommon_JSB, D3D11_JSB, D3DX11_JSB, D3DCompiler_JSB, D3DX10_JSB,
  Core.Types, Core.Shader;

type
  TShaderDX = class(TShader)
  private
    FDevice: ID3D11Device;
    FVertexShader: ID3D11VertexShader;
    FPixelShader: ID3D11PixelShader;
    FInputLayout: ID3D11InputLayout;
    FStringList: TStringList;
    FIndex: Integer;
    FMipMapped: Boolean;
    FInputs: TArray<D3D11_INPUT_ELEMENT_DESC>;
    FTags: TShaderFlags;
    FDXVersion: Single;
  private
    function ReadMainVars: string;
    function ReadModelVars: string;
    function ReadInputStruct: string;
    function ReadVariables: string;
    function ReadOutputStruct: string;
    function ReadVertexFunc: string;
    function ReadPixelFunc: string;
    function ReadVertexCode: string;
    function ReadPixelCode: string;
  public
    FSemantics: TShaderSemantics;
    constructor Create(ADevice: ID3D11Device; ASemantics: TShaderSemantics; ATags: TShaderFlags; DxVersion: Single);
    destructor Destroy; override;
  public
    property VertexShader: ID3D11VertexShader read FVertexShader;
    property PixelShader: ID3D11PixelShader read FPixelShader;
    property InputLayout: ID3D11InputLayout read FInputLayout;
    procedure CompileShader;
    procedure SetInputLayout(AShaderByteCode: Pointer; AShaderByteSize: Cardinal);
    procedure AddInputElement(ASemantic: TShaderSemantic ; ASemanticName: LPCSTR; Format: TDXGI_Format; var AByteOffset: UINT );
    procedure ResetText;
    procedure AddText(AText: string; AIncrement, ACondition: Boolean);
  public
    property ShaderInputs: TShaderSemantics read FSemantics;
    property DXVersion: Single read FDXVersion;
  end;

implementation

constructor TShaderDX.Create(ADevice: ID3D11Device; ASemantics: TShaderSemantics; ATags: TShaderFlags; DXVersion: Single);
begin
  inherited Create();

  FDevice     := ADevice;
  FStringList := TStringList.Create();
  FSemantics  := ASemantics;
  FMipMapped  := ( stMipMap in ATags );
  FTags       := ATags;
  FDXVersion := DXVersion;

  CompileShader();
end;

destructor TShaderDX.Destroy();
begin
  FPixelShader  := nil;
  FVertexShader := nil;
  FDevice       := nil;

  inherited Destroy();
end;

procedure TShaderDX.ResetText();
begin
  FStringList.Clear();
end;

procedure TShaderDX.AddText( AText: string ; AIncrement, ACondition: Boolean );
begin
  if( FStringList = nil ) then Exit;

  if( ACondition = False )  then Exit;
  if( AIncrement = True )   then FIndex := FIndex + 1;

  FStringList.Add( AText );
end;

procedure TShaderDX.CompileShader();
var
  ShaderName: string;
  pBuffer: AnsiString;
  BufferSize: Cardinal;
  Result: HRESULT;
  fs: TFileStream;
  dwShaderFlags: Cardinal;
  hr: HRESULT;
  AShaderByteCode, ErrorBlob: ID3DBlob;
  sm: TD3D_ShaderMacro;
  PErrorBuffer: array[ 0..2045 ] of AnsiChar;
  AText: AnsiString;
  FeatureStr: string;
begin
  { shader macro definition }

  if DXVersion < 10 then
    FeatureStr := '_level_' + Trunc(DXVersion).ToString + '_' + Trunc(Frac(DXVersion) * 10).ToString
  else
    FeatureStr := '';

  sm.Name := '';
  sm.Definition := '';

  { set shader flags }

  dwShaderFlags := Cardinal(D3DCOMPILE_ENABLE_STRICTNESS );
  {$IFDEF DEBUG}
    dwShaderFlags := dwShaderFlags or Cardinal( D3DCOMPILE_DEBUG );
  {$ENDIF}

  { read, compile and create vertex shader }

  pBuffer := AnsiString(ReadVertexCode);
  BufferSize := Length(pBuffer);

  hr := D3DCompile(PAnsiChar(pBuffer), BufferSize, nil, nil, nil, PAnsiChar(AnsiString('VS')), PAnsiChar( AnsiString( 'vs_4_0' + FeatureStr)), dwShaderFlags, 0, AShaderByteCode, ErrorBlob );
  if (FAILED(hr)) then
    raise Exception.Create('Could not compile Shader ' + pBuffer);

  //SetString(AText, PChar(AShaderByteCode.GetBufferPointer), AShaderByteCode.GetBufferSize);
  //ShowMessage(AText);

  FVertexShader := nil;
  hr := FDevice.CreateVertexShader(AShaderByteCode.GetBufferPointer, AShaderByteCode.GetBufferSize, nil, FVertexShader);
  if (FAILED(hr)) then
    ShowMessage('Error creating Vertexshader: ' + IntToHex(hr, 8) + ': ' + SysErrorMessage(hr));

  SetInputLayout( AShaderByteCode.GetBufferPointer(), AShaderByteCode.GetBufferSize );

  { read, compile and create pixel shader }

  pBuffer := AnsiString(ReadPixelCode());
  BufferSize := Length( pBuffer );

  hr := D3DCompile( PAnsiChar( pBuffer ), BufferSize, nil, nil, nil, PAnsiChar( AnsiString( 'PS' )), PAnsiChar( AnsiString( 'ps_4_0' + FeatureStr)), dwShaderFlags, 0, AShaderByteCode, ErrorBlob );
  if( FAILED(hr)) then Exit;

  hr := FDevice.CreatePixelShader(AShaderByteCode.GetBufferPointer(), AShaderByteCode.GetBufferSize(), nil, FPixelShader );
  if( FAILED( hr )) then
    ShowMessage('Error creating Pixelshader: ' + IntToHex(hr, 8) + ': ' + SysErrorMessage(hr));
end;

procedure TShaderDX.AddInputElement( ASemantic: TShaderSemantic ; ASemanticName: LPCSTR; Format: TDXGI_Format; var AByteOffset: UINT );
var
  n: Integer;
begin
  if( not ( ASemantic in FSemantics )) then Exit;

  n := Length( FInputs );
  SetLength( FInputs, n + 1 );

  FInputs[ n ].SemanticName          := ASemanticName;
  FInputs[ n ].SemanticIndex         := 0;
  FInputs[ n ].Format                := Format;
  FInputs[ n ].InputSlot             := 0;
  FInputs[ n ].AlignedByteOffset     := AByteOffset;
  FInputs[ n ].InputSlotClass        := D3D11_INPUT_PER_VERTEX_DATA;
  FInputs[ n ].InstanceDataStepRate  := 0;

  case Format of
    DXGI_FORMAT_R32G32_FLOAT:       Inc( AByteOffset,  8 );
    DXGI_FORMAT_R32G32B32_FLOAT:    Inc( AByteOffset, 12 );
    DXGI_FORMAT_R32G32B32A32_FLOAT: Inc( AByteOffset, 16 );
  end;
end;

procedure TShaderDX.SetInputLayout( AShaderByteCode: Pointer ; AShaderByteSize: Cardinal );
var
  AByteOffset: UINT;
  numElements: Cardinal;
  hr: HRESULT;
begin
  AByteOffset := 0;
  AddInputElement( asPosition,  'POSITION',  DXGI_FORMAT_R32G32B32_FLOAT,     AByteOffset );
  AddInputElement( asNormal,    'NORMAL',    DXGI_FORMAT_R32G32B32_FLOAT,     AByteOffset );
  AddInputElement( asColor,     'COLOR',     DXGI_FORMAT_R32G32B32A32_FLOAT,  AByteOffset );
  AddInputElement( asTexcoord,  'TEXCOORD',  DXGI_FORMAT_R32G32_FLOAT,        AByteOffset );
  numElements := Length( FInputs );

  hr := FDevice.CreateInputLayout( @FInputs[0], numElements, AShaderByteCode, AShaderByteSize, FInputLayout);
  if( FAILED( hr )) then Exit;
end;

//**********************************************************************************************************************
// Please bear in mind that the compiler reserves a shader slot for each constant buffer but only if at least one
// variable of this buffer is used in the shader byte code. If one of the below stated constants should not be in
// use, then do not link or update a constant buffer to the relevant shader.
//**********************************************************************************************************************
function TShaderDX.ReadMainVars(): string;
begin
  AddText( 'cbuffer GX_MainConst : register(b0)',                                                                False, True);
  AddText( '{',                                                                                   False, True);
  AddText( '    matrix TransView;',                                                               False, True );
  AddText( '    matrix TransProj;',                                                               False, True );
  AddText( '    matrix TransViewProj;',                                                           False, True );
  AddText( '',                                                                                    False, True );
  AddText( '    float4 LightDir;',                                                                False, True );
  AddText( '    float4 CameraPos;',                                                               False, True );
  AddText( '}',                                                                                   False, True);
  AddText( '',                                                                                    False, True );
end;

function TShaderDX.ReadModelVars(): string;
begin
  AddText( 'cbuffer GX_CastConst : register(b1)',                                                                False, True);
  AddText( '{',                                                                                   False, True);
  AddText( '    matrix VertexMtx;',                                                               False, True );
  AddText( '    matrix NormalMtx;',                                                               False, True );
  AddText( '    matrix VertexViewProjMtx;',                                                       False, True );
  AddText( '',                                                                                    False, True );
  AddText( '    float4 CastPos;',                                                                 False, True );
  AddText( '',                                                                                    False, True );
  AddText( '    float4 ColorAmb;',                                                                False, True );
  AddText( '    float4 ColorDiff;',                                                               False, True );
  AddText( '    float4 ColorSpc;',                                                                False, True );
  AddText( '}',                                                                                   False, True);
  AddText( '',                                                                                    False, True );
end;

function TShaderDX.ReadVariables(): string;
begin
  AddText( 'SamplerState samDevice;',                                                             False, ( asTexcoord in FSemantics ) or ( FMipMapped = True ));
  AddText( 'Texture2D samTexture;',                                                               False, ( asTexcoord in FSemantics ) or ( FMipMapped = True ));
end;

function TShaderDX.ReadInputStruct(): string;
begin
  AddText( 'struct VS_INPUT',                                                                     False, True );
  AddText( '{',                                                                                   False, True );
  AddText( '    float4 Pos : POSITION;',                                                          False, True );
  AddText( '    float3 Norm : NORMAL;',                                                           False, ( asNormal   in FSemantics ));
  AddText( '    float2 Tex : TEXCOORD;',                                                          False, ( asTexcoord in FSemantics ) or ( FMipMapped = True ));
  AddText( '    float4 Color : COLOR;',                                                           False, ( asColor    in FSemantics ));
  AddText( '};',                                                                                  False, True );
  AddText( '',                                                                                    False, True );
end;

function TShaderDX.ReadOutputStruct(): string;
begin
  AddText( 'struct PS_INPUT',                                                                     False, True );
  AddText( '{',                                                                                   False, True );
  AddText( '    float4 Pos : SV_POSITION;',                                                       False, True );
  AddText( '    float3 Norm : NORMAL;',                                                           False, ( asNormal   in FSemantics ));
  AddText( '    float2 Tex : TEXCOORD;',                                                          False, ( asTexcoord in FSemantics ) or ( FMipMapped = True ));
  AddText( '    float4 Color : COLOR;',                                                           False, ( asColor    in FSemantics ));
  AddText( '};',                                                                                  False, True );
  AddText( '',                                                                                    False, True );
end;

function TShaderDX.ReadVertexFunc(): string;
begin
  AddText( 'PS_INPUT VS( VS_INPUT input )',                                                       False, True );
  AddText( '{' ,                                                                                  False, True );
  AddText( '    PS_INPUT output = (PS_INPUT)0;',                                                  False, True );
  AddText( '',                                                                                    False, True );
  AddText( '    output.Pos = mul( input.Pos, VertexMtx );',                                       False, True );
  AddText( '    output.Pos = mul( output.Pos, TransView );',                                      False, True );
  AddText( '    output.Pos = mul( output.Pos, TransProj );',                                      False, True );
  AddText( '',                                                                                    False, True );
  AddText( '    output.Norm = mul( input.Norm, NormalMtx );',                                     False, ( asNormal   in FSemantics ));
  AddText( '    output.Tex =  input.Tex;',                                                        False, ( asTexcoord in FSemantics ));
  AddText( '    output.Color =  input.Color;',                                                    False, ( asColor    in FSemantics ));
  AddText( '',                                                                                    False, True );
  AddText( '    output.Tex.x = input.Pos.x * 0.4;',                                               False, ( FMipMapped = True ));
  AddText( '    output.Tex.y = input.Pos.z * 0.4;',                                               False, ( FMipMapped = True ));
  AddText( '',                                                                                    False, True );
  AddText( '    return output;',                                                                  False, True );
  AddText( '}',                                                                                   False, True );
  AddText( '',                                                                                    False, True );
end;

function TShaderDX.ReadPixelFunc(): string;
begin
  AddText( 'float4 PS( PS_INPUT input ) : SV_TARGET',                                             False, True );
  AddText( '{',                                                                                   False, True );
  //AddText( '    input.Pos.z += 0.01f;',                                                           False, ( FSemantics = [ asPosition ]));
  AddText( '    float4 RESULT = samTexture.Sample(samDevice, input.Tex);',                        False, ( asTexcoord in FSemantics ) or ( FMipMapped = True ));
  AddText( '    float4 RESULT = input.Color;',                                                    False, ( asColor    in FSemantics ));
  AddText( '    float4 RESULT = ColorAmb + ColorDiff;',                                           False, ( not( asTexcoord in FSemantics )) and ( not( asColor in FSemantics )) and ( not( FMipMapped )));
  AddText( '',                                                                                    False, True );
  AddText( '    RESULT = dot(LightDir, normalize(input.Norm)) * RESULT;',                         False, ( asNormal   in FSemantics ));
  AddText( '    float ATransparency = RESULT.xyz * 1.0f;      ',                                  False, ( stOpaqueColor in FTags ));
  AddText( '    RESULT.a = ATransparency;',                                                       False, ( stOpaqueColor in FTags ));
  AddText( '    return saturate(RESULT);',                                                        False, True );
  AddText( '}',                                                                                   False, True );
  AddText( '',                                                                                    False, True );
end;

function TShaderDX.ReadVertexCode(): string;
begin
  ResetText();

  AddText( '//---------------------------------------------------------------------------------', False, True );
  AddText( '// Buffers',                                                                          False, True );
  AddText( '//---------------------------------------------------------------------------------', False, True );

  ReadMainVars();
  ReadModelVars();

  AddText( '//---------------------------------------------------------------------------------', False, True );
  AddText( '// Variables',                                                                        False, True );
  AddText( '//---------------------------------------------------------------------------------', False, True );

  ReadVariables();

  AddText( '//---------------------------------------------------------------------------------', False, True );
  AddText( '// Structs',                                                                          False, True );
  AddText( '//---------------------------------------------------------------------------------', False, True );

  ReadInputStruct();
  ReadOutputStruct();

  AddText( '//---------------------------------------------------------------------------------', False, True );
  AddText( '// Function',                                                                         False, True );
  AddText( '//---------------------------------------------------------------------------------', False, True );

  ReadVertexFunc();

  Result := FStringList.Text;
  //if (FSemantics = [asPosition]) then
  //FStringlist.SaveToFile('C:\Users\akaragm\Documents\RAD Studio\Projekte\GameMachine\testing\Shader\ShaderVertex.txt');
  //MessageBox( 0, PChar( 'VS: '#13 + Result ), '', MB_OK );
end;

function TShaderDX.ReadPixelCode(): string;
begin
  ResetText();

  AddText( '//---------------------------------------------------------------------------------', False, True );
  AddText( '// Buffers',                                                                          False, True );
  AddText( '//---------------------------------------------------------------------------------', False, True );

  ReadMainVars();
  ReadModelVars();

  AddText( '//---------------------------------------------------------------------------------', False, True );
  AddText( '// Variables',                                                                        False, True );
  AddText( '//---------------------------------------------------------------------------------', False, True );

  ReadVariables();

  AddText( '//---------------------------------------------------------------------------------', False, True );
  AddText( '// Structs',                                                                          False, True );
  AddText( '//---------------------------------------------------------------------------------', False, True );

  ReadOutputStruct();

  AddText( '//---------------------------------------------------------------------------------', False, True );
  AddText( '// Function',                                                                         False, True );
  AddText( '//---------------------------------------------------------------------------------', False, True );

  ReadPixelFunc();

  Result := FStringList.Text;
  //if (FSemantics = [asPosition]) then
  //  FStringlist.SaveToFile('C:\Users\akaragm\Documents\RAD Studio\Projekte\GameMachine\testing\Shader\ShaderPixel.txt' );
  //ShowMessage( 0, PChar( 'VS: '#13 + Result ), '', MB_OK );
end;


end.
