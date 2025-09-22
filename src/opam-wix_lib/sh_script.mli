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

(** Prints the given script using shell syntax to the given formatter. *)
val pp_sh : Format.formatter -> t -> unit

(** [exit i] is ["exit i"] *)
val exit : int -> command

(** [echo fmt args] is ["echo \"s\""] where [s] is the expanded format
    string. *)
val echof : ('a, Format.formatter, unit, command) format4 -> 'a

(** [mkdir f1::f2::_] is ["mkdir -p f1 f2 ..."] *)
val mkdir : string list -> command

(** [chmod i f1::f2::_] is ["chmod i f1 f2 ..."] *)
val chmod : int -> string list -> command

(** [cp ~src ~dst] is ["cp src dst"] *)
val cp : src: string -> dst: string -> command

(** [rm f1::f2::_] is ["rm -f f1 f2 ..."] *)
val rm : string list -> command

(** [rm_rf f1::f2::_] is ["rm -rf f1 f2 ..."] *)
val rm_rf : string list -> command

(** [symlink ~target ~link] is ["ln -s target link"] *)
val symlink : target: string -> link: string -> command

(** [if_ condition commands] is
    ["if [ condition ]; then
      commands
    fi"] *)
val if_ : condition -> command list -> command

(** [set_permissions_in starting_point ~on ~permissions] is
    ["find starting_point -type find_type -exec chmod permissions {} +"] *)
val set_permissions_in : on: find_type -> permissions: int -> string -> command

(** [promt ~question ~varname] is ["printf \"question \""] followed by
    [read varname]. *)
val prompt : question: string -> varname: string -> command

val case : string -> case list -> command

val save : t -> OpamFilename.t -> unit
