#!/usr/bin/env wolframscript
(* Generates the reference-page notebooks under Documentation/English.
   Examples are executed live against the real OEIS JSON API, so the
   captured Input/Output cells are genuine, not illustrative -- run
   this whenever example output needs to be refreshed:

     wolframscript -file DevTools/BuildDocumentation.wls

   Requires network access. *)

root = DirectoryName[DirectoryName[AbsoluteFileName[First[$ScriptCommandLine]]]];
Get[FileNameJoin[{root, "Kernel", "OEIS.wl"}]];

symbolsDir = FileNameJoin[{root, "Documentation", "English", "ReferencePages", "Symbols"}];
guidesDir = FileNameJoin[{root, "Documentation", "English", "Guides"}];

(* ---------- helpers ---------- *)

FormatOutput[expr_] := Module[{e = expr},
  Which[
    ListQ[e] && Length[e] > 12, ToString[Take[e, 12], InputForm] <> " (* ... " <> ToString[Length[e]] <> " terms total *)",
    True, ToString[e, InputForm]
  ]
];

(* Evaluates a Wolfram input string with the OEIS` context on the path
   and returns {inputString, outputString}, so the doc page shows real,
   verified output instead of hand-typed text. *)
RunExample[inputString_String] := Module[{result},
  result = Quiet@Check[ToExpression[inputString], $Failed];
  {inputString, FormatOutput[result]}
];

(* NOTE: building this by mapping a function that returns Sequence[a,b]
   looks natural but silently corrupts the cell list -- Function lacks
   SequenceHold, so Sequence[...] returned from the mapped function
   gets spliced into Function's own argument list instead of the
   surrounding List, turning a later Cell[...] & into a malformed
   2-argument Function. Returning a {a,b} pair and Flatten-ing avoids
   Sequence altogether. *)
ExampleCells[pairs_List] := Flatten[{
  Cell[CellGroupData[
    Flatten[{
      Cell["Basic Examples", "ExampleSection"],
      Map[{Cell[#[[1]], "Input"], Cell[#[[2]], "Output"]} &, pairs]
    }],
    Open
  ]]
}];

OptionsTable[opts : {{_String, _String} ...}] := If[opts === {},
  {},
  {
    Cell["Options", "Subsubsection"],
    Cell[StringRiffle[(#[[1]] <> " -> " <> #[[2]]) & /@ opts, "\n"], "Text"]
  }
];

MakeReferencePage[name_String, usage_String, opts : {{_String, _String} ...}, exampleInputs_List, seeAlso_List] := Module[{examplePairs, nb, file},
  examplePairs = RunExample /@ exampleInputs;
  nb = Notebook[
    Flatten[{
      Cell[name, "ObjectName"],
      Cell[usage, "Usage"],
      OptionsTable[opts],
      ExampleCells[examplePairs],
      If[seeAlso === {}, {}, {
        Cell["See Also", "SeeAlsoSection"],
        Cell[StringRiffle[seeAlso, "  \[FilledSmallSquare]  "], "SeeAlso"]
      }]
    }],
    StyleDefinitions -> "Reference.nb",
    WindowTitle -> name,
    TaggingRules -> <|"Paclet" -> "OEIS"|>
  ];
  file = FileNameJoin[{symbolsDir, name <> ".nb"}];
  Export[file, nb, "NB"];
  Print["Wrote ", file, "  (", Length[examplePairs], " examples)"];
];

(* ---------- reference pages ---------- *)

MakeReferencePage[
  "OEISServerURL",
  "OEISServerURL is the base URL used to build every OEIS request (\"https://oeis.org/\").",
  {},
  {"OEISServerURL"},
  {"OEISURL", "OEISImport"}
];

MakeReferencePage[
  "OEISValidateIDQ",
  "OEISValidateIDQ[id] checks that id has the canonical OEIS shape \"A\" followed by 6 digits, such as \"A000045\". OEISValidateIDQ[{id1,id2,...}] checks every id in the list.",
  {},
  {
    "OEISValidateIDQ[\"A000045\"]",
    "OEISValidateIDQ[{\"A000045\", \"A000040\"}]",
    "Quiet[OEISValidateIDQ[\"not-an-id\"]]"
  },
  {"OEISImport", "OEISURL", "OEISFunction"}
];

MakeReferencePage[
  "OEISURL",
  "OEISURL[id] gives the OEIS sequence URL for id. OEISURL[id, bFile->True] gives the URL of that sequence's b-file instead.",
  {{"URL", "True"}, {"bFile", "False"}},
  {
    "OEISURL[\"A000045\"]",
    "OEISURL[\"A000045\", bFile -> True]",
    "OEISURL[\"A000045\", URL -> False]"
  },
  {"OEISValidateIDQ", "OEISImport", "OEISbFile"}
];

MakeReferencePage[
  "OEISImport",
  "OEISImport[id,element] retrieves the requested piece of data for an OEIS sequence from the official JSON API. element can be \"Data\", \"Description\", \"Author\", \"Date\", \"Offset\"/\"MinData\", \"MaxData\" or \"bFile\".",
  {},
  {
    "OEISImport[\"A000045\", \"Description\"]",
    "OEISImport[\"A000045\", \"Data\"]",
    "OEISImport[\"A000045\", \"MinData\"]",
    "OEISImport[\"A000045\", \"Author\"]"
  },
  {"OEISFunction", "OEISExport", "OEISbFile", "OEISValidateIDQ"}
];

MakeReferencePage[
  "OEISFunction",
  "OEISFunction[id] defines id[n] in the current session, preloaded with the data available from OEIS, and adds a usage message built from the sequence description.",
  {{"AddHelp", "True"}, {"bFile", "True"}, {"Output", "True"}},
  {
    "OEISFunction[\"A000045\", Output -> False]; A000045[10]"
  },
  {"OEISImport", "OEISbFile"}
];

MakeReferencePage[
  "OEISExport",
  "OEISExport[id,filename] exports OEIS content for id to filename, in a format chosen from the file extension: \".m\"/\".gp\" (usage message code), \".txt\"/\".csv\"/\".tsv\"/\".dat\" (data), image formats, \".bib\" (BibTeX citation), \".html\" and \".wiki\" (MediaWiki citation).",
  {},
  {},
  {"OEISImport", "OEISbFile"}
];

MakeReferencePage[
  "OEISbFile",
  "OEISbFile[id,VMax,filename] writes a b-file with the values of id(n) for n from the sequence offset up to VMax. If id[n_]:=... is already defined in the session, that definition is used to compute every term up to VMax; otherwise the data already published on OEIS is used instead.",
  {},
  {
    "A358061[n_] := Mod[EulerPhi[n], DivisorSigma[0, n]]; OEISbFile[\"A358061\", 20, FileNameJoin[{$TemporaryDirectory, \"b358061_doc_example.txt\"}]]; ReadList[FileNameJoin[{$TemporaryDirectory, \"b358061_doc_example.txt\"}], String]"
  },
  {"OEISFunction", "OEISImport", "OEISURL"}
];

MakeReferencePage[
  "OEISTotalNumberOfSequences",
  "OEISTotalNumberOfSequences[] returns an estimate of the number of sequences OEIS currently contains, by checking that OEIS can be reached.",
  {{"URL", "True"}},
  {"OEISTotalNumberOfSequences[]"},
  {"OEISValidateIDQ"}
];

Print["Reference pages done."];

(* ---------- guide page ---------- *)

GuideEntry[name_String, blurb_String] := {
  Cell[name, "GuideFunction"],
  Cell[blurb, "GuideText"]
};

guideNb = Notebook[
  Flatten[{
    Cell["OEIS Package", "GuideTitle"],
    Cell["Retrieve, export and generate b-files for On-Line Encyclopedia of Integer Sequences (OEIS) data through the official JSON API.", "GuideAbstract"],

    Cell["Look up and validate sequences", "GuideFunctionsSubsection"],
    GuideEntry["OEISValidateIDQ", "check that an identifier has the canonical OEIS shape"],
    GuideEntry["OEISURL", "build a sequence or b-file URL"],
    GuideEntry["OEISServerURL", "the base URL used for every OEIS request"],
    GuideEntry["OEISTotalNumberOfSequences", "an estimate of how many sequences OEIS contains"],

    Cell["Retrieve sequence data", "GuideFunctionsSubsection"],
    GuideEntry["OEISImport", "retrieve data, description, author, date or offset for a sequence"],
    GuideEntry["OEISFunction", "materialize id[n] in your session, preloaded from OEIS"],

    Cell["Export and generate files", "GuideFunctionsSubsection"],
    GuideEntry["OEISExport", "export sequence data or citations to .m, .txt, .bib, .html, .wiki, images"],
    GuideEntry["OEISbFile", "write a b-file, using a locally defined id[n] when available"],

    Cell["Tutorials", "RelatedTutorialsSection"],
    Cell["OEIS Package: A Tutorial", "RelatedTutorials"]
  }],
  StyleDefinitions -> "Guide.nb",
  WindowTitle -> "OEIS Package"
];
Export[FileNameJoin[{guidesDir, "OEIS.nb"}], guideNb, "NB"];
Print["Wrote ", FileNameJoin[{guidesDir, "OEIS.nb"}]];

(* ---------- tutorial notebook ---------- *)

tutorialsDir = FileNameJoin[{root, "Documentation", "English", "Tutorials"}];

(* Bare Input/Output pairs, interleaved with narrative text -- unlike
   ExampleCells, no CellGroupData wrapper, so a tutorial reads top to
   bottom like a walkthrough. *)
StepCells[pairs_List] := Flatten[Map[{Cell[#[[1]], "Input"], Cell[#[[2]], "Output"]} &, pairs]];

tutorialInputs = {
  "Needs[\"OEIS`\"]",
  "OEISValidateIDQ[\"A000045\"]",
  "OEISURL[\"A000045\"]",
  "OEISURL[\"A000045\", bFile -> True]",
  "OEISImport[\"A000045\", \"Description\"]",
  "OEISImport[\"A000045\", \"Data\"][[1 ;; 10]]",
  "{OEISImport[\"A000045\", \"MinData\"], OEISImport[\"A000045\", \"MaxData\"]}",
  "OEISFunction[\"A000045\", Output -> False]; A000045[20]",
  "A358061[n_] := Mod[EulerPhi[n], DivisorSigma[0, n]]; OEISbFile[\"A358061\", 2000, FileNameJoin[{$TemporaryDirectory, \"b358061_tutorial.txt\"}]]; Length[ReadList[FileNameJoin[{$TemporaryDirectory, \"b358061_tutorial.txt\"}], String]]",
  "ClearAll[A358061]; OEISbFile[\"A000045\", 15, FileNameJoin[{$TemporaryDirectory, \"b000045_tutorial.txt\"}]]; ReadList[FileNameJoin[{$TemporaryDirectory, \"b000045_tutorial.txt\"}], String]"
};
tutorialPairs = RunExample /@ tutorialInputs;

