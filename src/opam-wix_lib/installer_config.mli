(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(** Information module used to generated main wxs document. *)
type t = {
    package_dir : OpamFilename.Dir.t ;
    (** Path to the bundle containing all required files. Every relative file
        path will be concatenated to this path *)
    package_name : string;
    (** Package name used as product name. Deduced from opam file *)
    package_fullname : string ;
    package_version : string;
    (** Package version used as part of product name. Deduced from opam file *)
    package_description : string;
    (** Package description. Deduced from opam file *)
    package_manufacturer : string;
    (** Product manufacturer. Deduced from field {i maintainer} in opam file *)
    package_guid : string option;
    (** Package UID. Should be equal for every version of given package. If not
        specified, generated new UID *)
    package_tags : string list; (** Package tags. Deduced from opam file *)
    package_exec_file : string; (** Filename of bundled .exe binary. *)
    package_dlls : string list; (** Filenames for all bundled DLLs. *)
    package_icon_file : string; (** Icon filename. *)
    package_dlg_bmp_file : string; (** Dialog bmp filename. *)
    package_banner_bmp_file : string; (* Banner bmp filename. *)
    package_embedded_dirs : (OpamFilename.Base.t * OpamFilename.Dir.t) list;
    (** Embedded directories information (reference another wxs file) *)
    package_additional_embedded_name : string list ;
    package_additional_embedded_dir : OpamFilename.Dir.t list;
    package_embedded_files : (OpamFilename.Base.t * OpamTypes.filename) list;
    (** Embedded files *)
    package_environment : (string * string) list;
    (** Environement variables to set/unset in Windows terminal on install/uninstall respectively. *)
  }
[@@deriving yojson]

val load : OpamFilename.t -> t
val save : t -> OpamFilename.t -> unit

