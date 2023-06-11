open Cmdliner

type config = {
  path : string;
  output_dir : string;
  wix_path : string
}

module Args = struct
  open Arg

  let path =
    required & pos 0 (some file) None & info [] ~docv:"PROGRAM" ~doc:
    "The path to the binary file to handle"

  let output_dir =
    value & opt dir "." & info ["output"] ~docv:"DIR" ~doc:
    "The output directory where bundle will be stored"

  let wix_path =
    value & opt dir "/cygdrive/c/Program Files (x86)/WiX Toolset v3.10/bin" & info ["wix-path"] ~docv:"DIR" ~doc:
    "The path where WIX tools are stored. The path should be full."

  let term =
    let apply path output_dir wix_path = { path; output_dir; wix_path } in
    Term.(const apply $ path $ output_dir $ wix_path)

end

let handle_result f res =
  match res with
  | Ok x -> begin
    try f x
    with exn ->
      raise (Failure (Printexc.to_string exn))
    end
  | Error err -> raise (Failure err)

let perform_subst str env =
  List.fold_left (fun res (pattern, replacement) ->
    let regex = Str.regexp_string pattern in
    Str.global_replace regex replacement res
  ) str env

let write_to_file path content =
  let oc = open_out path in
  Out_channel.output_string oc content;
  close_out oc

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
          handle_result @@ fun _ ->
            let make_msi_script = Option.get @@
              Scripts.read "make_msi.sh" in
            let make_msi_script =
              perform_subst make_msi_script
                [ "%{wix-path}%", conf.wix_path]
            in
            write_to_file (Filename.concat bundle_dir "make_msi.sh") make_msi_script


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
