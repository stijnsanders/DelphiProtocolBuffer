unit pbv1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Menus, ComCtrls, ExtCtrls, StdCtrls, ProtBufParse;

type
  TfrmProtBufViewMain = class(TForm)
    tvFields: TTreeView;
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    Open1: TMenuItem;
    N1: TMenuItem;
    Exit1: TMenuItem;
    odBuffer: TOpenDialog;
    txtValue: TMemo;
    Splitter1: TSplitter;
    Openproto1: TMenuItem;
    Panel1: TPanel;
    cbMessages: TComboBox;
    odProto: TOpenDialog;
    procedure Exit1Click(Sender: TObject);
    procedure Open1Click(Sender: TObject);
    procedure tvFieldsDeletion(Sender: TObject; Node: TTreeNode);
    procedure tvFieldsChange(Sender: TObject; Node: TTreeNode);
    procedure tvFieldsExpanding(Sender: TObject; Node: TTreeNode;
      var AllowExpansion: Boolean);
    procedure FormResize(Sender: TObject);
    procedure Openproto1Click(Sender: TObject);
    procedure cbMessagesChange(Sender: TObject);
  private
    FDataFile,FProtoFile:string;
    FData:TStream;
    FProto:TProtocolBufferParser;
    procedure LoadFile(const FilePath:string);
    procedure LoadProto(const FilePath:string);
    procedure LoadFields(pos, max: int64; parent: TTreeNode;
      desc: TProtBufMessageDescriptor);
  protected
    procedure DoCreate; override;
    procedure DoDestroy; override;
  end;

  TNodeData=class(TObject)
  public
    procedure Node(n:TTreeNode); virtual;
    function Display: string; virtual; abstract;
  end;

  TMessageNodeData=class(TNodeData)
  private
    FTitle,FMessage:string;
  public
    constructor Create(const Title, Msg: string);
    procedure Node(n:TTreeNode); override;
    function Display: string; override;
  end;

  TErrorNodeData=class(TNodeData)
  private
    FMessage:string;
  public
    constructor Create(const Msg: string);
    procedure Node(n:TTreeNode); override;
    function Display: string; override;
  end;

  TNumberNodeData=class(TNodeData)
  private
    FValue:int64;
  public
    constructor Create(Value: int64);
    procedure Node(n:TTreeNode); override;
    function Display: string; override;
  end;

  TFixed64=array[0..7] of byte;
  TFixed32=array[0..3] of byte;

  TFixed64NodeData=class(TNodeData)
  private
    FValue:TFixed64;
  public
    constructor Create(const Value:TFixed64);
    procedure Node(n:TTreeNode); override;
    function Display: string; override;
  end;

  TFixed32NodeData=class(TNodeData)
  private
    FValue:TFixed32;
  public
    constructor Create(const Value:TFixed32);
    procedure Node(n:TTreeNode); override;
    function Display: string; override;
  end;

  TByLengthNodeData=class(TNodeData)
  private
    FData:TStream;
    FPos,FLen:int64;
  public
    constructor Create(Data:TStream;Pos,Len:int64);
    procedure Node(n:TTreeNode); override;
    function Display: string; override;
    property Pos: int64 read FPos;
    property Len: int64 read FLen;
  end;

  TStringNodeData=class(TNodeData)
  private
    FData:TStream;
    FPos,FLen:int64;
    FValue:string;
  public
    constructor Create(Data:TStream;Pos,Len:int64);
    procedure Node(n:TTreeNode); override;
    function Display: string; override;
  end;

  TEmbeddedMsgNodeData=class(TNodeData)
  private
    FName:string;
    FPos,FLen:int64;
    FDesc:TProtBufMessageDescriptor;
  public
    constructor Create(const Name: string; Pos, Len: int64;
      Desc: TProtBufMessageDescriptor);
    procedure Node(n:TTreeNode); override;
    function Display: string; override;
    property Pos: int64 read FPos;
    property Len: int64 read FLen;
    property Desc:TProtBufMessageDescriptor read FDesc;
  end;

var
  frmProtBufViewMain: TfrmProtBufViewMain;

implementation

{$R *.dfm}

{ TfrmProtBufViewMain }

procedure TfrmProtBufViewMain.DoCreate;
var
  i:integer;
  fn:string;
