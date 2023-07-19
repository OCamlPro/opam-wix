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
open OpamFile

val conf_default: filename
module Conf: sig

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
  include IO_FILE with type t := t

end
