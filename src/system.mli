type uuid_mode =
  | Rand
  | Exec of string * string * string option
exception System_error of string

type _ command =
  | Cygcheck: string command
  | Copy : (string * string) command
  | Mkdir : (bool * string) command
  | Remove : (bool * string) command
  | Uuidgen : uuid_mode command
  | Candle : (string * string list) command
  | Light : (string * string list * string list * string) command

val call : 'a command -> 'a -> string list
val call_unit : 'a command -> 'a -> unit
val call_list : ('a command * 'a) list -> unit
