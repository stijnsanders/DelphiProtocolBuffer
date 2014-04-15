{

DelphiProtocolBuffer ProtBuf.pas
    declares the TProtocolBufferMessage base class
    used by units generated by dpbp

Copyright 2014 Stijn Sanders
Made available under terms described in file "LICENSE"
https://github.com/stijnsanders/DelphiProtocolBuffer

}
unit ProtBuf;

{$D-}
{$L-}

interface

uses Classes;

type
  TProtocolBufferKey = 0..536870911;//cardinal, uint23

  TDynArrayOfBytes = array of byte;

  TProtocolBufferMessage=class(TObject)//,IStreamPersist)
  private
    FDidRead:boolean;
  protected
    procedure SetDefaultValues; virtual;
    procedure ReadVarInt(Stream: TStream; Key: TProtocolBufferKey); virtual;
    procedure ReadLengthDelim(Stream: TStream; Key: TProtocolBufferKey); virtual;
    procedure ReadFixed64(Stream: TStream; Key: TProtocolBufferKey); virtual;
    procedure ReadFixed32(Stream: TStream; Key: TProtocolBufferKey); virtual;
    procedure WriteFields(Stream: TStream); virtual;

    //use from LoadFromStream
    procedure ReadUint(Stream: TStream; var Value: cardinal); overload;
    procedure ReadUint(Stream: TStream; var Value: int64); overload;
    procedure ReadSint(Stream: TStream; var Value: integer); overload;
    procedure ReadSint(Stream: TStream; var Value: int64); overload;
    procedure ReadStr(Stream: TStream; var Value: string);
    procedure ReadBytes(Stream: TStream; var Value: TDynArrayOfBytes);
    function ReadBool(Stream: TStream): boolean;
    function ReadEnum(Stream: TStream): cardinal;
    procedure ReadMessage(Stream: TStream; Value: TProtocolBufferMessage);
    procedure ReadBlock(Stream: TSTream; var Data; Length: cardinal);

    //use from ReadValue
    procedure WriteSInt(Stream: TStream; Key: TProtocolBufferKey;
      Value: integer);
    procedure WriteUInt(Stream: TStream; Key: TProtocolBufferKey;
      Value: cardinal);
    procedure WriteSInt64(Stream: TStream; Key: TProtocolBufferKey;
      Value: int64);
    procedure WriteUInt64(Stream: TStream; Key: TProtocolBufferKey;
      Value: int64);
    procedure WriteSingle(Stream: TStream; Key: TProtocolBufferKey;
      Value: Single);
    procedure WriteDouble(Stream: TStream; Key: TProtocolBufferKey;
      Value: Double);
    procedure WriteStr(Stream: TStream; Key: TProtocolBufferKey;
      const Value: UTF8String); overload;
    procedure WriteStrA(Stream: TStream; Key: TProtocolBufferKey;
      const Value: AnsiString);
    procedure WriteStr(Stream: TStream; Key: TProtocolBufferKey;
      const Value: WideString); overload;
    procedure WriteMessage(Stream: TStream; Key: TProtocolBufferKey;
      Value: TProtocolBufferMessage);
    procedure WriteBlock(Stream: TStream; Key: TProtocolBufferKey;
      var Data; Length: cardinal);

  public
    constructor Create;

    procedure LoadFromStream(Stream: TStream; Length: int64);
    procedure SaveToStream(Stream: TStream);
  end;

implementation

uses SysUtils, Variants;

{ TProtocolBufferMessage }

constructor TProtocolBufferMessage.Create;
begin
  inherited;
  SetDefaultValues;
  //
end;

procedure _ReadError; //virtual? keep Stream reference?
begin
  raise Exception.Create('Error reading from stream');
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

procedure _WriteError; //virtual? keep Stream reference?
begin
  raise Exception.Create('Error writing to stream');
end;

procedure _WriteVarInt(Stream: TStream; x: cardinal); overload;
var
  i:cardinal;
  b:byte;
begin
  i:=0;
  repeat inc(i,7) until (1 shl i)>=x;
  while i<>0 do
   begin
    dec(i,7);
    b:=(x shr i) and $7F;
    if Stream.Write(b,1)<>1 then _WriteError;
   end;
end;

procedure _WriteVarInt(Stream: TStream; x: int64); overload;
var
  i:int64;
  b:byte;
begin
  i:=0;
  repeat inc(i,7) until (1 shl i)>=x;
  while i<>0 do
   begin
    dec(i,7);
    b:=(x shr i) and $7F;
    if Stream.Write(b,1)<>1 then _WriteError;
   end;
end;

procedure TProtocolBufferMessage.LoadFromStream(Stream: TStream;
  Length: int64);
var
  i:cardinal;
  k:TProtocolBufferKey;
  j,p:int64;
