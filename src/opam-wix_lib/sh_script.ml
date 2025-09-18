(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type find_type =
  | Files
  | Dirs

type condition =
  | Dir_exists of string
  | Link_exists of string
  | Is_not_root

type command =
  | Exit of int
  | Echo of string
  | Mkdir of string list
  | Chmod of {permissions: int; files: string list}
  | Cp of {src: string; dst: string}
  | Rm of {rec_: bool; files : string list}
  | Symlink of {target: string; link: string}
  | Set_permissions_in of
      {on: find_type; permissions: int; starting_point: string}
  | If of {condition : condition; then_ : command list}
  | Prompt of {question: string; varname: string}
  | Case of {varname: string; cases: case list}
and case =
  { pattern : string
  ; commands : command list
  }

type t = command list

let exit i = Exit i
let echof fmt = Format.kasprintf (fun s -> Echo s) fmt
let mkdir dirs = Mkdir dirs
let chmod permissions files = Chmod {permissions; files}
let cp ~src ~dst = Cp {src; dst}
let rm files = Rm {rec_ = false; files}
let rm_rf files = Rm {rec_ = true; files}
let symlink ~target ~link = Symlink {target; link}
let if_ condition then_ = If {condition; then_}
let prompt ~question ~varname = Prompt {question; varname}
let case varname cases = Case {varname; cases}

let set_permissions_in ~on ~permissions starting_point =
  Set_permissions_in {on; permissions; starting_point}

let pp_sh_find_type fmtr ft =
  match ft with
  | Files -> Format.fprintf fmtr "f"
  | Dirs -> Format.fprintf fmtr "d"

let pp_sh_condition fmtr condition =
  match condition with
  | Dir_exists s -> Format.fprintf fmtr "-d %S" s
  | Link_exists s -> Format.fprintf fmtr "-L %S" s
  | Is_not_root -> Format.fprintf fmtr {|"$(id -u)" -ne 0|}

let rec pp_sh_command ~indent fmtr command =
  let indent_str = String.make indent ' ' in
  let fpf fmt = Format.fprintf fmtr ("%s" ^^ fmt ^^ "\n") indent_str in
  let pp_files = Fmt.(list ~sep:(const string " ") string) in
  match command with
  | Exit i -> fpf "exit %d" i
  | Echo s -> fpf "echo %S" s
  | Mkdir dirs -> fpf "mkdir -p %a" pp_files dirs
  | Chmod {permissions; files} -> fpf "chmod %i %a" permissions pp_files files
  | Cp {src; dst} -> fpf "cp %s %s" src dst
  | Rm {rec_ = true; files} -> fpf "rm -rf %a" pp_files files
  | Rm {rec_ = false; files} -> fpf "rm -f %a" pp_files files
  | Symlink {target; link} -> fpf "ln -s %s %s" target link
  | Set_permissions_in {on; permissions; starting_point} ->
    fpf "find %s -type %a -exec chmod %i {} +"
      starting_point
      pp_sh_find_type on
      permissions
  | If {condition; then_} ->
    fpf "if [ %a ]; then" pp_sh_condition condition;
    List.iter (pp_sh_command ~indent:(indent + 2) fmtr) then_;
    fpf "fi"
  | Prompt {question; varname} ->
    fpf {|printf "%s "|} question;
    fpf {|read %s|} varname
  | Case {varname; cases} ->
    fpf {|case "$%s" in|} varname;
    List.iter (pp_sh_case ~indent:(indent + 2) fmtr) cases;
    fpf "esac"
and pp_sh_case ~indent fmtr {pattern; commands} =
  let indent_str = String.make indent ' ' in
  let fpf fmt = Format.fprintf fmtr ("%s" ^^ fmt ^^ "\n") indent_str in
  match commands with
  | [] -> fpf "%s) ;;" pattern
  | _ ->
    fpf "%s)" pattern;
    List.iter (pp_sh_command ~indent:(indent + 2) fmtr) commands;
    fpf ";;"


let pp_sh fmtr t =
  Format.fprintf fmtr "#!/bin/sh\n";
  Format.fprintf fmtr "set -e\n";
  List.iter (pp_sh_command ~indent:0 fmtr) t

let save t file =
  let file = OpamFilename.to_string file in
  let out_ch = open_out file in
  let formatter = Format.formatter_of_out_channel out_ch in
  pp_sh formatter t;
  close_out out_ch
