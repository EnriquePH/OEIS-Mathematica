---
title: Function Index
---

# Function Index

Every public symbol `OEIS.m` exports, alphabetically. Each one links to its
generated reference notebook under
[`Documentation/English/ReferencePages/Symbols`](https://github.com/EnriquePH/OEIS-Mathematica/tree/master/Documentation/English/ReferencePages/Symbols),
which has runnable, real examples. For a guided walkthrough, see the
[Tutorial](index.md) instead.

| Function | Signature | Summary |
|---|---|---|
| [`OEISbFile`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISbFile.nb) | `OEISbFile[id, VMax, filename]` | Writes a b-file for `id(n)`, `n` from the sequence offset up to `VMax`. Uses a locally predefined `id[n_] := ...` when present; otherwise falls back to data already published on OEIS. |
| [`OEISCitation`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISCitation.nb) | `OEISCitation[id, format]` | A citation string for `id` in `"BibTeX"` or `"Wiki"` format, without writing to a file. `OEISExport`'s `.bib`/`.wiki` output is built from this. |
| [`OEISData`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISData.nb) | `OEISData[id]` | The full entry for `id` as an Association (`"ID"`, `"Description"`, `"Author"`, `"Date"`, `"Offset"`, `"Data"`, `"Formula"`) -- e.g. for `Dataset[OEISData[id]]`. Thin wrapper around `OEISImport[id, "Entry"]`. |
| [`OEISExport`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISExport.nb) | `OEISExport[id, filename]` | Exports sequence data or citation info, format chosen from `filename`'s extension: `.m`/`.gp`, `.txt`/`.csv`/`.tsv`/`.dat`, image formats, `.bib`, `.html`, `.wiki`. |
| [`OEISFunction`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISFunction.nb) | `OEISFunction[id, opts]` | Materializes `id[n]` in the current session, preloaded from OEIS, and adds a usage message from the sequence description. Options: `AddHelp`, `bFile`, `Output`. |
| [`OEISGraph`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISGraph.nb) | `OEISGraph[id]` | A `Graph` of `id` and the sequences `OEISRelated` finds for it, star-shaped around `id`. |
| [`OEISImport`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISImport.nb) | `OEISImport[id, element]` | Retrieves `"Data"`, `"Description"`, `"Author"`, `"Date"`, `"Offset"`/`"MinData"`, `"MaxData"`, `"bFile"` or `"Entry"` (every element bundled into one Association) for a sequence from the official JSON API. |
| [`OEISRandom`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISRandom.nb) | `OEISRandom[]` | The Entry Association for a randomly chosen OEIS sequence. |
| [`OEISRelated`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISRelated.nb) | `OEISRelated[id]` | The IDs OEIS cross-references from `id`'s entry (its "Cf. A000032, ..." comments). |
| [`OEISSearch`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISSearch.nb) | `OEISSearch[text]` / `OEISSearch[{n1,n2,...}]` | Search OEIS by free text or by a sequence of numbers; up to 10 results as a list of Entry Associations. |
| [`OEISSequence`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISSequence.nb) | `OEISSequence[id][property]` | A lazy object wrapping one ID. Properties: `"Values"`, `"Data"`, `"Plot"`, `"Description"`, `"Author"`, `"Date"`, `"Offset"`, `"Formula"`, `"Keywords"`, `"References"`, `"Related"`, `"Graph"`, `"Citation"`, `"URL"`, `"Entry"`. Nothing is fetched until a property is accessed. |
| [`OEISServerURL`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISServerURL.nb) | `OEISServerURL` | The base URL used to build every OEIS request (`"https://oeis.org/"`). |
| [`OEISTotalNumberOfSequences`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISTotalNumberOfSequences.nb) | `OEISTotalNumberOfSequences[]` | An estimate of how many sequences OEIS currently contains, by checking connectivity. Option: `URL`. |
| [`OEISURL`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISURL.nb) | `OEISURL[id, opts]` | Builds a sequence URL, or its b-file URL with `bFile -> True`. Options: `URL`, `bFile`. |
| [`OEISValidateIDQ`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISValidateIDQ.nb) | `OEISValidateIDQ[id]` | Checks that `id` (or every id in a list) has the canonical OEIS shape, `"A"` followed by 6 digits. |

## Option symbols

`AddHelp`, `bFile`, `Output`, `URL` are the option names used above; `URLType`
is declared but not currently used by any function.

## By task

- **Look up / validate:** `OEISValidateIDQ`, `OEISURL`, `OEISServerURL`, `OEISTotalNumberOfSequences`
- **Retrieve data:** `OEISImport`, `OEISFunction`, `OEISData`
- **Search and discover:** `OEISSearch`, `OEISRelated`, `OEISGraph`, `OEISRandom`
- **Structured objects:** `OEISSequence`
- **Write files:** `OEISExport`, `OEISbFile`
- **Citations:** `OEISCitation`, `OEISExport`
