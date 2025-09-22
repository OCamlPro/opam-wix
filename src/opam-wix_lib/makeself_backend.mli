(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(** [create_installer ~installer_config ~bundle_dir installer] creates
    a standalone makeself installer [installer] based on the given
    bundle and installer configuration. *)
val create_installer :
  installer_config: Installer_config.t ->
  bundle_dir: OpamFilename.Dir.t ->
  OpamFilename.t ->
  unit

(**/**)

(* Exposed for tests purposes only *)

val install_script : Installer_config.t -> Sh_script.t

val uninstall_script : Installer_config.t -> Sh_script.t
