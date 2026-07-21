(* Tests that call the live OEIS JSON API. Require network access;
   skip these (run only OfflineTests.wlt) on air-gapped machines. *)

VerificationTest[
  StringQ[OEISImport["A000045", "Description"]],
  True,
  TestID -> "OEISImport-description-is-string"
]

VerificationTest[
  StringContainsQ[OEISImport["A000045", "Description"], "Fibonacci"],
  True,
  TestID -> "OEISImport-description-mentions-fibonacci"
]

VerificationTest[
  First[First[OEISImport["A000045", "Data"]]],
  0,
  TestID -> "OEISImport-data-starts-at-offset"
]

VerificationTest[
  OEISImport["A000045", "MinData"],
  0,
  TestID -> "OEISImport-mindata-offset"
]

(* Regression test for the OEISbFile fix (2026-07-21): a locally
   predefined ID[n_] must be used to compute every term up to VMax,
   instead of truncating to whatever data OEIS already has published.
   A358061 only has ~90 published terms, so this also proves VMax=2000
   is not silently capped. *)
VerificationTest[
  Module[{file, lines},
    ClearAll[A358061];
    A358061[n_] := Mod[EulerPhi[n], DivisorSigma[0, n]];
    file = FileNameJoin[{$TemporaryDirectory, "b358061_test.txt"}];
    OEISbFile["A358061", 2000, file];
    lines = ReadList[file, String];
    Quiet[DeleteFile[file]];
    Length[lines]
  ],
  2000,
  TestID -> "OEISbFile-local-function-computes-full-range"
]

VerificationTest[
  Module[{file, lines},
    ClearAll[A358061];
    A358061[n_] := Mod[EulerPhi[n], DivisorSigma[0, n]];
    file = FileNameJoin[{$TemporaryDirectory, "b358061_test_first.txt"}];
    OEISbFile["A358061", 5, file];
    lines = ReadList[file, String];
    Quiet[DeleteFile[file]];
    First[lines]
  ],
  "1 0",
  TestID -> "OEISbFile-local-function-first-line"
]

VerificationTest[
  Module[{file, lines},
    ClearAll[A999999999];
    file = FileNameJoin[{$TemporaryDirectory, "b_fallback_test.txt"}];
    OEISbFile["A000045", 15, file];
    lines = ReadList[file, String];
    Quiet[DeleteFile[file]];
    {First[lines], Length[lines]}
  ],
  {"0 0", 16},
  TestID -> "OEISbFile-fallback-to-oeis-data-when-not-predefined"
]
