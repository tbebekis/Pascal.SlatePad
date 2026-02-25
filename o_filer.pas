unit o_Filer;

{$mode delphi}
{$H+}

interface

uses
  Classes, SysUtils,
  LConvEncoding; // ConvertEncoding

type
  TEolKind = (eolUnknown, eolLF, eolCRLF, eolCR);

  TFileEncoding = (
    feUnknown,
    feANSI_Unknown,

    // Unicode families
    feUTF8,
    feUTF8_BOM,
    feUTF16LE_BOM,
    feUTF16BE_BOM,

    // Single-byte families (detected/forced)
    feCP1253,      // Greek (Windows)
    feISO8859_7,   // Greek (ISO)
    feCP1252,      // Western (Windows)
    feISO8859_1,   // Latin-1
    feCP1251,      // Cyrillic
    feKOI8R,       // Cyrillic
    feCP437,       // DOS US
    feCP850,       // DOS Western

    // everything else legacy/single-byte will land here
    feSingleByte_Detected
  );

  TFileReadInfo = record
    Encoding: TFileEncoding;
    EncodingName: string; // e.g. 'utf8', 'cp1253', 'iso8859-7'
    HadBOM: Boolean;
    Eol: TEolKind;
  end;

  { Filer }

  Filer = class
  strict private
    class function DetectEolFromBytes(const B: TBytes; AStart, ACount: Integer): TEolKind; static;
    class function IsValidUtf8(const B: TBytes; AStart, ACount: Integer): Boolean; static;

    class procedure BytesToUnicodeString_UTF16LE(const B: TBytes; AStart, ACount: Integer; out W: UnicodeString); static;
    class procedure BytesToUnicodeString_UTF16BE(const B: TBytes; AStart, ACount: Integer; out W: UnicodeString); static;

    class function EncToName(E: TFileEncoding): string; static;
    class function NameToEnc(const S: string): TFileEncoding; static;

    class function BytesToAnsiString(const B: TBytes; AStart, ACount: Integer): AnsiString; static;

    class function ScoreDecodedText(const S: string; const Orig: AnsiString; const EncName: string): Integer; static;
    class function DetectSingleByteEncoding(const Raw: AnsiString; out BestName: string; out BestEnc: TFileEncoding): Boolean; static;
  public
    class function EolToStr(E: TEolKind): string; static;
    class function EncodingToStr(E: TFileEncoding): string; static;
    class function EncodingDisplay(const Info: TFileReadInfo): string; static;

    // Reads file and returns Lazarus UTF-8 string.
    class function ReadTextFile(const FileName: string; out Info: TFileReadInfo): string; static;

    // Writes Lazarus UTF-8 string to disk. For UTF16* it writes BOM.
    // For feUTF8 it writes no BOM, for feUTF8_BOM it writes BOM.
    class procedure WriteTextFile(const FileName, Text: string; Encoding: TFileEncoding = feUTF8); static;
  end;

implementation

class function Filer.EolToStr(E: TEolKind): string;
begin
  case E of
    eolLF:   Result := 'LF';
    eolCRLF: Result := 'CRLF';
    eolCR:   Result := 'CR';
  else
    Result := '?';
  end;
end;

class function Filer.EncodingToStr(E: TFileEncoding): string;
begin
  case E of
    feUTF8:        Result := 'UTF-8';
    feUTF8_BOM:    Result := 'UTF-8 BOM';
    feUTF16LE_BOM: Result := 'UTF-16 LE';
    feUTF16BE_BOM: Result := 'UTF-16 BE';

    feCP1253:      Result := 'CP1253';
    feISO8859_7:   Result := 'ISO-8859-7';
    feCP1252:      Result := 'CP1252';
    feISO8859_1:   Result := 'ISO-8859-1';
    feCP1251:      Result := 'CP1251';
    feKOI8R:       Result := 'KOI8-R';
    feCP437:       Result := 'CP437';
    feCP850:       Result := 'CP850';

    feANSI_Unknown:        Result := 'ANSI';
    feSingleByte_Detected: Result := 'SINGLE-BYTE';
  else
    Result := '?';
  end;
end;

class function Filer.EncodingDisplay(const Info: TFileReadInfo): string;
begin
  if Info.EncodingName <> '' then
    Result := UpperCase(Info.EncodingName)
  else
    Result := Filer.EncodingToStr(Info.Encoding);
end;

class function Filer.EncToName(E: TFileEncoding): string;
begin
  // Names as expected by LConvEncoding.ConvertEncoding
  case E of
    feUTF8, feUTF8_BOM: Result := 'utf8';
    feUTF16LE_BOM:      Result := 'utf16le';
    feUTF16BE_BOM:      Result := 'utf16be';

    feCP1253:      Result := 'cp1253';
    feISO8859_7:   Result := 'iso8859-7';
    feCP1252:      Result := 'cp1252';
    feISO8859_1:   Result := 'iso8859-1';
    feCP1251:      Result := 'cp1251';
    feKOI8R:       Result := 'koi8-r';
    feCP437:       Result := 'cp437';
    feCP850:       Result := 'cp850';
  else
    Result := '';
  end;
