// Copyright (c) 2021 Arsanias
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.Arrays;

interface

uses
  Winapi.Windows,
  System.Variants, System.SysUtils, System.Classes,  System.Generics.Collections,
  Core.Types, Core.Utils;

type
  TCoreNode = class
  private
    FChildCount: Integer;
    FFirstChild: TCoreNode;
    FLastChild: TCoreNode;
    FLevel: Integer;
    FParent: TCoreNode;
    FPrevSibling: TCoreNode;
    FNextSibling: TCoreNode;
  protected
    property ChildCount: Integer read FChildCount;
    property FirstChild: TCoreNode read FFirstChild;
    property LastChild: TCoreNode read FLastChild;
    property Level: Integer read FLevel;
    property Parent: TCoreNode read FParent;
    property PrevSibling: TCoreNode read FPrevSibling;
    property NextSibling: TCoreNode read FNextSibling;
  end;

  TCoreNodeCompareFunction = Reference to function(const Item1, Item2: Pointer): Integer;

  TCoreTree = class
  private
    FCount: Integer;
    FRoot: TCoreNode;
    function GetFirst: TCoreNode;
  protected
    function Add(AParent, AItem: TCoreNode): Integer; virtual;
    procedure Sort(ACompareFunction: TCoreNodeCompareFunction);
    procedure Swap(AItem1, AItem2: TCoreNode);
  public
    constructor Create;
    destructor Destroy; override;
    property Count: Integer read FCount;
    property First: TCoreNode read GetFirst;
  end;

  TGX_Array = class;

  TGX_NodeList<T> = class
  type
    PGX_Node = ^TGX_Node;
    TGX_Node = record
      Next: PGX_Node;
      Prev: PGX_Node;
      Data: T;
    end;
  private
    FCount: Integer;
    Last: PGX_Node;
    procedure RemoveNode( ANode: PGX_Node );
    function GetCount(): Integer;
    function GetNode( AIndex: Integer ): PGX_Node;
    function GetNodeData( AIndex: Integer ): T;
  public
    Data: PGX_Node;
    constructor Create;
    destructor Destroy; override;
    function Add(const AData: T): Integer;
    procedure Clear;
    procedure Delete(AIndex: Integer);
  public
    property Items[AIndex: Integer]: T read GetNodeData; default;
    property Count: Integer read GetCount;
  end;

  TNodeList<T> = class(TList<T>)
  private
    FCount: Integer;
    function GetLast: T;
  public
    constructor Create;
    destructor Destroy; override;
    property Last: T read GetLast;
  end;

  TSemanticItem = class
  private
    function GetPosition: TVector3;
    procedure SetPosition(AVector: TVector3);
  public
    property Position: TVector3 read GetPosition write SetPosition;
  end;

  TSemanticList = class
  private
    FData: array of Byte;
    FSize: Cardinal;
    FPosIdx, FNormIdx, FTexCoordIdx, FTexCoord2Idx, FTexCoord3Idx: Integer;
    function GetSemanticItem(AIndex: Integer): TSemanticItem;
  public
    constructor Create(Semantics: TShaderSemantics);
    property Items[AIndex: Integer]: TSemanticItem read GetSemanticItem; default;
  end;

  TGX_ArrayField = class
  private
    FOffset: Cardinal;
    FSemantic: TGX_Semantic;
    FIndex: Integer;
    FSize: Integer;
    FName: string;
    FArray: TGX_Array;
  public
    constructor Create(AArray: TGX_Array; ASemantic: TGX_Semantic; AName: string; ASize: Integer );
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
    property Semantic: TGX_Semantic read FSemantic;
    property AsFloat[ ARow: Integer ]: Single read GetFloat write SetFloat;
    property AsFloat2[ ARow: Integer ]: TVector2 read GetFloat2 write SetFloat2;
    property AsFloat3[ ARow: Integer ]: TVector3 read GetFloat3 write SetFloat3;
    property AsFloat4[ ARow: Integer ]: TVector4 read GetFloat4 write SetFloat4;
    property AsInteger[ ARow: Integer ]: Integer read GetInteger write SetInteger;
  end;

  TGX_Array = class
  private
    FData: Pointer;
    FStride: Cardinal;
    FRowCount: Integer;
    FIndexed: Boolean;
    FFields:  TGX_NodeList<TGX_ArrayField>;
    function  GetSize(): Cardinal;
    procedure SetRowCount(ARowCount: Integer );
    procedure UpdateFieldOffsets();
    function GetFieldCount(): Integer;
    function GetFieldByIndex(AIndex: Integer ): TGX_ArrayField;
    function GetFieldBySemantic(ASemantic: TGX_Semantic): TGX_ArrayField;
  public
    constructor Create(); overload;
    constructor Create(ASemantics: TGX_Semantics ); overload;
    destructor  Destroy(); override;
  public
    function  FieldIndex(ASemantic: TGX_Semantic ): Integer;
    function  AddField(ASemantic: TGX_Semantic ; AName: string ; ASize: Integer ): TGX_ArrayField;
    function  AddRows(ARowCount: Integer ): LongBool;
    procedure Clear();
    procedure Zero();
    function  Field(AFieldIndex: Integer ): TGX_ArrayField;
    function  AsHex(ARow: Integer ): string;
    procedure Copy(ASourceRow, ADestRow: Cardinal );
    procedure GetValue(AOffset, ARow: Cardinal ; AValue: Pointer ; ASize: Cardinal );
    procedure SetValue(AOffset, ARow: Cardinal ; AValue: Pointer ; ASize: Cardinal );
  public
    property  Data: Pointer read FData;
    property  FieldCount: Integer read GetFieldCount;
    property  RowCount: Integer read FRowCount write SetRowCount;
    property  Stride: Cardinal read FStride;
    property  Size: Cardinal read GetSize;
    property  Fields[ AIndex: Integer ]: TGX_ArrayField read GetFieldByIndex; default;
    property  Fields[ ASemantic: TGX_Semantic ]: TGX_ArrayField read GetFieldBySemantic; default;
    procedure LoadFromStream(AStream: TMemoryStream );
    procedure SaveToStream(AStream: TMemoryStream );
  end;

