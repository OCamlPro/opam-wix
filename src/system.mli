type _ command =
  | Cygcheck: string command
  | Copy : (string * string) command
  | Mkdir : (bool *string) command
  | Remove : (bool * string) command

val call : 'a command -> 'a -> (string list, string) result