begin
  //TODO: use some byte buffer
  if Length=0 then
    p:=Stream.Size //raise? detect?
  else
    p:=Stream.Position+Length;
  //TODO: increase counter on (all!) reads instead of Stream.Position here
  while (Stream.Position<p) and _ReadVarInt(Stream,i) do
   begin
    k:=TProtocolBufferKey(i shr 3);
    FDidRead:=false;//see read methods
    case i and $7 of
      0://varint
       begin
        ReadVarInt(Stream,k);
        if not FDidRead then if not _ReadVarInt(Stream,j) then _ReadError;
       end;
      1://fixed64
       begin
        ReadFixed64(Stream,k);
        if not FDidRead then if Stream.Read(j,8)<>8 then _ReadError;
       end;
      2://length delimited
       begin
        ReadLengthDelim(Stream,k);
        if not FDidRead then
         begin
          if not _ReadVarInt(Stream,j) then _ReadError;
          Stream.Seek(j,soFromCurrent);
         end;
       end;
      3,4:raise Exception.Create('ProtBuf: groups are deprecated');
      5://fixed32
       begin
        ReadFixed32(Stream,k);
        if not FDidRead then if Stream.Read(j,4)<>4 then _ReadError;
       end;
      else
        raise Exception.Create('ProfBuf: unexpected wire type '+IntToHex(i,8));
    end;
   end;
end;

procedure TProtocolBufferMessage.SaveToStream(Stream: TStream);
begin
  WriteFields(Stream);
end;

procedure TProtocolBufferMessage.SetDefaultValues;
begin
  //implemented by inheriters
end;

procedure TProtocolBufferMessage.ReadFixed32(Stream: TStream;
  Key: TProtocolBufferKey);
begin
  //implemented by inheriters
end;

procedure TProtocolBufferMessage.ReadFixed64(Stream: TStream;
  Key: TProtocolBufferKey);
begin
  //implemented by inheriters
end;

procedure TProtocolBufferMessage.ReadLengthDelim(Stream: TStream;
  Key: TProtocolBufferKey);
begin
  //implemented by inheriters
end;

procedure TProtocolBufferMessage.ReadVarInt(Stream: TStream;
  Key: TProtocolBufferKey);
begin
  //implemented by inheriters
end;

procedure TProtocolBufferMessage.WriteFields(Stream: TStream);
begin
  //implemented by inheriters
end;

procedure TProtocolBufferMessage.WriteSInt(Stream: TStream;
  Key: TProtocolBufferKey; Value: integer);
begin
  _WriteVarInt(Stream,Key shl 3);//Key, 0
  if Value<0 then
    _WriteVarInt(Stream,cardinal(Value*-2-1))
  else
    _WriteVarInt(Stream,cardinal(Value*2));
end;

procedure TProtocolBufferMessage.WriteSInt64(Stream: TStream;
  Key: TProtocolBufferKey; Value: int64);
begin
  _WriteVarInt(Stream,Key shl 3);//Key, 0
  if Value<0 then
    _WriteVarInt(Stream,Value*-2-1)
  else
    _WriteVarInt(Stream,Value*2);
end;

procedure TProtocolBufferMessage.WriteUInt(Stream: TStream;
  Key: TProtocolBufferKey; Value: cardinal);
begin
  _WriteVarInt(Stream,Key shl 3);//Key, 0
  _WriteVarInt(Stream,Value);
end;

procedure TProtocolBufferMessage.WriteUInt64(Stream: TStream;
  Key: TProtocolBufferKey; Value: int64);
begin
  _WriteVarInt(Stream,Key shl 3);//Key, 0
  _WriteVarInt(Stream,Value);
end;

procedure TProtocolBufferMessage.WriteSingle(Stream: TStream;
  Key: TProtocolBufferKey; Value: Single);
begin
  _WriteVarInt(Stream,(Key shl 3) or 5);
  if Stream.Write(Value,4)<>4 then _WriteError;
end;

procedure TProtocolBufferMessage.WriteDouble(Stream: TStream;
  Key: TProtocolBufferKey; Value: Double);
begin
  _WriteVarInt(Stream,(Key shl 3) or 1);
  if Stream.Write(Value,8)<>8 then _WriteError;
end;

procedure TProtocolBufferMessage.WriteStr(Stream: TStream;
  Key: TProtocolBufferKey; const Value: UTF8String);
var
  l:cardinal;
begin
  l:=Length(Value);
  _WriteVarInt(Stream,(Key shl 3) or 2);
  _WriteVarInt(Stream,l);
  if l<>0 then
    if cardinal(Stream.Write(Value[1],l))<>l then _WriteError;
end;

procedure TProtocolBufferMessage.WriteStr(Stream: TStream;
  Key: TProtocolBufferKey; const Value: WideString);
var
  x:UTF8String;
  l:cardinal;