implementation

var
  AData: TSemanticList;

//======================================================================================================

constructor TCoreTree.Create;
begin
  inherited;
  FRoot := TCoreNode.Create;
  FRoot.FLevel := -1;
end;

destructor TCoreTree.Destroy;
begin
  FRoot.Free;
  inherited;
end;

function TCoreTree.GetFirst: TCoreNode;
begin
  Result := FRoot.FirstChild;
end;

procedure TCoreTree.Sort(ACompareFunction: TCoreNodeCompareFunction);
var
  ANext, ATemp: TCoreNode;
  i: Integer;
  procedure DoSort(ATest, AItem: TCoreNode; ACount: Integer);
  begin
    while (ATest <> nil) and (AItem <> nil) and (ACount > 0) do
    begin
      if ACompareFunction(ATest, AItem) > 0 then
      begin
        Swap(ATest, AItem);
        if ACount = 1 then
          ATest.FNextSibling := nil;
        Exit;
      end
      else
      if ACount = 1 then
      begin
        ATest.FNextSibling := AItem;
        AItem.FPrevSibling := ATest;
        AItem.FNextSibling := nil;
      end;
      ATest := ATest.NextSibling;
      Dec(ACount);
    end;
  end;
begin
  if Count < 2 then Exit;

  ANext := First;

  for i := 1 to Count - 1 do
  begin
    if ANext <> nil then
    begin
      ATemp := ANext.NextSibling;
      DoSort(First, ANext, i);
      ANext := ATemp;
    end;
  end;
end;

procedure TCoreTree.Swap(AItem1, AItem2: TCoreNode);
var
  ATemp: TCoreNode;
begin
  if AItem1.PrevSibling <> nil then AItem1.PrevSibling.FNextSibling := AItem2;
  if AItem1.NextSibling <> nil then AItem1.NextSibling.FPrevSibling := AItem2;

  AItem2.FPrevSibling := AItem1.FPrevSibling;
  AItem1.FPrevSibling := AItem2;
  AItem2.FNextSibling := AItem1;

  if AItem1 = FRoot.FirstChild then
    FRoot.FFirstChild := AItem2
  else
  if AItem2 = FRoot.FirstChild then
    FRoot.FFirstChild := AItem1;
end;

