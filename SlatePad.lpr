program SlatePad;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  SimpleIPC,
  Forms, SysUtils, f_MainForm, o_Docs, Tripous, o_App, o_AppSettings,
  o_PageHandler, o_Consts, o_Highlighters, o_TextEditor, o_FindAndReplace,
  o_FindAndReplaceInFiles, f_FindAndReplaceInFilesDialog, f_AppSettingsDialog,
  f_PageForm, f_TextEditorForm, o_Filer, o_DocMonitor, f_DocActionDialog
  { you can add units after this };

{$R *.res}

var
  Client: TSimpleIPCClient;
  FilePath: string;

begin
  {$IFDEF CHECK_MEMORY_LEAKS}
  // Assuming your build mode sets -dDEBUG in Project Options/Other when defining -gh
  // This avoids interference when running a production/default build without -gh

  // Set up -gh output for the Leakview package:
  if FileExists('heap.trc') then
    DeleteFile('heap.trc');

    SetHeapTraceOutput('heap.trc');
  {$ENDIF}

  if ParamCount > 0 then
    FilePath := ExpandFileName(ParamStr(1))
  else
    FilePath := '';

  Client := TSimpleIPCClient.Create(nil);
  try
    Client.ServerID := App.GetSimpleIpcServerName();

    if Client.ServerRunning then
    begin
      if (FilePath <> '') and FileExists(FilePath) then
      begin
        Client.Connect;
        try
          Client.SendStringMessage(FilePath);
        finally
          Client.Disconnect;
        end;
      end;
      Halt;
      Exit;
    end;
  finally
    Client.Free;
  end;

  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

