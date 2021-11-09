// Copyright (c) 2021 Arsanias (arsaniasbb@gmail.com)
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.Shader;

interface

uses
  System.SysUtils, System.Classes,
  Core.Types, Core.Utils, Core.Arrays;

const
  MAX_SEMANTICS = 10;

type
  TShaderSemantic = (asUnknown, asIndex, asCounter, asPosition, asNormal, asTexcoord, asColor, asTerrain, asBoneIndex, asBoneWeight);
  TShaderSemantics = set of TShaderSemantic;

  TShadeMode = (smFlat, smGouraud);

  TShaderFlag = (stMipMap, stOpaqueColor);
  TShaderFlags = set of TShaderFlag;

  TVertexTopology = (ptPoints, ptLines, ptTriangles, ptTriangleStrip);

  TShaderArray = class;

  TShaderArrayField = class
  private
    FOffset: Cardinal;
    FSemantic: TShaderSemantic;
    FIndex: Integer;
    FSize: Integer;
    FName: string;
    FArray: TShaderArray;
  public
    constructor Create(AArray: TShaderArray; ASemantic: TShaderSemantic; AName: string; ASize: Integer);
  private
    function GetFloat(ARow: Integer): Single;
    function GetFloat2(ARow: Integer): TVector2;
    function GetFloat3(ARow: Integer): TVector3;
    function GetFloat4(ARow: Integer): TVector4;
    function GetInteger(ARow: Integer): Integer;
    procedure SetFloat(ARow: Integer ; AFloat: Single);
    procedure SetFloat2(ARow: Integer; AFloat2: TVector2);
    procedure SetFloat3(ARow: Integer; AFloat3: TVector3);
    procedure SetFloat4(ARow: Integer; AFloat4: TVector4);
    procedure SetInteger(ARow: Integer; AInteger: Integer);
  public
    property Name: String read FName;
    property Offset: Cardinal read FOffset write FOffset;
    property Index: Integer read FIndex write FIndex;
    property Size: Integer read FSize;
    property Semantic: TShaderSemantic read FSemantic;
    property AsFloat[ARow: Integer]: Single read GetFloat write SetFloat;
    property AsFloat2[ARow: Integer]: TVector2 read GetFloat2 write SetFloat2;
    property AsFloat3[ARow: Integer]: TVector3 read GetFloat3 write SetFloat3;
    property AsFloat4[ARow: Integer]: TVector4 read GetFloat4 write SetFloat4;
    property AsInteger[ARow: Integer]: Integer read GetInteger write SetInteger;
  end;

  TShaderArray = class
  private
    FData: Pointer;
    FStride: Cardinal;
    FRowCount: Integer;
    FIndexed: Boolean;
    FFields: TNodeList<TShaderArrayField>;
    function GetSize: Cardinal;
    procedure SetRowCount(ARowCount: Integer);
    procedure UpdateFieldOffsets;
    function GetFieldCount: Integer;
    function GetFieldByIndex(AIndex: Integer): TShaderArrayField;
    function GetFieldBySemantic(ASemantic: TShaderSemantic): TShaderArrayField;
  public
    constructor Create; overload;
    constructor Create(ASemantics: TShaderSemantics); overload;
    destructor Destroy; override;
  public
    function FieldIndex(ASemantic: TShaderSemantic): Integer;
    function AddField(ASemantic: TShaderSemantic; AName: string; ASize: Integer): TShaderArrayField;
    function AddRows(ARowCount: Integer): LongBool;
    procedure Clear;
    procedure Zero;
    function Field(AFieldIndex: Integer): TShaderArrayField;
    function AsHex(ARow: Integer): string;
    procedure Copy(ASourceRow, ADestRow: Cardinal);
    procedure GetValue(AOffset, ARow: Cardinal; AValue: Pointer ; ASize: Cardinal);
    procedure SetValue(AOffset, ARow: Cardinal; AValue: Pointer ; ASize: Cardinal);
  public
    property Data: Pointer read FData;
    property FieldCount: Integer read GetFieldCount;
    property RowCount: Integer read FRowCount write SetRowCount;
    property Stride: Cardinal read FStride;
    property Size: Cardinal read GetSize;
    property Fields[AIndex: Integer]: TShaderArrayField read GetFieldByIndex; default;
    property Fields[ASemantic: TShaderSemantic]: TShaderArrayField read GetFieldBySemantic; default;
    procedure LoadFromStream(AStream: TMemoryStream);
    procedure SaveToStream(AStream: TMemoryStream);
  end;

  TShader = class

  end;

