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

(* "Entry" bundles every element into one Association, built from the
   same OEISRequest-cached fetch each standalone element uses -- so it
   must always agree with them exactly, never drift. *)
VerificationTest[
  Sort[Keys[OEISImport["A000045", "Entry"]]],
  Sort[{"ID", "Description", "Author", "Date", "Offset", "Data", "Formula"}],
  TestID -> "OEISImport-entry-has-expected-keys"
]

VerificationTest[
  With[{entry = OEISImport["A000045", "Entry"]},
    entry["Description"] === OEISImport["A000045", "Description"] &&
    entry["Data"] === OEISImport["A000045", "Data"] &&
    entry["Author"] === OEISImport["A000045", "Author"] &&
    entry["Date"] === OEISImport["A000045", "Date"] &&
    entry["Offset"] === OEISImport["A000045", "Offset"]
  ],
  True,
  TestID -> "OEISImport-entry-agrees-with-standalone-elements"
]

VerificationTest[
  MatchQ[OEISImport["A000045", "Entry"]["Formula"], {__String}],
  True,
  TestID -> "OEISImport-entry-formula-is-a-string-list"
]

(* Proves the memoization contract from OEISRequest: asking for every
   element of one ID, including "Entry" (five element lookups on its
   own), must add exactly one memoized rule -- one network fetch for
   the whole batch, not one per element. *)
VerificationTest[
  Module[{id = "A000032", before, after},
    before = Length[DownValues[OEIS`Private`OEISRequest]];
    OEISImport[id, "Description"];
    OEISImport[id, "Entry"];
    OEISImport[id, "Data"];
    OEISImport[id, "MaxData"];
    after = Length[DownValues[OEIS`Private`OEISRequest]];
    after - before
  ],
  1,
  TestID -> "OEISRequest-one-fetch-per-id-regardless-of-element-count"
]

(* OEISData is a thin wrapper around OEISImport[ID,"Entry"] -- must
   agree with it exactly. *)
VerificationTest[
  OEISData["A000045"] === OEISImport["A000045", "Entry"],
  True,
  TestID -> "OEISData-agrees-with-entry"
]

(* OEISSearch: free text and search-by-sequence-of-numbers both hit the
   same JSON endpoint OEISImport uses for ID lookup, just with a
   different query; results must come back as Entry Associations. *)
VerificationTest[
  Module[{results = OEISSearch["prime gaps"]},
    Length[results] > 0 && AllTrue[results, AssociationQ] && AllTrue[results, KeyExistsQ["ID"]]
  ],
  True,
  TestID -> "OEISSearch-text-returns-entries"
]

VerificationTest[
  MemberQ[OEISSearch["prime gaps"][[All, "ID"]], "A001223"],
  True,
  TestID -> "OEISSearch-text-finds-expected-sequence"
]

VerificationTest[
  First[OEISSearch[{1, 1, 2, 3, 5, 8, 13}]]["ID"],
  "A000045",
  TestID -> "OEISSearch-by-sequence-finds-fibonacci"
]

(* OEISRelated: parsed from the entry's "xref" field. A000045 (Fibonacci)
   is very well cross-referenced, including to A001622 (golden ratio). *)
VerificationTest[
  Module[{related = OEISRelated["A000045"]},
    Length[related] > 0 && MemberQ[related, "A001622"] && !MemberQ[related, "A000045"]
  ],
  True,
  TestID -> "OEISRelated-finds-cross-references-excludes-self"
]

(* OEISGraph: a star graph of ID plus every OEISRelated ID, so vertex
   count is always related-count + 1 and edge count always equals
   related-count. *)
VerificationTest[
  Module[{related = OEISRelated["A000045"], graph = OEISGraph["A000045"]},
    GraphQ[graph] && VertexCount[graph] == Length[related] + 1 &&
    EdgeCount[graph] == Length[related] &&
    MemberQ[VertexList[graph], "A000045"] && MemberQ[VertexList[graph], "A001622"]
  ],
  True,
  TestID -> "OEISGraph-star-topology-matches-related"
]

(* OEISRandom: no dedicated endpoint exists, so this is retry-based --
   verify it actually lands on a real, fetchable entry, not just that
   it returns some Association. *)
VerificationTest[
  Module[{r = OEISRandom[]},
    AssociationQ[r] && StringMatchQ[r["ID"], RegularExpression["A[0-9]{6}"]] &&
    StringQ[r["Description"]] && r["Description"] =!= "" &&
    r === OEISImport[r["ID"], "Entry"]
  ],
  True,
  TestID -> "OEISRandom-lands-on-real-fetchable-entry"
]

(* OEISSequence: every property, cross-checked against the equivalent
   OEISImport/OEISRelated/OEISGraph/OEISCitation/OEISURL calls so the
   object can never drift from the functions it dispatches to. *)
VerificationTest[
  Module[{seq = OEISSequence["A000045"]},
    seq["ID"] === "A000045" &&
    seq["Entry"] === OEISImport["A000045", "Entry"] &&
    seq["Description"] === OEISImport["A000045", "Description"] &&
    seq["Author"] === OEISImport["A000045", "Author"] &&
    seq["Date"] === OEISImport["A000045", "Date"] &&
    seq["Offset"] === OEISImport["A000045", "Offset"] &&
    seq["Data"] === OEISImport["A000045", "Data"] &&
    seq["Values"] === OEISImport["A000045", "Data"][[All, 2]] &&
    seq["Formula"] === OEISImport["A000045", "Entry"]["Formula"] &&
    seq["Related"] === OEISRelated["A000045"] &&
    seq["Citation"] === OEISCitation["A000045", "BibTeX"] &&
    seq["URL"] === OEISURL["A000045"]
  ],
  True,
  TestID -> "OEISSequence-properties-agree-with-underlying-functions"
]

VerificationTest[
  Module[{seq = OEISSequence["A000045"]},
    {MatchQ[seq["Keywords"], {__String}], MemberQ[seq["Keywords"], "core"],
     MatchQ[seq["References"], {__String}], GraphQ[seq["Graph"]],
     Head[seq["Plot"]] === Graphics}
  ],
  {True, True, True, True, True},
  TestID -> "OEISSequence-keywords-references-graph-plot"
]

(* OEISCitation: both formats, plus a direct proof that OEISExport's
   "bib"/"wiki" file output (refactored to call OEISCitation internally)
   still matches it exactly. *)
VerificationTest[
  StringStartsQ[OEISCitation["A000045", "BibTeX"], "@MISC{oeisA000045,"],
  True,
  TestID -> "OEISCitation-bibtex-format"
]

VerificationTest[
  OEISCitation["A000045", "Wiki"],
  "* {{oeis|A000045}}: " <> OEISImport["A000045", "Description"],
  TestID -> "OEISCitation-wiki-format"
]

VerificationTest[
  Module[{file, exported},
    file = FileNameJoin[{$TemporaryDirectory, "citation_consistency_test.bib"}];
    OEISExport["A000045", file];
    exported = Import[file, "Text"];
    Quiet[DeleteFile[file]];
    StringTrim[exported] === StringTrim[OEISCitation["A000045", "BibTeX"]]
  ],
  True,
  TestID -> "OEISExport-bib-matches-OEISCitation"
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