end;

class function Filer.NameToEnc(const S: string): TFileEncoding;
var
  T: string;
begin
  T := LowerCase(Trim(S));
  if (T='utf8') then Exit(feUTF8);
  if (T='utf16le') then Exit(feUTF16LE_BOM);
  if (T='utf16be') then Exit(feUTF16BE_BOM);

  if (T='cp1253') then Exit(feCP1253);
  if (T='iso8859-7') then Exit(feISO8859_7);
  if (T='cp1252') then Exit(feCP1252);
  if (T='iso8859-1') then Exit(feISO8859_1);
  if (T='cp1251') then Exit(feCP1251);
  if (T='koi8-r') then Exit(feKOI8R);
  if (T='cp437') then Exit(feCP437);
  if (T='cp850') then Exit(feCP850);

  // οτιδήποτε άλλο single-byte το κρατάμε ως “detected”
  Result := feSingleByte_Detected;
end;

class function Filer.BytesToAnsiString(const B: TBytes; AStart, ACount: Integer): AnsiString;
begin
  Result := '';
  if (ACount <= 0) or (AStart < 0) or (AStart + ACount > Length(B)) then Exit;
  SetString(Result, PAnsiChar(@B[AStart]), ACount);
end;

class function Filer.DetectEolFromBytes(const B: TBytes; AStart, ACount: Integer): TEolKind;
var
  I, EndI: Integer;
  C: Byte;
  HasLF, HasCRLF, HasCR: Boolean;
begin
  Result := eolUnknown;
  HasLF := False; HasCRLF := False; HasCR := False;

  if ACount <= 0 then Exit;
  EndI := AStart + ACount - 1;
  I := AStart;

  while I <= EndI do
  begin
    C := B[I];
    if C = 10 {LF} then
      HasLF := True
    else if C = 13 {CR} then
    begin
      if (I < EndI) and (B[I+1] = 10) then
      begin
        HasCRLF := True;
        Inc(I); // skip LF
      end
      else
        HasCR := True;
    end;
    Inc(I);
  end;

  // Prefer CRLF if present
  if HasCRLF then Exit(eolCRLF);
  if HasLF then Exit(eolLF);
  if HasCR then Exit(eolCR);
end;

class function Filer.IsValidUtf8(const B: TBytes; AStart, ACount: Integer): Boolean;
var
  I, Need: Integer;
  C: Byte;
begin
  Result := True;
  Need := 0;
  if (ACount <= 0) then Exit(True);

  I := AStart;
  while I < AStart + ACount do
  begin
    C := B[I];

    if Need = 0 then
    begin
      if C < $80 then
        Inc(I)
      else if (C and $E0) = $C0 then
      begin
        // avoid overlong 2-byte sequences (C0,C1 are invalid)
        if C < $C2 then Exit(False);
        Need := 1; Inc(I);
      end
      else if (C and $F0) = $E0 then
      begin
        Need := 2; Inc(I);
      end
      else if (C and $F8) = $F0 then
      begin
        // restrict to valid UTF-8 (max F4)
        if C > $F4 then Exit(False);
        Need := 3; Inc(I);
      end
      else
        Exit(False);
    end
    else
    begin
      if (C and $C0) <> $80 then Exit(False);
      Dec(Need);
      Inc(I);
    end;
  end;

  Result := (Need = 0);
end;

class procedure Filer.BytesToUnicodeString_UTF16LE(const B: TBytes; AStart, ACount: Integer; out W: UnicodeString);
var
  N, I: Integer;
  P: PWideChar;
begin
  W := '';
  if ACount <= 0 then Exit;
  N := ACount div 2;
  SetLength(W, N);
  P := PWideChar(W);
  for I := 0 to N - 1 do
    P[I] := WideChar(B[AStart + I*2] or (B[AStart + I*2 + 1] shl 8));
end;

class procedure Filer.BytesToUnicodeString_UTF16BE(const B: TBytes; AStart, ACount: Integer; out W: UnicodeString);
var
  N, I: Integer;
  P: PWideChar;
begin
  W := '';
  if ACount <= 0 then Exit;
  N := ACount div 2;
  SetLength(W, N);
  P := PWideChar(W);
  for I := 0 to N - 1 do
    P[I] := WideChar((B[AStart + I*2] shl 8) or B[AStart + I*2 + 1]);
end;

class function Filer.ScoreDecodedText(const S: string; const Orig: AnsiString; const EncName: string): Integer;
var
  Back: string;
  I: Integer;
  BadCtrl: Integer;
  ZeroCount: Integer;
