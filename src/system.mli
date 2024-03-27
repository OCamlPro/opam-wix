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

(** Way to define in/output files for {i candle} *)
type candle_files =
  | One of string * string (** Input + output *)
  | Many of string list (** Inputs *)

(** Configuration options for {i candle} command as a part of WiX tools. Consists of the path to
    WiX toolset binaries, input and output files for {i candle} as well as a list of
    variable declarations. *)
type candle = {
  candle_wix_path : string;
  candle_files : candle_files;
  candle_defines : string list;
}

(** Configuration options for {i light} command as a part of WiX tools. Consists of the path to
    WiX toolset binaries, input files, extensions to be used and output file path. *)
type light = {
  light_wix_path : string;
  light_files : string list;
  light_exts : string list;
  light_out : string
}

(** Configuration options for {i heat} command as a part of WiX tools, that generates wxs file
    for given directory structure. Consists of the path to WiX toolset binaries, directory path,
    output filname, component group that could be used in main file to reference a generated feature,
    reference to a directory tag in the main wxs file and variable used to rely file with the main wxs. *)
type heat = {
  heat_wix_path : string;
  heat_dir : string;
  heat_out : string;
  heat_component_group : string;
  heat_directory_ref : string;
  heat_var : string
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
  | Cygpath : (cygpath_out * string) command (** {b cygpath} command to translate path between cygwin and windows and vice-versa *)
  | Uuidgen : uuid_mode command  (** {b uuidgen} command to create a new UUID value, based on seed. *)
  | Candle : candle command  (** {b candle.exe} command as a part of WiX toolset to compile Wix source files. *)
  | Light : light command  (** {b light.exe} command as a part of WiX toolset to link all compiled Wix source files in MSI. *)
  | Heat : heat command  (** {b heat.exe} command as a part of WiX toolset to generate WiX source for specified directory. *)

(** Calls given command with its arguments and parses output, line by line. Raises [System_error]
    with command's output when command exits with non-zero exit status. *)
val call : 'a command -> 'a -> string list

(** Same as [call] but ignores output. *)
val call_unit : 'a command -> 'a -> unit

(** Same as [call_unit], but calls commands simultaneously. *)
val call_list : ('a command * 'a) list -> unit

(** Checks if all handled commands are available system-widely. *)
val check_avalable_commands : string -> unit

(** Performs path translations between Windows and Cygwin. See [System.cygpath_out] for more details. *)
val cyg_win_path : cygpath_out -> string -> string

(** Adopts path to the current system's format (cygwin or win32). *)
val normalize_path : string -> string

(** Convert safely path from [OpamFilename.t] *)
val path_str : OpamFilename.t -> string

(** Convert safely path from [OpamFilename.Dir.t] *)
val path_dir_str : OpamFilename.Dir.t -> string