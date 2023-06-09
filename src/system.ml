open Lwt.Infix

type _ command =
  | Cygcheck: string command
  | Copy : (string * string) command
  | Mkdir : string command

let command_to_string : type a. a command -> a -> string = function
  | Cygcheck -> Format.sprintf "cygcheck %s"
  | Copy -> Format.sprintf "cp %a"
    (fun _ (a,b) -> Format.asprintf "%s %s" a b)
  | Mkdir -> Format.sprintf "mkdir %s"

let call : type a. a command -> a -> (string list, string) result Lwt.t =
  fun command args ->
    let cmd = match command,args with
    | Cygcheck, (path:string) ->
      ("cygcheck", [|"cygcheck"; path|])
    | Copy, (src,dst) ->
      ("cp", [|"cp"; src; dst|])
    | Mkdir, dir ->
      ("mkdir", [|"mkdir"; dir|])
    in
    Lwt_process.(with_process_full cmd @@ fun proc ->
    proc#status >>= function
    | Unix.WEXITED 0 -> Lwt_io.read_lines proc#stdout |> Lwt_stream.to_list >>= Lwt.return_ok
    | _ -> command_to_string command args |> Lwt.return_error )