implementation

//==============================================================================

constructor TShaderArray.Create;
begin
  inherited Create;

  FFields := TNodeList<TShaderArrayField>.Create;
  Clear;
end;

constructor TShaderArray.Create(ASemantics: TShaderSemantics);
var
  i: Integer;
begin
  Create;

  for i := 0 to MAX_SEMANTICS - 1 do
    if (TShaderSemantic(i) in ASemantics) then
      AddField(TShaderSemantic(i), '', 0);
end;

destructor TShaderArray.Destroy;
var
  i: Integer;
  AField: TShaderArrayField;
begin
  Clear;

  { fields }

  if(FFields.Count > 0) then
    for i := 0 to FFields.Count - 1 do
    begin
      AField := FFields.Items[i];
      SafeFree(AField);
    end;
  SafeFree(FFields);

  inherited Destroy;
end;

procedure TShaderArray.Clear;
begin
  RowCount := 0;
end;

function TShaderArray.Field(AFieldIndex: Integer): TShaderArrayField;
begin
  if(FFields.Count <= AFieldIndex) then Exit(nil);
  Result := FFields[AFieldIndex];
end;

function TShaderArray.AsHex(ARow: Integer): string;
var
  AByte: PByte;
  i: Integer;
begin
  Result := '';
  AByte := Pointer(Cardinal(FData) + ARow * FStride);

  for i := FStride-1 downto 0 do
    Result := Result + ByteToHex(PByte(Cardinal(AByte) + i)^);
end;

procedure TShaderArray.Copy(ASourceRow, ADestRow: Cardinal);
var
  ASourcePointer: Pointer;
  ADestPointer:   Pointer;
begin
  ASourcePointer := Pointer(Cardinal(FData) + ASourceRow * Stride);
  ADestPointer   := Pointer(Cardinal(FData) + ADestRow   * Stride);

  Move(ASourcePointer^, ADestPointer^, Stride);
end;

function TShaderArray.FieldIndex(ASemantic: TShaderSemantic): Integer;
var
  i: Integer;
  AField: TShaderArrayField;
begin
  AField := Fields[ASemantic];
  if (AField = nil) then
    Exit(-1)
  else
    Result := AField.Index;
end;

function TShaderArray.GetSize: Cardinal;
begin
  Result := FRowCount * FStride;
end;

procedure TShaderArray.GetValue(AOffset, ARow: Cardinal; AValue: Pointer; ASize: Cardinal);
var
  APointer: Pointer;
begin
  APointer := Pointer(Cardinal(FData) + ARow * Stride + AOffset);
  Move(APointer^, AValue^, ASize);
end;

procedure TShaderArray.SetValue(AOffset, ARow: Cardinal ; AValue: Pointer; ASize: Cardinal);
var
  APointer: Pointer;
begin
  APointer := Pointer(Cardinal(FData) + ARow * Stride + AOffset);
  Move(AValue^, APointer^, ASize);
end;

procedure TShaderArray.SetRowCount(ARowCount: Integer);
begin
  if (ARowCount = FRowCount) then Exit;

  if (ARowCount = 0) then
  begin
    if(Size > 0) then FreeMem(FData, Size);
    FRowCount := 0;
  end
  else
  begin
    ReallocMem(FData, FStride * ARowCount);
    FRowCount := ARowCount;
  end;
end;

function TShaderArray.AddField(ASemantic: TShaderSemantic ; AName: string ; ASize: Integer): TShaderArrayField;
var
  AField: TShaderArrayField;
