(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let parse_true_so_line l =
  match String.trim l |> String.split_on_char ' ' with
  | lib_name :: "=>" :: lib_path :: _ ->
    Some (lib_name, OpamFilename.of_string lib_path)
  | _ -> None

let should_embed (name, _) =
  (* Those are hardcoded for now but we should ultimately make this
     configurable by the user. *)
  match String.split_on_char '.' name with
  | "libc"::_
  | "libm"::_ -> false
  | _ -> true

let get_sos binary =
  let path = OpamFilename.to_string binary in
  let output = System.call Ldd path in
  let shared_libs = List.filter_map parse_true_so_line output in
  let to_embed = List.filter should_embed shared_libs in
  List.map snd to_embed
