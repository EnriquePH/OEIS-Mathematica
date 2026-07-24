---
title: OEIS.m Tutorial
---

# OEIS.m Tutorial

A step-by-step walkthrough of [`OEIS.m`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/OEIS.m), the Wolfram Language package for working with [OEIS](https://oeis.org/) data. Every example on this page was run against the live OEIS JSON API with `wolframscript` — the printed output is real, not illustrative.

The runnable version of this tutorial lives at [`test/OEISTutorial.wl`](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/test/OEISTutorial.wl) and doubles as an integration test: run it yourself with

```
wolframscript -file test/OEISTutorial.wl
```

The original package page, with its own usage examples, is on the OEIS wiki: [User:Enrique Pérez Herrero/OEIS Package](https://oeis.org/wiki/User:Enrique_P%C3%A9rez_Herrero/OEIS_Package).

## 1. Load the package

```wl
Needs["OEIS`"]
```

Place `OEIS.m` on your `$Path`, or `Get` it directly:

```wl
Get["/path/to/OEIS.m"]
```

## 2. Validate an OEIS identifier

`OEISValidateIDQ` checks that a string has the canonical `A` + 6-digit shape used by OEIS.

```wl
OEISValidateIDQ["A000045"]
(* True *)
```

## 3. Build the sequence URL

```wl
OEISURL["A000045"]
(* "https://oeis.org/A000045" *)
```

Pass `bFile -> True` to get the b-file URL instead:

```wl
OEISURL["A000045", bFile -> True]
(* "https://oeis.org/b000045.txt" *)
```

## 4. Retrieve a sequence's description

```wl
OEISImport["A000045", "Description"]
(* "Fibonacci numbers: F(n) = F(n-1) + F(n-2) with F(0) = 0 and F(1) = 1." *)
```

## 5. Retrieve the terms of a sequence

`OEISImport[ID, "Data"]` returns `{n, a(n)}` pairs, correctly offset to the sequence's actual starting index (A000045 starts at n = 0, not n = 1):

{% raw %}
```wl
OEISImport["A000045", "Data"][[1 ;; 5]]
(* {{0, 0}, {1, 1}, {2, 1}, {3, 2}, {4, 3}} *)
```
{% endraw %}

## 6. Inspect the available range

```wl
{OEISImport["A000045", "MinData"], OEISImport["A000045", "MaxData"]}
(* {0, 40} *)
```

## 7. Materialize a function from an OEIS sequence

`OEISFunction` defines `A000045[n]` in your session, preloaded with real data, and prints a short report:

```wl
OEISFunction["A000045"]
```

```
A000045(n): Fibonacci numbers: F(n) = F(n-1) + F(n-2) with F(0) = 0 and F(1) = 1.
Link-1: https://oeis.org/A000045
Link-2: https://oeis.org/b000045.txt
Help Added: True
Loaded data from bFile: True
Loaded data from Sequence: False
Data available: Table of n, A000045(n) for n=0..40
```

```wl
A000045[10]
(* 55 *)
```

## 8. Export data and citations

`OEISExport` picks the output format from the file extension.

**Wolfram help stub (`.m`):**

```wl
OEISExport["A000045", "A000045.m"]
```
```
A000045::usage="A000045[n]: Fibonacci numbers: F(n) = F(n-1) + F(n-2) with F(0) = 0 and F(1) = 1.";
```

**BibTeX citation (`.bib`):**

```wl
OEISExport["A000045", "A000045.bib"]
```
```bibtex
@MISC{oeisA000045,
AUTHOR={_N. J. A. Sloane_, 1964},
TITLE={The {O}n-{L}ine {E}ncyclopedia of {I}nteger {S}equences},
HOWPUBLISHED={\href{https://oeis.org/A000045}{A000045}},
MONTH={Apr},
YEAR={1991},
NOTE={Fibonacci numbers: F(n) = F(n-1) + F(n-2) with F(0) = 0 and F(1) = 1.}
}
```

**HTML citation (`.html`) and MediaWiki citation (`.wiki`)** work the same way, and every `OEISExport`/`OEISImport` function accepts a list of IDs to batch-process several sequences at once.

## 9. Search OEIS

`OEISSearch[text]` searches by free text; `OEISSearch[{n1,n2,...}]` searches by a sequence of numbers. Both hit the same JSON endpoint `OEISImport` uses for ID lookup, just with a different query, and return up to 10 results (OEIS's default page size) as a list of Entry Associations:

```wl
OEISSearch["prime gaps"][[1]]["ID"]
(* "A001223" *)

First[OEISSearch[{1, 1, 2, 3, 5, 8, 13}]]["ID"]
(* "A000045" *)
```

## 10. Related sequences and citations without a file

`OEISRelated` parses the IDs OEIS cross-references from an entry's `"xref"` field (its "Cf. A000032, ..." comments):

```wl
OEISRelated["A000045"][[1 ;; 5]]
(* {"A001622", "A039834", "A001519", "A001906", "A001690"} *)
```

`OEISCitation[id, format]` returns a citation string directly, without writing to a file -- `OEISExport`'s `.bib`/`.wiki` output is built from it:

{% raw %}
```wl
OEISCitation["A000045", "Wiki"]
(* "* {{oeis|A000045}}: Fibonacci numbers: F(n) = F(n-1) + F(n-2) with F(0) = 0 and F(1) = 1." *)
```
{% endraw %}

## 11. Structured data

`OEISData[id]` is a thin wrapper around `OEISImport[id, "Entry"]` -- the whole entry as one Association, e.g. for `Dataset[OEISData[id]]`:

```wl
Keys[OEISData["A000045"]]
(* {"ID", "Description", "Author", "Date", "Offset", "Data", "Formula"} *)
```

## 12. The OEISSequence object

`OEISSequence[id]` is a lazy object wrapping one ID: nothing is fetched until a property is actually accessed.

```wl
seq = OEISSequence["A000045"];
seq["Values"][[1 ;; 10]]
(* {0, 1, 1, 2, 3, 5, 8, 13, 21, 34} *)
```

`"Values"` gives just the a(n) values, unlike `"Data"`, which pairs them with n. `"Keywords"` gives OEIS's own classification keywords:

```wl
seq["Keywords"]
(* {"nonn", "core", "nice", "easy", "hear", "changed"} *)
```

Other properties: `"Data"`, `"Plot"`, `"Description"`, `"Author"`, `"Date"`, `"Offset"`, `"Formula"`, `"References"` (literature references -- distinct from `"Related"`), `"Related"`, `"Graph"`, `"Citation"`, `"URL"`, `"Entry"`.

## 13. Graph of related sequences

`OEISGraph[id]` returns a `Graph` of `id` and the sequences `OEISRelated` finds for it, star-shaped around `id` -- built from the one fetch `OEISRelated` already makes, no extra network calls per related sequence:

```wl
g = OEISGraph["A000045"];
{VertexCount[g], EdgeCount[g]}
(* {90, 89} *)
```

## 14. A random sequence

OEIS has no dedicated random-sequence endpoint, so `OEISRandom[]` picks a random A-number and retries on a miss (a withdrawn/merged/not-yet-assigned number), returning the Entry Association for whatever it lands on:

```wl
Keys[OEISRandom[]]
(* {"ID", "Description", "Author", "Date", "Offset", "Data", "Formula"} *)
```

## Environment note: broken CURLLink on Linux

If `Import`/`URLFetch` fail with `curlLink_initialize was not loaded` or `OEIS::conopen` even though the network is reachable, your Wolfram Engine's bundled `libcurllink.so` is likely incompatible with the system's OpenSSL (common on older Mathematica installs paired with a modern Linux distro). `OEIS.m` already works around this: `OEISReadJSON` automatically falls back to invoking the system's `curl` (with `LD_LIBRARY_PATH` cleared, since Mathematica otherwise makes `curl` load its own bundled, older `libcurl`) whenever the built-in HTTP client fails.

## Reference

| Function | Purpose |
|---|---|
| `OEISValidateIDQ` | Validate an OEIS identifier's shape |
| `OEISImport` | Retrieve data, description, author, date, offset, etc. |
| `OEISURL` | Build a sequence or b-file URL |
| `OEISFunction` | Materialize `ID[n]` in your session |
| `OEISExport` | Export to `.m`, `.txt`/`.csv`/`.tsv`, `.bib`, `.html`, `.wiki`, images |
| `OEISbFile` | Write a b-file for a given ID up to a maximum index |
| `OEISSearch` | Search by free text or by a sequence of numbers |
| `OEISRelated` | IDs OEIS cross-references from an entry |
| `OEISGraph` | A `Graph` of a sequence and its cross-references |
| `OEISRandom` | The Entry Association for a randomly chosen sequence |
| `OEISData` | The full entry as an Association, e.g. for `Dataset` |
| `OEISCitation` | A `"BibTeX"`/`"Wiki"` citation string, without writing to a file |
| `OEISSequence` | A lazy object wrapping one ID, with `Plot`/`Values`/`Formula`/... properties |

See the [Function Index](functions.md) for full signatures and options, the [README](https://github.com/EnriquePH/OEIS-Mathematica#readme) for installation and project status, and [CONTRIBUTING.md](https://github.com/EnriquePH/OEIS-Mathematica/blob/master/CONTRIBUTING.md) to send improvements.
