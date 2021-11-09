// Copyright (c) 2021 Arsanias (arsaniasbb@gmail.com)
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.RenderDeviceDX;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.Types, SysUtils, System.Math,
  Vcl.Forms, Vcl.Dialogs,
  DXTypes_JSB, DXGI_JSB, D3DCommon_JSB, D3D11_JSB, D3DX11_JSB,
  Core.Types, Core.Utils, Core.Arrays, Core.Mesh, Core.Model, Core.Camera, Core.Material,
  Core.RenderDevice, Core.Shader, Core.ShaderDX, Core.Cast;

type
  PGX_VertexBufferDX = ^TGX_VertexBufferDX;
  TGX_VertexBufferDX = record
    Data:             ID3D11Buffer;
    Name:             string;
    Stride:           Cardinal;
    Size:             Cardinal;
    VertexCount:      Cardinal;
  end;

  PGX_IndexBufferDX = ^TGX_IndexBufferDX;
  TGX_IndexBufferDX = record
    Data:             ID3D11Buffer;
    Name:             string;
    IndexCount:       Cardinal;
    IndexSize:        Cardinal;
    Size:             Cardinal;
  end;

  PGX_ResourceBufferDX = ^TGX_ResourceBufferDX;
  TGX_ResourceBufferDX = record
    BufferPointer:    ID3D11ShaderResourceView;
    BufferName:       string;
    Size:             Cardinal;
  end;

  TRenderDeviceDX = class(TRenderDevice)
  private
    { directx }
    FDevice: ID3D11Device;
    FDepthStencilView:ID3D11DepthStencilView;
    FDepthStencil: ID3D11Texture2D;
    FDStencilState: array[ 0..1 ] of ID3D11DepthStencilState;
    FShaders: array[ 0..6 ] of TShaderDX;
    FIContext: ID3D11DeviceContext;
    FDriverType: TD3D_DriverType;
    FFeatureLevel: TD3D_FeatureLevel;
    FFeatureLevelID: string;
    FSwapChain: IDXGISwapChain;
    FRenderTargetView: array[ 0..1 ] of ID3D11RenderTargetView;
    FBlendState: array[ 0..1 ] of ID3D11BlendState;
    FRasterState: array[ 0..1 ] of ID3D11RasterizerState;
    FSamplerState: ID3D11SamplerState;
    FMainBufferID: ID3D11Buffer;
    FCastBufferID: ID3D11Buffer;
    FVertexBuffers: TNodeList<PGX_VertexBufferDX>;
    FIndexBuffers: TNodeList<PGX_IndexBufferDX>;
    FResourceBuffers: TNodeList<PGX_ResourceBufferDX>;
    procedure Clear();
    procedure CreateBlendStates();
    procedure CreateDepthStencilStates();
    procedure CreateDeviceAndSwapChain();
    procedure CreateRasterizers();
    procedure CreateRenderTargetAndDepthStencil();
    procedure CreateSampler();
    procedure CreateShaders();
    procedure CreateViewPorts();
    procedure SetRasterMode(ARasterMode: TRasterMode); override;
    procedure Start();
  public
    { derived from device }
    constructor Create(Windowed: Boolean ; AHandle: HWND ; AViewRect: TRect); override;
    destructor Destroy; override;
    function GetBuffer(ByteWidth: UINT; InitSys: Pointer; BindFlags: UINT): ID3D11Buffer;
  public
    procedure ClearScene(); override;
    function CreateIndexBuffer( AIndexArray: TShaderArray ): Integer; override;
    function CreateResourceBuffer(ATexture: TTexture ): Integer; override;
    function CreateVertexBuffer( AVertexArray: TShaderArray ): Integer; override;
    procedure Draw( ACount: Integer ; AVBufferIndex, AIBufferIndex: Integer; Instances: TInstanceArray); override;
    procedure GetDeviceInfo; override;
    function GetShaderIndex(var ASemantics: TShaderSemantics ; ATexture: TTexture ): Integer; override;
    procedure SetBlendState( ABlendState: TBlendState ); override;
    procedure SetFullScreen( GoFullScreen: Boolean ); override;
    procedure SetResources( ATexture: TTexture ); override;
    procedure SetTopology( ATopology: TVertexTopology ); override;
    procedure SetViewRect( AViewRect: TRect ); override;
    procedure SetShaders( AShaderIndex: Integer ; ABufferIndex: Integer ); override;
    procedure Show(); override;
    procedure UpdateCastBuffer( AShaderIndex: Integer ); override;
    procedure UpdateMainBuffer( AShaderIndex: Integer ); override;
    procedure UpdateVertexBuffer( AVBufferIndex: Integer ; AVertexArray: TShaderArray ); override;
  public
    property Device: ID3D11Device read FDevice;
    property IContext: ID3D11DeviceContext read FIContext;
    property SamplerState: ID3D11SamplerState read FSamplerState;
    property SwapChain: IDXGISwapChain read FSwapChain;
  end;

