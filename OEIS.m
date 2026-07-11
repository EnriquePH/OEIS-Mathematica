(* ::Package:: *)

(* ::Section:: *)
(*(*OEIS Package: Title and comments*)*)

(* :Title: Package OEIS *)
(* :Context: Utilities`OEIS` *)
(* :Author: Enrique Pérez Herrero *)
(* :Summary:
    Lightweight access to OEIS sequence data through the official JSON API.
*)
(* :Package Version: 3.0 *)
(* :Mathematica Version: 11.0.0.0 *)
(* :Links:
The OEIS Foundation Inc:            https://oeisf.org/
OEIS:                               https://oeis.org/
*)
(* :History:
    V. 3.0 11 Jul 2026, by Copilot. Rebuilt around the official OEIS JSON API.
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

ClearAll[OEISJSONURL, OEISReadJSON, OEISGetResult, OEISLookupValue, OEISParseTerms, OEISMakePairs, OEISGetEntry];

(* Build the official OEIS search URL for a given sequence ID. *)
OEISJSONURL[ID_String] := OEISServerURL <> "search?q=id:" <> ID <> "&fmt=json";

(* Download and parse the JSON payload returned by OEIS. *)
OEISReadJSON[ID_String] := Quiet@Check[Import[OEISJSONURL[ID], "JSON"], $Failed];

(* Extract the first result entry from the returned JSON structure. *)
OEISGetResult[json_] := Module[{entries},
  entries = If[AssociationQ[json], Lookup[json, "results", {}], {}];
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
      offset = Quiet@Check[ToExpression[OEISLookupValue[entry, {"offset", "start", "from"}]], 1];
      If[!IntegerQ[offset], offset = 1];
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
      If[MissingQ[result] || result === "", result = {""}];
      If[!ListQ[result], result = {result}];
      result,

    element === "Image",
      Message[OEIS::bFile, "Image data is not exposed by the official JSON API."];
      $Failed,

    element === "bFile",
      result = OEISImport[ID, "Data"];
      If[result === $Failed || result === {}, $Failed, result],

    element === "Offset" || element === "MinData",
      offset = Quiet@Check[ToExpression[OEISLookupValue[entry, {"offset", "start", "from"}]], 1];
      If[!IntegerQ[offset], offset = 1];
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

(* Write a simple b-file with the sequence values for a range of indices. *)
OEISbFile[ID_?OEISValidateIDQ, VMax_Integer, filename___] := Module[{mybfiledata, mybfilename, mydata, mymindata},
  mymindata = OEISImport[ID, "MinData"];
  If[filename === "Null" || filename === "", mybfilename = OEISURL[ID, URL -> False, bFile -> True], mybfilename = filename];
  OEISFunction[ID, Output -> False];
  mydata = Select[OEISImport[ID, "Data"], #[[1]] <= VMax && #[[1]] >= mymindata &];
  If[mydata === $Failed || mydata === {}, Return[$Failed]];
  mybfile = OpenWrite[mybfilename, BinaryFormat -> True, CharacterEncoding -> "Unicode"];
  WriteString[mybfile, ToString[#[[1]]] <> " " <> ToString[#[[2]]] <> "\n"] & /@ mydata;
  Close[mybfile]
];

End[];
Protect["`*"];
EndPackage[];