begin
  // Higher is better.
  // 1) round-trip score (how many bytes survive re-encode)
  // 2) penalize lots of control chars (except tab/cr/lf)
  // 3) penalize embedded #0
  Result := 0;

  Back := ConvertEncoding(S, 'utf8', EncName);

  // Round-trip: compare bytes
  if Length(Back) = Length(Orig) then
  begin
    for I := 1 to Length(Orig) do
      if Back[I] = Orig[I] then
        Inc(Result, 2) // match worth 2
      else
        Dec(Result, 1);
  end
  else
    Dec(Result, 1000);

  BadCtrl := 0;
  ZeroCount := 0;
  for I := 1 to Length(S) do
  begin
    if S[I] = #0 then Inc(ZeroCount);

    if (Ord(S[I]) < 32) and (S[I] <> #9) and (S[I] <> #10) and (S[I] <> #13) then
      Inc(BadCtrl);
  end;

  Dec(Result, BadCtrl * 10);
  Dec(Result, ZeroCount * 200);
end;

class function Filer.DetectSingleByteEncoding(const Raw: AnsiString; out BestName: string; out BestEnc: TFileEncoding): Boolean;
const
  Candidates: array[0..40] of string = (
    // Greek first (Windows/ISO/Mac/DOS)
    'cp1253', 'iso8859-7', 'macgreek',
    'cp737', 'cp869', 'cp875', 'cp851', 'cp928',

    // Western / common
    'cp1252', 'iso8859-1', 'iso8859-15', 'macintosh',
    'cp850', 'cp437', 'cp852', 'cp858', 'cp860', 'cp863', 'cp865',

    // Central/Eastern Europe
    'cp1250', 'iso8859-2', 'macce',

    // Cyrillic family
    'cp1251', 'iso8859-5', 'koi8-r', 'koi8-u', 'cp866', 'maccyrillic',

    // Turkish
    'cp1254', 'iso8859-9', 'macturkish',

    // Hebrew / Arabic
    'cp1255', 'iso8859-8', 'machebrew',
    'cp1256', 'iso8859-6', 'macarabic',

    // Baltic
    'cp1257', 'iso8859-13',

    // Nordic (rare but exists)
    'iso8859-10',

    // Thai
    'cp874'
  );
var
  I: Integer;
  EncName: string;
  S: string;
  Score, BestScore: Integer;
begin
  Result := False;
  BestName := '';
  BestEnc := feUnknown;
  BestScore := Low(Integer);

  // Decode raw bytes using each candidate, score, pick best
  for I := Low(Candidates) to High(Candidates) do
  begin
    EncName := Candidates[I];
    try
      S := ConvertEncoding(Raw, EncName, 'utf8');
    except
      Continue;
    end;

    Score := ScoreDecodedText(S, Raw, EncName);
    if Score > BestScore then
    begin
      BestScore := Score;
      BestName := EncName;
    end;
  end;

  if BestName <> '' then
  begin
    BestEnc := NameToEnc(BestName);
    // Note: unknown single-byte names map to feSingleByte_Detected (desired)
    Result := True;
  end;
end;

class function Filer.ReadTextFile(const FileName: string; out Info: TFileReadInfo): string;
const
  UTF8_BOM:    array[0..2] of Byte = ($EF, $BB, $BF);
  UTF16LE_BOM: array[0..1] of Byte = ($FF, $FE);
  UTF16BE_BOM: array[0..1] of Byte = ($FE, $FF);
var
  FS: TFileStream;
  Size: Int64;
  B: TBytes;
  Start: Integer;
  Raw: AnsiString;
  W: UnicodeString;
  BestName: string;
  BestEnc: TFileEncoding;
begin
  B := [];
  Result := '';

  Info.Encoding := feUnknown;
  Info.EncodingName := '';
  Info.HadBOM := False;
  Info.Eol := eolUnknown;

  if not FileExists(FileName) then Exit;

  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    Size := FS.Size;
    if Size = 0 then Exit;

    SetLength(B, Size);
    FS.ReadBuffer(B[0], Size);

    Start := 0;

    // BOM detect first
    if (Size >= 3) and (B[0]=UTF8_BOM[0]) and (B[1]=UTF8_BOM[1]) and (B[2]=UTF8_BOM[2]) then
    begin
      Info.Encoding := feUTF8_BOM;
      Info.EncodingName := 'utf8';
      Info.HadBOM := True;
      Start := 3;

      Info.Eol := DetectEolFromBytes(B, Start, Size - Start);
      if Start < Size then
        SetString(Result, PChar(@B[Start]), Size - Start);
      Exit;
    end;

    if (Size >= 2) and (B[0]=UTF16LE_BOM[0]) and (B[1]=UTF16LE_BOM[1]) then
    begin
      Info.Encoding := feUTF16LE_BOM;
      Info.EncodingName := 'utf16le';
      Info.HadBOM := True;
      Start := 2;

      Info.Eol := DetectEolFromBytes(B, Start, Size - Start);
      BytesToUnicodeString_UTF16LE(B, Start, Size - Start, W);
      Result := UTF8Encode(W);
      Exit;
    end;

    if (Size >= 2) and (B[0]=UTF16BE_BOM[0]) and (B[1]=UTF16BE_BOM[1]) then
    begin
      Info.Encoding := feUTF16BE_BOM;
      Info.EncodingName := 'utf16be';
      Info.HadBOM := True;
      Start := 2;

      Info.Eol := DetectEolFromBytes(B, Start, Size - Start);
      BytesToUnicodeString_UTF16BE(B, Start, Size - Start, W);
      Result := UTF8Encode(W);
      Exit;
    end;

    // No BOM
    Info.Eol := DetectEolFromBytes(B, 0, Size);

    // Check UTF-8 validity (heuristic)
    if IsValidUtf8(B, 0, Size) then
    begin
      Info.Encoding := feUTF8;
      Info.EncodingName := 'utf8';
      SetString(Result, PChar(@B[0]), Size);
      Exit;
    end;

    // Single-byte: try to detect codepage
    Raw := BytesToAnsiString(B, 0, Size);

    if DetectSingleByteEncoding(Raw, BestName, BestEnc) then
    begin
      Info.Encoding := BestEnc;
      Info.EncodingName := BestName;
      Result := ConvertEncoding(Raw, BestName, 'utf8');
      Exit;
    end;

    // Fallback: keep raw bytes (best effort)
    Info.Encoding := feANSI_Unknown;
    Info.EncodingName := 'ansi';
    SetString(Result, PChar(@B[0]), Size);

  finally
    FS.Free;
  end;
end;

class procedure Filer.WriteTextFile(const FileName, Text: string; Encoding: TFileEncoding);
var
  FS: TFileStream;
  S: string;
  B: TBytes;
  W: UnicodeString;
  I: Integer;
  BOM: array[0..2] of Byte;
  EncName: string;
  Dir: string;
begin
  B := [];

  // FIX #1: ForceDirectories only if directory part exists
  Dir := ExtractFileDir(FileName);
  if Dir <> '' then
    ForceDirectories(Dir);

  FS := TFileStream.Create(FileName, fmCreate);
  try
    case Encoding of
      feUTF8:
        begin
          // no BOM
          S := Text;
          // FIX #2: guard empty string
          if Length(S) > 0 then
            FS.WriteBuffer(S[1], Length(S));
        end;

      feUTF8_BOM:
        begin
          BOM[0] := $EF; BOM[1] := $BB; BOM[2] := $BF;
          FS.WriteBuffer(BOM[0], 3);
          S := Text;
          if Length(S) > 0 then
            FS.WriteBuffer(S[1], Length(S));
        end;

      feUTF16LE_BOM:
        begin
          // BOM
          BOM[0] := $FF; BOM[1] := $FE; BOM[2] := 0;
          FS.WriteBuffer(BOM[0], 2);

          W := UTF8Decode(Text);
          SetLength(B, Length(W) * 2);
          for I := 1 to Length(W) do
          begin
            B[(I-1)*2]     := Byte(Ord(W[I]) and $FF);
            B[(I-1)*2 + 1] := Byte((Ord(W[I]) shr 8) and $FF);
          end;
          if Length(B) > 0 then
            FS.WriteBuffer(B[0], Length(B));
        end;

      feUTF16BE_BOM:
        begin
          BOM[0] := $FE; BOM[1] := $FF; BOM[2] := 0;
          FS.WriteBuffer(BOM[0], 2);

          W := UTF8Decode(Text);
          SetLength(B, Length(W) * 2);
          for I := 1 to Length(W) do
          begin
            B[(I-1)*2]     := Byte((Ord(W[I]) shr 8) and $FF);
            B[(I-1)*2 + 1] := Byte(Ord(W[I]) and $FF);
          end;
          if Length(B) > 0 then
            FS.WriteBuffer(B[0], Length(B));
        end;

      // Single-byte encodings
      feCP1253, feISO8859_7, feCP1252, feISO8859_1, feCP1251, feKOI8R, feCP437, feCP850:
        begin
          EncName := EncToName(Encoding);
          if EncName = '' then EncName := 'cp1252';
          S := ConvertEncoding(Text, 'utf8', EncName);
          if Length(S) > 0 then
            FS.WriteBuffer(S[1], Length(S));
        end;

    else
      // fallback: write UTF-8
      S := Text;
      if Length(S) > 0 then
        FS.WriteBuffer(S[1], Length(S));
    end;

  finally
    FS.Free;
  end;
end;

end.
