program dpbp;

uses
  SysUtils,
  Classes,
  ProtBufParse in 'ProtBufParse.pas';

{$APPTYPE CONSOLE}
{$R *.res}

var
  p:TProtocolBufferParser;
  s,t,UnitName,Prefix,InputFN,OutputFN:string;
  i,l:integer;
  f:TFileStream;
begin
  try
    l:=ParamCount;
    if l=0 then
     begin
      writeln('dbpb: Delphi Protocol Buffer Parser');
      writeln('Usage:');
      writeln('  dbpb [-p<TypePrefix>] [-u<UnitName>] <inputfile> [<outputfile>]');
     end
    else
     begin
      //defaults
      Prefix:='T';
      UnitName:='';
      InputFN:='';
      OutputFN:='';
      i:=1;
      while (i<=l) do
       begin
        s:=ParamStr(i);
        inc(i);
        if (Length(s)>1) and (s[1]='-') then
         begin
          if (Length(s)=2) and (i<=l) then
           begin
            t:=ParamStr(i);
            inc(i);
           end
          else
            t:=Copy(s,3,Length(s)-2);
          case s[2] of
            'p','P':Prefix:=t;
            'u','U':UnitName:=t;
            //TODO: more flags
            else raise Exception.Create('Unknown option "'+s+'"'); 
          end;
         end
        else
         begin
          if InputFN='' then
           begin
            InputFN:=s;
            OutputFN:=ChangeFileExt(s,'.pas');
            if UnitName='' then UnitName:=ChangeFileExt(s,'');
           end
          else
           begin
            OutputFN:=s;
           end;
         end;
       end;

      p:=TProtocolBufferParser.Create(UnitName,Prefix);
      try

        //TODO: multiple input files
        writeln('Parsing '+InputFN);
        f:=TFileStream.Create(InputFN,fmOpenRead or fmShareDenyWrite);
        try
          l:=f.Size;
          SetLength(s,l);
          if f.Read(s[1],l)<>l then RaiseLastOSError;
        finally
          f.Free;
        end;
        p.Parse(s);

        writeln(IntToStr(p.DescriptorCount)+' descriptors');

        writeln('Writing '+OutputFN);
        s:=p.GenerateUnit;
        f:=TFileStream.Create(OutputFN,fmCreate);
        try
          f.Write(s[1],Length(s));
        finally
          f.Free;
        end;

      finally
        p.Free;
      end;
     end;
  except
    on e:Exception do
     begin
      writeln('### Abnormal termination ('+e.ClassName+')');
      writeln(e.Message);
     end;
  end;
end.