begin
  x:=UTF8Encode(Value);
  l:=Length(x);
  _WriteVarInt(Stream,(Key shl 3) or 2);
  _WriteVarInt(Stream,l);
  if l<>0 then
    if cardinal(Stream.Write(x[1],l))<>l then _WriteError;
end;

procedure TProtocolBufferMessage.WriteStrA(Stream: TStream;
  Key: TProtocolBufferKey; const Value: AnsiString);
var
  x:UTF8String;
  l:cardinal;
begin
  x:=AnsiToUtf8(Value);
  l:=Length(x);
  _WriteVarInt(Stream,(Key shl 3) or 2);
  _WriteVarInt(Stream,l);
  if l<>0 then
    if cardinal(Stream.Write(x[1],l))<>l then _WriteError;
end;

procedure TProtocolBufferMessage.WriteMessage(Stream: TStream;
  Key: TProtocolBufferKey; Value: TProtocolBufferMessage);
var
  m:TMemoryStream;
  l:cardinal;
begin
  _WriteVarInt(Stream,(Key shl 3) or 2);
  //TODO: find another way to write data first and a variable length prefix after
  m:=TMemoryStream.Create;
  try
    Value.SaveToStream(m);
    l:=m.Position;
    _WriteVarInt(Stream,l);
    m.Position:=0;
    if l<>0 then
      if cardinal(Stream.Write(m.Memory^,l))<>l then _WriteError;
  finally
    m.Free;
  end;
end;

procedure TProtocolBufferMessage.WriteBlock(Stream: TStream;
  Key: TProtocolBufferKey; var Data; Length: cardinal);
begin
  _WriteVarInt(Stream,(Key shl 3) or 2);
  if Length<>0 then
    if cardinal(Stream.Write(Data,Length))<>Length then _WriteError;
end;

procedure TProtocolBufferMessage.ReadBytes(Stream: TStream;
  var Value: TDynArrayOfBytes);
var
  l:cardinal;//int64?
begin
  if not _ReadVarInt(Stream,l) then _ReadError;
  SetLength(Value,l);
  if l<>0 then
    if cardinal(Stream.Read(Value[0],l))<>l then _ReadError;
  FDidRead:=true;
end;

procedure TProtocolBufferMessage.ReadStr(Stream: TStream; var Value: string);
var
  l:cardinal;//int64?
begin
  if not _ReadVarInt(Stream,l) then _ReadError;
  SetLength(Value,l);
  if l<>0 then
    if cardinal(Stream.Read(Value[1],l))<>l then _ReadError;
  FDidRead:=true;
end;

procedure TProtocolBufferMessage.ReadUint(Stream: TStream;
  var Value: cardinal);
begin
  if not _ReadVarInt(Stream,Value) then _ReadError;
  FDidRead:=true;
end;

procedure TProtocolBufferMessage.ReadUint(Stream: TStream;
  var Value: int64);
begin
  if not _ReadVarInt(Stream,Value) then _ReadError;
  FDidRead:=true;
end;

procedure TProtocolBufferMessage.ReadSint(Stream: TStream;
  var Value: int64);
begin
  if not _ReadVarInt(Stream,Value) then _ReadError;
  if (Value and 1)=0 then
    Value:=Value shr 1
  else
    Value:=-((Value+1) shr 1);
  FDidRead:=true;
end;

procedure TProtocolBufferMessage.ReadSint(Stream: TStream;
  var Value: integer);
begin
  if not _ReadVarInt(Stream,cardinal(Value)) then _ReadError;
  if (Value and 1)=0 then
    Value:=Value shr 1
  else
    Value:=-((Value+1) shr 1);
  FDidRead:=true;
end;

function TProtocolBufferMessage.ReadBool(Stream: TStream): boolean;
var
  i:cardinal;
begin
  if not _ReadVarInt(Stream,i) then _ReadError;
  FDidRead:=true;
  Result:=i<>0;
end;

function TProtocolBufferMessage.ReadEnum(Stream: TStream): cardinal;
begin
  if not _ReadVarInt(Stream,Result) then _ReadError;
  FDidRead:=true;
end;

procedure TProtocolBufferMessage.ReadMessage(Stream: TStream;
  Value: TProtocolBufferMessage);
var
  l:int64;
begin
  if not _ReadVarInt(Stream,l) then _ReadError;
  //p:=Stream.Position;
  Value.LoadFromStream(Stream,l);
  //if Stream.Position<>p+l then _ReadError;
  FDidRead:=true;
end;

procedure TProtocolBufferMessage.ReadBlock(Stream: TSTream; var Data;
  Length: cardinal);
begin
  if Length<>0 then
    if cardinal(Stream.Read(Data,Length))<>Length then _ReadError;
  FDidRead:=true;
end;

end.
