program SlatePad;

{$mode objfpc}{$H+}

{$IFDEF CHECK_MEMORY_LEAKS}
  {$DEFINE DEBUG}
{$ENDIF}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  SysUtils, f_MainForm, o_Docs, Tripous, o_App, o_AppSettings,
  o_PageHandler, o_Consts, o_Highlighters, o_TextEditor, 
  o_FindAndReplace, o_FindAndReplaceInFiles, f_FindAndReplaceInFilesDialog,
  f_AppSettingsDialog, f_PageForm, f_TextEditorForm, o_Filer
  { you can add units after this };

{$R *.res}

begin
  {$IFDEF DEBUG}
  // Assuming your build mode sets -dDEBUG in Project Options/Other when defining -gh
  // This avoids interference when running a production/default build without -gh

  // Set up -gh output for the Leakview package:
  if FileExists('heap.trc') then
    DeleteFile('heap.trc');
  {$IFDEF CHECK_MEMORY_LEAKS}
    SetHeapTraceOutput('heap.trc');
  {$ENDIF}
  {$ENDIF DEBUG}

  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

