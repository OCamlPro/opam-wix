open Lwt.Infix

let cygwin_from_windows_path path =
  let remove_colon path =
    String.(sub path 0 (length path - 1))
  in
  match String.split_on_char '\\' path with
  | disk :: path ->
    let cygwin_path =
      "/cygdrive" ::
      String.lowercase_ascii (remove_colon disk) ::
      path
    in
    String.concat "/" cygwin_path
  | [] -> ""

let get_map_stream stream f =
  let rec aux acc =
    Lwt_stream.get stream >>= function
    | Some line -> aux (f line::acc)
    | None -> Lwt.return @@ List.rev acc
  in
  aux []

let get_dlls path =
  let cmd = ("cygcheck", [|"cygcheck"; path|]) in
  Lwt_process.(with_process_full cmd) @@ fun proc ->
  let stream = Lwt_io.read_lines proc#stdout in
  get_map_stream stream
  (fun s -> String.trim s |> cygwin_from_windows_path)
  >>= fun lines ->
  List.tl lines |> Lwt.return

