// Copyright (c) 2021 Arsanias
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

  TGX_BlendState = ( bsSolid, bsTransparent );

  TGX_Texture = class
  private
    FName:            string;
    FData:            Pointer;
    FWidth:           Integer;
    FHeight:          Integer;
    FStatus:          TGX_Status;
    FUniqueID:        Cardinal;
    procedure         LoadFromBMP( AFileName: string );
    procedure         LoadFromPNG( AFileName: string );
    procedure         LoadFromTGA( AFileName: string );
    procedure         LoadFromJPG( AFileName: string );
    procedure         LoadFromTIF( AFileName: string );
    function          GetSize(): Cardinal;
  public
    RBufferIndex:     Integer;
    constructor       Create( AName: string ; AData: Pointer ; AWidth, AHeight: Integer );
    destructor        Destroy(); override;

    function          Load( AFileName: string ): Boolean; overload;
    function          Load( AUniqueID: Cardinal ): Boolean; overload;
    function          Save(): Boolean;
  public
    property          Name:       string        read FName          write FName;
    property          Data:       Pointer       read FData;
    property          Size:       Cardinal      read GetSize;
    property          Width:      Integer       read FWidth;
    property          Height:     Integer       read FHeight;
    property          Status:     TGX_Status    read FStatus;
    property          UniqueID:   Cardinal      read FUniqueID;
  end;
  TGX_TextureList = TGX_NodeList<TGX_Texture>;

  TGX_Material = class
  private
    FUniqueID:      Cardinal;
    FStatus:        TGX_Status;
    FName:          string;
    FEmissiveColor: TVector4;
    FAmbientColor:  TVector4;
    FDiffuseColor:  TVector4;
    FSpecularColor: TVector4;
    FColorFilter:   TVector4;
    FSpecular:      LongBool;
    FTransparency:  Single;
    FSpecularity:   Single;
    FAmbientMap:    TGX_Texture;
    FDiffuseMap:    TGX_Texture;
    FSpecularMap:   TGX_Texture;
    FNormalMap:     TGX_Texture;
    FBlendState:    TGX_BlendState;
    procedure       SetName( AName: string );
    procedure       SetBlendState( ABlendState: TGX_BlendState );
  public
    constructor     Create();
    destructor      Destroy(); override;
    procedure       Clear();
    function        Load( AUniqueID: Cardinal ): Boolean;
    function        Save( AObjectID: Cardinal ): Boolean;
  public
    property        UniqueID:       Cardinal        read FUniqueID;
    property        Name:           string          read FName          write SetName;
    property        EmissiveColor:  TVector4      read FEmissiveColor write FEmissiveColor;
    property        AmbientColor:   TVector4      read FAmbientColor  write FAmbientColor;
    property        DiffuseColor:   TVector4      read FDiffuseColor  write FDiffuseColor;
    property        SpecularColor:  TVector4      read FSpecularColor write FSpecularColor;
    property        ColorFilter:    TVector4      read FColorFilter   write FColorFilter;
    property        Specular:       LongBool      read FSpecular      write FSpecular;
    property        Transparency:   Single       read FTransparency  write FTransparency;
    property        Specularity:    Single       read FSpecularity   write FSpecularity;
    property        AmbientMap:     TGX_Texture     read FAmbientMap    write FAmbientMap;
    property        DiffuseMap:     TGX_Texture     read FDiffuseMap    write FDiffuseMap;
    property        SpecularMap:    TGX_Texture     read FSpecularMap   write FSpecularMap;
    property        NormalMap:      TGX_Texture     read FNormalMap     write FNormalMap;
    property        BlendState:     TGX_BlendState  read FBlendState    write FBlendState;
  end;
  TGX_MaterialList = TGX_NodeList<TGX_Material>;

implementation

constructor TGX_Material.Create();
begin
  inherited Create();

  FAmbientColor   := TVector4.Create( 0.3, 0.3, 0.6, 1.0 );
  FDiffuseColor   := TVector4.Create( 0.6, 0.6, 0.9, 1.0 );
  FSpecularColor  := TVector4.Create( 1.0, 1.0, 1.0, 1.0 );

  FAmbientMap     := nil;
  FDiffuseMap     := nil;
  FSpecularMap    := nil;
  FNormalMap      := nil;

  FUniqueID       := 0;
  FStatus         := stCreated;
  FBlendState     := bsSolid;
end;

destructor TGX_Material.Destroy;
begin
  Clear();

  inherited Destroy;
end;

procedure TGX_Material.Clear;
begin
  FAmbientColor  := TVector4.Create( 0.3, 0.3, 0.6, 1.0 );
  FDiffuseColor  := TVector4.Create( 0.6, 0.6, 0.9, 1.0 );
  FSpecularColor := TVector4.Create( 1.0, 1.0, 1.0, 1.0 );

  SafeFree( FAmbientMap );
  SafeFree( FDiffuseMap );
  SafeFree( FSpecularMap );
  SafeFree( FNormalMap );

  FUniqueID       := 0;
  FStatus         := stCreated;
  FBlendState     := bsSolid;
