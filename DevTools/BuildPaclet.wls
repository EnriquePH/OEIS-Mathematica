#!/usr/bin/env wolframscript
(* Builds the installable .paclet archive from this repository.

   Usage:
     wolframscript -file DevTools/BuildPaclet.wls [outputDirectory]

   outputDirectory defaults to <repo root>/build. Requires Wolfram
   Language 12.1+ (PacletManager understanding the PacletInfo.wl
   association format); see README.md for the version note. *)

Needs["PacletManager`"];

root = DirectoryName[DirectoryName[AbsoluteFileName[First[$ScriptCommandLine]]]];
outDir = If[Length[$ScriptCommandLine] >= 2, $ScriptCommandLine[[2]], FileNameJoin[{root, "build"}]];

(* Stage only the files that belong in the shipped paclet: source,
   docs and license -- not Tests/, DevTools/, .github/, docs/ (the
   GitHub Pages tutorial site) or repository-level metadata files. *)
stageDir = FileNameJoin[{$TemporaryDirectory, "OEIS-paclet-stage-" <> ToString[$ProcessID]}];
If[DirectoryQ[stageDir], DeleteDirectory[stageDir, DeleteContents -> True]];
CreateDirectory[stageDir];

CopyFileOrDir[relPath_String] := Module[{src = FileNameJoin[{root, relPath}], dst = FileNameJoin[{stageDir, relPath}]},
  If[!FileExistsQ[src] && !DirectoryQ[src], Print["  (skipping missing ", relPath, ")"]; Return[]];
  If[DirectoryQ[src],
    CopyDirectory[src, dst],
    If[!DirectoryQ[DirectoryName[dst]], CreateDirectory[DirectoryName[dst], CreateIntermediateDirectories -> True]];
    CopyFile[src, dst]
  ]
];

Print["Staging paclet contents in ", stageDir];
CopyFileOrDir["PacletInfo.wl"];
CopyFileOrDir["Kernel"];
CopyFileOrDir["Documentation"];
CopyFileOrDir["Assets"];
CopyFileOrDir["LICENSE"];
CopyFileOrDir["OEIS.m"];

If[!DirectoryQ[outDir], CreateDirectory[outDir, CreateIntermediateDirectories -> True]];

Print["Building archive..."];
archive = Quiet@Check[CreatePacletArchive[stageDir, outDir], $Failed];
built = StringQ[archive] && FileExistsQ[archive];

Quiet@DeleteDirectory[stageDir, DeleteContents -> True];

If[!built,
  Print["Paclet build FAILED (got: ", archive, "). This requires Wolfram Language 12.1+ (PacletManager reading the PacletInfo.wl association format); current $Version: ", $Version];
  Exit[1],
  Print["Built paclet: ", archive];
  Exit[0]
]
