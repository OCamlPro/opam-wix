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

let get_dlls path =
  System.(call Cygcheck path)
  >>= function
  | Ok dlls ->
    List.map
      (fun s -> String.trim s |> cygwin_from_windows_path)
      (List.tl dlls)
    |> Lwt.return_ok
  | Error err -> err |> Lwt.return_error
