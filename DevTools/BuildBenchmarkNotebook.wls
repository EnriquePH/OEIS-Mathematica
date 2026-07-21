#!/usr/bin/env wolframscript
(* Runs Benchmarks/Benchmark.wls and packages the real, captured
   timings into Benchmarks/Benchmark.nb (table + bar chart). Requires
   network access; re-run whenever the timings should be refreshed:

     wolframscript -file DevTools/BuildBenchmarkNotebook.wls *)

root = DirectoryName[DirectoryName[AbsoluteFileName[First[$ScriptCommandLine]]]];
Get[FileNameJoin[{root, "Kernel", "OEIS.wl"}]];

results = {};
SetAttributes[BenchStep, HoldRest];
BenchStep[label_String, expr_] := Module[{time, value},
  {time, value} = AbsoluteTiming[expr];
  AppendTo[results, {label, time}];
  value
];

BenchStep["OEISValidateIDQ (pure)", OEISValidateIDQ["A000045"]];
BenchStep["OEISURL, bFile->True (pure)", OEISURL["A000045", bFile -> True]];
BenchStep["OEISImport, \"Description\" (network)", OEISImport["A000045", "Description"]];
BenchStep["OEISImport, \"Data\" (network)", OEISImport["A000045", "Data"]];
BenchStep["OEISImport, \"MinData\" (network)", OEISImport["A000045", "MinData"]];
BenchStep["OEISFunction (network)", (ClearAll[A000045]; OEISFunction["A000045", Output -> False])];

ClearAll[A358061];
A358061[n_] := Mod[EulerPhi[n], DivisorSigma[0, n]];
Do[
  Module[{file = FileNameJoin[{$TemporaryDirectory, "bench_A358061_" <> ToString[vmax] <> ".txt"}]},
    BenchStep["OEISbFile local formula, VMax=" <> ToString[vmax], OEISbFile["A358061", vmax, file]];
    Quiet[DeleteFile[file]];
  ],
  {vmax, {100, 1000, 5000, 20000}}
];

ClearAll[A000045];
Module[{file = FileNameJoin[{$TemporaryDirectory, "bench_A000045_fallback.txt"}]},
  BenchStep["OEISbFile OEIS-data fallback, VMax=1000", OEISbFile["A000045", 1000, file]];
  Quiet[DeleteFile[file]];
];

roundedResults = {#[[1]], Round[#[[2]], 0.0001]} & /@ results;

tableGrid = Grid[
  Prepend[roundedResults, {"Operation", "Time (s)"}],
  Frame -> All,
  Background -> {None, {LightGray, None}},
  Alignment -> {{Left, Right}}
];

chart = BarChart[
  roundedResults[[All, 2]],
  ChartLabels -> Placed[Rotate[#, 60 Degree] & /@ roundedResults[[All, 1]], Axis],
  ChartStyle -> "Rainbow",
  AxesLabel -> {None, "seconds"},
  ImageSize -> 650,
  PlotLabel -> "OEIS.m benchmark (\!\(\*StyleBox[\"lower is better\",FontSlant->Italic]\))"
];

nb = Notebook[
  {
    Cell["OEIS Package: Benchmark", "Title"],
    Cell["Real, captured timings from a single run of Benchmarks/Benchmark.wls -- not illustrative. Network-bound operations depend on the OEIS server and connection, so treat absolute numbers as indicative; the relative shape (pure/local-formula operations are essentially free; network calls dominate) is the useful takeaway.", "Text"],
    Cell["$Version: " <> $Version, "Text"],

    Cell["Results", "Section"],
    Cell[BoxData[ToBoxes[tableGrid]], "Output"],

    Cell["Chart", "Section"],
    Cell[BoxData[ToBoxes[chart]], "Output"],

    Cell["Reading the OEISbFile rows", "Section"],
    Cell["The four \"local formula\" rows use a session-defined A358061[n_] (see the OEISbFile reference page and the tutorial) with VMax growing from 100 to 20000: since OEISbFile only makes one network call (to look up the sequence's starting offset) regardless of VMax, their timings mostly reflect pure local computation and scale far more gently than a network round trip per term would. The \"OEIS-data fallback\" row -- no local definition -- pays for two network calls (the offset lookup, then OEISFunction's own description/data fetch) and is capped by how many terms OEIS has actually published.", "Text"]
  },
  StyleDefinitions -> "Default.nb",
  WindowTitle -> "OEIS Package: Benchmark"
];

outFile = FileNameJoin[{root, "Benchmarks", "Benchmark.nb"}];
Export[outFile, nb, "NB"];
Print["Wrote ", outFile];
