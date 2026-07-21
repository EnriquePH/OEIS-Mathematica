(* Tests that need no network access: ID validation and URL building.
   Run with Tests/RunTests.wls, or individually via TestReport. *)

VerificationTest[
  OEISValidateIDQ["A000045"],
  True,
  TestID -> "OEISValidateIDQ-valid"
]

VerificationTest[
  Quiet[OEISValidateIDQ["Z000045"]],
  False,
  TestID -> "OEISValidateIDQ-bad-prefix"
]

VerificationTest[
  Quiet[OEISValidateIDQ["A45"]],
  False,
  TestID -> "OEISValidateIDQ-bad-length"
]

VerificationTest[
  OEISValidateIDQ[{"A000045", "A000040"}],
  True,
  TestID -> "OEISValidateIDQ-list-all-valid"
]

VerificationTest[
  Quiet[OEISValidateIDQ[{"A000045", "Z000040"}]],
  False,
  TestID -> "OEISValidateIDQ-list-one-invalid"
]

VerificationTest[
  OEISURL["A000045"],
  "https://oeis.org/A000045",
  TestID -> "OEISURL-default"
]

VerificationTest[
  OEISURL["A000045", URL -> False],
  "A000045",
  TestID -> "OEISURL-no-url"
]

VerificationTest[
  OEISURL["A000045", bFile -> True],
  "https://oeis.org/b000045.txt",
  TestID -> "OEISURL-bfile"
]

VerificationTest[
  OEISURL["A000045", URL -> False, bFile -> True],
  "b000045.txt",
  TestID -> "OEISURL-bfile-no-url"
]
