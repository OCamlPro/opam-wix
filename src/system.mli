type _ command =
  | Cygcheck: string command
  | Copy : (string * string) command
  | Mkdir : string command

val call : 'a command -> 'a -> (string list, string) result Lwt.t