function TCoreTree.Add(AParent, AItem: TCoreNode): Integer;
begin
  Result := Count;

  if AParent = nil then AParent := FRoot;

  AItem.FParent := AParent;
  AItem.FLevel := AParent.Level + 1;

  if AParent.FirstChild = nil then
  begin
    AParent.FFirstChild := AItem;
    AParent.FLastChild := AItem;
  end
  else
  begin
    if AParent.FirstChild.NextSibling = nil then
      AParent.FirstChild.FNextSibling := AItem
    else
      AParent.LastChild.FNextSibling := AItem;
    AItem.FPrevSibling := AParent.LastChild;
    AParent.FLastChild := AItem;
  end;
  Inc(AParent.FChildCount);

  Inc(FCount);
end;

//======================================================================================================

constructor TGX_NodeList<T>.Create();
begin
  inherited Create();
  FCount := 0;
end;

destructor TGX_NodeList<T>.Destroy();
begin
  Clear();

  inherited Destroy();
end;

function TGX_NodeList<T>.Add(const AData: T): Integer;
var
  ANode: PGX_Node;
begin
  ANode := new( PGX_Node );
  ANode.Next := nil;

  if( Data = nil ) then
  begin
    ANode.Prev := nil;
    Data := ANode;
  end
  else
  begin
    ANode.Prev := Last;
    Last.Next  := ANode;
  end;
  Last := ANode;
  Inc( FCount );

  ANode.Data := AData;

  Result := Count - 1;
end;

procedure TGX_NodeList<T>.RemoveNode( ANode: PGX_Node );
begin
  if( ANode = Data ) then
  begin
    ANode.Prev := nil;
    Data := ANode.Next;
  end
  else
  begin
    if( ANode.Prev <> nil ) then ANode.Prev.Next := ANode.Next;
    if( ANode.Next <> nil ) then ANode.Next.Prev := ANode.Prev;
  end;
  Dispose( ANode );

  Dec( FCount );
  if( FCount <= 0 ) then Data := nil;
end;

procedure TGX_NodeList<T>.Clear();
var
  ANode, ATemp: PGX_Node;
begin
  ANode := Data;
  while( ANode <> nil ) do
  begin
    ATemp := ANode.Next;
    Dispose( ANode );
    ANode := ATemp;
  end;

  Data := nil;
  Last := nil;
  FCount := 0;
end;

procedure TGX_NodeList<T>.Delete( AIndex: Integer );
begin
  RemoveNode( GetNode( AIndex ));
end;

function TGX_NodeList<T>.GetCount(): Integer;
begin
  Result := FCount;
end;

function TGX_NodeList<T>.GetNode( AIndex: Integer ): PGX_Node;
begin
  if(( AIndex < 0 ) or ( AIndex >= Count )) then Exit;

  Result := Data;
  while(( Result <> nil ) and ( Result.Next <> nil ) and ( AIndex > 0 )) do
  begin
    Result := Result.Next;
    Dec( AIndex );
  end;
end;

function TGX_NodeList<T>.GetNodeData( AIndex: Integer ): T;
var
  ANode: PGX_Node;
begin
  ANode := GetNode( AIndex );
  if( ANode = nil ) then Exit;

  Result := ANode.Data;
end;

constructor TNodeList<T>.Create;
begin
  inherited Create();
end;

destructor TNodeList<T>.Destroy;
begin
  Clear();
  inherited Destroy();
end;

function TNodeList<T>.GetLast: T;
begin
  if Count = 0 then Exit(T(nil));
  Result := Items[Count-1];
end;

//==============================================================================

constructor TGX_Array.Create();
begin
  inherited Create();

  FFields := TGX_NodeList<TGX_ArrayField>.Create();
  Clear();
end;

constructor TGX_Array.Create(ASemantics: TGX_Semantics );
var
  i: Integer;
begin
  Create();

  for i := 0 to GX_MAX_SEMANTICS - 1 do
    if(TGX_Semantic(i ) in ASemantics ) then
      AddField(TGX_Semantic(i ), '', 0 );
end;

destructor TGX_Array.Destroy();
var
  i: Integer;
  AField: TGX_ArrayField;
begin
  Clear();

  { fields }

  if(FFields.Count > 0 ) then
    for i := 0 to FFields.Count - 1 do
    begin
      AField := FFields.Items[ i ];
      SafeFree(AField );
    end;
  SafeFree(FFields );

  inherited Destroy();
end;

