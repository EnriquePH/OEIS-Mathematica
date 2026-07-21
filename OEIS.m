(* ::Package:: *)

(* ::Section:: *)
(*(*OEIS Package: Title and comments*)*)

(* :Title: Package OEIS *)
(* :Context: Utilities`OEIS` *)
(* :Author: Enrique Pérez Herrero *)
(* :Summary:
    Lightweight access to OEIS sequence data through the official JSON API.
*)
(* :Package Version: 3.1 *)
(* :Mathematica Version: 11.0.0.0 *)
(* :Links:
The OEIS Foundation Inc:            https://oeisf.org/
OEIS:                               https://oeis.org/
*)
(* :History:
    V. 3.0 11 Jul 2026, by Copilot. Rebuilt around the official OEIS JSON API.
    V. 3.1 11 Jul 2026. Fixed JSON result parsing (the live API returns a
      bare array, not a {"results": [...]} wrapper), fixed offset parsing
      ("start,digits" strings), fixed BibTeX date parsing (ISO-8601
      timestamps), and added a curl-based fallback for HTTP fetches when
      Mathematica's built-in client is unavailable.
*)
(* :Keywords:
    packages, sequence, OEIS
*)
(* :Licence:
    OEIS.m: Wolfram Language package for working with OEIS data.
    Copyright (C) 2026 Enrique Pérez Herrero
*)

BeginPackage["OEIS`"];

OEISServerURL::usage = "Base URL for OEIS.";
OEISTotalNumberOfSequences::usage = "OEISTotalNumberOfSequences[] returns an estimate of the number of OEIS sequences.";
OEISValidateIDQ::usage = "OEISValidateIDQ[ID] checks that the sequence identifier has the expected OEIS format.";
OEISImport::usage = "OEISImport[ID,element] retrieves data from OEIS using the official JSON API.";
OEISURL::usage = "OEISURL[ID] gives the OEIS sequence URL for an ID.";
OEISFunction::usage = "OEISFunction[ID] creates a function named with the OEIS ID and preloads the available data.";
OEISExport::usage = "OEISExport[ID,filename] exports OEIS data to a supported file format.";
OEISbFile::usage = "OEISbFile[ID,VMax,filename] writes a b-file compatible with the OEIS package.";

bFile::usage = "bFile";
URL::usage = "URL";
URLType::usage = "URLType";
AddHelp::usage = "AddHelp";
Output::usage = "Output";

OEIS::conopen = "Cannot connect to OEIS Server: `1`";
OEIS::bFile = "Cannot read OEIS data from the official JSON API: `1`";
OEIS::ID = "`1` is not a valid OEIS ID";

Unprotect["`*"]; 
Begin["`Private`"];

OEISServerURL = "https://oeis.org/";

ClearAll[OEISJSONURL, OEISReadJSON, OEISReadJSONViaCurl, OEISGetResult, OEISLookupValue, OEISParseTerms, OEISMakePairs, OEISParseOffset, OEISParseDateTokens, OEISGetEntry];

(* Build the official OEIS search URL for a given sequence ID. *)
OEISJSONURL[ID_String] := OEISServerURL <> "search?q=id:" <> ID <> "&fmt=json";

(* Download and parse the JSON payload returned by OEIS.
   Falls back to an external curl call when Mathematica's built-in
   HTTP client cannot be used (e.g. a broken/mismatched CURLLink on
   some Linux installs), so the package keeps working either way. *)
OEISReadJSON[ID_String] := Module[{result},
  result = Quiet@Check[Import[OEISJSONURL[ID], "JSON"], $Failed];
  If[result === $Failed, result = OEISReadJSONViaCurl[ID]];
  result
];