var
  DriverTypes: array[0..2] of TD3D_DriverType = ( D3D_DRIVER_TYPE_HARDWARE,
                                                  D3D_DRIVER_TYPE_WARP,
                                                  D3D_DRIVER_TYPE_REFERENCE );

  FeatureLevels: array[0..3]of TD3D_FeatureLevel = (D3D_FEATURE_LEVEL_9_3,
                                                    D3D_FEATURE_LEVEL_10_0,
                                                    D3D_FEATURE_LEVEL_10_1,
                                                    D3D_FEATURE_LEVEL_11_0 );
implementation

constructor TRenderDeviceDX.Create( Windowed: Boolean ; AHandle: HWND ; AViewRect: TRect ) ;
begin
  inherited Create( Windowed, AHandle, AViewRect );

  FDeviceType := dtDirectX;

  FVertexBuffers    := TNodeList<PGX_VertexBufferDX>.Create();
  FIndexBuffers     := TNodeList<PGX_IndexBufferDX>.Create();
  FResourceBuffers  := TNodeList<PGX_ResourceBufferDX>.Create();

  Start();
end;

destructor TRenderDeviceDX.Destroy;
begin
  Clear();

  inherited Destroy();
end;

procedure TRenderDeviceDX.ClearScene();
var
  AClearColor: TVector4;
begin
  AClearColor := TVector4.Create( 0.20, 0.40, 0.40, 1.00 );

	FIContext.ClearRenderTargetView( FRenderTargetView[ 0 ], TColorArray( AClearColor ));
	FIContext.ClearDepthStencilView( FDepthStencilView, Cardinal( D3D11_CLEAR_DEPTH ), 1.0, 0 );
end;

procedure TRenderDeviceDX.CreateDeviceAndSwapChain();
var
  CreateFlags: LongWord;
  SwapChainDesc: DXGI_SWAP_CHAIN_DESC;
  i: Integer;
  hr: HRESULT;
