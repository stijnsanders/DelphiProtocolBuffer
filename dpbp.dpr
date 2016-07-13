{

DelphiProtocolBuffer: dpbp.dpr

Copyright 2014-2016 Stijn Sanders
Made available under terms described in file "LICENSE"
https://github.com/stijnsanders/DelphiProtocolBuffer

}
program dpbp;

uses
  SysUtils,
  Classes,
  ProtBufParse in 'ProtBufParse.pas',
  SelfVersion in 'SelfVersion.pas';

{$APPTYPE CONSOLE}
{$R *.res}

var
  p:TProtocolBufferParser;
  s,t,InputFN,OutputFN,RelPath:string;
  i,j,l,l1:integer;
  f:TFileStream;
  fv:TProtocolBufferParserValue;
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
      fv:=TProtocolBufferParserValue(0);
      while fv<>pbpv_Unknown do
       begin
        if ProtocolBufferParserValueDefaults[fv]<>'' then
          writeln('    [-'+ProtocolBufferParserValueName[fv]+'] (default:"'+
            ProtocolBufferParserValueDefaults[fv]+'")')
        else
          writeln('    [-'+ProtocolBufferParserValueName[fv]+']');
        inc(fv);
       end;
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
      p:=TProtocolBufferParser.Create;
      try
        InputFN:='';
        OutputFN:='';
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
            if s[2] in ['f','F'] then
             begin
              //flags
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
             end
            else
             begin
              //values
              fv:=TProtocolBufferParserValue(0);
              while (fv<>pbpv_Unknown) and
                (s[2]<>ProtocolBufferParserValueName[fv][1]) do inc(fv);
              if fv=pbpv_Unknown then
                raise Exception.Create('Unknown option "'+s+'"')
              else
                p.Values[fv]:=t;
             end;
           end
          else
           begin
            if InputFN='' then
             begin
              InputFN:=s;
              OutputFN:=ChangeFileExt(s,'.pas');
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

        //TODO: multiple input files
        writeln('Parsing '+InputFN);
        p.Parse(InputFN);

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