OEISReadJSONViaCurl[ID_String] := Module[{proc},
  (* Mathematica prepends its own bundled libraries to LD_LIBRARY_PATH,
     which can make an external curl load an incompatible libcurl.so;
     unset it in the subshell so the system's own curl runs cleanly. *)
  proc = Quiet@Check[
    RunProcess[{"bash", "-c", "unset LD_LIBRARY_PATH; exec curl -sS --max-time 20 \"$1\"", "curl-oeis", OEISJSONURL[ID]}],
    $Failed
  ];
  If[proc === $Failed || proc["ExitCode"] =!= 0, Return[$Failed]];
  Quiet@Check[ImportString[proc["StandardOutput"], "JSON"], $Failed]
];

(* Extract the first result entry from the returned JSON structure.
   The live API returns a bare JSON array of results; older/alternate
   endpoints wrap it as {"results": [...]}, so both shapes are handled. *)
OEISGetResult[json_] := Module[{entries},
  entries = Which[
    ListQ[json], json,
    AssociationQ[json], Lookup[json, "results", {}],
    True, {}
  ];
  If[ListQ[entries] && Length[entries] > 0, First[entries], Missing["NotFound"]]
];

(* Try several possible field names and return the first value that exists. *)
OEISLookupValue[entry_, names_List] := Module[{values},
  values = DeleteCases[Lookup[entry, #, Missing["NotFound"]] & /@ names, Missing["NotFound"], {1}];
  If[Length[values] > 0, First[values], Missing["NotFound"]]
];

(* Convert the raw terms returned by OEIS into a list of numeric values. *)
OEISParseTerms[raw_] := Module[{value = raw},
  If[MissingQ[value] || value === $Failed || value === "", Return[{}]];
  If[ListQ[value], value = value];
  If[AssociationQ[value], value = Lookup[value, "data", value]];
  value = ToString[value];
  value = StringReplace[value, {"[" -> "", "]" -> "", "{" -> "", "}" -> "", "(" -> "", ")" -> "", " " -> "", "\n" -> "", "\r" -> "", "\t" -> ""}];
  value = StringReplace[value, ";" -> ","];
  If[StringMatchQ[value, RegularExpression["^\\s*$"]], Return[{}]];
  value = StringSplit[value, ","];
  value = DeleteCases[value, ""];
  If[Length[value] == 0, Return[{}]];
  ToExpression[value]
];

(* Build the standard {n, value} pairs used by the package. *)
OEISMakePairs[terms_List, offset_Integer: 1] := MapIndexed[{offset + #2[[1]] - 1, #1} &, terms];

(* OEIS reports the offset as "start,digits" (e.g. "0,4"); only the
   leading number is the actual starting index n for the data terms. *)
OEISParseOffset[raw_] := Module[{value = raw, first},
  If[MissingQ[value] || value === $Failed, Return[1]];
  If[IntegerQ[value], Return[value]];
  first = First[StringSplit[ToString[value], ","], "1"];
  value = Quiet@Check[ToExpression[first], 1];
  If[IntegerQ[value], value, 1]
];

(* OEIS reports dates as ISO-8601 timestamps (e.g. "1991-04-30T03:00:00-04:00");
   this returns {monthShortName, day, year} for use in citation exports. *)
OEISParseDateTokens[raw_] := Module[{value = raw, dateObj},
  If[ListQ[value], value = If[Length[value] > 0, First[value], ""]];
  If[!StringQ[value] || StringLength[value] < 10, Return[{ToString[value]}]];
  dateObj = Quiet@Check[DateObject[DateList[StringTake[value, 10]], "Day"], $Failed];
  If[dateObj === $Failed, Return[{value}]];
  {DateString[dateObj, "MonthNameShort"], DateString[dateObj, "Day"], DateString[dateObj, "Year"]}
];

(* Fetch one complete OEIS entry for a given ID. *)
OEISGetEntry[ID_String] := Module[{json, result},
  json = OEISReadJSON[ID];
  If[json === $Failed, Return[$Failed]];
  result = OEISGetResult[json];
  If[MissingQ[result], Return[$Failed]];
  result
];

Options[OEISTotalNumberOfSequences] = {URL -> True};

(* Return an estimate of the number of OEIS sequences when possible. *)
OEISTotalNumberOfSequences[OptionsPattern[OEISTotalNumberOfSequences]] := OEISTotalNumberOfSequences[OptionsPattern[OEISTotalNumberOfSequences]] = Module[{urlQ, json, defaultvalue = 20000},
  urlQ = OptionValue[URL];
  If[Head[Element[urlQ, Booleans]] === Symbol,
    If[!urlQ, Return[defaultvalue]];
    json = Quiet@Check[OEISReadJSON["A000001"], $Failed];
    If[json === $Failed, Message[OEIS::conopen, OEISServerURL]; Return[defaultvalue]];
    Return[defaultvalue]
    ,
    Message[General::opttf, "URL", 1];
    Return[$Failed]
  ]
];

OEISTotalNumberOfSequences[];

(* Validate that the supplied identifier has the canonical OEIS shape, such as A000045. *)
OEISValidateIDQ[ID_String] := Module[{idNumber, ok},
  idNumber = Quiet@Check[ToExpression[StringDrop[ID, 1]], $Failed];
  ok = StringLength[ID] === 7 && StringTake[ID, 1] === "A" && NumberQ[idNumber];
  If[!ok, Message[OEIS::ID, ID]];
  ok
];

OEISValidateIDQ[ID_List] := And @@ (OEISValidateIDQ /@ ID);

OEISValidateIDQ[other_] := (Message[General::string, "ID", 1]; $Failed);

(* Main importer: retrieve the requested piece of information for one or more OEIS IDs. *)
OEISImport[ID_?OEISValidateIDQ, element_ : "Data"] := Module[{entry, result, offset, raw, terms},
  entry = OEISGetEntry[ID];
  Which[
    entry === $Failed,
      Message[OEIS::conopen, OEISJSONURL[ID]];
      Return[$Failed],

    element === "Data",
      raw = OEISLookupValue[entry, {"data", "seq", "values", "terms"}];
      terms = OEISParseTerms[raw];
      If[terms === {}, Return[{}]];
      offset = OEISParseOffset[OEISLookupValue[entry, {"offset", "start", "from"}]];
      result = OEISMakePairs[terms, offset];
      result,

    element === "Description",
      result = OEISLookupValue[entry, {"name", "title"}];
      If[MissingQ[result], result = ""];
      result,

    element === "Author",
      result = OEISLookupValue[entry, {"author", "createdby", "created_by"}];
      If[MissingQ[result], result = {}];
      If[!ListQ[result], result = {result}];
      result,

    element === "Date",
      result = OEISLookupValue[entry, {"date", "created", "updated"}];
      If[MissingQ[result] || result === "", Return[{""}]];
      OEISParseDateTokens[result],

    element === "Image",
      Message[OEIS::bFile, "Image data is not exposed by the official JSON API."];
      $Failed,

    element === "bFile",
      result = OEISImport[ID, "Data"];
      If[result === $Failed || result === {}, $Failed, result],

    element === "Offset" || element === "MinData",
      offset = OEISParseOffset[OEISLookupValue[entry, {"offset", "start", "from"}]];
      offset,

    element === "MaxData",
      result = OEISImport[ID, "Data"];
      If[result === $Failed || result === {}, $Failed, First[Last[result]]],

    True,
      Message[General::optx, element, 2];
      $Failed
  ]
];

SetAttributes[OEISImport, {Listable}];

Options[OEISURL] = {URL -> True, bFile -> False};

(* Build the sequence URL or the b-file URL, depending on the chosen option. *)
OEISURL[ID_?OEISValidateIDQ, OptionsPattern[OEISURL]] := Module[{urlQ, bfileQ, url = "", result = "", myid = ID},
  urlQ = OptionValue[URL];
  bfileQ = OptionValue[bFile];
  If[!(Head[Element[bfileQ, Booleans]] === Symbol),
    Message[General::opttf, "bFile", bfileQ];
    Return[$Failed]
  ];
  If[!(Head[Element[urlQ, Booleans]] === Symbol),
    Message[General::opttf, "URL", urlQ];
    Return[$Failed]
  ];
  If[bfileQ, myid = "b" <> StringDrop[ID, 1] <> ".txt", myid = ID];
  If[urlQ, url = OEISServerURL];
  result = url <> myid;
  Return[result]
];

Options[OEISFunction] = {AddHelp -> True, bFile -> True, Output -> True};

(* Create a function with the OEIS ID and preload the retrieved values. *)
OEISFunction[ID_?OEISValidateIDQ, OptionsPattern[OEISFunction]] := Module[{descriptionloaded, dataloaded, bfileloaded, bfileQ, addhelpQ, outputQ},
  addhelpQ = OptionValue[AddHelp];
  bfileQ = OptionValue[bFile];
  outputQ = OptionValue[Output];
  If[!(Head[Element[addhelpQ, Booleans]] === Symbol), Message[General::opttf, "AddHelp", addhelpQ]; Return[$Failed]];
  If[!(Head[Element[bfileQ, Booleans]] === Symbol), Message[General::opttf, "bFile", bfileQ]; Return[$Failed]];
  If[!(Head[Element[outputQ, Booleans]] === Symbol), Message[General::opttf, "Output", outputQ]; Return[$Failed]];

  descriptionloaded = Quiet[OEISImport[ID, "Description"]];
  If[descriptionloaded === $Failed || descriptionloaded === "",
    Return[$Failed],
    If[addhelpQ,
      ToExpression[ID <> "::usage=\"" <> StringReplace[descriptionloaded, "\"" -> "\\\""] <> "\";"]
    ];
    If[bfileQ,
      bfileloaded = Quiet[OEISImport[ID, "bFile"]],
      bfileloaded = {}
    ];
    If[bfileloaded === $Failed || !bfileQ, dataloaded = OEISImport[ID, "Data"], dataloaded = bfileloaded];
    Scan[With[{id = ID, n = #[[1]], v = #[[2]]}, ToExpression[id <> "[" <> ToString[n] <> "] = " <> ToString[v] <> ";"]] &, dataloaded];
    If[outputQ,
      Print[ID, "(n): ", descriptionloaded];
      Print["Link-1: ", Hyperlink[OEISURL[ID]]];
      If[bfileQ && bfileloaded =!= $Failed, Print["Link-2: ", Hyperlink[OEISURL[ID, bFile -> True]]]];
      Print["Help Added: ", addhelpQ || descriptionloaded === $Failed];
      Print["Loaded data from bFile: ", bfileQ && bfileloaded =!= $Failed];
      Print["Loaded data from Sequence: ", !bfileQ || bfileloaded === $Failed];
      Print["Data available: Table of n, ", ID, "(n) for n=", First[First[dataloaded]], "..", First[Last[dataloaded]]]
    ]
  ]
];

(* Export OEIS content in several useful formats such as help code, data files and citations. *)
OEISExport[ID_?OEISValidateIDQ, filename_] := Module[{myfileextension = ToLowerCase[FileExtension[filename]], myID, myhelpstring, myfilename, dataloaded, mybibtex, myhtmlcode, mywikicode},
  Which[
    MemberQ[{"gp", "m"}, myfileextension],
      If[ListQ[ID], myID = ID, myID = {ID}];
      myhelpstring = StringJoin[# , "::usage=\"", #, "[n]: ", OEISImport[#, "Description"], "\";"] & /@ myID;
      Export[filename, myhelpstring, "Text"],

    MemberQ[{"txt", "xls", "csv", "tsv", "dat"}, myfileextension],
      If[ListQ[ID], myID = ID, myID = {ID}];
      If[Length[myID] > 1, myfilename = Function[# <> "_" <> filename], myfilename = Function[filename]];
      dataloaded = Quiet[OEISImport[#, "bFile"]];
      If[dataloaded === $Failed, dataloaded = OEISImport[#, "Data"]];
      Export[myfilename[#], dataloaded] & /@ myID,

    MemberQ[{"jpg", "jpeg", "jp2", "j2k", "bmp", "pgn", "gif", "tiff", "tif"}, myfileextension],
      If[ListQ[ID],
        Export[# <> "_" <> filename, OEISImport[#, "Image"], "Image"] & /@ ID,
        Export[filename, OEISImport[ID, "Image"], "Image"]
      ],

    MemberQ[{"bib"}, myfileextension],
      If[ListQ[ID], myID = ID, myID = {ID}];
      mybibtex = (Module[{mydate, mymonth = {}, myyear = {}, myauthor, mydescription, mycitation},
        mydate = OEISImport[#, "Date"];
        If[Length[mydate] != 1, mymonth = mydate[[1]]; myyear = mydate[[3]]];
        myauthor = Flatten[OEISImport[#, "Author"]];
        mydescription = OEISImport[#, "Description"];
        mycitation = "@MISC{oeis" <> # <> "," <> "\n" <> "AUTHOR={" <> myauthor <> "}," <> "\n" <> "TITLE={The {O}n-{L}ine {E}ncyclopedia of {I}nteger {S}equences}," <> "\n" <> "HOWPUBLISHED={\\href{" <> OEISServerURL <> # <> "}{" <> # <> "}}," <> "\n" <> "MONTH={" <> mymonth <> "}," <> "\n" <> "YEAR={" <> myyear <> "}," <> "\n" <> "NOTE={" <> mydescription <> "}" <> "\n" <> "}" <> "\n";
        mycitation
      ]) & /@ myID;
      Export[filename, mybibtex, "Text"],

    MemberQ[{"htm", "html"}, myfileextension],
      If[ListQ[ID], myID = ID, myID = {ID}];
      myID = ({#, Part[myID, #]} & /@ Range[Length[myID]]);
      myhtmlcode = (Module[{separator, myauthor, mydescription, mycitation},
        myauthor = Flatten[OEISImport[#[[2]], "Author"]];
        If[Length[myauthor] == 1, separator = ", ", separator = ""];
        mydescription = OEISImport[#[[2]], "Description"];
        mycitation = "<a name=\"oeis" <> ToString[#[[2]]] <> "\">[" <> ToString[#[[1]]] <> "]-</a> " <> myauthor <> separator <> "The On-Line Encyclopedia of Integer Sequences. " <> "<a href=\"" <> OEISServerURL <> ToString[#[[2]]] <> "\">" <> ToString[#[[2]]] <> "</a>: " <> mydescription <> "<br/>";
        mycitation
      ]) & /@ myID;
      Export[filename, myhtmlcode, "Text"],

    MemberQ[{"wiki"}, myfileextension],
      If[ListQ[ID], myID = ID, myID = {ID}];
      myID = ({#, Part[myID, #]} & /@ Range[Length[myID]]);
      mywikicode = (Module[{mydescription, mycitation},
        mydescription = OEISImport[#[[2]], "Description"];
        mycitation = "* {{oeis|" <> ToString[#[[2]]] <> "}}: " <> mydescription;
        mycitation
      ]) & /@ myID;
      Export[filename, mywikicode, "Text"],

    True,
      Message[General::optx, filename, 2];
      Return[$Failed]
  ]
];

(* Write a b-file with the sequence values for indices MinData..VMax.
   If ID[n] is already defined in this session (e.g. the user wrote
   ID[n_] := ... before calling OEISbFile, as documented on the OEIS
   wiki), that local definition is used to compute every term up to
   VMax. Otherwise OEISFunction is used first to preload ID[n] with
   the data available from OEIS. *)
OEISbFile[ID_?OEISValidateIDQ, VMax_Integer, filename___] := Module[{mybfile, mybfilename, mydata, mymindata, idsymbol, predefinedQ},
  mymindata = OEISImport[ID, "MinData"];
  If[!IntegerQ[mymindata], mymindata = 1];
  If[filename === "Null" || filename === "", mybfilename = OEISURL[ID, URL -> False, bFile -> True], mybfilename = filename];
  idsymbol = Symbol[ID];
  predefinedQ = DownValues[Evaluate[idsymbol]] =!= {} || OwnValues[Evaluate[idsymbol]] =!= {};
  If[!predefinedQ, OEISFunction[ID, Output -> False]];
  mydata = Select[
    Table[{n, Quiet[idsymbol[n]]}, {n, mymindata, VMax}],
    NumericQ[#[[2]]] &
  ];
  If[mydata === {}, Return[$Failed]];
  mybfile = OpenWrite[mybfilename, BinaryFormat -> True, CharacterEncoding -> "Unicode"];
  WriteString[mybfile, ToString[#[[1]]] <> " " <> ToString[#[[2]]] <> "\n"] & /@ mydata;
  Close[mybfile]
];

End[];
Protect["`*"];
EndPackage[];
