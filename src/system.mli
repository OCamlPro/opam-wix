exception System_error of string * string list

type uuid_mode =
  | Rand
  | Package of string * string option

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
