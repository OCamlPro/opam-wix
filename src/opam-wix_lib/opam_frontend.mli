(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

val with_install_bundle :
  OpamCLIVersion.Sourced.t ->
  OpamArg.global_options ->
  Types.config ->
  (Types.config ->
   Installer_config.t ->
   tmp_dir:OpamFilename.Dir.t -> unit) ->
  unit
