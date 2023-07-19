(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open OpamFile
open OpamTypes
open OpamPp.Op

let conf_default = OpamFilename.of_string "opam-wix.conf"

module Syntax = struct
  let internal = "conf"
  let format_version = OpamVersion.of_string "0.1"
  type images = { ico: filename ; bng: filename; ban: filename }
  type t = {
    c_version: OpamVersion.t;
    c_images: images;
    c_binary_path: filename option;
    c_binary: string option;
    c_embbed_dir : dirname list;
    c_embbed_file : filename list;
    c_envvar: (string * string) list;
  }

  let empty = {
    c_version = format_version;
    c_images = {
      ico = OpamFilename.of_string "data/images/logo.ico";
      bng = OpamFilename.of_string "data/images/dlgbmp.bmp";
      ban = OpamFilename.of_string "data/images/bannrbmp.bmp";
    };
    c_binary_path = None;
    c_binary = None;
    c_embbed_dir = [];
    c_embbed_file = [];
    c_envvar = [];
  }

  let fields = [
    "opamwix-version", OpamPp.ppacc
      (fun c_version t -> { t with c_version}) (fun t -> t.c_version)
      (OpamFormat.V.string -| OpamPp.of_module "version" (module OpamVersion));
    "ico", OpamPp.ppacc
      (fun ico t -> { t with c_images = { t.c_images with ico } })
      (fun t -> t.c_images.ico)
      (OpamFormat.V.string -| OpamPp.of_module "filename" (module OpamFilename));
    "bng", OpamPp.ppacc
      (fun bng t -> { t with c_images = { t.c_images with bng } })
      (fun t -> t.c_images.bng)
      (OpamFormat.V.string -| OpamPp.of_module "filename" (module OpamFilename));
    "ban", OpamPp.ppacc
      (fun ban t -> { t with c_images = { t.c_images with ban } })
      (fun t -> t.c_images.ban)
      (OpamFormat.V.string -| OpamPp.of_module "filename" (module OpamFilename));
    "binary-path", OpamPp.ppacc_opt
      (fun bp t -> { t with c_binary_path = Some bp})
      (fun t -> t.c_binary_path)
      (OpamFormat.V.string -| OpamPp.of_module "filename" (module OpamFilename));
    "binary", OpamPp.ppacc_opt
      (fun binary t -> { t with c_binary = Some binary }) (fun t -> t.c_binary)
      (OpamFormat.V.string);
    "embbed-file", OpamPp.ppacc
      (fun file t -> { t with c_embbed_file = file }) (fun t -> t.c_embbed_file)
      (OpamFormat.V.map_list ~depth:1
         (OpamFormat.V.string -| OpamPp.of_module "filename" (module OpamFilename)));
    "embbed-dir", OpamPp.ppacc
      (fun dir t -> { t with c_embbed_dir = dir }) (fun t -> t.c_embbed_dir)
      (OpamFormat.V.map_list ~depth:1
         (OpamFormat.V.string -| OpamPp.of_module "dirname" (module OpamFilename.Dir)));
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
  include SyntaxFile(Syntax)
end

