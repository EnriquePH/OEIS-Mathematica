(* Mathics3-compatible mirror of Tests/OfflineTests.wlt.
   Mathics3 (the free, pip-installable, no-license-needed implementation
   of the Wolfram Language: https://mathics.org) does not implement
   VerificationTest / TestReport, so the real .wlt suite can't run here.
   This hand-ports the same offline assertions (ID validation, URL
   building -- nothing that touches the network) using plain If/Print.
   Keep this in sync by hand whenever Tests/OfflineTests.wlt changes.

   Exit[] does not propagate to the process exit code under `mathics
   --script` or `mathicsscript`, so pass/fail is signaled by printing
   a fixed marker line that the CI step greps for instead. *)

Get["Kernel/OEIS.wl"];

failCount = 0;
passCount = 0;

Check1[id_String, actual_, expected_] := Module[{},
  If[actual === expected,
    passCount = passCount + 1,
    failCount = failCount + 1;
    Print["FAIL ", id, ": expected ", expected, ", got ", actual]
  ]
];

Check1["OEISValidateIDQ-valid", OEISValidateIDQ["A000045"], True];
Check1["OEISValidateIDQ-bad-prefix", Quiet[OEISValidateIDQ["Z000045"]], False];
Check1["OEISValidateIDQ-bad-length", Quiet[OEISValidateIDQ["A45"]], False];
Check1["OEISValidateIDQ-list-all-valid", OEISValidateIDQ[{"A000045", "A000040"}], True];
Check1["OEISValidateIDQ-list-one-invalid", Quiet[OEISValidateIDQ[{"A000045", "Z000040"}]], False];
Check1["OEISURL-default", OEISURL["A000045"], "https://oeis.org/A000045"];
Check1["OEISURL-no-url", OEISURL["A000045", URL -> False], "A000045"];
Check1["OEISURL-bfile", OEISURL["A000045", bFile -> True], "https://oeis.org/b000045.txt"];
Check1["OEISURL-bfile-no-url", OEISURL["A000045", URL -> False, bFile -> True], "b000045.txt"];

Print["Passed: ", passCount, "  Failed: ", failCount];

If[failCount > 0,
  Print["MATHICS_OFFLINE_TESTS: FAILED"],
  Print["MATHICS_OFFLINE_TESTS: PASSED"]
];