tutorialNb = Notebook[
  Flatten[{
    Cell["OEIS Package: A Tutorial", "Title"],
    Cell["Every example on this page was executed live against the real OEIS JSON API -- the output shown is real, not illustrative. The runnable, plain-script version of this tutorial is test/OEISTutorial.wl.", "Text"],

    Cell["Load the package", "Section"],
    Cell["Loading the package puts every OEISXXX function on $ContextPath.", "Text"],
    StepCells[{tutorialPairs[[1]]}],

    Cell["Validate an identifier and build its URLs", "Section"],
    StepCells[tutorialPairs[[2 ;; 4]]],

    Cell["Retrieve sequence data", "Section"],
    Cell["OEISImport talks to the live OEIS JSON API for \"Description\", \"Data\", \"Author\", \"Date\", \"MinData\"/\"Offset\" and \"MaxData\".", "Text"],
    StepCells[tutorialPairs[[5 ;; 7]]],

    Cell["Materialize a sequence as a function", "Section"],
    Cell["OEISFunction defines id[n] in this session, preloaded with the data OEIS already has.", "Text"],
    StepCells[{tutorialPairs[[8]]}],

    Cell["Generate a b-file from your own formula", "Section"],
    Cell["If id[n_] := ... is already defined -- as documented on the OEIS wiki page for this package -- OEISbFile uses that definition to compute every term up to VMax, even far beyond what OEIS has published. A358061 only has about 90 published terms; this still produces all 2000 requested, computed locally with EulerPhi and DivisorSigma.", "Text"],
    StepCells[{tutorialPairs[[9]]}],

    Cell["Generate a b-file straight from OEIS data", "Section"],
    Cell["Without a local definition, OEISbFile falls back to whatever OEIS already has published for that ID.", "Text"],
    StepCells[{tutorialPairs[[10]]}],

    Cell["See Also", "Section"],
    Cell["The OEIS Package guide page lists every function with a one-line description.", "Text"]
  }],
  StyleDefinitions -> "Tutorial.nb",
  WindowTitle -> "OEIS Package: A Tutorial"
];
Export[FileNameJoin[{tutorialsDir, "OEIS.nb"}], tutorialNb, "NB"];
Print["Wrote ", FileNameJoin[{tutorialsDir, "OEIS.nb"}]];
