// Copyright (c) 2021 Arsanias
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.BitReader;

interface

uses
  System.Types, System.SysUtils, System.Math, System.StrUtils, System.Classes,
  System.Generics.Collections,
  Core.Utils, Core.ByteReader;

type
  TBitReader = class
  private
    FBitsRead: Int64;
    FByteBuffer: TByteReader;
    FFile: TFileStream;
    FByteOrder: TByteOrder;
    function GetByte: Byte;
  protected
    LastByteRead: Byte;
    function Read(BitsToRead: Integer): Int64;
  public
    constructor Create(AByteBuffer: TByteReader; AByteOrder: TByteOrder); overload;
    constructor Create(AFile: TFileStream; AByteOrder: TByteOrder); overload;
    function ReadUnsigned(BitsToRead: Integer): Integer;
    function ReadSigned(BitsToRead: Integer): Integer;
    procedure Reset;
    property ByteOrder: TByteOrder read FByteOrder write FByteOrder;
    property BitsRead: Int64 read FBitsRead;
  end;

implementation

constructor TBitReader.Create(AByteBuffer: TByteReader; AByteOrder: TByteOrder);
begin
  FFile := nil;
  FByteBuffer := AByteBuffer;
  FByteOrder := AByteOrder;
  FBitsRead := 0;
end;

constructor TBitReader.Create(AFile: TFileStream; AByteOrder: TByteOrder);
begin
  FByteBuffer := nil;
  FFile := AFile;
  FByteOrder := AByteOrder;
  FBitsRead := 0;
end;

function TBitReader.GetByte: Byte;
begin
  if (FByteBuffer <> nil) then
    FByteBuffer.Read(Result, 1)
  else
  if (FFile <> nil) then
    FFile.Read(Result, 1);
  LastByteRead := Result;
end;

function TBitReader.Read(BitsToRead: Integer): Int64;
var
  BytesToRead: Integer;
  mask: Int64;
  BytePortion: Int64;
  i: Integer;
  ShiftBits: Int64;
begin
  if (BitsToRead <= 0) then
    Exit(0);

  BytesToRead := Trunc(((BitsRead mod 8) + BitsToRead + 7) / 8);
  Mask := $FFFFFFFFFFFFFFFF shr (64 - BitsToRead); // WARNING - >>> means shifted signed integer, not supprted on Delphi // war $FFFFFFFFFFFFFFFFL
  Result := 0;
  BytePortion := 0;

  { read value from buffer }

  for i := 0 to BytesToRead - 1 do
  begin
    if ((i = 0) and ((BitsRead mod 8) > 0)) then
      BytePortion := $FF and LastByteRead
    else
      BytePortion := $FF and GetByte;

    if (ByteOrder = TByteOrder.boLittleEndian) then
      Result := Result or (bytePortion shl (i shl 3))
    else
      Result := (bytePortion shl ((bytesToRead - i - 1) shl 3)) or Result;
  end;

  { right shift the number }

  if (ByteOrder = boBigEndian) then
    ShiftBits := 7 - ((BitsToRead + BitsRead + 7) mod 8)
  else
    ShiftBits := BitsRead mod 8;
  Result := Result shr shiftBits;

  Result := Mask and Result;

  FBitsRead := FBitsRead + BitsToRead;
end;

function TBitReader.ReadUnsigned(BitsToRead: Integer): Integer;
begin
  Result := Integer(Read(BitsToRead));
end;

function TBitReader.ReadSigned(BitsToRead: Integer): Integer;
begin
  Result := Integer(Read(BitsToRead));

  Result := Result shl (32 - BitsToRead);
  Result := SAR(Result, (32 - BitsToRead));
end;

procedure TBitReader.Reset;
var
  BitsToSkip: Integer;
begin
  BitsToSkip := BitsRead mod 8;
  if (BitsToSkip > 0) then
    ReadUnsigned(8 - BitsToSkip);
  FBitsRead := 0;
  LastByteRead := 0;
end;

end.
