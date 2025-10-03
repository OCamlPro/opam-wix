(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(** Wxs document type. *)
type wxs

(** Component group id *)
type component_group = string

(** Directory id reference *)
type directory_ref = string

(** Version in the form [0-9.]+, i.e dot separated numbers *)
module Version: sig
  type t = string
  val to_string : t -> string
  val of_string : string -> t
end

(** Information module used to generated main wxs document. *)
type info = {
  (* Path to the bundle containing all required files. Every relative file path will be concatenated to this path *)
  wix_path : string;

  (* Package name used as product name. Deduced from opam file *)
  wix_name : string;

  (* Package version used as part of product name. Deduced from opam file *)
  wix_version : string;

  (* Package description. Deduced from opam file *)
  wix_description : string;

  (* Product manufacturer. Deduced from field {i maintainer} in opam file *)
  wix_manufacturer : string;

  (* Package UID. Should be equal for every version of given package. If not specified,
      generated new UID *)
  wix_guid : string option;

  (* Package tags. Deduced from opam file *)
  wix_tags : string list;

  (* Filename of bundled .exe binary. *)
  wix_exec_file : string;

  (* Filenames for all bundled DLLs. *)
  wix_dlls : string list;

  (* Icon filename. *)
  wix_icon_file : string;

  (* Dialog bmp filename. *)
  wix_dlg_bmp_file : string;

  (* Banner bmp filename. *)
  wix_banner_bmp_file : string;

  (* Embedded directories information (reference another wxs file) *)
  wix_embedded_dirs : (string (* name *) * component_group * directory_ref * string (* source *)) list;

  (* Embedded files *)
  wix_embedded_files : string list;

  (* Environement variables to set/unset in Windows terminal on install/uninstall respectively. *)
  wix_environment : (string * string) list;
}

(** [main_wxs (module Info)] produces content for main Wix source file. Input represents a
    module containing set of value required for main wxs generation. *)
val main_wxs : info -> wxs

(** Write a wxs file content to a .wxs file with the specified path. *)
val write_wxs : string -> wxs -> unit
