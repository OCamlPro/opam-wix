open Cmdliner

type config = {
  path : string;
  output_dir : string
}

module Args = struct
  open Arg

  let path =
    required & pos 0 (some file) None & info [] ~docv:"PROGRAM" ~doc:
    "The path to the binary file to handle"

  let output_dir =
    value & opt dir "." & info ["output"] ~docv:"DIR" ~doc:
    "The output directory where bundle will be stored"

  let term =
    let apply path output_dir = { path; output_dir } in
    Term.(const apply $ path $ output_dir)

end

let handle_result f res =
  match res with
  | Ok x -> begin
    try f x
    with exn ->
      raise (Failure (Printexc.to_string exn))
    end
  | Error err -> raise (Failure err)

let create_bundle conf =
  Cygcheck.get_dlls conf.path |>
  handle_result @@ fun dlls ->
    let bundle_dir = Filename.concat conf.output_dir
      (Filename.basename conf.path ^ "-msi") in
    if Sys.file_exists bundle_dir then begin
      System.call System.Remove (true, bundle_dir) |>
        handle_result ignore;
    end;
    let bundle_bin = Filename.concat bundle_dir "bin" in
    System.call System.Mkdir (true, bundle_bin) |>
    handle_result @@ fun _ ->
      List.iter (fun dll ->
        let dst = Filename.(concat bundle_bin (basename dll)) in
        System.call System.Copy (dll, dst) |>
          handle_result ignore
      ) dlls |> fun () ->
        let exe_path =
          if not (Filename.extension conf.path = "exe")
          then conf.path ^ ".exe"
          else conf.path
        in
        let dst = Filename.(concat bundle_bin (basename exe_path)) in
        System.call System.Copy (conf.path, dst) |>
          handle_result @@ fun _ -> ()

let main_info =
  Cmd.info
    ~doc:"Windows msi bundeling for cygwin program"
    "owix"

let main_term = Term.(const create_bundle $ Args.term)


let () =
  match
    Cmd.eval_value ~catch:false (Cmd.v main_info main_term)
  with
  | exception Failure msg ->
    Printf.eprintf "[ERROR] %s\n" msg;
    exit 1
  | Error _ -> exit 2
  | _ -> exit 0
