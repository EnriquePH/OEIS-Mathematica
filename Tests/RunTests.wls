#!/usr/bin/env wolframscript
(* Runs the OEIS.m test suite and exits with a nonzero status on failure,
   so it can be used both locally and as a CI step.

   Usage:
     wolframscript -file Tests/RunTests.wls            (* all tests *)
     wolframscript -file Tests/RunTests.wls --offline   (* skip NetworkTests.wlt *)
*)

root = DirectoryName[AbsoluteFileName[First[$ScriptCommandLine]]];
Get[FileNameJoin[{root, "..", "Kernel", "OEIS.wl"}]];

offlineOnly = MemberQ[$ScriptCommandLine, "--offline"];

testFiles = If[offlineOnly,
  {FileNameJoin[{root, "OfflineTests.wlt"}]},
  FileNames["*.wlt", root]
];

Print["Running: ", testFiles];
Print["$Version: ", $Version];

(* Run each file separately and aggregate: TestReport applied to a list
   of filenames is not reliable across Wolfram Engine versions. *)
reports = TestReport /@ testFiles;

succeeded = Total[#["TestsSucceededCount"] & /@ reports];
failed = Total[#["TestsFailedCount"] & /@ reports];

Print["Passed: ", succeeded, "  Failed: ", failed];

If[failed > 0,
  Print["--- Failures ---"];
  Scan[
    Function[report,
      Scan[
        Print[#["TestID"], " (", #["TestIndex"], "): ", #["Outcome"], "\n  Input: ", #["Input"], "\n  Expected: ", #["ExpectedOutput"], "\n  Actual: ", #["ActualOutput"]] &,
        Values[KeyTake[report["TestResults"], report["TestsFailedIndices"]]]
      ]
    ],
    reports
  ];
  Exit[1],
  Exit[0]
]
