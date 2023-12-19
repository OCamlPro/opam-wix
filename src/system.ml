(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type uuid_mode =
  | Rand
  | Exec of string * string * string option

type candle_files =
  | One of string * string
  | Many of string list

type candle = {
  candle_wix_path : string;
  candle_files : candle_files;
  candle_defines : string list;
}

type light = {
  light_wix_path : string;
  light_files : string list;
  light_exts : string list;
  light_out : string
}

type heat = {
  heat_wix_path : string;
  heat_dir : string;
  heat_out : string;
  heat_component_group : string;
  heat_directory_ref : string;
  heat_var : string
}

type cygpath_out = [ `Win | `WinAbs | `Cyg | `CygAbs ]

type _ command =
  | Which : string command
  | Cygcheck : string command
  | Cygpath : (cygpath_out * string) command
  | Uuidgen : uuid_mode command
  | Candle : candle command
  | Light : light command
  | Heat : heat command

exception System_error of string

let call_inner : type a. a command -> a -> string * string list =
  fun command args -> match command, args with
  | Which, (path : string) ->
    "which", [ path ]
  | Cygcheck, path ->
    "cygcheck", [ path ]
  | Cygpath, (out, path) ->
    let opts = match out with
      | `Win -> "-w"
      | `WinAbs -> "-wa"
      | `Cyg -> "-u"
      | `CygAbs -> "-ua"
    in
    "cygpath", [ opts; path ]
  | Uuidgen, Rand ->
    "uuidgen", []
  | Uuidgen, Exec (p,e,v) ->
    "uuidgen", ["--md5"; "--namespace"; "@dns"; "--name";
      Format.sprintf "opam.%s.%s%s" p e
        (if v = None then "" else "."^ Option.get v)]
  | Candle, {candle_wix_path; candle_files; candle_defines} ->
    let files =
      match candle_files with
      | One (file,out) -> ["-o"; out; file ]
      | Many files -> files
    in
    let candle = Filename.concat candle_wix_path "candle.exe" in
    let defines = List.map (fun d -> "-d"^d) candle_defines in
    candle, defines @ files
  | Light, {light_wix_path; light_files; light_exts; light_out} ->
    let light = Filename.concat light_wix_path "light.exe" in
    let args =
      List.flatten (List.map (fun e -> ["-ext"; e]) light_exts)
      @ light_files @ ["-o"; light_out]
    in
    light, args
  | Heat, {
      heat_wix_path;
      heat_dir;
      heat_out;
      heat_component_group;
      heat_directory_ref;
      heat_var
    } ->
    let heat = Filename.concat heat_wix_path "heat.exe" in
    let args =
      [ "dir"; heat_dir; "-o"; heat_out;
        "-scom"; "-frag"; "-srd"; "-sreg"; "-gg";
        "-cg"; heat_component_group;
        "-dr"; heat_directory_ref ;
        "-var"; heat_var]
    in
    heat, args

let gen_command_tmp_dir cmd =
  Printf.sprintf "%s-%06x" (Filename.basename cmd) (Random.int 0xFFFFFF)

let call : type a. a command -> a -> string list =
  fun command arguments ->
    let cmd, args = call_inner command arguments in
    let name = gen_command_tmp_dir cmd in
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
    let name = gen_command_tmp_dir cmd in
    let result = OpamProcess.run @@ OpamSystem.make_command ~name cmd args in
    (if OpamProcess.is_failure result then
      raise @@ System_error (Format.sprintf "%s" (OpamProcess.string_of_result result)));
    OpamProcess.cleanup result

let call_list : type a. (a command * a) list -> unit =
  fun commands ->
    let cmds = List.map (fun (cmd,args) ->
      let cmd, args = call_inner cmd args in
      let name = gen_command_tmp_dir cmd in
      OpamSystem.make_command ~name cmd args) commands
    in
    match OpamProcess.Job.(run @@ of_list cmds) with
    | Some (_,result) -> raise @@ System_error
      (Format.sprintf "%s" (OpamProcess.string_of_result result))
    | _ -> ()

let cyg_win_path out path =
  match call Cygpath (out,path) with
  | line :: _ -> String.trim line
  | _ -> raise @@ System_error "cygpath raised an error. \
    You probably chose a file with invalid format as your binary."

let normalize_path = 
  if Sys.cygwin
  then cyg_win_path `CygAbs
  else cyg_win_path `WinAbs

let check_avalable_commands wix_path =
  let wix_bin_exists bin =
    Sys.file_exists @@ Filename.concat wix_path bin
  in
  if List.for_all wix_bin_exists [ "candle.exe"; "light.exe"; "heat.exe" ]
  then
    call_list [
      Which, "cygcheck";
      Which, "cygpath";
      Which, "uuidgen";
    ]
  else
    raise @@ System_error
      (Format.sprintf "Wix binaries couldn't be found in %s directory." wix_path)

