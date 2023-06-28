type uuid_mode =
  | Rand
  | Exec of string * string * string option

type _ command =
  | Cygcheck: string command
  | Copy : (string * string) command
  | Mkdir : (bool *string) command
  | Remove : (bool * string) command
  | Uuidgen : uuid_mode command
  | Candle : (string * string list) command
  | Light : (string * string list * string list * string) command

exception System_error of string

(* let command_to_string : type a. a command -> a -> string =
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
  | Uuidgen -> begin function
    | Rand -> "uuidgen"
    | Package (p,v) -> Format.sprintf
      "uuidgen --md5 --namespace @dns --name opam.%s%s" p
        (if v = None then "" else "."^ Option.get v)
  end
  | Candle -> fun (wix_path, files) ->
    Format.asprintf "%s %a" (Filename.concat wix_path "candle.exe")
      Format.(pp_print_list ~pp_sep:(fun fmt () -> Format.fprintf fmt " ") pp_print_string)
      files
  | Light -> fun (wix_path, files, exts, out) ->
    Format.asprintf {|%s %a %a %s|} (Filename.concat wix_path "light.exe")
      Format.(pp_print_list ~pp_sep:(fun fmt () -> Format.fprintf fmt " ")
        (fun fmt -> Format.fprintf fmt "-ext %s"))
      exts
      Format.(pp_print_list ~pp_sep:(fun fmt () -> Format.fprintf fmt " ") pp_print_string)
      files
      out *)

(* let read_lines inc =
  let rec aux acc =
    match In_channel.input_line inc with
    | Some line -> aux (line::acc)
    | None -> List.rev acc
  in
  aux [] *)

let call_inner : type a. a command -> a -> string * string list =
  fun command args -> match command, args with
  | Cygcheck, (path:string) ->
    "cygcheck", [ path ]
  | Copy, (src,dst) ->
    "cp", [ src; dst ]
  | Mkdir, (p,dir) ->
    let args = (if p then ["-p"] else []) @ [ dir ] in
    "mkdir", args
  | Remove, (is_dir,path) ->
    let args = (if is_dir then ["-r"] else []) @ [ path ]
    in
    "rm", args
  | Uuidgen, Rand ->
    "uuidgen", []
  | Uuidgen, Exec (p,e,v) ->
    "uuidgen", ["--md5"; "--namespace"; "@dns"; "--name";
      Format.sprintf "opam.%s.%s%s" p e
        (if v = None then "" else "."^ Option.get v)]
  | Candle, (wix_path, files) ->
    let candle = Filename.concat wix_path "candle.exe" in
    candle, files
  | Light, (wix_path, files, exts, out) ->
    let light = Filename.concat wix_path "light.exe" in
    let args =
      List.flatten (List.map (fun e -> ["-ext"; e]) exts)
      @ files @ [ "-o"; out ]
    in
    light, args


let call : type a. a command -> a -> string list =
  fun command arguments ->
    let cmd, args = call_inner command arguments in
    let _ =
      let name = OpamSystem.temp_file cmd in
      Printf.printf "name %s is relative ? %B\n" name (Filename.is_relative name)
    in
    let name = Filename.basename @@ OpamSystem.temp_file cmd in
    let result = OpamProcess.run @@ OpamSystem.make_command ~name cmd args in
    let out = if OpamProcess.is_failure result then
        raise @@ System_error (Format.sprintf "%s" (OpamProcess.string_of_result result))
      else
        result.OpamProcess.r_stdout
    in
    OpamProcess.cleanup result;
    out

let call_unit : type a. a command -> a -> unit =
  fun command arguments ->
    let cmd, args = call_inner command arguments in
    let _ =
      let name = OpamSystem.temp_file cmd in
      Printf.printf "name %s is relative ? %B\n" name (Filename.is_relative name)
    in
    let name = Filename.basename @@ OpamSystem.temp_file cmd in
    let result = OpamProcess.run @@ OpamSystem.make_command ~name cmd args in
    (if OpamProcess.is_failure result then
      raise @@ System_error (Format.sprintf "%s" (OpamProcess.string_of_result result)));
    OpamProcess.cleanup result

let call_list : type a. (a command * a) list -> unit =
  fun commands ->
    let cmds = List.map (fun (cmd,args) ->
      let cmd, args = call_inner cmd args in
      let name = Filename.basename @@ OpamSystem.temp_file cmd in
      OpamSystem.make_command ~name cmd args) commands
    in
    match OpamProcess.Job.(run @@ of_list cmds) with
    | Some (_,result) -> raise @@ System_error
      (Format.sprintf "%s" (OpamProcess.string_of_result result))
    | _ -> ()