end;

function TGX_Material.Load( AUniqueID: Cardinal ): Boolean;
var
  ASQL: string;
  //ASet: TGX_DataSet;
  AStream: TMemoryStream;
  ARecordCount: Integer;
  ATexture: ^TGX_Texture;
  ABmp: TBitmap;
  (*
  function TTS( ATexture: TGX_Texture ): string; begin if( ATexture = nil ) then Result := '0' else Result := IntToStr( ATexture.UniqueID ); end;
  function RCL( R, G, B, A: string ): TVector4 ; begin
    Result.R := ASet.FieldByName( R ).AsFloat;
    Result.G := ASet.FieldByName( G ).AsFloat;
    Result.B := ASet.FieldByName( B ).AsFloat;
    Result.A := ASet.FieldByName( A ).AsFloat;
  end;
  *)
begin
  (*
  if(( GX_Connector = nil ) or ( AUniqueID = 0 )) then Exit( False );

  Clear();

  { load material }

  ASet := GX_Connector.GetDataSet( 'SELECT * FROM tbMaterial WHERE ( FID = ' + IntToStr( AUniqueID ) + ' );' );

  FName           := ASet[ 'FName' ].AsString;

  FAmbientColor   := GX_Connector.GetColor( ASet, 'FAmbientColor' );
  FDiffuseColor   := GX_Connector.GetColor( ASet, 'FDiffuseColor' );
  FSpecularColor  := GX_Connector.GetColor( ASet, 'FSpecularColor' );

  FTransparency   := ASet[ 'FTransparency' ].AsFloat;
  FSpecularity    := ASet[ 'FTransparency' ].AsFloat;
  FBlendState     := TGX_BlendState( ASet[ 'FBlendState' ].AsInteger );

  SafeFree( ASet );

  { load textures }

  ASet := GX_Connector.GetDataSet( 'SELECT * FROM tbMaterialTexture WHERE ( FMaterialID = ' + IntToStr( AUniqueID ) + ' );' );

  while( not ASet.Eof ) do
  begin
    case ASet.FieldByName( 'FType' ).AsInteger of
      1: ATexture := @AmbientMap;
      2: ATexture := @DiffuseMap;
      3: ATexture := @SpecularMap;
      4: ATexture := @NormalMap;
      else
         ATexture := nil;
    end;
    if( ATexture <> nil ) then
    begin
      ATexture^ := TGX_Texture.Create( '', nil, 0, 0 );
      ATexture^.Load( ASet.FieldByName( 'FTextureID' ).AsInteger );
    end;
    ASet.Next;
  end;

  SafeFree( ASet );

  FUniqueID := AUniqueID;
  Result := True;
  *)
end;

procedure TGX_Material.SetName( AName: string );
begin
  FName := AName;
end;

function TGX_Material.Save( AObjectID: Cardinal ): Boolean;
var
  ASQL: string;
begin
  (*
  if( GX_Connector = nil )then Exit( False );

  { create database record if none exists }

  if( UniqueID = 0 ) then
  begin
    GX_Connector.Execute( 'INSERT INTO tbMaterial ( FName, FObjectID ) VALUES ( ' + QuotedStr( 'Temporäres Material' ) + ', 0 );' );
    FUniqueID := GX_Connector.GetLastAutoValue();
  end;

  { save material }

  try
    ASQL := 'UPDATE tbMaterial SET ' +
              GX_Connector.SetString(   'FName',          Name,                   True )  +
              GX_Connector.SetInteger(  'FObjectID',      AObjectID,              True )  +
              GX_Connector.SetColor(    'FAmbientColor',  AmbientColor,           True )  +
              GX_Connector.SetColor(    'FDiffuseColor',  DiffuseColor,           True )  +
              GX_Connector.SetColor(    'FSpecularColor', SpecularColor,          True )  +
              GX_Connector.SetFloat(    'FTransparency',  Transparency,           True )  +
              GX_Connector.SetFloat(    'FSpecularity',   Specularity,            True )  +
              GX_Connector.SetInteger(  'FBlendState ',   Integer( BlendState ),  False ) +
            'WHERE ( FID = ' + GX_IntToStr( UniqueID ) + ' );';
    GX_Connector.Execute( ASQL );
  except
    Clear();
    Exit( False );
  end;

  FUniqueID := GX_Connector.GetLastAutoValue();

  { save texture to material links }

  GX_Connector.Execute( 'DELETE * FROM tbMaterialTexture WHERE ( tbMaterialTexture.FMaterialID = ' + IntToStr( UniqueID ) + ' );' );

  if( AmbientMap <> nil ) then
  begin
    AmbientMap.Save();
    GX_Connector.Execute( 'INSERT INTO tbMaterialTexture ( FMaterialID, FTextureID, FType, FIndex ) VALUES ( ' + IntToStr( UniqueID ) + ', ' + IntToStr( AmbientMap.UniqueId ) + ', 1, 0 );' );
  end;

  if( DiffuseMap <> nil ) then
  begin
    DiffuseMap.Save();
    GX_Connector.Execute( 'INSERT INTO tbMaterialTexture ( FMaterialID, FTextureID, FType, FIndex ) VALUES ( ' + IntToStr( UniqueID ) + ', ' + IntToStr( DiffuseMap.UniqueId ) + ', 2, 0 );' );
  end;

  if( SpecularMap <> nil ) then
  begin
    SpecularMap.Save();
    GX_Connector.Execute( 'INSERT INTO tbMaterialTexture ( FMaterialID, FTextureID, FType, FIndex ) VALUES ( ' + IntToStr( UniqueID ) + ', ' + IntToStr( SpecularMap.UniqueId ) + ', 3, 0 );' );
  end;

  if( NormalMap <> nil ) then
  begin
    NormalMap.Save();
    GX_Connector.Execute( 'INSERT INTO tbMaterialTexture ( FMaterialID, FTextureID, FType, FIndex ) VALUES ( ' + IntToStr( UniqueID ) + ', ' + IntToStr( NormalMap.UniqueId ) + ', 4, 0 );' );
  end;

  FStatus := stLoaded;
  Result  := True;
  *)
