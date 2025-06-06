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
  conf: OpamFilename.t option;
  package : OpamPackage.Name.t;
  path : filename option;
  binary: string option;
  wix_version: Wix.Version.t option;
  output_dir : dirname;
  wix_path : string;
  package_guid: string option;
  icon_file : filename option;
  dlg_bmp : filename option;
  ban_bmp : filename option;
  keep_wxs : bool;
}

type embedded =
  | Copy_alias of string * string
  | Copy_external of string
  | Copy_opam of string
