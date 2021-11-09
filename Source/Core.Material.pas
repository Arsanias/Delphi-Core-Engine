// Copyright (c) 2021 Arsanias (arsaniasbb@gmail.com)
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.Material;

interface

uses
  System.Types, System.Variants, System.SysUtils, System.classes, System.StrUtils,
  Graphics, JPEG, PNGImage,
  Core.Types, Core.Utils, Core.Arrays;

type
  TDataArray = array[0..0] of Cardinal;
  PDataArray = ^TDataArray;

  TBlendState = (bsSolid, bsTransparent);

  TTexture = class
  private
    FData: Pointer;
    FWidth: Integer;
    FHeight: Integer;
    procedure LoadFromBMP(AFileName: string);
    procedure LoadFromPNG(AFileName: string);
    procedure LoadFromTGA(AFileName: string);
    procedure LoadFromJPG(AFileName: string);
    procedure LoadFromTIF(AFileName: string);
    function GetSize: Cardinal;
  public
    RBufferIndex: Integer;
    constructor Create(AData: Pointer ; AWidth, AHeight: Integer);
    destructor Destroy; override;
    function Load(AFileName: string): Boolean; overload;
  public
    property Data: Pointer read FData;
    property Size: Cardinal read GetSize;
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
  end;
  TTextureList = TNodeList<TTexture>;

  TMaterial = class
  private
    FEmissiveColor: TVector4;
    FAmbientColor: TVector4;
    FDiffuseColor: TVector4;
    FSpecularColor: TVector4;
    FColorFilter: TVector4;
    FSpecular: LongBool;
    FTransparency: Single;
    FSpecularity: Single;
    FAmbientMap: TTexture;
    FDiffuseMap: TTexture;
    FSpecularMap: TTexture;
    FNormalMap: TTexture;
    FBlendState:  TBlendState;
    procedure SetBlendState(ABlendState: TBlendState);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
  public
    property EmissiveColor: TVector4 read FEmissiveColor write FEmissiveColor;
    property AmbientColor: TVector4 read FAmbientColor  write FAmbientColor;
    property DiffuseColor: TVector4 read FDiffuseColor  write FDiffuseColor;
    property SpecularColor: TVector4 read FSpecularColor write FSpecularColor;
    property ColorFilter: TVector4 read FColorFilter   write FColorFilter;
    property Specular: LongBool read FSpecular write FSpecular;
    property Transparency: Single read FTransparency  write FTransparency;
    property Specularity: Single read FSpecularity write FSpecularity;
    property AmbientMap: TTexture read FAmbientMap write FAmbientMap;
    property DiffuseMap: TTexture read FDiffuseMap write FDiffuseMap;
    property SpecularMap: TTexture read FSpecularMap write FSpecularMap;
    property NormalMap: TTexture read FNormalMap write FNormalMap;
    property BlendState: TBlendState  read FBlendState write FBlendState;
  end;
  TMaterialList = TNodeList<TMaterial>;

implementation

constructor TMaterial.Create();
begin
  inherited Create();

  FAmbientColor   := TVector4.Create( 0.3, 0.3, 0.6, 1.0 );
  FDiffuseColor   := TVector4.Create( 0.6, 0.6, 0.9, 1.0 );
  FSpecularColor  := TVector4.Create( 1.0, 1.0, 1.0, 1.0 );

  FAmbientMap := nil;
  FDiffuseMap := nil;
  FSpecularMap := nil;
  FNormalMap := nil;

  FBlendState := bsSolid;
end;

destructor TMaterial.Destroy;
begin
  Clear;

  inherited Destroy;
end;

procedure TMaterial.Clear;
begin
  FAmbientColor  := TVector4.Create( 0.3, 0.3, 0.6, 1.0 );
  FDiffuseColor  := TVector4.Create( 0.6, 0.6, 0.9, 1.0 );
  FSpecularColor := TVector4.Create( 1.0, 1.0, 1.0, 1.0 );

  SafeFree( FAmbientMap );
  SafeFree( FDiffuseMap );
  SafeFree( FSpecularMap );
  SafeFree( FNormalMap );

  FBlendState     := bsSolid;
end;

procedure TMaterial.SetBlendState( ABlendState: TBlendState );
begin
  FBlendState := ABlendState;
