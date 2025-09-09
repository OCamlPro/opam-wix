(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(** [get_sos binary] returns the path to .so files that [binary] depends
    on, as resolved by [ldd] on the host system.
    Filters out special .so such as ld-linux and linux-vdso, as well as
    base system libraries libc and libm. *)
val get_sos : OpamFilename.t -> OpamFilename.t list

(**/**)
(* Undocumented Section. Exposed for test purposes only *)

(* Parse an ldd output line, returning a pair of the shared library name
   and path.
   Returns [None] on special .so such as ld-linux or linux-vdso. *)
val parse_true_so_line : string -> (string * OpamFilename.t) option

(* Whether the given shared library should be embedded by the installer. *)
val should_embed : (string * OpamFilename.t) -> bool