begin
  inherited;
  FDataFile:='';
  FData:=nil;
  FProtoFile:='';
  FProto:=TProtocolBufferParser.Create;
  case ParamCount of
    1:
     begin
      fn:=ParamStr(1);
      i:=Length(fn);
      while (i<>0) and (fn[i]<>'.') do dec(i);
      if LowerCase(Copy(fn,i,Length(fn)-i+1))='.proto' then
        LoadProto(fn)
      else
        LoadFile(fn);
     end;
    2:
     begin
      LoadProto(ParamStr(1));
      cbMessages.ItemIndex:=0;//?
      LoadFile(ParamStr(2));
     end;
    3:
     begin
      LoadProto(ParamStr(1));
      cbMessages.ItemIndex:=cbMessages.Items.IndexOf(ParamStr(2));//?
      LoadFile(ParamStr(3));
     end;
    //else?
  end;
end;

procedure TfrmProtBufViewMain.DoDestroy;
begin
  inherited;
  FProto.Free;
  FreeAndNil(FData);
end;

procedure TfrmProtBufViewMain.Exit1Click(Sender: TObject);
begin
  Close;
end;

procedure TfrmProtBufViewMain.Open1Click(Sender: TObject);
begin
  if odBuffer.Execute then LoadFile(odBuffer.FileName);
end;

procedure TfrmProtBufViewMain.tvFieldsDeletion(Sender: TObject;
  Node: TTreeNode);
begin
  TTreeNode(Node.Data).Free;
end;

procedure TfrmProtBufViewMain.LoadFile(const FilePath: string);
var
  f:TFileStream;
  m:TProtBufMessageDescriptor;
begin
  FreeAndNil(FData);
  FDataFile:=FilePath;
  if FProtoFile='' then
    Caption:=FDataFile+' - Protocol Buffer Viewer'
  else
    Caption:=ExtractFileName(FDataFile)+' - '+ExtractFileName(FProtoFile)+
      ' - Protocol Buffer Viewer';
  Application.Title:=Caption;
  f:=TFileStream.Create(FilePath,fmOpenRead or fmShareDenyWrite);
  if f.Size>$100000 then FData:=f else
   begin
    FData:=TMemoryStream.Create;
    FData.CopyFrom(f,f.Size);
    f.Free;
   end;
  if cbMessages.ItemIndex=-1 then m:=nil else
    m:=cbMessages.Items.Objects[cbMessages.ItemIndex]
      as TProtBufMessageDescriptor;
  LoadFields(0,FData.Size,nil,m);
end;

function _ReadVarInt(Stream: TStream; var Value: cardinal): boolean; overload;
var
  b:byte;
  i,l:integer;
begin
  b:=0;//default
  i:=0;
  l:=Stream.Read(b,1);
  Value:=b and $7F;
  while (l<>0) and ((b and $80)<>0) do
   begin
    l:=Stream.Read(b,1);
    inc(i,7);
    Value:=Value or ((b and $7F) shl i);
   end;
  Result:=l<>0;
end;

function _ReadVarInt(Stream: TStream; var Value: int64): boolean; overload;
var
  b:byte;
  i,l:integer;
begin
  b:=0;//default
  i:=0;
  l:=Stream.Read(b,1);
  Value:=b and $7F;
  while (l<>0) and ((b and $80)<>0) do
   begin
    l:=Stream.Read(b,1);
    inc(i,7);
    Value:=Value or ((b and $7F) shl i);
   end;
  Result:=l<>0;
end;

function _UnZigZag(x:int64):int64; overload;
begin
  if (x and 1)=0 then Result:=x shr 1 else Result:=-((x+1) shr 1);
end;

function _UnZigZag(x:integer):integer; overload;
begin
  if (x and 1)=0 then Result:=x shr 1 else Result:=-((x+1) shr 1);
end;

procedure TfrmProtBufViewMain.LoadFields(pos, max: int64; parent: TTreeNode;
  desc: TProtBufMessageDescriptor);
var
  n:TTreeNode;
  i,d:int64;
  d64:TFixed64 absolute d;
  d32:TFixed32 absolute d;
  dF64:double absolute d;
  dF32:single absolute d;
  FieldName,FieldType:string;
  Quant,TypeNr:integer;
  m:TProtBufMessageDescriptor;
  procedure Msg(const Title,Msg:string);
  begin
    TMessageNodeData.Create(Title,Msg).Node(n);
  end;
