(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open OpamPp.Op

let conf_default = OpamFilename.of_string "opam-wix.conf"

module Syntax = struct
  let internal = "conf"
  let format_version = OpamVersion.of_string "0.2"
  type images = { ico: string option; dlg: string option; ban: string option }
  type t = {
    c_version: OpamVersion.t;
    c_images: images;
    c_binary_path: string option;
    c_binary: string option;
    c_wix_version: Wix.Version.t option;
    c_embedded : (string * string option) list;
    c_envvar: (string * string) list;
  }

  let empty = {
    c_version = format_version;
    c_images = {
      ico = None;
      dlg = None;
      ban = None;
    };
    c_binary_path = None;
    c_binary = None;
    c_wix_version = None;
    c_embedded = [];
    c_envvar = [];
  }

  let embedded_pp : (OpamParserTypes.FullPos.value, string * string option) OpamPp.t =
    let from_list ~pos = function
      | [ path ] -> path, None
      | [ path; alias ] -> path, Some alias
      | _ -> OpamPp.bad_format ~pos
        "embedded declaration should contain 1 (path) or 2 (path and alias) elements."
    in
    let to_list = function
      | (path, Some alias) -> [ path; alias ]
      | (path, None) -> [ path ]
    in
    OpamPp.Op.(OpamFormat.V.map_list OpamFormat.V.string -| OpamPp.pp from_list to_list)

  let fields = [
    "opamwix-version", OpamPp.ppacc
      (fun c_version t -> { t with c_version}) (fun t -> t.c_version)
      (OpamFormat.V.string -| OpamPp.of_module "version" (module OpamVersion));
    "ico", OpamPp.ppacc_opt
      (fun ico t -> { t with c_images = { t.c_images with ico = Some ico } })
      (fun t -> t.c_images.ico)
      OpamFormat.V.string;
    "bng", OpamPp.ppacc_opt
      (fun dlg t -> { t with c_images = { t.c_images with dlg = Some dlg } })
      (fun t -> t.c_images.dlg)
      OpamFormat.V.string;
    "ban", OpamPp.ppacc_opt
      (fun ban t -> { t with c_images = { t.c_images with ban = Some ban } })
      (fun t -> t.c_images.ban)
      OpamFormat.V.string;
    "binary-path", OpamPp.ppacc_opt
      (fun bp t -> { t with c_binary_path = Some bp})
      (fun t -> t.c_binary_path)
      OpamFormat.V.string;
    "binary", OpamPp.ppacc_opt
      (fun binary t -> { t with c_binary = Some binary }) (fun t -> t.c_binary)
      OpamFormat.V.string;
    "wix-version", OpamPp.ppacc_opt
      (fun c_wix_version t -> { t with c_wix_version = Some c_wix_version })
      (fun t -> t.c_wix_version)
      (OpamFormat.V.string -| OpamPp.of_module "wix_version" (module Wix.Version));
    "embedded", OpamPp.ppacc
      (fun file t -> { t with c_embedded = file }) (fun t -> t.c_embedded)
      (OpamFormat.V.map_list ~depth:2 embedded_pp);
    "envvar", OpamPp.ppacc
      (fun c_envvar t -> { t with c_envvar }) (fun t -> t.c_envvar)
      (OpamFormat.V.map_list ~depth:2
         (OpamFormat.V.map_pair OpamFormat.V.string OpamFormat.V.string));
  ]

  let pp =
    let name = internal in
    OpamFormat.I.map_file
    @@ OpamFormat.I.fields ~name ~empty fields
       -| OpamFormat.I.show_errors ~name ~strict:true ()
       (** XXX Add some checks *)


end

module Conf = struct
  include Syntax
  include OpamFile.SyntaxFile(Syntax)
end

