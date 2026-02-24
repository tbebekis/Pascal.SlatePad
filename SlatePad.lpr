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
  Forms, f_MainForm, o_Docs, Tripous, o_App, o_AppSettings, fr_FramePage,
  fr_EditorPage, o_PageHandler, o_Consts, o_Highlighters, o_TextEditor, 
o_FindAndReplace, o_FindAndReplaceInFiles, f_FindAndReplaceInFilesDialog
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