begin
  CreateFlags := 0;

  //{$IFDEF DEBUG}
  //  CreateFlags := CreateFlags or Cardinal(D3D11_CREATE_DEVICE_DEBUG);
  //{$ENDIF}

  ZeroMemory( @SwapChainDesc, SizeOf(SwapChainDesc));
  SwapChainDesc.BufferCount := 1;
  SwapChainDesc.BufferUsage := DXGI_USAGE_RENDER_TARGET_OUTPUT;
  SwapChainDesc.OutputWindow := FWindowHandle;
  SwapChainDesc.Windowed := TRenderDeviceFlag.gmWindowed in FDeviceFlags;
  SwapChainDesc.BufferDesc.Width := ViewWidth;
  SwapChainDesc.BufferDesc.Height := ViewHeight;
  SwapChainDesc.BufferDesc.Format := DXGI_FORMAT_R8G8B8A8_UNORM;
  SwapChainDesc.BufferDesc.RefreshRate.Numerator := 60;
  SwapChainDesc.BufferDesc.RefreshRate.Denominator := 1;
  SwapChainDesc.SampleDesc.Count := 1;

  for i := Low(DriverTypes) to High(DriverTypes) do
  begin
    FDriverType := DriverTypes[i];
    hr := D3D11CreateDeviceAndSwapChain(nil, FDriverType, 0, CreateFlags, @FeatureLevels[0], 3,
      D3D11_SDK_VERSION, @SwapChainDesc, FSwapChain, FDevice, @FFeatureLevel, FIContext);
    if( SUCCEEDED( hr )) then Break;
  end;

  case FFeatureLevel of
    D3D_FEATURE_LEVEL_9_1: FVersion := 9.1;
    D3D_FEATURE_LEVEL_9_2: FVersion := 9.2;
    D3D_FEATURE_LEVEL_9_3: FVersion := 9.3;
    D3D_FEATURE_LEVEL_10_0: FVersion := 10.0;
    D3D_FEATURE_LEVEL_10_1: FVersion := 10.1;
    D3D_FEATURE_LEVEL_11_0: FVersion := 11.0;
  end;

  if FAILED(HR) then
    raise Exception.Create('TRenderDeviceDX'#13 + 'Error ' + IntToHex(hr, 8) + ': Cannot create Device and Swap Chain');
end;

procedure TRenderDeviceDX.CreateRenderTargetAndDepthStencil();
var
  hr: HRESULT;
  BackBuffer: ID3D11Texture2D;
  TextureDesc: D3D11_TEXTURE2D_DESC;
  DepthStencilDesc: D3D11_DEPTH_STENCIL_VIEW_DESC;
begin
  { create rander target view }

  hr := FSwapChain.GetBuffer( 0, ID3D11Texture2D, BackBuffer );
  if FAILED(HR) then Exit;

  hr := FDevice.CreateRenderTargetView( BackBuffer, nil, FRenderTargetView[ 0 ]);
  if FAILED(HR) then Exit;

  { create depth stencil view }

  ZeroMemory( @TextureDesc, SizeOf( TextureDesc ));
  TextureDesc.Width              := ViewWidth;
  TextureDesc.Height             := ViewHeight;
  TextureDesc.MipLevels          := 1;
  TextureDesc.ArraySize          := 1;
  TextureDesc.Format             := DXGI_FORMAT_D24_UNORM_S8_UINT;
  TextureDesc.SampleDesc.Count   := 1;
  TextureDesc.Usage              := D3D11_USAGE_DEFAULT;
  TextureDesc.BindFlags          := Cardinal( D3D11_BIND_DEPTH_STENCIL );

  hr := FDevice.CreateTexture2D( TextureDesc, nil, FDepthStencil );
  if FAILED(HR) then Exit;

  ZeroMemory( @DepthStencilDesc, SizeOf( DepthStencilDesc ));
  DepthStencilDesc.Format             := TextureDesc.Format;
  DepthStencilDesc.ViewDimension      := D3D11_DSV_DIMENSION_TEXTURE2D;
  DepthStencilDesc.Texture2D.MipSlice := 0;

  hr := FDevice.CreateDepthStencilView( FDepthStencil, @DepthStencilDesc, FDepthStencilView );
  if FAILED(HR) then Exit;

  BackBuffer := nil;

  { set render targets }

  FIContext.OMSetRenderTargets( 1, @FRenderTargetView[0], FDepthStencilView );
end;

procedure TRenderDeviceDX.CreateViewPorts();
var
  ViewPort: array[ 0..0 ] of D3D11_VIEWPORT;
begin
  ViewPort[0].Width    := ViewWidth;
  ViewPort[0].Height   := ViewHeight;
  ViewPort[0].MinDepth := 0.0;
  ViewPort[0].MaxDepth := 1.0;
  ViewPort[0].TopLeftX := ViewRect.Left;
  ViewPort[0].TopLeftY := ViewRect.Top;

  FIContext.RSSetViewports( 1, @ViewPort[0] );
end;

procedure TRenderDeviceDX.CreateRasterizers();
var
	ARasterDesc: D3D11_RASTERIZER_DESC;

  function CR( AFillMode: D3D11_FILL_MODE ; ACullMode: D3D11_CULL_MODE ; ASmoothLine, AMultisample, ADepthClip: Boolean ; ADepthBias: Integer ): ID3D11RasterizerState;
  begin
	  ARasterDesc.FillMode               := AFillMode;
	  ARasterDesc.CullMode               := ACullMode;
    ARasterDesc.DepthBias              := -ADepthBias;
    ARasterDesc.FrontCounterClockwise  := False;
    ARasterDesc.DepthClipEnable        := ADepthClip;
    ARasterDesc.ScissorEnable          := False;
    ARasterDesc.MultisampleEnable      := AMultisample;
    ARasterDesc.AntialiasedLineEnable  := ASmoothLine;

	  FDevice.CreateRasterizerState( ARasterDesc, Result );
  end;
begin
  ZeroMemory( @ARasterDesc, SizeOf( ARasterDesc ));

  FRasterState[ Integer(TRasterMode.rmDefault )]    := CR( D3D11_FILL_SOLID,     D3D11_CULL_NONE, False, False, True,  0 );
  FRasterState[ Integer(TRasterMode.rmWireframe )]  := CR( D3D11_FILL_WIREFRAME, D3D11_CULL_BACK, False, False, False, Round( 0.00001 / ( 1 / Power( 2, 23 ))));
end;

procedure TRenderDeviceDX.CreateBlendStates();
var
  hr: HRESULT;
  ABlendDsc: D3D11_BLEND_DESC;
  function BS( ABlendEnable: Boolean ): ID3D11BlendState;
  begin
    ZeroMemory( @ABlendDsc, sizeof( D3D11_BLEND_DESC ));
    ABlendDsc.RenderTarget[0].BlendEnable              := ABlendEnable;
    if( ABlendEnable = True ) then
    begin
      ABlendDsc.AlphaToCoverageEnable                  := ABlendEnable;
      ABlendDsc.IndependentBlendEnable                 := False;
      ABlendDsc.RenderTarget[0].SrcBlend               := D3D11_BLEND_SRC_ALPHA;
      ABlendDsc.RenderTarget[0].DestBlend              := D3D11_BLEND_INV_SRC_ALPHA;
      ABlendDsc.RenderTarget[0].BlendOp                := D3D11_BLEND_OP_ADD;
      ABlendDsc.RenderTarget[0].SrcBlendAlpha          := D3D11_BLEND_ONE;
      ABlendDsc.RenderTarget[0].DestBlendAlpha         := D3D11_BLEND_INV_SRC_ALPHA;
      ABlendDsc.RenderTarget[0].BlendOpAlpha           := D3D11_BLEND_OP_ADD;
      ABlendDsc.RenderTarget[0].RenderTargetWriteMask  := Byte( D3D11_COLOR_WRITE_ENABLE_ALL );
    end
    else
    begin
      ABlendDsc.RenderTarget[0].SrcBlend               := D3D11_BLEND_ONE;
      ABlendDsc.RenderTarget[0].DestBlend              := D3D11_BLEND_ZERO;
      ABlendDsc.RenderTarget[0].BlendOp                := D3D11_BLEND_OP_ADD;
      ABlendDsc.RenderTarget[0].SrcBlendAlpha          := D3D11_BLEND_ONE;
      ABlendDsc.RenderTarget[0].DestBlendAlpha         := D3D11_BLEND_ZERO;
      ABlendDsc.RenderTarget[0].BlendOpAlpha           := D3D11_BLEND_OP_ADD;
      ABlendDsc.RenderTarget[0].RenderTargetWriteMask  := Byte( D3D11_COLOR_WRITE_ENABLE_ALL );
    end;

    hr := FDevice.CreateBlendState( ABlendDsc, Result );
  end;
begin
  FBlendState[ 0 ] := BS( False );
  FBlendState[ 1 ] := BS( True );
end;

procedure TRenderDeviceDX.CreateDepthStencilStates();
var
  hr: HRESULT;
  dsDesc: TD3D11_DepthStencilDesc;
  function DS( ADepthEnable: Boolean ; AComparison: TD3D11_ComparisonFunc ): ID3D11DepthStencilState;
  begin
    ZeroMemory( @dsDesc, sizeof( dsDesc ));

    // Depth test parameters
    dsDesc.DepthEnable    := True;
    dsDesc.DepthWriteMask := D3D11_DEPTH_WRITE_MASK_ALL;
    dsDesc.DepthFunc      := AComparison;

    // Stencil test parameters
    dsDesc.StencilEnable    := ADepthEnable;
    dsDesc.StencilReadMask  := $FF;
    dsDesc.StencilWriteMask := $FF;

    // Stencil operations if pixel is front-facing
    dsDesc.FrontFace.StencilFailOp      := D3D11_STENCIL_OP_KEEP;
    dsDesc.FrontFace.StencilDepthFailOp := D3D11_STENCIL_OP_INCR;
    dsDesc.FrontFace.StencilPassOp      := D3D11_STENCIL_OP_KEEP;
    dsDesc.FrontFace.StencilFunc        := D3D11_COMPARISON_ALWAYS;

    // Stencil operations if pixel is back-facing
    dsDesc.BackFace.StencilFailOp       := D3D11_STENCIL_OP_KEEP;
    dsDesc.BackFace.StencilDepthFailOp  := D3D11_STENCIL_OP_DECR;
    dsDesc.BackFace.StencilPassOp       := D3D11_STENCIL_OP_KEEP;
    dsDesc.BackFace.StencilFunc         := D3D11_COMPARISON_ALWAYS;

    // Create depth stencil state
    hr := FDevice.CreateDepthStencilState( dsDesc, Result );
  end;
begin
  FDStencilState[ 0 ] := DS( True, D3D11_COMPARISON_LESS );
  FDStencilState[ 1 ] := DS( True, D3D11_COMPARISON_LESS );
end;

procedure TRenderDeviceDX.CreateShaders();
begin
  FShaders[0] := TShaderDX.Create(FDevice, [asPosition], [], Version);
  FShaders[1] := TShaderDX.Create(FDevice, [asPosition, asNormal], [], Version);
  FShaders[2] := TShaderDX.Create(FDevice, [asPosition, asTexcoord], [], Version);
  FShaders[3] := TShaderDX.Create(FDevice, [asPosition, asColor], [], Version);
  FShaders[4] := TShaderDX.Create(FDevice, [asPosition, asNormal, asTexcoord], [], Version);
  FShaders[5] := TShaderDX.Create(FDevice, [asPosition, asNormal], [stMipMap], Version);
  FShaders[6] := TShaderDX.Create(FDevice, [asPosition, asTexcoord], [stOpaqueColor], Version);

  { create constant buffers }

  FMainBufferID := Getbuffer(SizeOf(TRenderDeviceMainConst), nil, Cardinal(D3D11_BIND_CONSTANT_BUFFER));
  FCastBufferID := GetBuffer(SizeOf(TRenderDeviceCastConst), nil, Cardinal(D3D11_BIND_CONSTANT_BUFFER));
end;

procedure TRenderDeviceDX.CreateSampler;
var
  hr: HRESULT;
  SamplerDesc: D3D11_SAMPLER_DESC;
begin
  ZeroMemory( @SamplerDesc, SizeOf( SamplerDesc ));

  SamplerDesc.Filter := D3D11_FILTER_MIN_MAG_MIP_LINEAR;
	SamplerDesc.AddressU := D3D11_TEXTURE_ADDRESS_WRAP;
	SamplerDesc.AddressV := D3D11_TEXTURE_ADDRESS_WRAP;
	SamplerDesc.AddressW := D3D11_TEXTURE_ADDRESS_WRAP;
  SamplerDesc.MaxAnisotropy  := 1;
	SamplerDesc.ComparisonFunc := D3D11_COMPARISON_NEVER;
	SamplerDesc.MaxLOD         := D3D11_FLOAT32_MAX;

  hr := FDevice.CreateSamplerState( SamplerDesc, FSamplerState );
  if FAILED(HR) then
    raise Exception.Create('TRenderDeviceDX'#13 + 'Could not create Sampler State');
end;

procedure TRenderDeviceDX.Start();
begin
  FError := False;

  CreateDeviceAndSwapChain();
  CreateRenderTargetAndDepthStencil();
  CreateViewPorts();
  CreateRasterizers();
  CreateBlendStates();
  CreateDepthStencilStates();
  CreateShaders();
  CreateSampler();

  FActive := not FError;
end;

procedure TRenderDeviceDX.Clear();
var
  i: Integer;
begin
  FActive := False;
  Sleep( 250 );

  if( Assigned( FDevice )) then FIContext.ClearState;

  FSamplerState           := nil;
  FDStencilState[ 0 ]     := nil;
  FDStencilState[ 1 ]     := nil;
  FRasterState[ 0 ]       := nil;
  FRasterState[ 1 ]       := nil;
  FRenderTargetView[ 0 ]  := nil;
  FDepthStencil           := nil;
  FDepthStencilView       := nil;
  FSwapChain              := nil;
  FMainBufferID           := nil;
  FCastBufferID           := nil;
  FDevice                 := nil;

  { free shaders }

  if( Length( FShaders ) > 0 ) then
    for i := 0 to 6 do
      SafeFree( FShaders[ i ]);

  { delete vertex buffer }

  if(( FVertexBuffers <> nil ) and ( FVertexBuffers.Count > 0 )) then
  begin
    for i := 0 to FVertexBuffers.Count - 1 do
    begin
      FVertexBuffers[ i ].Data := nil;
      Dispose( FVertexBuffers[ i ]);
    end;
  end;
  SafeFree( FVertexBuffers );

  { delete index buffers }

  if(( FIndexBuffers <> nil ) and ( FIndexBuffers.Count > 0 )) then
  begin
    for i := 0 to FIndexBuffers.Count - 1 do
    begin
      FIndexBuffers[ i ].Data := nil;
      Dispose( FIndexBuffers[ i ]);
    end;
  end;
  SafeFree( FIndexBuffers );

  { delete resource buffers }

  if(( FResourceBuffers <> nil ) and ( FResourceBuffers.Count > 0 )) then
  begin
    for i := 0 to FResourceBuffers.Count - 1 do
    begin
      FResourceBuffers[ i ].BufferPointer := nil;
      Dispose( FResourceBuffers[ i ]);
    end;
  end;
  SafeFree( FResourceBuffers );

  { delete constant buffers }

  FMainBufferID := nil;
  FCastBufferID := nil;

  { clear blend states }

  FBlendState[ 0 ] := nil;
  FBlendState[ 1 ] := nil;

  { clear depth stencil states }

  FDStencilState[ 0 ] := nil;
  FDStencilState[ 1 ] := nil;
end;

// http://msdn.microsoft.com/en-us/library/windows/desktop/bb205075%28v=vs.85%29.aspx#Handling_Window_Resizing}
procedure TRenderDeviceDX.SetViewRect( AViewRect: TRect );
var
  hr: HRESULT;
begin
  FViewRect := AViewRect;

  { release render target and depth stencil }

  FIContext.OMSetRenderTargets( 0, nil, nil );

  FRenderTargetView[ 0 ]  := nil;
  FDepthStencil           := nil;
  FDepthStencilView       := nil;

  { resize buffers }

  hr := FSwapChain.ResizeBuffers( 0, 0, 0, DXGI_FORMAT_UNKNOWN, 0 );
  if FAILED(HR) then Exit;

  { restart render context }

  CreateRenderTargetAndDepthStencil();
  CreateViewPorts();

  UpdateMatrix();
end;

function TRenderDeviceDX.GetBuffer( ByteWidth: UINT; InitSys: Pointer; BindFlags: UINT ): ID3D11Buffer;
var
  bd: D3D11_BUFFER_DESC ;
	InitData: D3D11_SUBRESOURCE_DATA;
  hr: HRESULT;
begin
	Result := nil;
	ZeroMemory( @bd, SizeOf( bd ));

	bd.Usage      := D3D11_USAGE_DEFAULT;
	bd.ByteWidth  := ByteWidth;
	bd.BindFlags  := BindFlags;

	if( InitSys <> nil ) then
  begin
		ZeroMemory( @InitData, SizeOf( InitData ));
		InitData.pSysMem := InitSys;
    hr := FDevice.CreateBuffer( bd, @InitData, Result );
	end
	else
		hr := FDevice.CreateBuffer( bd, nil, Result );

  if(FAILED( hr )) then Exit;
end;

procedure TRenderDeviceDX.SetRasterMode( ARasterMode: TRasterMode );
begin
  if(( not FActive ) or ( FRasterMode = ARasterMode )) then Exit;
  IContext.RSSetState( FRasterState[ Integer( ARasterMode )]);
  FRasterMode := ARasterMode;
end;

procedure TRenderDeviceDX.SetBlendState( ABlendState: TBlendState );
var
  ABlendArray: TColorArray;
begin
  ABlendArray := ColorArray( 0.0, 0.0, 0.0, 0.00 );

  case ABlendState of
    bsSolid:
      begin
        IContext.OMSetBlendState( FBlendState[ 0 ], ABlendArray, $FFFFFFFF );
        //IContext.OMSetDepthStencilState( FDStencilState[ 0 ], 1 );
      end;
    bsTransparent:
      begin
        IContext.OMSetBlendState( FBlendState[ 1 ], ABlendArray, $FFFFFFFF );
        //IContext.OMSetDepthStencilState( FDStencilState[ 1 ], 1 );
      end;
  end;
end;

procedure TRenderDeviceDX.SetFullScreen( GoFullScreen: Boolean );
begin
  FSwapChain.SetFullscreenState( GoFullScreen, nil );
end;

function TRenderDeviceDX.CreateVertexBuffer( AVertexArray: TShaderArray ): Integer;
var
  AVertexBuffer: PGX_VertexBufferDX;
begin
  AVertexBuffer := New( PGX_VertexBufferDX );

  AVertexBuffer.Size        := AVertexArray.Size;
  AVertexBuffer.Stride      := AVertexArray.Stride;
  AVertexBuffer.VertexCount := AVertexArray.RowCount;
  AVertexBuffer.Data := GetBuffer(AVertexBuffer.Size, AVertexArray.Data, Cardinal( D3D11_BIND_VERTEX_BUFFER ));

  Result := FVertexBuffers.Add(AVertexBuffer);
end;

procedure TRenderDeviceDX.UpdateVertexBuffer( AVBufferIndex: Integer ; AVertexArray: TShaderArray );
var
  AVertexBuffer: PGX_VertexBufferDX;
begin
  AVertexBuffer := FVertexBuffers[ AVBufferIndex ];
  IContext.UpdateSubresource( AVertexBuffer.Data, 0, nil, AVertexArray.Data, 0, 0 );
end;

function TRenderDeviceDX.CreateIndexBuffer( AIndexArray: TShaderArray ): Integer;
var
  AIndexBuffer: PGX_IndexBufferDX;
begin
  AIndexBuffer            := New( PGX_IndexBufferDX );

  AIndexBuffer.IndexCount := AIndexArray.RowCount;
  AIndexBuffer.Size       := AIndexArray.Size;
  AIndexBuffer.IndexSize  := 4;
  AIndexBuffer.Data       := GetBuffer(AIndexBuffer.Size, AIndexArray.Data, Cardinal( D3D11_BIND_INDEX_BUFFER ));

  Result := FIndexBuffers.Add( AIndexBuffer );
end;

function TRenderDeviceDX.CreateResourceBuffer( ATexture: TTexture ): Integer;
var
  AResourceBuffer: PGX_ResourceBufferDX;
  hr: HRESULT;
  AInfo: TD3DX11_ImageLoadInfo;
  AResourceDesc: TD3D11_ShaderResourceViewDesc;
  ATextureDesc: TD3D11_Texture2DDesc;
  ATexture2D: ID3D11Texture2D;
  ASubresourceData: TD3D11_SubresourceData;
begin
  if( ATexture = nil ) then Exit( -1 );

  ZeroMemory( @ATextureDesc, SizeOf( ATextureDesc ));

  ATextureDesc.Width            := ATexture.Width;
  ATextureDesc.Height           := ATexture.Height;
  ATextureDesc.Format           := DXGI_FORMAT_R8G8B8A8_UNORM;
  ATextureDesc.Usage            := D3D11_USAGE_DEFAULT;
  ATextureDesc.MipLevels        := 1;
  ATextureDesc.ArraySize        := 1;
  ATextureDesc.SampleDesc.Count := 1;
  ATextureDesc.BindFlags        := Cardinal( D3D11_BIND_SHADER_RESOURCE );

  ZeroMemory( @ASubResourceData, SizeOf( ASubResourceData ));

  ASubresourceData.pSysMem     := ATexture.Data;
  ASubresourceData.SysMemPitch := ATexture.Width * 4;

  hr := FDevice.CreateTexture2D( ATextureDesc, @ASubresourceData, ATexture2D );

  ZeroMemory( @AResourceDesc, SizeOf( AResourceDesc ));

  AResourceDesc.Format              := ATextureDesc.Format;
  AResourceDesc.ViewDimension       := D3D11_SRV_DIMENSION_TEXTURE2D;
  AResourceDesc.Texture2D.MipLevels := ATextureDesc.MipLevels;

  AResourceBuffer := New( PGX_ResourceBufferDX );

  HR := FDevice.CreateShaderResourceView( ATexture2D, @AResourceDesc, AResourceBuffer.BufferPointer );
  if FAILED(HR) then
  begin
    Dispose( AResourceBuffer );
    Exit( -1 );
  end;
  AResourceBuffer.Size := ATexture.Size;

  Result := FResourceBuffers.Add( AResourceBuffer );
end;

function TRenderDeviceDX.GetShaderIndex(var ASemantics: TShaderSemantics; ATexture: TTexture): Integer;
var
  i: Integer;
begin
  { remove texcoord semantic if material does not have a texture resource }

  if ((asTexcoord in ASemantics) and ((ATexture = nil) or (ATexture.RBufferIndex < 0))) then
    ASemantics := ASemantics - [ asTexcoord ];

  for i := 0 to 6 - 1 do
    if( FShaders[i].FSemantics = ASemantics) then
    begin
      Result := i;
      Break;
    end;
end;

procedure TRenderDeviceDX.UpdateMainBuffer( AShaderIndex: Integer );
begin
  if (not FMBufferModified) then Exit;

  MainConst.FViewMatrix := MainConst.FViewMatrix.Transpose;
  MainConst.FProjMatrix := MainConst.FProjMatrix.Transpose;
  MainConst.FViewProjMatrix := MainConst.FViewProjMatrix.Transpose;

  IContext.UpdateSubresource(FMainBufferID, 0, nil, @MainConst, 0, 0);
  FMBufferModified := False;
end;

procedure TRenderDeviceDX.UpdateCastBuffer( AShaderIndex: Integer );
begin
  if (not FCBufferModified) then Exit;

  CastConst.FWorldMtx            := CastConst.FWorldMtx.Transpose;
  CastConst.FNormalMtx           := CastConst.FNormalMtx.Transpose;
  CastConst.FWorldViewProjMatrix := CastConst.FWorldViewProjMatrix.Transpose;

  IContext.UpdateSubresource(FCastBufferID, 0, nil, @CastConst, 0, 0 );

  FCBufferModified := False;
end;

//********************************************************************************************************************//
// Sets the required shader based on the index
// A Index 0 stands for the most simple shader without normals and lights. Here we do not set the main constant
// buffer of the pixel shader because there is no use for the data. Instead of we use the 0 slot just for the cast
// constant buffer.
//********************************************************************************************************************//
procedure TRenderDeviceDX.SetShaders( AShaderIndex: Integer ; ABufferIndex: Integer );
var
  AShader: TShaderDX;
begin
  AShader := FShaders[ AShaderIndex ];

  IContext.IASetInputLayout( AShader.InputLayout );

  IContext.VSSetShader(AShader.VertexShader, nil, 0);
  IContext.VSSetConstantBuffers(0, 1, @FMainBufferID);
  IContext.VSSetConstantBuffers(1, 1, @FCastBufferID);

  IContext.PSSetShader(AShader.PixelShader, nil, 0);
  if (AShaderIndex > 0) then
  begin
    IContext.PSSetConstantBuffers(0, 1, @FMainBufferID);
    IContext.PSSetConstantBuffers(1, 1, @FCastBufferID);
  end
  else
  begin
    IContext.PSSetConstantBuffers(0, 1, @FCastBufferID);
    IContext.PSSetConstantBuffers(1, 0, nil);
  end;
end;

procedure TRenderDeviceDX.SetResources(ATexture: TTexture);
begin
  if ((ATexture <> nil) and (ATexture.RBufferIndex >= 0)) then
  begin
    IContext.PSSetSamplers( 0, 1, @FSamplerState );
    IContext.PSSetShaderResources( 0, 1, @FResourceBuffers[ ATexture.RBufferIndex ].BufferPointer );
  end
  else
  begin
    IContext.PSSetSamplers(0, 0, nil);
    IContext.PSSetShaderResources(0, 0, nil);
  end;
end;

procedure TRenderDeviceDX.SetTopology(ATopology: TVertexTopology);
begin
  case ATopology of
    ptPoints: IContext.IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_POINTLIST);
    ptLines: IContext.IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_LINELIST);
    ptTriangles: IContext.IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    ptTriangleStrip: IContext.IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP);
    else IContext.IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_UNDEFINED);
  end;
