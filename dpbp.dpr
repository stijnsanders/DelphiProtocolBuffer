program dpbp;

uses
  SysUtils,
  Classes,
  ProtBufParse in 'ProtBufParse.pas';

{$APPTYPE CONSOLE}
{$R *.res}

var
  p:TProtocolBufferParser;
  s,t,UnitName,Prefix,InputFN,OutputFN,RelPath:string;
  i,j,l,l1:integer;
  f:TFileStream;
  ff:TProtocolBufferParserFlag;
  Flags:TProtocolBufferParserFlags;
begin
  try
    l:=ParamCount;
    if l=0 then
     begin
      writeln('dbpb: Delphi Protocol Buffer Parser');
      writeln('Usage:');
      writeln('  dbpb');
      writeln('    [-p<TypePrefix>]');
      writeln('    [-u<UnitName>]');
      writeln('    [-i<ImportPath>]');
      writeln('    [-f<Flags>]');
      writeln('    <inputfile>');
      writeln('    [<outputfile>]');
      writeln('Flags:');
      ff:=TProtocolBufferParserFlag(0);
      while ff<>pbpf_Unknown do
       begin
        writeln('  '+ProtocolBufferParserFlagName[ff]);
        inc(ff);
       end;
     end
    else
     begin
      //defaults
      Prefix:='T';
      UnitName:='';
      InputFN:='';
      OutputFN:='';
      RelPath:='';
      Flags:=[];
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
            'i','I':RelPath:=t;
            'f','F':
             begin
              l1:=Length(t);
              j:=1;
              while (j<l1) do
               begin
                ff:=TProtocolBufferParserFlag(0);
                while (ff<>pbpf_Unknown) and (t[j]+t[j+1]<>
                  Copy(ProtocolBufferParserFlagName[ff],1,2)) do inc(ff);
                if ff=pbpf_Unknown then
                  raise Exception.Create('Unknown flag "'+Copy(t,j,2)+'"')
                else
                  Include(Flags,ff);
                inc(j,2);
               end;
              if j=l1 then
                raise Exception.Create('Incomplete flag "'+t[j]+'"');
             end;
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
            if UnitName='' then
              UnitName:=ChangeFileExt(ExtractFileName(s),'');
           end
          else
           begin
            OutputFN:=s;
           end;
         end;
       end;

      if RelPath='' then
        RelPath:=ExtractFilePath(InputFN)
      else
        RelPath:=IncludeTrailingPathDelimiter(RelPath);

      p:=TProtocolBufferParser.Create(UnitName,Prefix);
      try

        //TODO: multiple input files
        writeln('Parsing '+InputFN);
        p.Parse(InputFN,RelPath);

        writeln(IntToStr(p.DescriptorCount)+' descriptors');

        writeln('Writing '+OutputFN);
        s:=p.GenerateUnit(Flags);
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
