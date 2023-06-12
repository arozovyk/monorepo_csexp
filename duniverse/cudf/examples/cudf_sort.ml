(*****************************************************************************)
(*  libCUDF - CUDF (Common Upgrade Description Format) manipulation library  *)
(*  Copyright (C) 2009  Stefano Zacchiroli <zack@pps.jussieu.fr>             *)
(*                                                                           *)
(*  This library is free software: you can redistribute it and/or modify     *)
(*  it under the terms of the GNU Lesser General Public License as           *)
(*  published by the Free Software Foundation, either version 3 of the       *)
(*  License, or (at your option) any later version.  A special linking       *)
(*  exception to the GNU Lesser General Public License applies to this       *)
(*  library, see the COPYING file for more information.                      *)
(*****************************************************************************)

(** Sort by <package name, package version> an input CUDF or universe file *)

open Cudf

let pkg_compare p1 p2 =
  Stdlib.compare (p1.package, p1.version) (p2.package, p2.version)

let string_of_packages pkgs =
  let o = IO.output_string () in
  Cudf_printer.pp_io_packages o pkgs;
  IO.close_out o

let string_of_doc doc =
  let o = IO.output_string () in
  Cudf_printer.pp_io_doc o doc;
  IO.close_out o

let main () =
  let ic = open_in Sys.argv.(1) in
  let p = Cudf_parser.from_in_channel ic in
  let pre, pkgs, req = Cudf_parser.parse p in
  let pkgs' = List.fast_sort pkg_compare pkgs in
  let s =
    match req with
      | None -> string_of_packages pkgs'
      | Some req -> string_of_doc (pre, pkgs', req)
  in
    print_endline s

let () = main ()
