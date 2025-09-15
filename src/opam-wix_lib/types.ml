(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open OpamTypes

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