procedure TGX_Array.Clear();
begin
  RowCount := 0;
end;

function TGX_Array.Field(AFieldIndex: Integer ): TGX_ArrayField;
begin
  if(FFields.Count <= AFieldIndex ) then Exit(nil );
  Result := FFields[ AFieldIndex ];
end;

function TGX_Array.AsHex(ARow: Integer ): string;
var
  AByte: PByte;
  i: Integer;
begin
  Result := '';
  AByte := Pointer(Cardinal(FData ) + ARow * FStride );

  for i := FStride-1 downto 0 do
    Result := Result + ByteToHex(PByte(Cardinal(AByte ) + i )^);
end;

procedure TGX_Array.Copy(ASourceRow, ADestRow: Cardinal );
var
  ASourcePointer: Pointer;
  ADestPointer:   Pointer;
begin
  ASourcePointer := Pointer(Cardinal(FData ) + ASourceRow * Stride );
  ADestPointer   := Pointer(Cardinal(FData ) + ADestRow   * Stride );

  CopyMemory(ADestPointer, ASourcePointer, Stride );
end;

function TGX_Array.FieldIndex(ASemantic: TGX_Semantic ): Integer;
var
  i: Integer;
  AField: TGX_ArrayField;
begin
  AField := Fields[ ASemantic ];
  if(AField = nil ) then
    Exit(-1 )
  else
    Result := AField.Index;
end;

function TGX_Array.GetSize(): Cardinal;
begin
  Result := FRowCount * FStride;
end;

procedure TGX_Array.GetValue(AOffset, ARow: Cardinal ; AValue: Pointer; ASize: Cardinal );
var
  APointer: Pointer;
begin
  APointer := Pointer (Cardinal(FData ) + ARow * Stride + AOffset );
  CopyMemory(AValue, APointer, ASize );
end;

procedure TGX_Array.SetValue(AOffset, ARow: Cardinal ; AValue: Pointer; ASize: Cardinal );
var
  APointer: Pointer;
begin
  APointer := Pointer(Cardinal(FData ) + ARow * Stride + AOffset );
  CopyMemory(APointer, AValue, ASize );
end;

procedure TGX_Array.SetRowCount(ARowCount: Integer );
begin
  if(ARowCount = FRowCount ) then Exit;

  if(ARowCount = 0 ) then
  begin
    if(Size > 0 ) then FreeMem(FData, Size );
    FRowCount := 0;
  end
  else
  begin
    ReallocMem(FData, FStride * ARowCount);
    FRowCount := ARowCount;
  end;
end;

function TGX_Array.AddField(ASemantic: TGX_Semantic ; AName: string ; ASize: Integer ): TGX_ArrayField;
var
  AField: TGX_ArrayField;
begin
  if(ASize = 0 ) then
  begin
    if (ASemantic = asUnknown) then Exit;
    case ASemantic of
      asPosition, asNormal: ASize := SizeOf(TVector3 );
      asColor:              ASize := SizeOf(TVector4 );
      asTexcoord:           ASize := SizeOf(TVector2 );
      asBoneWeight:         ASize := SizeOf(Single );
      asIndex:              ASize := SizeOf(Integer);
      else
        Exit(nil );
    end
  end;

  { create new field at the end }

  Result := TGX_ArrayField.Create(Self, ASemantic, AName, ASize );
  FFields.Add(Result );

  FStride := FStride + ASize;

  UpdateFieldOffsets();
end;

function TGX_Array.AddRows(ARowCount: Integer ): LongBool;
begin
  RowCount := RowCount + ARowCount;
  Result := True;
end;

function TGX_Array.GetFieldCount(): Integer;
begin
  Result := FFields.Count;
end;

function TGX_Array.GetFieldByIndex(AIndex: Integer ): TGX_ArrayField;
begin
  if(AIndex >= FieldCount ) then Exit(nil );
  Result := FFields[ AIndex ];
end;

function TGX_Array.GetFieldBySemantic(ASemantic: TGX_Semantic ): TGX_ArrayField;
var
  i: Integer;
begin
  Result := nil;
  if(FieldCount = 0 ) then Exit;
  for i := 0 to FieldCount - 1 do
    if(Fields[ i ].Semantic = ASemantic ) then
    begin
      Result := Fields[ i ];
      Break;
    end;
