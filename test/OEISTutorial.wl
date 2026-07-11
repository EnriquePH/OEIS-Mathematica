(* ::Package:: *)

(*
  Tutorial-style Wolfram Language script for the OEIS package.
  Run it with:
    wolframscript -file test/OEISTutorial.wl
*)

Print["Loading OEIS package..."];
Needs["OEIS`"];

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

Print["\nTutorial completed."];
