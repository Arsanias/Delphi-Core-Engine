// Copyright (c) 2021 Arsanias
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

program
  DeviceTestingGL;

uses
  Forms,
  unDeviceGLTest in 'unDeviceGLTest.pas' {TestWnd};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TTestWnd, TestWnd);
  Application.Run;
end.
