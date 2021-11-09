// Copyright (c) 2021 Arsanias (arsaniasbb@gmail.com)
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

  TNodeList<T> = class
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
    procedure RemoveNode(ANode: PGX_Node);
    function GetCount: Integer;
    function GetNode(AIndex: Integer): PGX_Node;
    function GetNodeData(AIndex: Integer): T;
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

  // The TNodeList<T> is currently in use but not efficient, espeially adressing
  // items by index is a desaster... however, it is a very old class, written from
  // scratch and the intention was to keep it easy, so it made a good job.
  // The future is the new TNodeListEx class, based on a TList, what is definitevely
  // fast in adressing items by index. Anyhow... it is currently "under construction".

  TNodeListEx<T> = class(TList<T>)
  private
    FCount: Integer;
    function GetLast: T;
    function GetNext(ANode: T): T;
    function GetPrev(ANode: T): T;
  public
    constructor Create;
    destructor Destroy; override;
    property Last: T read GetLast;
    property Next[ANode: T]: T read GetNext;
    property Prev[ANode: T]: T read GetPrev;
  end;

implementation

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

constructor TNodeList<T>.Create();
begin
  inherited Create();
  FCount := 0;
end;

destructor TNodeList<T>.Destroy();
begin
  Clear();

  inherited Destroy();
end;

function TNodeList<T>.Add(const AData: T): Integer;
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

procedure TNodeList<T>.RemoveNode( ANode: PGX_Node );
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

procedure TNodeList<T>.Clear();
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

procedure TNodeList<T>.Delete( AIndex: Integer );
begin
  RemoveNode( GetNode( AIndex ));
end;

function TNodeList<T>.GetCount(): Integer;
begin
  Result := FCount;
end;

function TNodeList<T>.GetNode( AIndex: Integer ): PGX_Node;
begin
  if ((AIndex < 0) or (AIndex >= Count)) then Exit;

  Result := Data;
  while ((Result <> nil) and (Result.Next <> nil) and (AIndex > 0 )) do
  begin
    Result := Result.Next;
    Dec( AIndex );
  end;
end;

function TNodeList<T>.GetNodeData( AIndex: Integer ): T;
var
  ANode: PGX_Node;
begin
  ANode := GetNode(AIndex);
  if (ANode = nil) then Exit;

  Result := ANode.Data;
end;

constructor TNodeListEx<T>.Create;
begin
  inherited Create;
end;

destructor TNodeListEx<T>.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TNodeListEx<T>.GetLast: T;
begin
  if Count = 0 then Exit(T(nil));
  Result := Items[Count-1];
end;

function TNodeListEx<T>.GetNext(ANode: T): T;
var
  i: Integer;
begin
  i := IndexOf(ANode);
  if (i < 0) or (i >= Count) then Exit(T(nil));
  Result := Items[i + 1];
end;

function TNodeListEx<T>.GetPrev(ANode: T): T;
var
  i: Integer;
begin
  i := IndexOf(ANode);
  if (i <= 0) then Exit(T(nil));
  Result := Items[i - 1];
end;

end.
