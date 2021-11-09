// Copyright (c) 2021 Arsanias (arsaniasbb@gmail.com)
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.Utils;

interface

uses
  System.Types, System.Variants, System.Math, System.SysUtils, System.StrUtils,
  System.DateUtils, System.UITypes,
  Winapi.Windows, Winapi.ShellApi,
  Core.Types;

function CheckBit(const AValue: Longint; const ABit: Byte): Boolean;
function ExtractDelimetedStr(StrPas, Delimeter: string; SearchIndex: Integer): string;
procedure ExecuteHyperlink(const ALink: string);
function GetTempPath: string;
function GetIf(ACondition: Boolean; ATrueValue, AFalseValue: Variant): Variant;
function IntAsFloat(AValue: Integer): Single;
function Limit(const AValue, AMin, AMax: Double): Double;
function SAR(Value: Integer; Bits: Byte): Integer; overload;
function SAR(Value: Byte; Bits: Byte): Byte; overload;
procedure SafeFree(var AObject);
procedure SetBit(var AValue: Longint; const ABit: Byte; Checked: Boolean);
function SplitString(AString, ASeparator: string): TStringDynArray;
function StripExtension(AFileName: string): string;
function SafeInc(ACounter, ALimit: Integer): Integer;
procedure IncMod(var AValue: Integer; AModN: Integer);
procedure DecMod(var AValue: Integer; AModN: Integer);
function AddMod(const AValue: Integer; AModN: Integer): Integer;
function SubMod(const AValue: Integer; AModN: Integer): Integer;
function GetDelimetedStr(AString: string; AIndex: Integer; ADelimeter: string): string;
function Saturate(const AColor: TColor; AFactor: Double): TColor; overload;
function Saturate(const AColor1, AColor2: TColor; AIntensity: Double): TColor; overload;
function VarToDate(AValue: Variant): TDateTime;
function VarToInt(AValue: Variant): Integer;
function DateTime(Milliseconds: Boolean): TDateTime;
function CommaDelimetedToArray(var va: TDynamicVariantArray; str: string): Integer;
function Weighted(Weight, MinValue, MaxValue, Value: Variant): Double;
function VarArrayToDelimetedStr(AValue: Variant; ASeparator: string): string;
function VarToFloat(AValue: Variant): Double;
function dxVarToDate(value: Variant): TDateTime;

implementation

function CheckBit(const AValue: Longint; const ABit: Byte): Boolean;
begin
  Result := (AValue and (1 shl ABit)) <> 0;
end;

function ColorToRGB(Color: TColor): Longint;
begin
  if Color < 0 then
    Result := GetSysColor(Color and $000000FF)
  else
    Result := Color;
end;

function GetTempPath: string;
const
  MAX_PATH = 1600;
var
  lpPathBuffer: PChar;
begin
  GetMem(lpPathBuffer, MAX_PATH);
  Winapi.Windows.GetTempPath(MAX_PATH, lpPathBuffer);

  Result := StrPas(lpPathBuffer);
  FreeMem(lpPathBuffer, MAX_PATH);
end;

procedure SetBit(var AValue: Longint; const ABit: Byte; Checked: Boolean);
begin
  if Checked then
    AValue := AValue or (1 shl ABit)
  else
    AValue := AValue and ((1 shl ABit) xor $FFFFFFFF);
end;

function GX_BitOff(const val: Longint; const TheBit: Byte): Longint;
begin
  Result := val and ((1 shl TheBit) xor $FFFFFFFF);
end;

function GX_BitToggle(const val: Longint; const TheBit: Byte): Longint;
begin
  Result := val xor (1 shl TheBit);
end;

function ExtractDelimetedStr(StrPas, Delimeter: string; SearchIndex: Integer): string;
var
  Pos:      Integer;
  LastPos:  Integer;
  Index:    Integer;
begin
  if SearchIndex = 0 then SearchIndex := 1;

  Result  := '';
  Index   := 1;
  LastPos := 1;

  repeat
    Pos := PosEx(Delimeter, StrPas, LastPos);

    if (Pos > 0) and (Index = SearchIndex) then
      Result := MidStr(StrPas, LastPos, Pos - LastPos)
    else
    if (Pos = 0) and (LastPos <= Length(StrPas)) and (Index = SearchIndex) then
      Result := RightStr(StrPas, Length(StrPas) - LastPos + 1);

    LastPos := Pos + 1;
    Inc(Index);
  until (Pos = 0) or (Pos >= Length(StrPas)) or (Index > SearchIndex);
end;

procedure ExecuteHyperlink(const ALink: string);
begin
  if (ALink = '') then Exit;

  ShellExecute(0,
   'open',
   PChar(ALink),
   nil,
   nil,
   SW_SHOW);
