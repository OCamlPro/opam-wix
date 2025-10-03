(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(** Exception that is launched by command when proccess terminates with non-zero exit code status.
    Contains command's output. *)
exception System_error of string

(** Configuration option for {i uuidgen} command used as a seed for generator. *)
type uuid_mode =
  | Rand (** Random seed *)
  | Exec of string * string * string option (** Seed based on metadata information about package, its version and name of binary. *)

(** Configuration options for {i wix} command as a part of WiX tools. Consists of the path to
    WiX toolset binaries, input files, extensions to be used and output file path. *)
type wix = {
  wix_wix_path : string;
  wix_files : string list;
  wix_exts : string list;
  wix_out : string
}

(** makeself script arguments *)
type makeself = {
  archive_dir : OpamFilename.Dir.t;
  installer : OpamFilename.t;
  description : string;
  startup_script : string
}

(** Expected output path type *)
type cygpath_out = [
  | `Win (** Path Windows *)
  | `WinAbs (** Absolute Path Windows *)
  | `Cyg (** Path Cygwin *)
  | `CygAbs (** Absolute Path Cygwin *)
  ]

(** External commands that could be called and handled by {b opam-wix}. *)
type _ command =
  | Which : string command  (** {b which} command, to check programs availability *)
  | Cygcheck: string command   (** {b cygcheck} command to get binaries' DLLs paths *)
  | Ldd : string command (** {b ldd} command to get binaries .so paths *)
  | Cygpath : (cygpath_out * string) command (** {b cygpath} command to translate path between cygwin and windows and vice-versa *)
  | Uuidgen : uuid_mode command  (** {b uuidgen} command to create a new UUID value, based on seed. *)
  | Wix : wix command
  | Makeself : makeself command (** {b makeself.sh} command to generate linux installer. *)
  | Chmod : (int * OpamFilename.t) command

(** Calls given command with its arguments and parses output, line by line. Raises [System_error]
    with command's output when command exits with non-zero exit status. *)
val call : 'a command -> 'a -> string list

(** Same as [call] but ignores output. *)
val call_unit : 'a command -> 'a -> unit

(** Same as [call_unit], but calls commands simultaneously. *)
val call_list : ('a command * 'a) list -> unit

(** Checks if all handled commands are available system-widely. *)
val check_available_commands : string -> unit

(** Performs path translations between Windows and Cygwin. See [System.cygpath_out] for more details. *)
val cyg_win_path : cygpath_out -> string -> string

(** Resolve absolute path in the current system's format (Cygwin or Win32). *)
val normalize_path : string -> string

(** Convert safely path from [OpamFilename.t] *)
val path_str : OpamFilename.t -> string

(** Convert safely path from [OpamFilename.Dir.t] *)
val path_dir_str : OpamFilename.Dir.t -> string

module type FILE_INTF = sig
  type t
  val name : string
  val to_string : t -> string
  val of_string : string -> t
  val (/) : OpamTypes.dirname -> string -> t
  val copy : src:t -> dst:t -> unit
  val exists : t -> bool
  val basename : t -> OpamTypes.basename
end

module DIR_IMPL : FILE_INTF with type t = OpamFilename.Dir.t
module FILE_IMPL : FILE_INTF with type t = OpamFilename.t

val resolve_path : OpamFilter.env ->
                   (module FILE_INTF with type t = 'a) -> string -> 'a
val resolve_file_path : OpamFilter.env -> string -> OpamFilename.t
