// Copyright (c) 2021 Arsanias
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

unit
  unDeviceGLTest;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes, System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,
  Core.Types, Core.Utils, Core.Geometry, Core.Model, Core.Cast, Core.Camera, Core.Light,
  Core.RenderDevice, Core.RenderDeviceGL;

type
  TTestWnd = class( TForm )
    Timer1: TTimer;
    procedure FormDestroy( Sender: TObject );
    procedure FormCreate( Sender: TObject );
    procedure Form_Show( Sender: TObject );
    procedure Form_Resize( Sender: TObject );
    procedure Form_Paint( Sender: TObject );
    procedure Timer1Timer(Sender: TObject);
  private
    Device: TCoreGraphicsDeviceGL;
    Light: TLight;
    Camera: TCamera;
    Cast: TCast;
    Model: TModel;
    procedure RenderDevice;
    procedure ResizeDevice;
  end;

var
  TestWnd: TTestWnd;

implementation
  {$R *.dfm}

procedure TTestWnd.FormCreate(Sender: TObject);
begin
  Device := nil;
  Camera := nil;
  Light := nil;
  Model := nil;
  Cast := nil;
end;

procedure TTestWnd.Form_Show(Sender: TObject);
begin
  { create device }

  Device := TCoreGraphicsDeviceGL.Create(True, Self.Handle, TestWnd.ClientRect);

  { Create Camera and light }

  Camera := TCamera.Create;
  Light := TLight.Create;

  Device.MainConst.FLightDir := TVector4.Create(Light.Direction);
  Device.MainConst.FCameraPos := TVector4.Create(Camera.Position);

  { create cube }

  Model := TModel.Create('Cube', True);
  TGeometry.InitObject(Model, stCube, TVector3.Create( 2.0, 2.0, 2.0 ), 1);
  Cast := TCast.Create(Model, Model.Name );

  Cast.Prepare(Device);

  RenderDevice;

  Timer1.Enabled := True;
end;

procedure TTestWnd.Timer1Timer(Sender: TObject);
var
  ARotation: TVector3;
begin
  ARotation := Cast.Rotation;
  ARotation.Y := ARotation.Y + 0.01;
  Cast.Rotation := ARotation;

  RenderDevice;
end;

procedure TTestWnd.FormDestroy(Sender: TObject);
begin
  Timer1.Enabled := False;

  SafeFree(Cast);
  SafeFree(Model);
  SafeFree(Light);
  SafeFree(Camera);
  SafeFree(Device);
end;

procedure TTestWnd.Form_Resize(Sender: TObject);
begin
  ResizeDevice;
end;

procedure TTestWnd.Form_Paint(Sender: TObject);
begin
  RenderDevice;
end;

procedure TTestWnd.RenderDevice;
begin
  if (Device = nil) then Exit;

  Device.ClearScene;
  Cast.Render(Device, Camera);

  Device.Show;
end;

procedure TTestWnd.ResizeDevice;
begin
  if (Device = nil) then Exit;
  Device.ViewRect := TestWnd.ClientRect;
  RenderDevice;
end;

end.
