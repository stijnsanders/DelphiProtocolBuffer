object frmProtBufViewMain: TfrmProtBufViewMain
  Left = 192
  Top = 139
  Width = 573
  Height = 437
  Caption = 'Protocol Buffer Viewer'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = MainMenu1
  OldCreateOrder = False
  Position = poDefault
  OnResize = FormResize
  PixelsPerInch = 96
  TextHeight = 13
  object Splitter1: TSplitter
    Left = 233
    Top = 22
    Width = 4
    Height = 357
  end
  object tvFields: TTreeView
    Left = 0
    Top = 22
    Width = 233
    Height = 357
    Align = alLeft
    HideSelection = False
    Indent = 19
    TabOrder = 0
    OnChange = tvFieldsChange
    OnDeletion = tvFieldsDeletion
    OnExpanding = tvFieldsExpanding
  end
  object txtValue: TMemo
    Left = 237
    Top = 22
    Width = 320
    Height = 357
    Align = alClient
    HideSelection = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 557
    Height = 22
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 2
    object cbMessages: TComboBox
      Left = 0
      Top = 0
      Width = 153
      Height = 21
      Style = csDropDownList
      DropDownCount = 32
      ItemHeight = 13
      TabOrder = 0
      OnChange = cbMessagesChange
    end
  end
  object MainMenu1: TMainMenu
    Left = 8
    Top = 40
    object File1: TMenuItem
      Caption = '&File'
      object Openproto1: TMenuItem
        Caption = 'Open &proto...'
        OnClick = Openproto1Click
      end
      object Open1: TMenuItem
        Caption = 'Open &data...'
        OnClick = Open1Click
      end
      object N1: TMenuItem
        Caption = '-'
      end
      object Exit1: TMenuItem
        Caption = 'E&xit'
        OnClick = Exit1Click
      end
    end
  end
  object odBuffer: TOpenDialog
    DefaultExt = '.bin'
    Filter = 'Binary files (*.bin)|*.bin|All files (*.*)|*.*'
    Left = 8
    Top = 104
  end
  object odProto: TOpenDialog
    DefaultExt = '.proto'
    Filter = 
      'Protocol Buffer Declaration (*.proto)|*.proto|All files (*.*)|*.' +
      '*'
    Left = 8
    Top = 72
  end
end
