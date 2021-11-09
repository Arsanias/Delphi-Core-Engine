// Copyright (c) 2021 Arsanias (arsaniasbb@gmail.com)
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  Core.Light;

interface

uses
  System.Types,
  Core.Types;

type
  TLightType = (ltAmbiente, ltSpot, ltPoint);

  TLight = class
  private
    FName: string;
  public
    Direction: TVector3;
    Intensity: Single;
    LightType: TLightType;
    constructor Create;
  public
    property Name: string read FName write Fname;
  end;

implementation

constructor TLight.Create;
begin
  LightType := ltAmbiente;
  Intensity := 1.0;
  Direction := TVector3.Create(-0.25, -0.25, -0.75).Normalize;
end;

end.
