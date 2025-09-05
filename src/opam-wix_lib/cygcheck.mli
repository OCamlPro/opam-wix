(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(** Investigates binary file dependencies with {i cygcheck} and returns paths to system DLLs *)
val get_dlls : OpamFilename.t -> OpamFilename.t list