end;

function GetIf(ACondition: Boolean; ATrueValue, AFalseValue: Variant): Variant;
begin
  if ACondition then
    Result := ATrueValue
  else
    Result := AFalseValue;
end;

function IntAsFloat(AValue: Integer): Single;
begin
  Result := PSingle(@AValue)^;
end;

function CommaDelimetedToArray(var va: TDynamicVariantArray; str: string): Integer;
var
  Offset:   Integer;
  Position: Integer;
  i:        Integer;
  Buffer:   array[0..512] of string;
begin
  Result := 0;

  { set offset to first char in the string }
  Offset := 1;
  repeat
    { search for next comma starting at the current offset }
    Position := PosEx(',', str, Offset);
    if Position > 0 then
    begin
      if (Position - Offset) >= 2 then
      begin
        Buffer[Result] := MidStr(str, Offset, Position - Offset);
        Result    := Result + 1;
      end;
      Position  := Position + 1;
      Offset    := Position;
    end
    else
    if (Position = 0) and (Offset < Length(str)) then
    begin
      Buffer[Result] := MidStr(str, Offset, Length(str) - Offset + 1);
      Result := Result + 1;
    end;
  until (Position = 0) or (Position >= Length(str));

  if Result > 0 then
  begin
    SetLength(va, Result);
    for i := 0 to Result - 1 do
      va[i] := Buffer[i];
  end;
end;

function DateTime(MilliSeconds: Boolean): TDateTime;
begin
  Result := Now;
  if (not MilliSeconds) then
    Result :=
      EncodeDateTime(
        YearOf(Result), MonthOf(Result), DayOf(Result),
        HourOf(Result), MinuteOf(Result), SecondOf(Result), 0);
end;

function SAR(Value: Integer; Bits: Byte): Integer;
asm
  MOV CL, Bits
  SAR Value, CL
end;

function SAR(Value: Byte; Bits: Byte): Byte;
asm
  MOV CL, Bits
  SAR Value, CL
end;

procedure SafeFree(var AObject);
var
  Temp: TObject;
begin
  Temp := TObject(AObject);
  if (Temp = nil) then Exit;
  Pointer(AObject) := nil;
  Temp.Free;
end;

function SplitString(AString, ASeparator: string): TStringDynArray;
var
  ANewPos, AOldPos: Integer;
  ALen: Integer;
begin
  if(( AString = '' ) or ( ASeparator = '' )) then Exit;
  SetLength(Result, 0);
  AOldPos := 1;
  ALen := Length( AString );
  ANewPos := PosEx( ASeparator, AString, AOldPos );
  while(( ANewPos > 0 ) and ( ANewPos < ALen )) do
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := MidStr( AString, AOldPos, ANewPos - AOldPos );
    AOldPos := ANewPos + Length( ASeparator );
    ANewPos := PosEx( ASeparator, AString, AOldPos );
  end;
end;

function StripExtension(AFileName: string): string;
var
  AExt: string;
begin
  AExt := ExtractFileExt(AFileName);
  if AExt = '' then Exit(AFileName);

  Result := LeftStr(AFileName, Length(AFileName) - Length(AExt));
end;

function GetDelimetedStr(AString: string; AIndex: Integer; ADelimeter: string): string;
var
  ANewPos, AOldPos: Integer;
  ALen: Integer;
begin
  if ((AString = '') or (ADelimeter = '')) then Exit;

  AOldPos := 1;
  ALen := Length(AString);

  ANewPos := PosEx(ADelimeter, AString, AOldPos);
  while ((ANewPos > 0) and (ANewPos < ALen)) do
  begin
    Result := MidStr( AString, AOldPos, ANewPos - AOldPos);
    if (AIndex = 0) then Exit;
    Dec(AIndex);
    AOldPos := ANewPos + Length(ADelimeter);
    ANewPos := PosEx(ADelimeter, AString, AOldPos );
  end;
end;

function Limit(const AValue, AMin, AMax: Double): Double;
begin
  Result := AValue;
  if (Result < AMin) then
    Result := AMin
  else
  if (Result > AMax) then
    Result := AMax;
end;

function SafeInc(ACounter, ALimit: Integer): Integer;
begin
  Result := 0;
end;

procedure IncMod(var AValue: Integer; AModN: Integer);
begin
  AValue := (AValue + 1) and (Integer(AValue = AModN - 1) - 1);
end;

procedure DecMod(var AValue: Integer; AModN: Integer);
begin
  AValue := (AValue - 1) and (Integer(AValue = 0) - 1) or Integer(AModN - 1) and (Integer(AValue <> 0) - 1);