begin
  if(ASize = 0) then
  begin
    if (ASemantic = asUnknown) then Exit;
    case ASemantic of
      asPosition, asNormal: ASize := SizeOf(TVector3);
      asColor:              ASize := SizeOf(TVector4);
      asTexcoord:           ASize := SizeOf(TVector2);
      asBoneWeight:         ASize := SizeOf(Single);
      asIndex:              ASize := SizeOf(Integer);
      else
        Exit(nil);
    end
  end;

  { create new field at the end }

  Result := TShaderArrayField.Create(Self, ASemantic, AName, ASize);
  FFields.Add(Result);

  FStride := FStride + ASize;

  UpdateFieldOffsets;
end;

function TShaderArray.AddRows(ARowCount: Integer): LongBool;
begin
  RowCount := RowCount + ARowCount;
  Result := True;
end;

function TShaderArray.GetFieldCount: Integer;
begin
  Result := FFields.Count;
end;

function TShaderArray.GetFieldByIndex(AIndex: Integer): TShaderArrayField;
begin
  if(AIndex >= FieldCount) then Exit(nil);
  Result := FFields[AIndex];
end;

function TShaderArray.GetFieldBySemantic(ASemantic: TShaderSemantic): TShaderArrayField;
var
  i: Integer;
begin
  Result := nil;
  if(FieldCount = 0) then Exit;
  for i := 0 to FieldCount - 1 do
    if(Fields[i].Semantic = ASemantic) then
    begin
      Result := Fields[i];
      Break;
    end;
end;

procedure TShaderArray.LoadFromStream(AStream: TMemoryStream);
begin
  AStream.ReadBuffer(FData^, Size);
end;

procedure TShaderArray.SaveToStream(AStream: TMemoryStream);
begin
  AStream.WriteBuffer(FData^, Size);
end;

procedure TShaderArray.UpdateFieldOffsets;
var
  i, n: Integer;
  AField: TShaderArrayField;
begin
  if(FieldCount = 0) then Exit;

  n := 0;

  for i := 0 to FieldCount - 1 do
  begin
    AField := FFields[i];
    AField.Offset := n;
    AField.Index  := i;
    n := n + AField.Size;
  end;
end;

procedure TShaderArray.Zero;
begin
  if(FData <> nil) and (Size > 0) then
    FillChar(FData^, Size, 0);
end;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

constructor TShaderArrayField.Create(AArray: TShaderArray; ASemantic: TShaderSemantic; AName: string; ASize: Integer);
begin
  inherited Create;

  FArray    := AArray;
  FSemantic := ASemantic;
  FSize     := ASize;
end;

function TShaderArrayField.GetFloat(ARow: Integer): Single;
begin
  FArray.GetValue(Offset, ARow, @Result, SizeOf(Result));
end;

function TShaderArrayField.GetFloat2(ARow: Integer): TVector2;
begin
  FArray.GetValue(Offset, ARow, @Result, SizeOf(Result));
end;

function TShaderArrayField.GetFloat3(ARow: Integer): TVector3;
begin
  FArray.GetValue(Offset, ARow, @Result, SizeOf(Result));
end;

function TShaderArrayField.GetFloat4(ARow: Integer): TVector4;
begin
  FArray.GetValue(Offset, ARow, @Result, SizeOf(Result));
end;

function TShaderArrayField.GetInteger(ARow: Integer): Integer;
begin
  FArray.GetValue(Offset, ARow, @Result, SizeOf(Result));
end;

procedure TShaderArrayField.SetInteger(ARow: Integer ; AInteger: Integer);
begin
  FArray.SetValue(Offset, ARow, @AInteger, SizeOf(Integer));
end;

procedure TShaderArrayField.SetFloat(ARow: Integer ; AFloat: Single);
begin
  FArray.SetValue(Offset, ARow, @AFloat, SizeOf(AFloat));
end;

procedure TShaderArrayField.SetFloat2(ARow: Integer ; AFloat2: TVector2);
begin
  FArray.SetValue(Offset, ARow, @AFloat2, SizeOf(AFloat2));
end;

procedure TShaderArrayField.SetFloat3(ARow: Integer ; AFloat3: TVector3);
begin
  FArray.SetValue(Offset, ARow, @AFloat3, SizeOf(AFloat3));
end;

procedure TShaderArrayField.SetFloat4(ARow: Integer ; AFloat4: TVector4);
begin
  FArray.SetValue(Offset, ARow, @AFloat4, SizeOf(AFloat4));
end;

end.
