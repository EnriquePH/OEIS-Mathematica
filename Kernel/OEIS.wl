(* ::Package:: *)

(* ::Section:: *)
(*(*OEIS Package: Title and comments*)*)

(* :Title: Package OEIS *)
(* :Context: Utilities`OEIS` *)
(* :Author: Enrique Pérez Herrero *)
(* :Summary:
    Lightweight access to OEIS sequence data through the official JSON API.
*)
(* :Package Version: 3.1.0 *)
(* :Mathematica Version: 11.0.0.0 *)
(* :Links:
The OEIS Foundation Inc:            https://oeisf.org/
OEIS:                               https://oeis.org/
*)
(* :History:
    V. 3.0.0 11 Jul 2026, by Copilot. Rebuilt around the official OEIS JSON API.
    V. 3.0.1 11 Jul 2026. Fixed JSON result parsing (the live API returns a
      bare array, not a {"results": [...]} wrapper), fixed offset parsing
      ("start,digits" strings), fixed BibTeX date parsing (ISO-8601
      timestamps), and added a curl-based fallback for HTTP fetches when
      Mathematica's built-in client is unavailable.
    V. 3.1.0 21 Jul 2026. Converted to a proper Wolfram Language paclet
      (PacletInfo.wl, Kernel/init.m); source moved to Kernel/OEIS.wl.
      OEIS.m at the repository root is kept as a thin backward-compatible
      loader for `Get["OEIS.m"]` users. Fixed OEISbFile so a locally
      predefined ID[n_] is used to compute terms up to VMax, instead of
      truncating to whatever data OEIS already has published. See
      CHANGELOG.md for details.
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
OEISData::usage = "OEISData[ID] returns the full OEIS entry for ID as an Association, e.g. for Dataset[OEISData[ID]].";
OEISSearch::usage = "OEISSearch[text] searches OEIS by free text; OEISSearch[{n1,n2,...}] searches by a sequence of numbers. Returns a list of Entry Associations.";
OEISRelated::usage = "OEISRelated[ID] returns the IDs of sequences OEIS cross-references from ID's entry.";
OEISCitation::usage = "OEISCitation[ID,format] returns a citation string for ID in the given format (\"BibTeX\" or \"Wiki\").";
OEISRandom::usage = "OEISRandom[] returns the Entry Association for a randomly chosen OEIS sequence.";
OEISGraph::usage = "OEISGraph[ID] returns a Graph of ID and the sequences it cross-references, from OEISRelated.";
OEISSequence::usage = "OEISSequence[ID] represents an OEIS sequence; OEISSequence[ID][\"Property\"] accesses \"Values\", \"Data\", \"Plot\", \"Description\", \"Author\", \"Date\", \"Offset\", \"Formula\", \"Keywords\", \"References\", \"Related\", \"Citation\", \"URL\" or \"Entry\".";

bFile::usage = "bFile";
URL::usage = "URL";
URLType::usage = "URLType";
AddHelp::usage = "AddHelp";
Output::usage = "Output";

OEIS::conopen = "Cannot connect to OEIS Server: `1`";
OEIS::bFile = "Cannot read OEIS data from the official JSON API: `1`";
OEIS::ID = "`1` is not a valid OEIS ID";
OEIS::random = "Could not find a valid random sequence after `1` attempts.";

Unprotect["`*"]; 
Begin["`Private`"];

OEISServerURL = "https://oeis.org/";

ClearAll[OEISJSONURL, OEISQueryURL, OEISReadJSON, OEISReadJSONQuery, OEISReadJSONViaCurl, OEISReadJSONViaCurlQuery, OEISGetResult, OEISGetResults, OEISFormatID, OEISEntryAssociation, OEISLookupValue, OEISParseTerms, OEISMakePairs, OEISParseOffset, OEISParseDateTokens, OEISRequest];

(* Build the official OEIS search URL for an arbitrary query string, e.g.
   "id:A000045", a free-text search or a comma-joined list of terms --
   ID lookup is just the "id:ID" special case of a general OEIS search. *)
OEISQueryURL[query_String] := OEISServerURL <> "search?q=" <> query <> "&fmt=json";
OEISJSONURL[ID_String] := OEISQueryURL["id:" <> ID];

(* Download and parse the JSON payload returned by OEIS for an arbitrary
   query. Falls back to an external curl call when Mathematica's built-in
   HTTP client cannot be used (e.g. a broken/mismatched CURLLink on some
   Linux installs), so the package keeps working either way. *)
OEISReadJSONQuery[query_String] := Module[{result},
  result = Quiet@Check[Import[OEISQueryURL[query], "JSON"], $Failed];
  If[result === $Failed, result = OEISReadJSONViaCurlQuery[query]];
  result
];
OEISReadJSON[ID_String] := OEISReadJSONQuery["id:" <> ID];

OEISReadJSONViaCurlQuery[query_String] := Module[{proc},
  (* Mathematica prepends its own bundled libraries to LD_LIBRARY_PATH,
     which can make an external curl load an incompatible libcurl.so;
     unset it in the subshell so the system's own curl runs cleanly. *)
  proc = Quiet@Check[
    RunProcess[{"bash", "-c", "unset LD_LIBRARY_PATH; exec curl -sS --max-time 20 \"$1\"", "curl-oeis", OEISQueryURL[query]}],
    $Failed
  ];
  If[proc === $Failed || proc["ExitCode"] =!= 0, Return[$Failed]];
  Quiet@Check[ImportString[proc["StandardOutput"], "JSON"], $Failed]
];
OEISReadJSONViaCurl[ID_String] := OEISReadJSONViaCurlQuery["id:" <> ID];

(* Normalize the JSON structure OEIS returns into a plain list of result
   entries. The live API returns a bare JSON array of results;
   older/alternate endpoints wrap it as {"results": [...]}, so both
   shapes are handled. *)
OEISGetResults[json_] := Which[
  ListQ[json], json,
  AssociationQ[json], Lookup[json, "results", {}],
  True, {}
];

(* Extract just the first result entry, for the common single-ID case. *)
OEISGetResult[json_] := Module[{entries = OEISGetResults[json]},
  If[ListQ[entries] && Length[entries] > 0, First[entries], Missing["NotFound"]]
];

(* OEIS search results report the sequence number as a plain integer
   (e.g. 45), not the canonical "A000045" ID string -- and confusingly,
   the JSON "id" field is the *legacy* Handbook of Integer Sequences
   M/N-number (e.g. "M0692 N0256"), not an A-number at all. *)
OEISFormatID[number_Integer] := "A" <> StringPadLeft[ToString[number], 6, "0"];

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

(* Build the normalized "Entry" Association directly from an already-
   fetched raw JSON entry -- no network access here, so it is safe to
   call for every result of a multi-result OEISSearch as well as for
   the single-ID OEISImport[ID,"Entry"], without triggering any extra
   fetches. "Formula" is the one field not exposed as its own element,
   only here (and via OEISCitation, which reads it from this same
   Association). *)
OEISEntryAssociation[ID_String, entry_] := Module[
  {raw, terms, offset, description, author, date, formula},
  raw = OEISLookupValue[entry, {"data", "seq", "values", "terms"}];
  terms = OEISParseTerms[raw];
  offset = OEISParseOffset[OEISLookupValue[entry, {"offset", "start", "from"}]];

  description = OEISLookupValue[entry, {"name", "title"}];
  If[MissingQ[description], description = ""];

  author = OEISLookupValue[entry, {"author", "createdby", "created_by"}];
  Which[MissingQ[author], author = {}, !ListQ[author], author = {author}];

  date = OEISLookupValue[entry, {"date", "created", "updated"}];
  date = If[MissingQ[date] || date === "", {""}, OEISParseDateTokens[date]];

  formula = OEISLookupValue[entry, {"formula"}];
  formula = Which[MissingQ[formula], {}, ListQ[formula], formula, True, {formula}];

  <|
    "ID" -> ID,
    "Description" -> description,
    "Author" -> author,
    "Date" -> date,
    "Offset" -> offset,
    "Data" -> If[terms === {}, {}, OEISMakePairs[terms, offset]],
    "Formula" -> formula
  |>
];

(* Single point of contact with the network: fetches and validates one
   complete OEIS entry for a given ID, memoized for the rest of the
   session so that OEISImport/OEISFunction/OEISExport/OEISbFile -- which
   each ask for several elements of the same ID in turn -- only hit the
   network once per ID, not once per element. Only successful lookups
   are cached (via the assignment on the last line); a $Failed result
   is returned but deliberately left unmemoized, so a transient network
   or server problem doesn't permanently poison the cache for the rest
   of the session. *)
OEISRequest[ID_String] := Module[{json, result},
  json = OEISReadJSON[ID];
  If[json === $Failed, Return[$Failed]];
  result = OEISGetResult[json];
  If[MissingQ[result], Return[$Failed]];
  OEISRequest[ID] = result
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
  entry = OEISRequest[ID];
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

    element === "Entry",
      (* A single Association bundling every element, for callers who
         want the whole entry at once. Built by OEISEntryAssociation,
         the same helper OEISSearch uses for its (possibly many)
         results, so this can never drift out of sync with what each
         element returns on its own. *)
      OEISEntryAssociation[ID, entry],

    True,
      Message[General::optx, element, 2];
      $Failed
  ]
];

SetAttributes[OEISImport, {Listable}];

(* Convenience wrapper: the full Entry Association for one or more IDs,
   e.g. for Dataset[OEISData["A000045"]] or Dataset[OEISData[{"A000045",
   "A000040"}]] (Listable, like OEISImport). *)
OEISData[ID_?OEISValidateIDQ] := OEISImport[ID, "Entry"];
SetAttributes[OEISData, {Listable}];

(* Search OEIS by free text (OEISSearch["prime gaps"]) or by a sequence
   of numbers (OEISSearch[{1,1,2,3,5}]), returning up to OEIS's default
   page size (10) of results as a list of Entry Associations -- built
   directly from this one search response via OEISEntryAssociation, so
   none of the results trigger any further per-ID network fetches. *)
OEISSearch[query_String] := OEISSearchQuery[URLEncode[query]];
OEISSearch[query : {__?NumericQ}] := OEISSearchQuery[StringRiffle[ToString /@ query, ","]];

OEISSearchQuery[q_String] := Module[{json, entries},
  json = OEISReadJSONQuery[q];
  If[json === $Failed, Message[OEIS::conopen, OEISQueryURL[q]]; Return[$Failed]];
  entries = OEISGetResults[json];
  If[entries === {}, Return[{}]];
  OEISEntryAssociation[OEISFormatID[OEISLookupValue[#, {"number"}]], #] & /@ entries
];

(* IDs of sequences OEIS cross-references from this one's "xref" field
   (its "Cf. A000032, ..." / "See also A001622" style comments), e.g.
   for building a graph of related sequences. Order follows appearance
   in the xref text; duplicates removed. *)
OEISRelated[ID_?OEISValidateIDQ] := Module[{entry, xref},
  entry = OEISRequest[ID];
  If[entry === $Failed, Message[OEIS::conopen, OEISJSONURL[ID]]; Return[$Failed]];
  xref = OEISLookupValue[entry, {"xref"}];
  If[MissingQ[xref], Return[{}]];
  If[!ListQ[xref], xref = {xref}];
  DeleteDuplicates[DeleteCases[StringCases[StringRiffle[xref, " "], RegularExpression["A[0-9]{6}"]], ID]]
];

(* A Graph of ID and the sequences it cross-references (from
   OEISRelated), star-shaped around ID. Uses only the single fetch
   OEISRelated already makes -- does not also fetch each related
   sequence's own cross-references, which would mean one additional
   network round-trip per related ID (up to ~90 for a well-referenced
   sequence like A000045) just to draw a graph. *)
OEISGraph[ID_?OEISValidateIDQ] := Module[{related},
  related = OEISRelated[ID];
  If[related === $Failed, Return[$Failed]];
  If[related === {},
    Graph[{ID}, {}, VertexLabels -> "Name"],
    Graph[
      Prepend[related, ID],
      UndirectedEdge[ID, #] & /@ related,
      VertexLabels -> "Name",
      VertexStyle -> {ID -> Orange},
      GraphLayout -> "SpringElectricalEmbedding"
    ]
  ]
];

(* No dedicated "random sequence" endpoint exists on OEIS, so this picks
   a random A-number and retries on a miss (a withdrawn/merged/not-yet-
   assigned number). 420000 is a deliberately generous, hand-padded
   upper bound (OEIS held ~397,692 sequences as of 2026-07-23) so this
   keeps working without adjustment as the database grows; it only
   costs a few extra retries once the real max is closer to it. *)
OEISRandom[] := Module[{maxAttempts = 25, maxID = 420000, id, entry, found = $Failed},
  Do[
    id = OEISFormatID[RandomInteger[{1, maxID}]];
    entry = OEISRequest[id];
    If[entry =!= $Failed, found = OEISEntryAssociation[id, entry]; Break[]],
    {maxAttempts}
  ];
  If[found === $Failed, Message[OEIS::random, maxAttempts]];
  found
];

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

(* A single citation string for one ID, in the same formats OEISExport
   writes to file ("BibTeX", "Wiki"/"MediaWiki") -- used by both, so
   the two can never drift apart. *)
OEISCitation[ID_?OEISValidateIDQ, format_String : "BibTeX"] := Module[
  {entry, description, author, date, month = {}, year = {}},
  entry = OEISImport[ID, "Entry"];
  If[entry === $Failed, Return[$Failed]];
  description = entry["Description"];
  author = entry["Author"];
  date = entry["Date"];
  If[Length[date] != 1, month = date[[1]]; year = date[[3]]];
  Which[
    format === "BibTeX",
      "@MISC{oeis" <> ID <> "," <> "\n" <> "AUTHOR={" <> author <> "}," <> "\n" <> "TITLE={The {O}n-{L}ine {E}ncyclopedia of {I}nteger {S}equences}," <> "\n" <> "HOWPUBLISHED={\\href{" <> OEISServerURL <> ID <> "}{" <> ID <> "}}," <> "\n" <> "MONTH={" <> month <> "}," <> "\n" <> "YEAR={" <> year <> "}," <> "\n" <> "NOTE={" <> description <> "}" <> "\n" <> "}" <> "\n",

    format === "Wiki" || format === "MediaWiki",
      "* {{oeis|" <> ID <> "}}: " <> description,

    True,
      Message[General::optx, format, 2];
      $Failed
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
      mybibtex = OEISCitation[#, "BibTeX"] & /@ myID;
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
      mywikicode = OEISCitation[#, "Wiki"] & /@ myID;
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

(* A lazy object wrapping one OEIS ID: OEISSequence[ID] does no network
   access by itself (matches OEISSequence["invalid"] being constructible
   without erroring, just like ID strings are accepted unvalidated
   elsewhere until actually used) -- each OEISSequence[ID]["Property"]
   call below validates ID the same way every other public function
   here does (ID_?OEISValidateIDQ, which itself messages OEIS::ID and
   fails the pattern match on an invalid ID), and reads from the same
   OEISRequest-memoized fetch, so mixing OEISSequence[ID][...] calls
   with plain OEISImport[ID, ...] calls for the same ID still only
   costs one network round-trip. *)
OEISSequence[ID_?OEISValidateIDQ]["ID"] := ID;
OEISSequence[ID_?OEISValidateIDQ]["Entry"] := OEISImport[ID, "Entry"];
OEISSequence[ID_?OEISValidateIDQ]["Description"] := OEISImport[ID, "Description"];
OEISSequence[ID_?OEISValidateIDQ]["Author"] := OEISImport[ID, "Author"];
OEISSequence[ID_?OEISValidateIDQ]["Date"] := OEISImport[ID, "Date"];
OEISSequence[ID_?OEISValidateIDQ]["Offset"] := OEISImport[ID, "Offset"];
OEISSequence[ID_?OEISValidateIDQ]["Data"] := OEISImport[ID, "Data"];
OEISSequence[ID_?OEISValidateIDQ]["Formula"] := OEISImport[ID, "Entry"]["Formula"];
OEISSequence[ID_?OEISValidateIDQ]["Related"] := OEISRelated[ID];
OEISSequence[ID_?OEISValidateIDQ]["Graph"] := OEISGraph[ID];
OEISSequence[ID_?OEISValidateIDQ]["Citation"] := OEISCitation[ID, "BibTeX"];
OEISSequence[ID_?OEISValidateIDQ]["URL"] := OEISURL[ID];

(* Just the a(n) values, dropping the n index OEISImport[ID,"Data"] pairs
   with -- a natural complement to "Data" for callers who only want the
   numbers themselves. *)
OEISSequence[ID_?OEISValidateIDQ]["Values"] := Module[{data = OEISImport[ID, "Data"]},
  If[data === $Failed || data === {}, data, data[[All, 2]]]
];

OEISSequence[ID_?OEISValidateIDQ]["Keywords"] := Module[{entry = OEISRequest[ID], keyword},
  If[entry === $Failed, Return[$Failed]];
  keyword = OEISLookupValue[entry, {"keyword"}];
  If[MissingQ[keyword], {}, StringSplit[keyword, ","]]
];

OEISSequence[ID_?OEISValidateIDQ]["References"] := Module[{entry = OEISRequest[ID], reference},
  If[entry === $Failed, Return[$Failed]];
  reference = OEISLookupValue[entry, {"reference"}];
  Which[MissingQ[reference], {}, ListQ[reference], reference, True, {reference}]
];

OEISSequence[ID_?OEISValidateIDQ]["Plot"] := Module[{data = OEISImport[ID, "Data"]},
  If[data === $Failed || data === {}, $Failed,
    ListPlot[data, PlotLabel -> ID, Frame -> True, FrameLabel -> {"n", "a(n)"}, Joined -> True]
  ]
];

End[];
Protect["`*"];
EndPackage[];
