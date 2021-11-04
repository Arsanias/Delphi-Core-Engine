// Copyright (c) 2021 Arsanias
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.Loader;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.Classes, System.Variants, System.IOUtils, System.StrUtils, System.SysUtils, System.Math,
  Vcl.Dialogs, Vcl.Controls, Vcl.ComCtrls, Vcl.StdCtrls,
  XmlDoc, XMLIntf,
  Core.Utils, Core.Types, Core.Material, Core.Mesh, Core.Model;

type
  TGX_XMLArray = array of IXMLNode;

  PGX_TriangleIndex = ^TGX_TriangleIndex;
  TGX_TriangleIndex = record
    Vertex: Integer;
    Texture: Integer;
    Normal: Integer;
  end;

  TGX_FaceSemantic = record
    ID:             string;
    Source:         string;
    Offset:         Integer;
  end;

  TGX_Import = class
  public
    Pos: Integer;
    FLine: string;
    Decimal:        string;
    FGotError:      LongBool;
    FUpAxis:        TVector3;
    FMesh:          TMesh;
    FFileName:      string;
    function        CharsLeft(): Integer;
    procedure       SetLine( ALine: string );
    function        ReadInteger( var Value: Integer ): LongBool;
    function        ReadFloat( var Value: Single ): LongBool;
    function        ReadString( var AString: string ): LongBool; overload;
    function        ReadString( fs: TFileStream ; MaxLen: Integer ): string; overload;
    function        ReadText(): string;
    function        ReadVector4( var V4: TVector4 ): LongBool; overload;
    function        ReadVector4( AStr: string ; var V4: TVector4 ): LongBool; overload;
    function        ReadVector3( var V3: TVector3 ): LongBool; overload;
    function        ReadVector3( AStr: string ; var V3: TVector3 ): LongBool; overload;
    function        ReadVector2( var V2: TVector2 ): LongBool;
    function        ReadMatrix( var AMatrix: TMatrix ): LongBool; overload;
    function        ReadMatrix( const AStr: string ; var AMatrix: TMatrix ): Boolean; overload;
    procedure       SkipSpace();
    procedure       SkipStream( fs: TFileStream ; const ASize: Cardinal );
    function        FindNodeByName( const ANode: IXMLNode ; const ANodeName: string ): IXMLNode;
    function        FindNodeByAttribute( const ANode: IXMLNode ; const ANodeName, AAttributeId, AAttributeValue: string ): IXMLNode;
    function        GetAttribute( ANode: IXMLNode ; AAttribute, ADefaultValue: string ): string;
    function        NodeMatches( ANode: IXMLNode ; ANodeName, A1,V1, A2,V2: string ): LongBool;
    property        GotError: LongBool read FGotError write FGotError;
  public
    property        Line: string read FLine write SetLine;
    function        LoadFromFile( const AFileName: string ): LongBool; virtual; abstract;
    procedure       CreateModel( AModel: TModel ; AIndex: Integer ); virtual; abstract;
  end;

function GX_ImportFromFile( var AObject: TModel ; AFileName: string ): Boolean;

implementation

uses
  Core.ObjLoader, Core.DAELoader;

function TGX_Import.FindNodeByAttribute( const ANode: IXMLNode ; const ANodeName, AAttributeId, AAttributeValue: string ): IXMLNode;
var
  i: Integer;
  SN: IXMLNode;
begin
  Result := nil;
  // go through child notes as well
  if( ANode.ChildNodes.Count > 0 ) then
  begin
    for i := 0 to ANode.ChildNodes.Count - 1 do
    begin
      SN := ANode.ChildNodes[i];
      if(( SN.NodeName = ANodeName ) and
         ( SN.HasAttribute( AAttributeID )) and
         ( SN.Attributes[ AAttributeID ] = AAttributeValue )) then
      begin
        Result := SN;
        Break;
      end;

      if( SN.ChildNodes.Count > 0 ) then
        Result := FindNodeByAttribute( SN, ANodeName, AAttributeId, AAttributeValue );
      if( Result <> nil ) then Break;
    end;
  end;
  SN := nil;
end;

function TGX_Import.FindNodeByName( const ANode: IXMLNode ; const ANodeName: string ): IXMLNode;
var
  i: Integer;
