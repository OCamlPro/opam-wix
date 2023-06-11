type _ command =
  | Cygcheck: string command
  | Copy : (string * string) command
  | Mkdir : (bool *string) command
  | Remove : (bool * string) command

let command_to_string : type a. a command -> a -> string =
  let print_flag_short name flag =
    if flag then "-" ^ name ^ " " else ""
  in
  function
  | Cygcheck -> Format.sprintf "cygcheck %s"
  | Copy -> Format.sprintf "cp %a"
    (fun _ (a,b) -> Format.asprintf "%s %s" a b)
  | Mkdir -> fun (p,dir) -> Format.sprintf "mkdir %s%s"
    (print_flag_short "p" p) dir
  | Remove -> fun (is_dir,path) -> Format.sprintf "rm %s%s"
    (print_flag_short "r" is_dir) path

let read_lines inc =
  let rec aux acc =
    match In_channel.input_line inc with
    | Some line -> aux (line::acc)
    | None -> List.rev acc
  in
  aux []

let call : type a. a command -> a -> (string list, string) result =
  fun command arguments ->
    let cmd, args = match command,arguments with
    | Cygcheck, (path:string) ->
      "cygcheck", [| "cygcheck"; path |]
    | Copy, (src,dst) ->
      "cp", [|"cp"; src; dst|]
    | Mkdir, (p,dir) ->
      let args = [ "mkdir" ] @
        (if p then ["-p"] else []) @
        [ dir ]
      in
      "mkdir", Array.of_list args
    | Remove, (is_dir,path) ->
      let args = [ "rm" ] @
        (if is_dir then ["-r"] else []) @
        [ path ]
      in
      "rm", Array.of_list args
    in
    let inc = Unix.open_process_args_in cmd args in
    let pid = Unix.process_in_pid inc in
    let _,status = Unix.waitpid [] pid in
    match status with
    | Unix.WEXITED 0 -> Ok (read_lines inc)
    | _ -> Error (command_to_string command arguments)

