(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

module Section : sig
  (** Section name for package argument. Should be passed as [~docs]
      where relevant. *)
  val package_arg : string

  (** Section name for binary argument. Should be passed as [~docs]
      where relevant. *)
  val bin_args : string
end

(** Manpage Configuration Section. Describes the configuration file
    format. *)
val configuration : Cmdliner.Manpage.block list
