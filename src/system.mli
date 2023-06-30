type uuid_mode =
  | Rand
  | Exec of string * string * string option
exception System_error of string

type candle = {
  candle_wix_path : string;
  candle_files : string list;
}

type light = {
  light_wix_path : string;
  light_files : string list;
  light_exts : string list;
  light_out : string
}

type _ command =
  | Which : string command
  | Cygcheck: string command
  | Uuidgen : uuid_mode command
  | Candle : candle command
  | Light : light command

val call : 'a command -> 'a -> string list
val call_unit : 'a command -> 'a -> unit
val call_list : ('a command * 'a) list -> unit
val check_avalable_commands : string -> unit
