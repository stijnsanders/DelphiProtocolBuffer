program pbv;

uses
  Forms,
  pbv1 in 'pbv1.pas' {frmProtBufViewMain},
  ProtBufParse in '..\ProtBufParse.pas',
  SelfVersion in '..\SelfVersion.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmProtBufViewMain, frmProtBufViewMain);
  Application.Run;
end.
