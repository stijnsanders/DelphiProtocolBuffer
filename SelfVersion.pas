{

DelphiProtocolBuffer: SelfVersion.pas

Copyright 2014 Stijn Sanders
Made available under terms described in file "LICENSE"
https://github.com/stijnsanders/DelphiProtocolBuffer

}
unit SelfVersion;

interface

function GetSelfVersion: string;

implementation

uses SysUtils, Windows;

function GetSelfVersion: string;
var
  r:THandle;
  p:pointer;
  v:PVSFIXEDFILEINFO;
  vl:cardinal;
begin
  try
    r:=LoadResource(HInstance,
      FindResource(HInstance,MakeIntResource(1),RT_VERSION));
    p:=LockResource(r);
    if VerQueryValue(p,'\',pointer(v),vl) then
      Result:=Format('v%d.%d.%d.%d',
        [v.dwFileVersionMS shr 16
        ,v.dwFileVersionMS and $FFFF
        ,v.dwFileVersionLS shr 16
        ,v.dwFileVersionLS and $FFFF
        ]);
  except
    Result:='v???';
  end;
end;

end.
