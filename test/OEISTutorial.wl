(* ::Package:: *)

(*
  Tutorial-style Wolfram Language script for the OEIS package.
  Run it with:
    wolframscript -file test/OEISTutorial.wl
*)

Print["Loading OEIS package..."];
(* Load relative to this script's own location, not via ambient Needs
   resolution -- a stale OEIS.wl elsewhere on $Path (e.g. a leftover
   copy in ~/.Mathematica/Applications) would otherwise silently
   shadow the current repository source, defeating the point of this
   script doubling as an integration test. Mirrors Tests/RunTests.wls. *)
root = DirectoryName[DirectoryName[AbsoluteFileName[First[$ScriptCommandLine]]]];
Get[FileNameJoin[{root, "Kernel", "OEIS.wl"}]];

Print["\n1) Validate an OEIS identifier"];
Print[OEIS`OEISValidateIDQ["A000045"]];

Print["\n2) Build the OEIS URL for a sequence"];
Print[OEIS`OEISURL["A000045"]];

Print["\n3) Retrieve the description of a sequence"];
Print[OEIS`OEISImport["A000045", "Description"]];

Print["\n4) Retrieve the first terms of a sequence"];
Print[OEIS`OEISImport["A000045", "Data"][[1 ;; 5]]];

Print["\n5) Get the minimum and maximum available index"];
Print[{OEIS`OEISImport["A000045", "MinData"], OEIS`OEISImport["A000045", "MaxData"]}];

Print["\n6) Export a small help file"];
OEIS`OEISExport["A000045", FileNameJoin[{"test", "A000045.m"}]];
Print["Generated test/A000045.m"];

Print["\n7) Search OEIS by free text and by a sequence of numbers"];
Print[OEIS`OEISSearch["prime gaps"][[1]]["ID"]];
Print[First[OEIS`OEISSearch[{1, 1, 2, 3, 5, 8, 13}]]["ID"]];

Print["\n8) Related sequences and a citation string"];
Print[OEIS`OEISRelated["A000045"][[1 ;; 5]]];
Print[OEIS`OEISCitation["A000045", "Wiki"]];

Print["\n9) The full entry as an Association"];
Print[Keys[OEIS`OEISData["A000045"]]];

Print["\n10) The OEISSequence object"];
seq = OEIS`OEISSequence["A000045"];
Print[seq["Values"][[1 ;; 10]]];
Print[seq["Keywords"]];

Print["\n11) A graph of related sequences"];
g = OEIS`OEISGraph["A000045"];
Print[{VertexCount[g], EdgeCount[g]}];

Print["\n12) A random sequence"];
Print[Keys[OEIS`OEISRandom[]]];

Print["\nTutorial completed."];
