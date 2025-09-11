(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

module Yojsonable = struct
  type dirname = OpamFilename.Dir.t

  let dirname_to_yojson dir = `String (OpamFilename.Dir.to_string dir)
  let dirname_of_yojson = function
    | `String dir -> Ok (OpamFilename.Dir.of_string dir)
    | _ -> Error "Invalid OpamFilename.Dir.t JSON encoding"

  type filename = OpamFilename.t

  let filename_to_yojson fn = `String (OpamFilename.to_string fn)
  let filename_of_yojson = function
    | `String fn -> Ok (OpamFilename.of_string fn)
    | _ -> Error "Invalid OpamFilename.t JSON encoding"

  type basename = OpamFilename.Base.t

  let basename_to_yojson bn = `String (OpamFilename.Base.to_string bn)
  let basename_of_yojson = function
    | `String bn -> Ok (OpamFilename.Base.of_string bn)
    | _ -> Error "Invalid OpamFilename.Base.t JSON encoding"
end

type t = {
    package_dir : Yojsonable.dirname;
    package_name : string;
    package_fullname : string ;
    package_version : string;
    package_description : string;
    package_manufacturer : string;
    package_guid : string option;
    package_tags : string list;
    package_exec_file : string;
    package_dlls : string list;
    package_icon_file : string;
    package_dlg_bmp_file : string;
    package_banner_bmp_file : string;
    package_embedded_dirs : (Yojsonable.basename * Yojsonable.dirname) list;
    package_additional_embedded_name : string list ;
    package_additional_embedded_dir : Yojsonable.dirname list;
    package_embedded_files : (Yojsonable.basename * Yojsonable.filename) list;
    package_environment : (string * string) list;
  }
[@@deriving yojson]

exception Invalid_file of string

let invalid_file fmt =
  Printf.ksprintf (fun s -> raise (Invalid_file s)) fmt

let load filename =
  let file = (OpamFilename.to_string filename) in
  let json = Yojson.Safe.from_file file in
  match of_yojson json with
  | Ok t -> t
  | Error msg ->
    invalid_file "Could not parse installer config %s: %s" file msg

let save t filename =
  Yojson.Safe.to_file (OpamFilename.to_string filename) (to_yojson t)
