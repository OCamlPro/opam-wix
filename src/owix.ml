open Cmdliner
open Lwt

let () =
  let path = Sys.argv.(1) in
  let dlls = Lwt_main.run @@ Cygcheck.get_dlls path in
  Format.printf "%a@." (Format.pp_print_list ~pp_sep:(fun fmt () -> Format.fprintf fmt "\n") Format.pp_print_string) dlls
