(** Exception that is launched by command when proccess terminates with non-zero exit code status.
    Contains command's output. *)
exception System_error of string

(** Configuration option for {i uuidgen} command used as a seed for generator. *)
type uuid_mode =
  | Rand (** Random seed *)
  | Exec of string * string * string option (** Seed based on metadata information about package, its version and name of binary. *)


(** Configuration options for {i candle} command as a part of WiX tools. Consists of the path to
    WiX toolset binaries and input files for {i candle}. *)
type candle = {
  candle_wix_path : string;
  candle_files : string list;
}

(** Configuration options for {i light} command as a part of WiX tools. Consists of the path to
    WiX toolset binaries, input files, extensions to be used and output file path. *)
type light = {
  light_wix_path : string;
  light_files : string list;
  light_exts : string list;
  light_out : string
}

(** External commands that could be called and handled by {b opam-wix}. *)
type _ command =
  | Which : string command  (** {b which} command, to check programs availability *)
  | Cygcheck: string command   (** {b cygcheck} command to get binaries' DLLs paths *)
  | Uuidgen : uuid_mode command  (** {b uuidgen} command to create a new UUID value, based on seed. *)
  | Candle : candle command  (** {b candle.exe} command as a part of WiX toolset to compile Wix source files. *)
  | Light : light command  (** {b light.exe} command as a part of WiX toolset to link all compiled Wix source files in MSI. *)

(** Calls given command with its arguments and parses output, line by line. Raises [System_error]
    with command's output when command exits with non-zero exit status. *)
val call : 'a command -> 'a -> string list

(** Same as [call] but ignores output. *)
val call_unit : 'a command -> 'a -> unit

(** Same as [call_unit], but calls commands simultaneously. *)
val call_list : ('a command * 'a) list -> unit

(** Checks if all handled commands are available system-widely. *)
val check_avalable_commands : string -> unit

(** [windows_from_cygwin_path cygwin_disk path] translates cygwin path to windows path.
    [cygwin_disk] indicates disk name ("C:", "D:") where cygwin root is stored in {i cygwin64} folder*)
val windows_from_cygwin_path : string -> string -> string
