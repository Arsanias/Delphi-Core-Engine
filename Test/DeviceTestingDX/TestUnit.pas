// Copyright (c) 2021 Arsanias (arsaniasbb@gmail.com)
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  TestUnit;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes, System.Math,
  Vcl.Graphics, Vcl.StdCtrls, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.Menus,
  Core.Types, Core.Utils, Core.Mesh, Core.Model, Core.Geometry, Core.RenderDevice,
  Core.RenderDeviceDX, Core.Camera, Core.Light, Core.Cast;

type
  TTestWnd = class(TForm)
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    FDevice: TRenderDevice;
    FCast: TCast;
    FModel: TModel;
    FCamera: TCamera;
    FLight:  TLight;
    procedure DeviceRender;
    procedure DeviceResize;
  end;

var
  TestWnd: TTestWnd;

implementation
  {$R *.dfm}

procedure TTestWnd.FormDestroy(Sender: TObject);
begin
  Timer1.Enabled := False;

  SafeFree(FDevice);
  SafeFree(FLight);
  SafeFree(FCamera);
  SafeFree(FCast);
end;

procedure TTestWnd.FormShow(Sender: TObject);
begin
  try
    FDevice := TRenderDeviceDX.Create(True, Self.Handle, TestWnd.ClientRect);

    { Create Camera and set light }

    FCamera := TCamera.Create;
    FLight := TLight.Create;

    FLight.Intensity := 0.5;
    FLight.Direction := TVector3.Create(0.6, 0.3, -0.1);

    FDevice.MainConst.FLightDir := TVector4.Create(FLight.Direction);
    FDevice.MainConst.FCameraPos := TVector4.Create(FCamera.Position);

    { create cube }

    FModel := TModel.Create(True);
    TGeometry.InitObject(FModel, stCube, TVector3.Create(2.0, 2.0, 2.0), 1);
    FCast := TCast.Create(FModel);

    FCast.Prepare(FDevice);

    DeviceRender;

    Timer1.Enabled := True;
  except

  end;
end;

procedure TTestWnd.Timer1Timer(Sender: TObject);
var
  ARotation: TVector3;
begin
  ARotation := FCast.Rotation;
  ARotation.Y := ARotation.Y + 0.01;
  FCast.Rotation := ARotation;

  DeviceRender;
end;

procedure TTestWnd.FormPaint(Sender: TObject);
begin
  DeviceRender;
end;

procedure TTestWnd.FormResize(Sender: TObject);
begin
  DeviceResize;
end;

procedure TTestWnd.FormCreate(Sender: TObject);
begin
  FCast   := nil;
  FDevice := nil;
  FCamera := nil;
  FModel := nil;
  FLight  := nil;
end;

procedure TTestWnd.DeviceRender;
begin
  if (FDevice = nil) then Exit;

  FDevice.ClearScene;
  FCast.Render(FDevice, FCamera);
  FDevice.Show;
end;

procedure TTestWnd.DeviceResize;
begin
  if (FDevice = nil) then Exit;
  FDevice.ViewRect := TestWnd.ClientRect;
  DeviceRender;
end;

end.