end;

function AddMod(const AValue: Integer; AModN: Integer): Integer;
begin
  Result := AValue;
  IncMod(Result, AModN);
end;

function Saturate(const AColor: TColor; AFactor: Double): TColor;
var
    ARGB: LongInt;
begin
    ARGB := ColorToRGB(AColor);
    AFactor := 1 + AFactor;
    Result := TColor(RGB(
        Round(GetRValue(ARGB) * AFactor),
        Round(GetGValue(ARGB) * AFactor),
        Round(GetBValue(ARGB) * AFactor)
    ));
end;

function Saturate(const AColor1, AColor2: TColor; AIntensity: Double): TColor;
var
  ARGB1, ARGB2: LongInt;
begin
  ARGB1 := ColorToRGB(AColor1);
  ARGB2 := ColorToRGB(AColor2);

  AIntensity := Limit(AIntensity, 0, 1);

  Result := TColor(RGB(
    Round(Limit(GetRValue(ARGB1) + (GetRValue(ARGB2) - GetRValue(ARGB1)) * AIntensity, 0, 255)),
    Round(Limit(GetGValue(ARGB1) + (GetGValue(ARGB2) - GetGValue(ARGB1)) * AIntensity, 0, 255)),
    Round(Limit(GetBValue(ARGB1) + (GetBValue(ARGB2) - GetBValue(ARGB1)) * AIntensity, 0, 255))
  ));
end;

function SubMod(const AValue: Integer; AModN: Integer): Integer;
begin
  Result := AValue;
  DecMod(Result, AModN);
end;

function VarToInt(AValue: Variant): Integer;
begin
  if (VarIsNull(AValue)) then Exit(0);

  if (VarIsNumeric(AValue)) then
    Result := Integer(AValue)
  else
  if (VarIsStr(AValue)) then
    Result := StrToInt(AValue)
  else
    Result := 0;
end;

function VarToDate(AValue: Variant): TDateTime;
begin
  if VarIsNull(AValue) then Exit(0);
  try
    Result := VarToDateTime(AValue);
  except
    Result := -693594;
  end;
end;

function VarArrayToDelimetedStr(AValue: Variant; ASeparator: string): string;
var
  i, n: Integer;
begin
  // Prüft, ob ein einzelner Variant oder ein dimensioniertes VarArray übermittelt wurde. Falls es
  // ein Array ist, wird jeder einzelne Wert mit Komma getrennt als String zurückgegeben

  n := VarArrayDimCount(AValue);

  if (n = 0) then
    Result := VarToStr(AValue)
  else
  begin
    for i := VarArrayLowBound(AValue, 1) to VarArrayHighBound(AValue, 1) do
    begin
      if (i > 0) then
        Result := Result + ASeparator + ' ';
      Result := Result + VarToStr(AValue[i]);
    end;
  end;
end;

function VarToFloat(AValue: Variant): Double;
begin
  try
    Result := AValue;
  except
    Result := 0;
  end;
end;

function dxVarToDate(value: Variant): TDateTime;
var
  ADate: TDateTime;
begin
  ADate := Date();

  if VarIsNull(value) then
    result := EncodeDate(YearOf(ADate), MonthOf(ADate), DayOf(ADate))
  else
    result := VarToDateTime(Value);
end;

{===============================================================================================
  UTILITIES UNIT - WEIGHTED RESULT
-----------------------------------------------------------------------------------------------
  Based on a total weight (e.g. 30%) this function calculates a weighted result what would
  correspond to a portion 30% depending on what value will be submitted.
  (Example: Min = 10;  Max = 30;  Value = 12;  Weight = 40%;  Result = 40 / (30-10) * 12
===============================================================================================
}
function Weighted(Weight, MinValue, MaxValue, Value: Variant): Double;
var
  arange: double;
begin
  Result := 0;
  if( (VarIsNull(Value) and (MinValue < MaxValue)) or (Weight=0) ) then Exit;

  if MaxValue >= MinValue then
  begin
    arange := (MaxValue-MinValue+1);
    if( Value < MinValue ) then
      Result := 0
    else
    if( Value > MaxValue ) then
      Result := Weight
    else
      Result := ((Value-MinValue+1) / arange * (Weight/100) ) * 100;
  end
  else
  begin
    arange := (MinValue-MaxValue+1);
    if( VarIsNull(Value) or (Value=0) or (Value > MinValue) ) then
      Result := 0
    else
    if( Value < MaxValue ) then
      Result := Weight
    else
      Result := ((2 - ((Value+MinValue-1) / arange)) * (Weight/100) ) * 100;
  end;
end;

end.