end;

procedure TGX_Array.LoadFromStream(AStream: TMemoryStream );
begin
  AStream.ReadBuffer(FData^, Size );
end;


procedure TGX_Array.SaveToStream(AStream: TMemoryStream );
begin
  AStream.WriteBuffer(FData^, Size );
end;

procedure TGX_Array.UpdateFieldOffsets();
var
  i, n: Integer;
  AField: TGX_ArrayField;
begin
  if(FieldCount = 0 ) then Exit;

  n := 0;

  for i := 0 to FieldCount - 1 do
  begin
    AField := FFields[ i ];
    AField.Offset := n;
    AField.Index  := i;
    n := n + AField.Size;
  end;
end;

procedure TGX_Array.Zero();
begin
  if(FData <> nil ) and (Size > 0 ) then
    ZeroMemory(FData, Size );
end;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

constructor TGX_ArrayField.Create(AArray: TGX_Array ; ASemantic: TGX_Semantic ; AName: string; ASize: Integer );
begin
  inherited Create();

  FArray    := AArray;
  FSemantic := ASemantic;
  FSize     := ASize;
end;

function TGX_ArrayField.GetFloat(ARow: Integer ): Single;
begin
  FArray.GetValue(Offset, ARow, @Result, SizeOf(Result ));
end;

function TGX_ArrayField.GetFloat2(ARow: Integer ): TVector2;
begin
  FArray.GetValue(Offset, ARow, @Result, SizeOf(Result ));
end;

function TGX_ArrayField.GetFloat3(ARow: Integer ): TVector3;
begin
  FArray.GetValue(Offset, ARow, @Result, SizeOf(Result ));
end;

function TGX_ArrayField.GetFloat4(ARow: Integer ): TVector4;
begin
  FArray.GetValue(Offset, ARow, @Result, SizeOf(Result ));
end;

function TGX_ArrayField.GetInteger(ARow: Integer ): Integer;
begin
  FArray.GetValue(Offset, ARow, @Result, SizeOf(Result ));
end;

procedure TGX_ArrayField.SetInteger(ARow: Integer ; AInteger: Integer );
begin
  FArray.SetValue(Offset, ARow, @AInteger, SizeOf(Integer ));
end;

procedure TGX_ArrayField.SetFloat(ARow: Integer ; AFloat: Single );
begin
  FArray.SetValue(Offset, ARow, @AFloat, SizeOf(AFloat ));
end;

procedure TGX_ArrayField.SetFloat2(ARow: Integer ; AFloat2: TVector2 );
begin
  FArray.SetValue(Offset, ARow, @AFloat2, SizeOf(AFloat2 ));
end;

procedure TGX_ArrayField.SetFloat3(ARow: Integer ; AFloat3: TVector3 );
begin
  FArray.SetValue(Offset, ARow, @AFloat3, SizeOf(AFloat3 ));
end;

procedure TGX_ArrayField.SetFloat4(ARow: Integer ; AFloat4: TVector4 );
begin
  FArray.SetValue(Offset, ARow, @AFloat4, SizeOf(AFloat4 ));
end;

//==============================================================================

constructor TSemanticList.Create(Semantics: TShaderSemantics);
var
  Semantic: TGX_Semantic;
  procedure SetSemantic(ASize: Integer; var AIndex: Integer);
  begin
    AIndex := FSize;
    Inc(FSize, ASize);
  end;
begin
  FSize := 0;

  for Semantic in Semantics do
    case Semantic of
      asPosition: SetSemantic(SizeOf(TVector3), FPosIdx);
      asNormal:   SetSemantic(SizeOf(TVector3), FNormIdx);
      asTexcoord: SetSemantic(SIzeOf(TVector2), FTexCoordIdx);
    end;
end;

function TSemanticList.GetSemanticItem(AIndex: Integer): TSemanticItem;
begin

end;

function TSemanticItem.GetPosition: TVector3;
begin
  //
end;

procedure TSemanticItem.SetPosition(AVector: TVector3);
begin
  //
end;

//==============================================================================

begin
  (*
  AData := TSemanticList.Create([asPosition, asNormal]);
  AData[12].Position := TVector3.Create(0, 0, 0);
  AData[12].Posiion.Z := 0.12;
  AData[12].Normal.Y := 24.5;
  *)
end.
