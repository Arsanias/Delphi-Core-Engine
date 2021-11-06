object TestWnd: TTestWnd
  Left = 0
  Top = 0
  Caption = 'Core Engine Device Testing DX'
  ClientHeight = 474
  ClientWidth = 845
  Color = clBtnFace
  Font.Charset = ANSI_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Arial'
  Font.Style = [fsBold]
  OldCreateOrder = False
  OnCreate = Form_Create
  OnDestroy = Form_Destroy
  OnPaint = Form_Paint
  OnResize = Form_Resize
  OnShow = Form_Show
  PixelsPerInch = 96
  TextHeight = 14
  object Timer1: TTimer
    Enabled = False
    Interval = 25
    OnTimer = Timer1Timer
    Left = 400
    Top = 192
  end
end
