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

(** Default path of config file *)
val conf_default: filename

(** Module that englobes config type and file primitives to read config file. *)
module Conf: sig

  (** Images files *)
  type images = {
    ico: string option;
    dlg: string option;
    ban: string option
  }

  (** Content of config file *)
  type t = {
    c_version: OpamVersion.t; (* Config file version *)
    c_images: images; (* Images files that are treated not as other embedded files *)
    c_binary_path: string option; (* Path to binary to install *)
    c_binary: string option; (* Binary name to install *)
    c_wix_version: Wix.Version.t option; (* Wix compatible version to use for install *)
    c_embedded : (string * string option) list; (* Files/directories to embed in installation directory *)
    c_envvar: (string * string) list; (* Environement variables to set in Windows Terminal on installation *)
  }

  include IO_FILE with type t := t

end
