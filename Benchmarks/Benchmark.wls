#!/usr/bin/env wolframscript
(* Benchmarks the OEIS package's core operations.
   Run with:
     wolframscript -file Benchmarks/Benchmark.wls
   Requires network access; timings depend on the OEIS server and
   your connection, so treat them as indicative, not as a strict
   pass/fail gate. *)

root = DirectoryName[DirectoryName[AbsoluteFileName[First[$ScriptCommandLine]]]];
Get[FileNameJoin[{root, "Kernel", "OEIS.wl"}]];

results = {};
(* HoldRest: expr must stay unevaluated until AbsoluteTiming runs it --
   an eagerly-evaluated argument would run (and be timed as instant,
   since the work already happened before the function body started). *)
SetAttributes[BenchStep, HoldRest];
BenchStep[label_String, expr_] := Module[{time, value},
  {time, value} = AbsoluteTiming[expr];
  AppendTo[results, {label, time}];
  Print[StringPadRight[label, 46], ": ", ToString[Round[time, 0.0001]], " s"];
  value
];

Print["OEIS.m benchmark -- $Version: ", $Version, "\n"];

BenchStep["OEISValidateIDQ[\"A000045\"] (pure)", OEISValidateIDQ["A000045"]];
BenchStep["OEISURL[\"A000045\", bFile->True] (pure)", OEISURL["A000045", bFile -> True]];

BenchStep["OEISImport[..., \"Description\"] (network)", OEISImport["A000045", "Description"]];
BenchStep["OEISImport[..., \"Data\"] (network)", OEISImport["A000045", "Data"]];
BenchStep["OEISImport[..., \"MinData\"] (network)", OEISImport["A000045", "MinData"]];

BenchStep["OEISFunction[\"A000045\", Output->False] (network)", (ClearAll[A000045]; OEISFunction["A000045", Output -> False])];

(* OEISbFile with a local formula: the network call is only for the
   starting offset (MinData); the per-term cost is pure computation,
   so this should scale with VMax roughly independently of the
   network. *)
ClearAll[A358061];
A358061[n_] := Mod[EulerPhi[n], DivisorSigma[0, n]];
Do[
  Module[{file = FileNameJoin[{$TemporaryDirectory, "bench_A358061_" <> ToString[vmax] <> ".txt"}]},
    BenchStep["OEISbFile[\"A358061\", " <> ToString[vmax] <> "] local formula", OEISbFile["A358061", vmax, file]];
    Quiet[DeleteFile[file]];
  ],
  {vmax, {100, 1000, 5000, 20000}}
];

(* OEISbFile without a local definition: bound by how many terms OEIS
   has actually published (network + Table over up-values only). *)
ClearAll[A000045];
Module[{file = FileNameJoin[{$TemporaryDirectory, "bench_A000045_fallback.txt"}]},
  BenchStep["OEISbFile[\"A000045\", 1000] OEIS data fallback", OEISbFile["A000045", 1000, file]];
  Quiet[DeleteFile[file]];
];

Print["\nDone. ", Length[results], " operations timed."];