end;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

constructor TTexture.Create(AData: Pointer ; AWidth, AHeight: Integer );
begin
  inherited Create;

  FWidth := AWidth;
  FHeight := AHeight;
  FData := AData;
  RBufferIndex := -1;

  if ((AWidth > 0) and (AHeight > 0) and (AData = nil)) then GetMem(FData, Size);
end;

function TTexture.Load( AFileName: string ): Boolean;
begin
  if( Copy( LowerCase( AFilename ), Length( AFilename ) - 3, 4 ) = '.bmp' ) then
    LoadFromBMP( AFilename )
  else
  if( Copy( LowerCase( AFilename ), Length( AFilename ) - 3, 4 ) = '.png' ) then
    LoadFromPNG( AFilename )
  else
  if( Copy( LowerCase( AFilename ), Length( AFilename ) - 3, 4 ) = '.jpg' ) then
    LoadFromJPG( AFilename )
  else
  if( Copy( LowerCase( AFilename ), Length( AFilename ) - 3, 4 ) = '.tga' ) then
    LoadFromTGA( AFilename )
  else
  if( Copy( LowerCase( AFilename ), Length( AFilename ) - 3, 4 ) = '.tif' ) then
    LoadFromTIF( AFilename )
  else
    Exit;

  Result  := True;
end;

destructor TTexture.Destroy();
begin
  if( FData <> nil ) then
    FreeMem( FData, Size );
end;

function TTexture.GetSize(): Cardinal;
begin
  Result := Width * Height * SizeOf( Cardinal );
end;

procedure TTexture.LoadFromBMP( AFileName: string );
var
  ACol, ARow:   Integer;
  ABMP:         TBitmap;
  APixPtr:      PByte;
  ARed, AGreen, ABlue, AAlpha: Cardinal;
  ASkip:        Cardinal;
begin
  ABMP := TBitmap.Create;
  ABMP.LoadFromFile( AFileName );

  FWidth  := ABMP.Width;
  FHeight := ABMP.Height;

  if(( ABMP.PixelFormat <> pf24bit ) and ( ABMP.PixelFormat <> pf32Bit )) then
  begin
    //GX_ShowError( 'Dieser Bitmap-Format wird nicht unterstützt' );
    SafeFree( ABMP );
    Exit;
  end;

  GetMem( FData, Size );

  for ARow := 0 to Height - 1 do
  begin
    APixPtr := ABMP.ScanLine[ Height - 1 - ARow ];
    for ACol := 0 to Width - 1 do
    begin
      ARed    := 0 + ( APixPtr^ shl 16 ); Inc( APixPtr );
      AGreen  := 0 + ( APixPtr^ shl  8 ); Inc( APixPtr );
      ABlue   := 0 + ( APixPtr^ );        Inc( APixPtr );

      if( ABMP.PixelFormat = pf32bit ) then
      begin
        AAlpha := ( APixPtr^ shl 24 ); Inc( APixPtr );
      end
      else
        AAlpha := $FF000000;

      PDataArray( FData )[ ACol + ( ARow * Width )] := AAlpha + ABlue + AGreen + ARed;
    end;
  end;

  SafeFree( ABMP );
end;

procedure TTexture.LoadFromPNG(AFileName: string);
var
  APng:       TPngImage;
  AAlphaPtr:  PByte;
  APixelPtr:  PByte;
  ACol, ARow: Integer;
  ARed, AGreen, ABlue, AAlpha: Cardinal;
