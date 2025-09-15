(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Opam_wix

(* [parse_true_so_line] *)

let pp_result fmt x =
  match x with
  | None -> Format.fprintf fmt "None"
  | Some (name, path) ->
    Format.fprintf fmt "Some (%S, %S)" name (OpamFilename.to_string path)

let%expect_test "parse_true_so_line: special .so" =
  let line = "	linux-vdso.so.1 (0x00007ffdf7bb4000)" in
  let result = Ldd.parse_true_so_line line in
  Format.printf "%a" pp_result result;
  [%expect {| None |}]

let%expect_test "parse_true_so_line: regular .so" =
  let line =
    "libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x00007ff78b95d000)"
  in
  let result = Ldd.parse_true_so_line line in
  Format.printf "%a" pp_result result;
  [%expect {| Some ("libm.so.6", "/usr/lib/x86_64-linux-gnu/libm.so.6") |}]

(* [should_embed] *)

let%expect_test "should_embed: libc" =
  let lib =
    ("libc.so.6", OpamFilename.of_string "/lib/x86_64-linux-gnu/libc.so.6")
  in
  let result = Ldd.should_embed lib in
  Format.printf "%b" result;
  [%expect {| false |}]

let%expect_test "should_embed: libm" =
  let lib =
    ("libm.so.6", OpamFilename.of_string "/lib/x86_64-linux-gnu/libm.so.6")
  in
  let result = Ldd.should_embed lib in
  Format.printf "%b" result;
  [%expect {| false |}]

let%expect_test "should_embed: somelib" =
  let lib =
    ("somelib.so.1", OpamFilename.of_string "/lib/x86_64-linux-gnu/somelib.so.1")
  in
  let result = Ldd.should_embed lib in
  Format.printf "%b" result;
  [%expect {| true |}]
