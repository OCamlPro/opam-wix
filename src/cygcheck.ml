let filter_system32 path =
  match String.split_on_char '\\' path with
  | _ :: "Windows" :: folder::_
    when String.lowercase_ascii folder = "system32" ->
      false
  | _ -> true

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
  let dlls = System.(call Cygcheck (OpamFilename.to_string path)) in
  List.tl dlls |>
  List.filter_map (fun dll ->
    let dll = String.trim dll in
    if filter_system32 dll
    then Some (cygwin_from_windows_path dll |> OpamFilename.of_string)
    else None)
