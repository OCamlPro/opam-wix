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
  let path = OpamFilename.to_string path in
  let path_win = System.(cyg_win_path `WinAbs path) in
  match System.(call Cygcheck path) |> List.filter (fun s ->
    not @@ String.equal s "") with
  | [line] when OpamStd.String.contains ~sub:path_win line -> []
  | line::dlls when OpamStd.String.contains ~sub:path_win line ->
    List.filter_map (fun dll ->
      let dll = String.trim dll in
      if filter_system32 dll
      then Some System.(normalize_path dll |> OpamFilename.of_string)
      else None) dlls
  | _ -> raise @@
  System.System_error "cygcheck raised an error. You probably chose a file \
  with invalid format as your binary."
