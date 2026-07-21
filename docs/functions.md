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
| [`OEISExport`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISExport.nb) | `OEISExport[id, filename]` | Exports sequence data or citation info, format chosen from `filename`'s extension: `.m`/`.gp`, `.txt`/`.csv`/`.tsv`/`.dat`, image formats, `.bib`, `.html`, `.wiki`. |
| [`OEISFunction`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISFunction.nb) | `OEISFunction[id, opts]` | Materializes `id[n]` in the current session, preloaded from OEIS, and adds a usage message from the sequence description. Options: `AddHelp`, `bFile`, `Output`. |
| [`OEISImport`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISImport.nb) | `OEISImport[id, element]` | Retrieves `"Data"`, `"Description"`, `"Author"`, `"Date"`, `"Offset"`/`"MinData"`, `"MaxData"` or `"bFile"` for a sequence from the official JSON API. |
| [`OEISServerURL`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISServerURL.nb) | `OEISServerURL` | The base URL used to build every OEIS request (`"https://oeis.org/"`). |
| [`OEISTotalNumberOfSequences`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISTotalNumberOfSequences.nb) | `OEISTotalNumberOfSequences[]` | An estimate of how many sequences OEIS currently contains, by checking connectivity. Option: `URL`. |
| [`OEISURL`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISURL.nb) | `OEISURL[id, opts]` | Builds a sequence URL, or its b-file URL with `bFile -> True`. Options: `URL`, `bFile`. |
| [`OEISValidateIDQ`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/Documentation/English/ReferencePages/Symbols/OEISValidateIDQ.nb) | `OEISValidateIDQ[id]` | Checks that `id` (or every id in a list) has the canonical OEIS shape, `"A"` followed by 6 digits. |

## Option symbols

`AddHelp`, `bFile`, `Output`, `URL` are the option names used above; `URLType`
is declared but not currently used by any function.

## By task

- **Look up / validate:** `OEISValidateIDQ`, `OEISURL`, `OEISServerURL`, `OEISTotalNumberOfSequences`
- **Retrieve data:** `OEISImport`, `OEISFunction`
- **Write files:** `OEISExport`, `OEISbFile`
