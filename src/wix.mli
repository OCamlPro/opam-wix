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

(** Information module used to generated main wxs document. *)
module type INFO = sig
    (** Path to the bundle containing all required files. Every relative file path will be concatenated to this path *)
    val path : string

    (** Package name used as product name. Deduced from opam file *)
    val package_name : string

    (** Package version used as part of product name. Deduced from opam file *)
    val package_version : string

    (** Package description. Deduced from opam file *)
    val description : string

    (** Product manufacturer. Deduced from field {i maintainer} in opam file *)
    val manufacturer : string

    (** Package UID. Should be equal for every version of given package. If not specified,
        generated new UID *)
    val package_guid : string option

    (** Package tags. Deduced from opam file *)
    val tags : string list

    (** Filename of bundled .exe binary. *)
    val exec_file : string

    (** Filenames for all bundled DLLs. *)
    val dlls : string list

    (** Icon filename. *)
    val icon_file : string

    (** Dialog bmp filename. *)
    val dlg_bmp_file : string

    (** Banner bmp filename. *)
    val banner_bmp_file : string

    (** Embedded directories information (reference another wxs file) *)
    val embedded_dirs : (string * component_group * directory_ref) list

    (** Embedded files *)
    val embedded_files : string list

    (** Environement variables to set/unset in Windows terminal on install/uninstall respectively. *)
    val environement : (string * string) list
end

(** [main_wxs (module Info)] produces content for main Wix source file. Input represents a
    module containing set of value required for main wxs generation. *)
val main_wxs : (module INFO) -> wxs

(** Write a wxs file content to a .wxs file with the specified path. *)
val write_wxs : string -> wxs -> unit
