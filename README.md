# OEIS-Mathematica

![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Wolfram Language](https://img.shields.io/badge/Wolfram-Language%2011%2F13%2F14-ff6b6b.svg)
![Package](https://img.shields.io/badge/Package-OEIS.m-success.svg)

Multipurpose package for using OEIS data from Wolfram Language.

This repository contains OEIS.m version 3.0, a streamlined package that uses the
official OEIS JSON API instead of scraping HTML pages. It is designed to work on
Wolfram Language 11, 13 and 14, and keeps the public functions of the earlier
package while being shorter, faster and more robust to future site changes.

The package exposes utilities to retrieve sequence descriptions, values, authors,
dates and export data in several formats such as BibTeX, HTML or plain text.

## Features

- Access to OEIS sequence metadata through the official JSON API
- Compatible with Wolfram Language 11, 13 and 14
- Lightweight and easier to maintain than the previous HTML-based implementation
- Support for common package operations such as validation, import and export

## Tutorial

A full walkthrough with real, verified output is available at
[EnriquePH.github.io/OEIS-Mathematica](https://enriqueph.github.io/OEIS-Mathematica/).
The runnable source for that tutorial is [test/OEISTutorial.wl](test/OEISTutorial.wl):

```
wolframscript -file test/OEISTutorial.wl
```

## Quick start

Load the package in a Wolfram notebook with:

```wl
<<OEIS`
```

Example:

```wl
OEISImport["A000045", "Description"]
```

## Main functions

- OEISTotalNumberOfSequences
- OEISValidateIDQ
- OEISImport
- OEISURL
- OEISFunction
- OEISExport
- OEISbFile

## Project status

- Package file: OEIS.m
- Documentation: README.md
- License: LICENSE

## Citation

If you use this package in a project or publication, please cite it using the metadata in [CITATION.cff](CITATION.cff).

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## Code of Conduct

Please review [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before participating in the project.

## License

This project is distributed under the GNU General Public License v3.0.

