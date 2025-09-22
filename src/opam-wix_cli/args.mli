(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

val opam_filename : OpamFilename.t Cmdliner.Arg.conv
val opam_dirname : OpamFilename.Dir.t Cmdliner.Arg.conv

val config : Opam_wix.Types.config Cmdliner.Term.t
(** Cmdliner term evaluating to the config compiled from relevant CLI args and
    options. Note that this consumes the first positional argument. *)

type backend = Wix | Makeself
type 'a choice = Autodetect | Forced of 'a option

val backend : backend choice Cmdliner.Term.t