end;

procedure TGX_Material.SetBlendState( ABlendState: TGX_BlendState );
begin
  FBlendState := ABlendState;
end;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

constructor TGX_Texture.Create( AName: string ; AData: Pointer ; AWidth, AHeight: Integer );
begin
  inherited Create();

  FName     := AName;
  FWidth    := AWidth;
  FHeight   := AHeight;
  FUniqueID := 0;
  FData     := AData;
  FStatus   := stCreated;
  RBufferIndex    := -1;

  if(( AWidth > 0 ) and ( AHeight > 0 ) and ( AData = nil )) then GetMem(FData, Size);
end;

function TGX_Texture.Load( AFileName: string ): Boolean;
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

  FName   := ExtractFileName( AFileName );
  Result  := True;
end;

function TGX_Texture.Load( AUniqueID: Cardinal ): Boolean;
//var
  //ASet: TGX_DataSet;
begin
  (*
  if(( GX_Connector = nil ) or ( AUniqueID = 0 )) then Exit( False );

  ASet := GX_Connector.GetDataSet( 'SELECT * FROM tbTexture WHERE FID = ' + IntToStr( AUniqueID ) + ';' );
  try
    FName     := ASet[ 'FName' ].AsString;
    FWidth    := ASet[ 'FWidth' ].AsInteger;
    FHeight   := ASet[ 'FHeight' ].AsInteger;
    GX_GetMem( FData, Size );
    GX_Connector.LoadDataFromBlob( ASet[ 'FData' ], FData, Size );
  except
    SafeFree( ASet );
    Exit( False);
  end;

  FUniqueID := AUniqueID;
  FStatus   := stLoaded;
  Result    := True;
  *)
end;

destructor TGX_Texture.Destroy();
begin
  if( FData <> nil ) then
    FreeMem( FData, Size );
end;

function TGX_Texture.GetSize(): Cardinal;
begin
  Result := Width * Height * SizeOf( Cardinal );
end;

procedure TGX_Texture.LoadFromBMP( AFileName: string );
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

procedure TGX_Texture.LoadFromPNG( AFileName: string );
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

  if(( APng.Header.ColorType = COLOR_RGB ) or ( APng.Header.ColorType = COLOR_GRAYSCALE )) then
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

procedure TGX_Texture.LoadFromJPG( AFileName: string );
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

procedure TGX_Texture.LoadFromTIF( AFileName: string );
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

procedure TGX_Texture.LoadFromTGA( AFileName: string );
begin

end;

function TGX_Texture.Save(): Boolean;
var
  ASQL: string;
  //ASet: TGX_DataSet;
begin
  (*
  if( GX_Connector = nil ) then Exit( False );
  if(( UniqueID > 0 ) and ( FStatus = stLoaded )) then Exit( True );

  { create database record if none exists }

  if( UniqueID = 0 ) then
  begin
    GX_Connector.Execute( 'INSERT INTO tbTexture ( FName ) VALUES ( ' + QuotedStr( 'Temporäre Textur' ) + ' );' );
    FUniqueID := GX_Connector.GetLastAutoValue();
  end;

  { save texture }

  ASQL := 'UPDATE tbTexture SET ' +
            GX_Connector.SetString(  'FName',   Name,   True )  +
            GX_Connector.SetInteger( 'FWidth',  Width,  True )  +
            GX_Connector.SetInteger( 'FHeight', Height, True )  +
            GX_Connector.SetInteger( 'FSize',   Size,   False ) +
          'WHERE ( FID = ' + GX_IntToStr( UniqueID ) + ' );';

  GX_Connector.Execute( ASQL );

  ASet := GX_Connector.GetDataSet( 'SELECT FID, FData FROM tbTexture WHERE ( FID = ' + IntToStr( FUniqueID ) + ' );' );
  try
    GX_Connector.SaveDataToBlob( ASet[ 'FData' ], Data, Size );
  finally
    SafeFree( ASet );
  end;
  *)
end;

end.
