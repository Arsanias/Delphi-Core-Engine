// Copyright (c) 2021 Arsanias
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.ByteReader;

interface

uses
  System.Types, System.SysUtils, System.Math, System.StrUtils, System.Classes,
  System.Generics.Collections,
  Core.Utils;

type
  TByteOrder = (boLittleEndian, boBigEndian);

  TByteReader = class
  private
    FBuffer: TByteDynArray;
    FByteOrder: TByteOrder;
    FCapacity: Int64;
    FPosition: Int64;
    function GetByte(AIndex: Integer): Byte;
    procedure SetByte(AIndex: Integer; AByte: Byte);
    procedure SetCapacity(ACapacity: Int64);
  public
    constructor Create(ACapacity: Int64);
    function Read(var ByteArray: array of Byte; Size: Integer): Integer; overload;
    function Read(var ABuffer; Size: Integer): Integer; overload;
    class function Wrap(AByteArray: TByteDynArray): TByteReader; overload;
    class function Wrap(AByteList: TList<ShortInt>): TByteReader; overload;
    property ByteOrder: TByteOrder read FByteOrder write FByteOrder;
    property Capacity: Int64 read FCapacity write SetCapacity;
    property Get[AIndex: Integer]: Byte read GetByte write SetByte; default;
    property Position: Int64 read FPosition write FPosition;
    property Buffer: TByteDynArray read FBuffer;
  end;

implementation

constructor TByteReader.Create(ACapacity: Int64);
begin
  FByteOrder := TByteOrder.boLittleEndian;
  FCapacity := ACapacity;
  SetLength(FBuffer, ACapacity);
end;

function TByteReader.Read(var ByteArray: array of Byte; Size: Integer): Integer;
var
  i: Integer;
begin
  for i := 0 to Size - 1 do
    ByteArray[i] := FBuffer[Position + i];
  //CopyArray(ABuffer, Buffer, TTypeKind.tkDynArray. Size);
  Position := Position + Size;
  Result := Size;
end;

function TByteReader.Read(var ABuffer; Size: Integer): Integer;
begin
  Move(Buffer[Position], ABuffer, Size);
  FPosition := FPosition + Size;
  Result := Size;
end;

function TByteReader.GetByte(AIndex: Integer): Byte;
begin
  if AIndex >= Capacity then
    raise Exception.Create('Index of ByteBuffer exceeds capacity.');

  Result := FBuffer[AIndex];
end;

procedure TByteReader.SetByte(AIndex: Integer; AByte: Byte);
begin
  if AIndex >= Capacity then
    raise Exception.Create('Index of ByteBuffer exceeds capacity.');

  FBuffer[AIndex] := AByte;
end;

procedure TByteReader.SetCapacity(ACapacity: Int64);
begin
  if (ACapacity = Capacity) then
    Exit;

  SetLength(FBuffer, ACapacity);
  FCapacity := ACapacity;

  if FPosition > Capacity then
    FPosition := Capacity;
end;

class function TByteReader.Wrap(AByteArray: TByteDynArray): TByteReader;
var
  i: Integer;
begin
  Result := TByteReader.Create(Length(AByteArray));
  for i := Low(AByteArray) to High(AByteArray) do
    Result.Buffer[i] := AByteArray[i];
end;

class function TByteReader.Wrap(AByteList: TList<ShortInt>): TByteReader;
var
  i: Integer;
begin
  Result := TByteReader.Create(AByteList.Count);
  for i := 0 to AByteList.Count - 1 do
    Result.Buffer[i] := AByteList[i];
end;

end.