begin
  FData.Position:=pos;
  tvFields.Items.BeginUpdate;
  try
    if parent=nil then tvFields.Items.Clear;
    while (FData.Position<max) and _ReadVarInt(FData,i) do
     begin
      if (desc=nil) or not(desc.MemberByKey(i shr 3,
        FieldName,FieldType,Quant,TypeNr)) then
       begin
        FieldName:=IntToStr(i shr 3);
        FieldType:='';
        Quant:=0;
        TypeNr:=0;
       end;
      n:=tvFields.Items.AddChild(parent,FieldName+': ');
      //n.Data:=
      case i and $7 of
        0://varint
          if _ReadVarInt(FData,d) then
            case TypeNr of
              TypeNr_int32:
                Msg(IntToStr(_UnZigZag(d)),'int32'#13#10+IntToStr(_UnZigZag(d)));
              TypeNr_int64:
                Msg(IntToStr(_UnZigZag(d)),'int64'#13#10+IntToStr(_UnZigZag(d)));
              TypeNr_uint32:
                Msg(IntToStr(d),'uint32'#13#10+IntToStr(d));
              TypeNr_uint64:
                Msg(IntToStr(d),'uint64'#13#10+IntToStr(d));
              TypeNr__typeByName://TypeNr_enum
               begin
                m:=FProto.MsgDescByName(desc,FieldType);
                if (m<>nil) and m.MemberByKey(d,
                  FieldName,FieldType,Quant,TypeNr) then
                  Msg(FieldName,
                    'enum '+FieldType+#13#10+IntToStr(d)+': '+FieldName)
                else
                  TNumberNodeData.Create(d).Node(n)
               end;
              TypeNr_bool:
                Msg(IntToStr(d),'bool'#13#10+IntToStr(d));
              else
                TNumberNodeData.Create(d).Node(n)
            end
          else
            TErrorNodeData.Create('read error').Node(n);
        1://fixed64
          if FData.Read(d64[0],8)=8 then
            case TypeNr of
              TypeNr_fixed64:
                Msg(IntToStr(d),'fixed64'#13#10+IntToStr(d));
              TypeNr_sfixed64:
                Msg(IntToStr(d),'sfixed64'#13#10+IntToStr(d));
              TypeNr_double:
                Msg(FloatToStr(dF64),'double'#13#10+FloatToStr(dF64));
              else
                TFixed64NodeData.Create(d64).Node(n);
            end
          else
            TErrorNodeData.Create('read error').Node(n);
        2://length delimited
          if _ReadVarInt(FData,d) then
           begin
            case TypeNr of
             TypeNr__typeByName://TypeNr_msg:
              begin
               m:=FProto.MsgDescByName(desc,FieldType);
               TEmbeddedMsgNodeData.Create(FieldType,FData.Position,d,m).Node(n);
              end;
             //TypeNr_bytes:;
             TypeNr_string:
               if d<$10000 then
                 TStringNodeData.Create(FData,FData.Position,d).Node(n)
               else
                 TByLengthNodeData.Create(FData,FData.Position,d).Node(n);
             else
               TByLengthNodeData.Create(FData,FData.Position,d).Node(n);
            end;
            FData.Seek(d,soFromCurrent);
           end
          else
            TErrorNodeData.Create('read error').Node(n);
        //3,4:raise Exception.Create('ProtBuf: groups are deprecated');
        5://fixed32
          if FData.Read(d32[0],8)=8 then
            case TypeNr of
              TypeNr_fixed32:
                Msg(IntToStr(d),'fixed32'#13#10+IntToStr(d));
              TypeNr_sfixed32:
                Msg(IntToStr(d),'sfixed32'#13#10+IntToStr(d));
              TypeNr_float:
                Msg(FloatToStr(dF32),'float'#13#10+FloatToStr(dF32));
              else
                TFixed32NodeData.Create(d32).Node(n);
            end
          else
            TErrorNodeData.Create('read error').Node(n);
        else
          TErrorNodeData.Create('Unknown wire type '+IntToHex(i,8)).Node(n);
      end;
     end;
  finally
    tvFields.Items.EndUpdate;
  end;
end;

procedure TfrmProtBufViewMain.tvFieldsChange(Sender: TObject;
  Node: TTreeNode);
begin
  if Node.Data=nil then txtValue.Text:='' else
    txtValue.Text:=TNodeData(Node.Data).Display;
end;

procedure TfrmProtBufViewMain.tvFieldsExpanding(Sender: TObject;
  Node: TTreeNode; var AllowExpansion: Boolean);
var
  d:TByLengthNodeData;
  e:TEmbeddedMsgNodeData;
begin
  if Node.HasChildren and (Node.Count=0) then
   begin
    Node.HasChildren:=false;
    if Node.Data<>nil then
     begin
      if TNodeData(Node.Data) is TByLengthNodeData then
       begin
        d:=TNodeData(Node.Data) as TByLengthNodeData;
        LoadFields(d.Pos,d.Pos+d.Len,Node,nil);
       end;
      if TNodeData(Node.Data) is TEmbeddedMsgNodeData then
       begin
        e:=TNodeData(Node.Data) as TEmbeddedMsgNodeData;
        LoadFields(e.Pos,e.Pos+e.Len,Node,e.Desc);
       end;
     end;
   end;
end;

procedure TfrmProtBufViewMain.FormResize(Sender: TObject);
begin
  cbMessages.Width:=Panel1.ClientWidth;
end;

procedure TfrmProtBufViewMain.Openproto1Click(Sender: TObject);
begin
  if odProto.Execute then
   begin
    LoadProto(odProto.FileName);
    cbMessages.ItemIndex:=0;
   end;
end;

procedure TfrmProtBufViewMain.LoadProto(const FilePath: string);
begin
  FProtoFile:=FilePath;
  if FDataFile='' then
    Caption:='('+FProtoFile+') - Protocol Buffer Viewer'
  else
    Caption:=ExtractFileName(FDataFile)+' - '+ExtractFileName(FProtoFile)+
      ' - Protocol Buffer Viewer';
  Application.Title:=Caption;
  FProto.Parse(FilePath);
  cbMessages.Items.BeginUpdate;
  try
    cbMessages.Items.Clear;
    FProto.ListDescriptors(cbMessages.Items);
  finally
    cbMessages.Items.EndUpdate;
  end;
end;

procedure TfrmProtBufViewMain.cbMessagesChange(Sender: TObject);
var
  m:TProtBufMessageDescriptor;
begin
  if FData<>nil then
   begin
    if cbMessages.ItemIndex=-1 then m:=nil else
      m:=cbMessages.Items.Objects[cbMessages.ItemIndex]
        as TProtBufMessageDescriptor;
    LoadFields(0,FData.Size,nil,m);//refresh
   end;
end;

{ TNodeData }

procedure TNodeData.Node(n: TTreeNode);
begin
  n.Data:=Self;
end;

{ TNumberNodeData }

constructor TNumberNodeData.Create(Value: int64);
begin
  inherited Create;
  FValue:=Value;
end;

function TNumberNodeData.Display: string;
begin
  Result:=Format('varint'#13#10'unsigned: %d'#13#10'signed: %d'#13#10'%.16x',
    [FValue,_UnZigZag(FValue),FValue]);
end;

procedure TNumberNodeData.Node(n: TTreeNode);
begin
  inherited;
  n.Text:=Format('%svarint %d %d',[n.Text,FValue,_UnZigZag(FValue)]);
end;

{ TErrorNodeData }

constructor TErrorNodeData.Create(const Msg: string);
begin
  inherited Create;
  FMessage:=Msg;
end;

function TErrorNodeData.Display: string;
begin
  Result:='!!!'#13#10+FMessage;
end;

procedure TErrorNodeData.Node(n: TTreeNode);
begin
  inherited;
  n.Text:=n.Text+'!!! '+FMessage;
end;

{ TFixed64NodeData }

constructor TFixed64NodeData.Create(const Value: TFixed64);
begin
  inherited Create;
  FValue:=Value;
end;

function TFixed64NodeData.Display: string;
var
  d:TFixed64;
  d1:int64 absolute d;
  d2:double absolute d;
begin
  d:=FValue;
  Result:=Format('fixed64'#13#10'unsigned: %d'#13#10'signed: %d'#13#10+
    'float: %f'#13#10'%.2x %.2x %.2x %.2x %.2x %.2x %.2x %.2x',
    [d1,d1,d2,d[0],d[1],d[2],d[3],d[4],d[5],d[6],d[7]]);
end;

procedure TFixed64NodeData.Node(n: TTreeNode);
var
  d:TFixed64;
  d1:int64 absolute d;
  d2:double absolute d;
begin
  inherited;
  d:=FValue;
  n.Text:=Format('%sfixed64 %d %f',[n.Text,d1,d2]);
end;

{ TFixed32NodeData }

constructor TFixed32NodeData.Create(const Value: TFixed32);
begin
  inherited Create;
  FValue:=Value;
end;

function TFixed32NodeData.Display: string;
var
  d:TFixed32;
  d1:cardinal absolute d;
  d2:integer absolute d;
  d3:single absolute d;
begin
  d:=FValue;
  Result:=Format('fixed32'#13#10'unsigned: %d'#13#10'signed: %d'#13#10+
    'float: %f'#13#10'%.2x %.2x %.2x %.2x',
    [d1,d2,d3,d[0],d[1],d[2],d[3]]);
end;

procedure TFixed32NodeData.Node(n: TTreeNode);
var
  d:TFixed32;
  d1:integer absolute d;
  d2:double absolute d;
begin
  inherited;
  d:=FValue;
  n.Text:=Format('%sfixed32 %d %f',[n.Text,d1,d2]);
end;

{ TByLengthNodeData }

constructor TByLengthNodeData.Create(Data: TStream; Pos, Len: int64);
begin
  inherited Create;
  FData:=Data;
  FPos:=Pos;
  FLen:=Len;
end;

function TByLengthNodeData.Display: string;
var
  x:integer;
begin
  Result:=Format('@%d:%d'#13#10,[FPos,FLen]);
  if FLen<$10000 then
   begin
    x:=Length(Result);
    SetLength(Result,x+FLen);
    FData.Position:=FPos;
    FData.Read(Result[x+1],FLen);
   end;
  //TODO: 'double click to...';
end;

procedure TByLengthNodeData.Node(n: TTreeNode);
begin
  inherited;
  n.Text:=Format('%sbyLength @%d :%d',[n.Text,FPos,FLen]);
  n.HasChildren:=FLen<>0;
end;

{ TMessageNodeData }

constructor TMessageNodeData.Create(const Title, Msg: string);
begin
  inherited Create;
  FTitle:=Title;
  FMessage:=Msg;
end;

function TMessageNodeData.Display: string;
begin
  Result:=FMessage;
end;

procedure TMessageNodeData.Node(n: TTreeNode);
begin
  inherited;
  n.Text:=n.Text+FTitle;
end;

{ TStringNodeData }

constructor TStringNodeData.Create(Data: TStream; Pos, Len: int64);
begin
  inherited Create;
  FData:=Data;
  FPos:=Pos;
  FLen:=Len;
  FValue:='';//see Node
end;

function TStringNodeData.Display: string;
begin
  Result:=FValue;//more info?
end;

procedure TStringNodeData.Node(n: TTreeNode);
var
  p:int64;
begin
  inherited;
  SetLength(FValue,FLen);
  p:=FData.Position;
  if FData.Read(FValue[1],FLen)<>FLen then
    FValue:='!!! READ ERROR !!!';//raise?
  FData.Position:=p;
  n.Text:=Format('%s(%d)"%s"',[n.Text,FLen,
    StringReplace(FValue,'"','\"',[rfReplaceAll])]);
end;

{ TEmbeddedMsgNodeData }

constructor TEmbeddedMsgNodeData.Create(const Name: string; Pos, Len: int64;
  Desc: TProtBufMessageDescriptor);
begin
  inherited Create;
  FName:=Name;
  FPos:=Pos;
  FLen:=Len;
  FDesc:=Desc;
end;

function TEmbeddedMsgNodeData.Display: string;
begin
  Result:=FName;
end;

procedure TEmbeddedMsgNodeData.Node(n: TTreeNode);
begin
  inherited;
  n.Text:=n.Text+FName;
  n.HasChildren:=FLen<>0;
end;

end.
