(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Cmdliner
open OpamTypes
open OpamStateTypes

type config = {
  conf_file: OpamFilename.t option;
  conf_package : OpamPackage.Name.t;
  conf_path : filename option;
  conf_binary: string option;
  conf_wix_version: Wix.Version.t option;
  conf_output_dir : dirname;
  conf_wix_path : string;
  conf_package_guid: string option;
  conf_icon_file : filename option;
  conf_dlg_bmp : filename option;
  conf_ban_bmp : filename option;
  conf_keep_wxs : bool;
}

type embedded =
  | Copy_alias of string * string
  | Copy_external of string
  | Copy_opam of string


(** Information module used to generated main wxs document. *)
type description = {

    (* Path to the bundle containing all required files. Every relative file path will be concatenated to this path *)
    package_dir : OpamFilename.Dir.t ;

    (* Package name used as product name. Deduced from opam file *)
    package_name : string;
    package_fullname : string ;
    (* Package version used as part of product name. Deduced from opam file *)
    package_version : string;

    (* Package description. Deduced from opam file *)
    package_description : string;

    (* Product manufacturer. Deduced from field {i maintainer} in opam file *)
    package_manufacturer : string;

    (* Package UID. Should be equal for every version of given package. If not specified,
       generated new UID *)
    package_guid : string option;

    (* Package tags. Deduced from opam file *)
    package_tags : string list;

    (* Filename of bundled .exe binary. *)
    package_exec_file : string;

    (* Filenames for all bundled DLLs. *)
    package_dlls : string list;

    (* Icon filename. *)
    package_icon_file : string;

    (* Dialog bmp filename. *)
    package_dlg_bmp_file : string;

    (* Banner bmp filename. *)
    package_banner_bmp_file : string;

    (* Embedded directories information (reference another wxs file) *)
    package_embedded_dirs : (OpamFilename.Base.t * OpamFilename.Dir.t) list;
    package_additional_embedded_name : string list ;
    package_additional_embedded_dir : OpamFilename.Dir.t list;
    
    (* Embedded files *)
    package_embedded_files : (OpamFilename.Base.t * OpamTypes.filename) list;
    
    (* Environement variables to set/unset in Windows terminal on install/uninstall respectively. *)
    package_environment : (string * string) list;
  }