begin
  Result := nil;
  if( ANode.ChildNodes.Count > 0 ) then
  begin
    for i := 0 to ANode.ChildNodes.Count - 1 do
    begin
      if( ANode.ChildNodes[ i ].NodeName = ANodeName ) then
      begin
        Result := ANode.ChildNodes[ i ];
        Break;
      end;

      if( ANode.ChildNodes[ i ].ChildNodes.Count > 0 ) then
        Result := FindNodeByName( ANode.ChildNodes[ i ], ANodeName );
      if( Result <> nil ) then Break;
    end;
  end;
end;

procedure TGX_Import.SkipStream( fs: TFileStream ; const ASize: Cardinal );
begin
  fs.Position := fs.Position + ASize;
end;

function TGX_Import.CharsLeft: Integer;
begin
  Result := Length( Line ) - Pos + 1;
end;

procedure TGX_Import.SetLine( ALine: string );
var
  i: Integer;
  AChar: Char;
  AOrd:  Integer;
begin
  FLine := ALine;

  if( Length( FLine ) > 0 ) then
    for i := 0 to Length( FLine ) - 1 do
    begin
      AChar := FLine[ i ];
      AOrd  := Ord( AChar );
      case AOrd of
        8, 9, 10, 13:
          FLine[ i ] := ' ';
      end;
    end;
end;

function TGX_Import.ReadFloat( var Value: Single): LongBool;
var
  c: string;
  s: string;
  AtEndOfVector: LongBool;
begin
  if( CharsLeft <= 0 ) then
  begin
    Result    := False;
    GotError  := True;
  end
  else
  begin
    AtEndOfVector := False;
    SkipSpace( );
    repeat
      c := Line[ Pos ];
      if( CharInSet( c[1], [ '0' .. '9', '.', '-', '+', 'E', 'e' ])) then
      begin
        s := s + c;
        Inc( Pos );
        if( CharsLeft( ) <= 0 ) then
          AtEndOfVector := True;
      end
      else
        AtEndOfVector := True;
    until( AtEndOfVector );
    s := ReplaceStr( s, '.', FormatSettings.DecimalSeparator );
    Value := StrToFloat( s );
    Result := True;
  end;
end;

function TGX_Import.ReadInteger( var Value: Integer ): LongBool;
var
  c: string;
  s: string;
  AtEndOfInteger: LongBool;
begin
  SkipSpace();
  if( CharsLeft <= 0 ) then
  begin
    Result    := False;
    GotError  := True;
  end
  else
  begin
    AtEndOfInteger := False;
    SkipSpace( );
    repeat
      c := Line[ Pos ];
      if( CharInSet( c[1], [ '0' .. '9', '-' ])) then
      begin
        s := s + c;
        Inc( Pos );
        if( CharsLeft( ) <= 0 ) then
          AtEndOfInteger := True;
      end
      else
        AtEndOfInteger := True;
    until( AtEndOfInteger );
    Value := StrToInt( s );
    Result := True;
  end;
end;

function TGX_Import.ReadString( var AString: string ): LongBool;
var
  c: string;
  s: string;
  AtEndOfString: LongBool;
begin
  if( CharsLeft <= 0 ) then
  begin
    Result    := False;
    GotError  := True;
  end
  else
  begin
    AtEndOfString := False;
    SkipSpace();
    repeat
      c := Line[ Pos ];
      if( c[1] <> ' ' ) then
      begin
        s := s + c;
        Inc( Pos );
        if( CharsLeft( ) <= 0 ) then
          AtEndOfString := True;
      end
      else
        AtEndOfString := True;
    until( AtEndOfString );
    AString := s;
    Result := True;
  end;
end;

function TGX_Import.ReadVector4( var V4: TVector4 ): LongBool;
var
  iV: Integer;
begin
  Result := False;
  SkipSpace();
  if( CharsLeft() <= 0 ) then Exit;

  for iV := 0 to 3 do
    ReadFloat( V4.V[ iV ]);
  Result := True;
end;

function TGX_Import.ReadVector4( AStr: string ; var V4: TVector4 ): LongBool;
var
  iV: Integer;
begin
  Line := AStr;
  Pos  := 1;

  Result := ReadVector4( V4 );
end;

function TGX_Import.ReadVector3( var V3: TVector3 ): LongBool;
var
  iV: Integer;
begin
  Result := False;
  SkipSpace();
  if( CharsLeft() <= 0 ) then Exit;

  for iV := 0 to 2 do
    ReadFloat( V3.V[ iV ]);
  Result := True;
end;

function TGX_Import.ReadVector3( AStr: string ; var V3: TVector3 ): LongBool;
var
  iV: Integer;