begin
  APng := TPngImage.Create();
  APng.LoadFromFile( AFileName );

  FWidth  := APng.Width;
  FHeight := APng.Height;

  GetMem( FData, Size );

  if ((APng.Header.ColorType = COLOR_RGB) or ( APng.Header.ColorType = COLOR_GRAYSCALE)) then
  begin
    for ARow := 0 to Height - 1 do
    begin
      APixelPtr := APng.Scanline[ Height - 1 - ARow ];
      for ACol := 0 to Width - 1 do
      begin
        ARed    := 0 + ( APixelPtr^ shl 16 ); Inc( APixelPtr );
        AGreen  := 0 + ( APixelPtr^ shl  8 ); Inc( APixelPtr );
        ABlue   := 0 + ( APixelPtr^ );        Inc( APixelPtr );
        AAlpha  := $FF000000;
        PDataArray( FData )[ ACol + ( ARow * Width )] := AAlpha + ABlue + AGreen + ARed;
      end;
    end;
  end
  else
  if(( APng.Header.ColorType = COLOR_RGBALPHA ) or ( APng.Header.ColorType = COLOR_GRAYSCALEALPHA )) then
  begin
    for ARow := 0 to Height - 1 do
    begin
      AAlphaPtr := PByte( APng.AlphaScanline[ Height - 1 - ARow ]);
      APixelPtr := APng.Scanline[ Height - 1 - ARow ];
      for ACol := 0 to Width - 1 do
      begin
        ARed    := 0 + ( APixelPtr^ shl 16 ); Inc( APixelPtr );
        AGreen  := 0 + ( APixelPtr^ shl 8 );  Inc( APixelPtr );
        ABlue   := 0 + ( APixelPtr^ );        Inc( APixelPtr );
        AAlpha  := ( AAlphaPtr^ shl 24 );     Inc( AAlphaPtr );
        PDataArray( FData )[ ACol + ( ARow * Width )] := AAlpha + ABlue + AGreen + ARed;
      end;
    end;
  end;

  SafeFree( APng );
end;

procedure TTexture.LoadFromJPG(AFileName: string);
var
  AJPG: TJPEGImage;
  ACol, ARow: Integer;
  ABMP: TBitmap;
  APixPtr: PByte;
  ARed, AGreen, ABlue, AAlpha: Cardinal;
begin
  AJPG := TJPEGImage.Create();
  AJPG.LoadFromFile( AFileName );

  FWidth  := AJPG.Width;
  FHeight := AJPG.Height;

  ABMP              := TBitmap.Create;
  ABMP.PixelFormat  := pf24bit;
  ABMP.Width        := Width;
  ABMP.Height       := Height;

  ABMP.Canvas.Draw( 0, 0, AJPG );

  GetMem(FData, Size);

  for ARow := 0 to Height - 1 do
  begin
    APixPtr := ABMP.ScanLine[ Height - ARow - 1 ];
    for ACol := 0 to Width - 1 do
    begin
      ARed    := 0 + ( APixPtr^ shl 16 ); Inc( APixPtr );
      AGreen  := 0 + ( APixPtr^ shl  8 ); Inc( APixPtr );
      ABlue   := 0 + ( APixPtr^ );        Inc( APixPtr );
      AAlpha  := $FF000000;
      PDataArray( FData )[ ACol + ( ARow * Width )] := AAlpha + ABlue + AGreen + ARed;
    end;
  end;

  SafeFree( ABMP );
  SafeFree( AJPG );
end;

procedure TTexture.LoadFromTIF(AFileName: string);
var
  ATIF: TWICImage;
  ACol, ARow: Integer;
  ABMP: TBitmap;
  APixPtr: PByte;
  ARed, AGreen, ABlue, AAlpha: Cardinal;
begin
  ATIF := TWICImage.Create();
  ATIF.LoadFromFile( AFileName );

  FWidth  := ATIF.Width;
  FHeight := ATIF.Height;

  ABMP              := TBitmap.Create;
  ABMP.PixelFormat  := pf24bit;
  ABMP.Width        := Width;
  ABMP.Height       := Height;

  ABMP.Canvas.Draw( 0, 0, ATIF );

  GetMem( FData, Size );

  for ARow := 0 to Height - 1 do
  begin
    APixPtr := ABMP.ScanLine[ Height - ARow - 1 ];
    for ACol := 0 to Width - 1 do
    begin
      ARed    := 0 + ( APixPtr^ shl 16 ); Inc( APixPtr );
      AGreen  := 0 + ( APixPtr^ shl  8 ); Inc( APixPtr );
      ABlue   := 0 + ( APixPtr^ );        Inc( APixPtr );
      AAlpha  := $FF000000;
      PDataArray( FData )[ ACol + ( ARow * Width )] := AAlpha + ABlue + AGreen + ARed;
    end;
  end;

  SafeFree(ABMP);
  SafeFree(ATIF);
end;

procedure TTexture.LoadFromTGA( AFileName: string );
begin

end;

end.