end;

procedure TRenderDeviceDX.Draw(ACount: Integer; AVBufferIndex, AIBufferIndex: Integer; Instances: TInstanceArray);
var
  Stride, Offset: LONGWORD;
  i: Integer;
begin
  if (AIBufferIndex >= 0) then
  begin
    if (ACount = 0) then
      ACount := FIndexBuffers[AIBufferIndex].IndexCount;
    Stride := FVertexBuffers[AVBufferIndex].Stride;
    Offset := 0;
    IContext.IASetVertexBuffers( 0, 1, @FVertexBuffers[ AVBufferIndex ].Data, @Stride, @Offset );
    IContext.IASetIndexBuffer(FIndexBuffers[AIBufferIndex].Data, DXGI_FORMAT_R32_UINT, 0);

    if Length(Instances) = 0 then
      IContext.DrawIndexed(ACount, 0, 0)
    else
    begin
      for i := 0 to Length(Instances) - 1 do
        IContext.DrawIndexed(Instances[i].Count, Instances[i].StartLocation, 0);
    end;
  end
  else
  begin
    if (ACount = 0) then
      ACount := FVertexBuffers[ AVBufferIndex ].VertexCount;
    Stride := FVertexBuffers[ AVBufferIndex ].Stride;
    Offset := 0;
    IContext.IASetVertexBuffers(0, 1, @FVertexBuffers[AVBufferIndex].Data, @Stride, @Offset);
    IContext.Draw(ACount, 0 );
  end;
end;

procedure TRenderDeviceDX.GetDeviceInfo();
begin
  //
end;

procedure TRenderDeviceDX.Show();
begin
  SwapChain.Present(0, 0);
end;

end.