begin
  Line := AStr;
  Pos  := 1;

  Result := ReadVector3( V3 );
end;

function TGX_Import.ReadVector2( var V2: TVector2): LongBool;
var
  iV: Integer;
begin
  Result := False;
  SkipSpace();
  if( CharsLeft() <= 0 ) then Exit;

  for iV := 0 to 1 do
    ReadFloat( V2._[ iV ]);
  Result := True;
end;

function TGX_Import.ReadMatrix( var AMatrix: TMatrix ): LongBool;
var
  i: Integer;
begin
  Result := False;
  SkipSpace();
  if( CharsLeft() <= 0 ) then Exit;

  for i := 0 to 16 - 1 do
    ReadFloat( AMatrix.V[ i ]);
  Result := True;
end;

function TGX_Import.ReadMatrix( const AStr: string ; var AMatrix: TMatrix ): Boolean;
begin
  Line := AStr;
  Pos  := 1;
  Result := ReadMatrix( AMatrix );
end;

function TGX_Import.ReadString( fs: TFileStream ; MaxLen: Integer ): string;
var
  i: Integer;
  C: AnsiChar;
begin
  Result := '';
  for i := 0 to MaxLen - 1 do
  begin
    fs.Read( C, 1 );
    if C = Chr(0) then Break;
    Result := Result + C;
  end;
end;

function TGX_Import.ReadText(): string;
var
  iLen: Integer;
begin
  Result := '';
  SkipSpace();

  iLen := Length( Line );
  if( Pos > Length( Line )) then Exit;

  Result := MidStr( Line, Pos, iLen - Pos + 1 );
end;

procedure TGX_Import.SkipSpace( );
begin
  if( CharsLeft <= 0 ) then Exit;

  while(( Pos <= Length( Line )) and (( Line[ Pos ] <= Chr( 32 )))) do
    Inc( Pos );
end;

function TGX_Import.GetAttribute( ANode: IXMLNode ; AAttribute, ADefaultValue: string ): string;
begin
  Result := ADefaultValue;
  if( ANode.HasAttribute( AAttribute )) then
    Result := ANode.Attributes[ AAttribute ];
end;

function TGX_Import.NodeMatches(ANode: IXMLNode; ANodeName, A1,V1,A2,V2: string ): LongBool;
begin
  Result := False;
  if( ANode = nil ) then Exit;

  if( ANode.NodeName = ANodeName ) then
  begin
    if( A1 <> '' ) then
    begin
      if( GetAttribute( ANode, A1, '' ) = V1 ) then
      begin
        if( A2 <> '' ) then
        begin
          if( GetAttribute( ANode, A2, '' ) = V2 ) then Result := True;
        end
        else
          Result := True;
      end;
    end
    else
      Result := True;
  end;
end;

function GX_ImportFromFile( var AObject: TModel ; AFileName: string ): Boolean;
var
  OpenDlg: TOpenDialog;
  AImport: TGX_Import;
  AScaleValue: Single;
begin
  AObject.Clear();

  AImport := nil;
  AObject.Name := 'Cast 1';

  if( AFileName = '' ) then
  begin
    OpenDlg := TOpenDialog.Create( nil );
    OpenDlg.Filter := 'Wavefront Object Files (*.obj)|*.obj|Sony Collada Format (*.dae)|*.dae|All supported Formats |*.dae;*.obj';
    OpenDlg.FilterIndex := 3;

    if( OpenDlg.Execute() ) then
      AFileName := OpenDlg.FileName
    else
      Exit( False );

    SafeFree(OpenDlg);
  end;

  if( LowerCase( ExtractFileExt( AFileName )) = '.obj' ) then
    AImport := TGX_ImportWFO.Create()
  else
  if( LowerCase( ExtractFileExt( AFileName )) = '.dae' ) then
    AImport := TGX_ImportDAE.Create()
  else
    Exit( False );

  if(( AImport <> nil ) and ( AImport.LoadFromFile( AFileName ))) then
      AImport.CreateModel( AObject, 0 );

  SafeFree( AImport );

  AObject.Meshes[0].Indexed := False;
  AObject.UpdateSize();

  //AScaleValue := 1.5 / Max( Max( ACast.Size.X, ACast.Size.Y ), ACast.Size.Z );
  //ACast.Scale := GX_Float3( AScaleValue, AScaleValue, AScaleValue );

  Result := True;
end;

end.
