(* ::Package:: *)

(* Backward-compatible loader.
   Since OEIS.m became a paclet (see PacletInfo.wl), the real source
   lives in Kernel/OEIS.wl. This file is kept so that
     Get["OEIS.m"]
   and
     <<OEIS`
   from this directory keep working exactly as before. Prefer
   PacletDirectoryLoad+Needs["OEIS`"], or installing the built paclet,
   for new code. *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "Kernel", "OEIS.wl"}]];
