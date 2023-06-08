open Lwt.Infix

let call_cygcheck path =
  let cmd = ("cygcheck", [|"cygcheck"; "-c"; path|]) in
    Lwt.catch
      (fun () ->
        Lwt_process.(with_process_full cmd) @@ fun proc ->
        Lwt_io.read_line proc#stdout >>= fun line ->
        Lwt.return @@ String.split_on_char '\n' @@ String.trim line)
      (function _ -> Lwt.return [])

let get_dlls path =
  call_cygcheck path
