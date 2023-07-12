(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let filter_system32 path =
  match String.split_on_char '\\' path with
  | _ :: "Windows" :: folder::_
    when String.lowercase_ascii folder = "system32" ->
      false
  | _ -> true

let get_dlls path =
  let check_consistency result =
    (* if cygchecks produces less then 3 lines, it signifies an error *)
    if List.length result > 2
    then result
    else raise @@
      System.System_error "cygcheck raised an error. You probably choosed a file \
      with invalid format as your binary."
  in
  let dlls =
    System.(call Cygcheck (OpamFilename.to_string path))
    |> check_consistency
  in
  List.tl dlls |>
  List.filter_map (fun dll ->
    let dll = String.trim dll in
    if filter_system32 dll
    then Some System.(cyg_win_path `CygAbs dll |> OpamFilename.of_string)
    else None)
