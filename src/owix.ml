open Cmdliner
open OpamTypes
open OpamStateTypes

type config = {
  package : OpamPackage.Name.t;
  path : string option;
  binary: string option;
  output_dir : string;
  wix_path : string;
  package_guid: string option;
  icon_file : string;
  dlg_bmp : string;
  ban_bmp : string
}

module Args = struct
  open Arg

  let package =
    required & pos 0 (some OpamArg.package_name) None & info [] ~docv:"PACKAGE"
    ~doc:"The package to create an installer"

  let path =
    value & opt (some file) None & info ["binary-path";"bp"] ~docv:"PROGRAM" ~doc:
    "The path to the binary file to handle"

  let binary =
    value & opt (some string) None & info ["binary";"b"] ~docv:"PROGRAM" ~doc:
    "The path to the binary file to handle"

  let output_dir =
    value & opt dir "." & info ["output"] ~docv:"DIR" ~doc:
    "The output directory where bundle will be stored"

  let wix_path =
    value & opt dir "/cygdrive/c/Program Files (x86)/WiX Toolset v3.11/bin" & info ["wix-path"] ~docv:"DIR" ~doc:
    "The path where WIX tools are stored. The path should be full."

  let package_guid =
    value & opt (some string) None & info ["pkg-guid"] ~docv:"UID" ~doc:
    "The package GUID that will be used to update the same package with different version without processing throught Windows Apps & features panel."

  let icon_file =
    value & opt file "data/images/logo.ico" & info ["ico"] ~docv:"FILE" ~doc:
    "Logo icon that will be used for application."

  let dlg_bmp =
    value & opt file "data/images/dlgbmp.bmp" & info ["dlg-bmp"] ~docv:"FILE" ~doc:
    "BMP file that is used as background for dialog window."

  let ban_bmp =
    value & opt file "data/images/bannrbmp.bmp" & info ["ban-bmp"] ~docv:"FILE" ~doc:
    "BMP file that is used as background for banner."

  let term =
    let apply package path binary output_dir wix_path package_guid icon_file dlg_bmp ban_bmp =
      { package; path; binary; output_dir; wix_path; package_guid; icon_file; dlg_bmp; ban_bmp }
    in
    Term.(const apply $ package $ path $ binary $ output_dir $ wix_path $ package_guid $ icon_file $
      dlg_bmp $ ban_bmp)

end

let write_to_file path content =
  let oc = open_out path in
  Out_channel.output_string oc content;
  close_out oc

let create_bundle cli =
  let create_bundle global_options conf () =
    OpamArg.apply_global_options cli global_options;
    OpamGlobalState.with_ `Lock_read @@ fun gt ->
    OpamSwitchState.with_ `Lock_read gt @@ fun st ->
    let package =
    OpamSwitchState.find_installed_package_by_name st conf.package
    in
    let opam = OpamSwitchState.opam st package in
    let bin_path =
      OpamFilename.Dir.to_string
        (OpamPath.Switch.bin gt.root st.switch st.switch_config)
    in
    let binaries =
      OpamPath.Switch.changes gt.root st.switch conf.package
      |> OpamFile.Changes.safe_read
      |> OpamStd.String.Map.keys
      |> List.filter_map (fun name ->
          let bin = OpamStd.String.remove_prefix ~prefix:"bin/" name in
          if String.equal bin name then None
          else Some bin)
    in
    let binary_path =
      match conf.path, conf.binary with
      | Some _, Some _ ->
        OpamConsole.error_and_exit `Bad_arguments
          "--binary-path and --binary can't be used together"
      | Some path, None ->
        if Sys.file_exists path then
          if OpamSystem.is_exec path then
            OpamConsole.error_and_exit `Bad_arguments
              "File %s is not executable" path
          else path
        else
          OpamConsole.error_and_exit `Not_found
            "File not found at %s" path
      | None, Some binary ->
        if List.exists (String.equal binary) binaries then
          Filename.concat bin_path binary
        else
          OpamConsole.error_and_exit `Not_found
            "Binary %s not found in opam installation" binary
      | None, None ->
        match binaries with
        | [bin] ->
          Filename.concat bin_path bin
        | [] ->
          OpamConsole.error_and_exit `Not_found
            "No binary file found at package installation %s"
            (OpamPackage.to_string package)
        | _::_ ->
          OpamConsole.error_and_exit `False
            "owix don't handle yet several binaries, \
             choose one in the list and give it in argument \
             with option '--binary':%s"
            (OpamStd.Format.itemize (fun x -> x) binaries)
    in
    let dlls =Cygcheck.get_dlls binary_path in
    let bundle_dir =
      Filename.concat conf.output_dir
        (OpamPackage.to_string package)
    in
    if Sys.file_exists bundle_dir then begin
      System.call_unit System.Remove (true, bundle_dir)
    end;
    System.call_unit System.Mkdir (true, bundle_dir);
    List.iter (fun dll ->
        System.call_unit System.Copy (dll, bundle_dir)
      ) dlls;
    let exe_file =
      let base = Filename.basename binary_path in
      if not (Filename.extension base = "exe")
      then base ^ ".exe"
      else base
    in
    System.call_unit System.Copy (binary_path, Filename.concat bundle_dir exe_file);
    System.call_unit System.Copy (conf.icon_file, bundle_dir);
    System.call_unit System.Copy (conf.dlg_bmp, bundle_dir);
    System.call_unit System.Copy (conf.ban_bmp, bundle_dir);
    let module Info = struct
      open OpamStd.Option.Op
      let path = bundle_dir
      let package_name =
        OpamPackage.Name.to_string (OpamPackage.name package)
      let package_version =
        OpamPackage.Version.to_string (OpamPackage.version package)
      let description =
        (OpamFile.OPAM.synopsis opam)
        ++ (OpamFile.OPAM.descr_body opam)
        +! (Printf.sprintf "Package %s - binary %s"
              (OpamPackage.to_string package)
              (Filename.basename binary_path))
      let manufacter =
        String.concat ", "
          (OpamFile.OPAM.maintainer opam)
      let package_guid = conf.package_guid
      let tags = OpamFile.OPAM.tags opam
      let exec_file = exe_file
      let dlls = List.map Filename.basename dlls
      let icon_file = Filename.basename conf.icon_file
      let dlg_bmp_file = Filename.basename conf.dlg_bmp
      let banner_bmp_file = Filename.basename conf.ban_bmp
    end in
    let wxs = Wix.main_wxs (module Info) in
    Wix.write_wxs "frama-c.wxs" wxs;
    System.call_unit System.Candle (conf.wix_path, ["frama-c.wxs"; "data/wix/CustomInstallDir.wxs"; "data/wix/CustomInstallDirDlg.wxs"]);
    System.call_unit System.Light (conf.wix_path, ["frama-c.wixobj"; "CustomInstallDir.wixobj"; "CustomInstallDirDlg.wixobj"],
                                   ["WixUIExtension"; "WixUtilExtension"], Filename.concat conf.output_dir "frama-c.msi");
    (*     System.call_unit System.Remove (false, "frama-c-gui.wxs");
           System.call_unit System.Remove (false, "frama-c-gui.wixobj");
           System.call_unit System.Remove (false, "CustomInstallDir.wixobj");
           System.call_unit System.Remove (false, "CustomInstallDirDlg.wixobj")
    *)
    (*     System.call_unit System.Remove (true, bundle_dir);
    *)
    OpamSwitchState.drop st;
    OpamGlobalState.drop gt
  in
  let doc =
    "Windows msi bundeling for cygwin program"
  in
  let man = [
    `S Manpage.s_description;
    `P "owix..........";
  ]
  in
  OpamArg.mk_command ~cli OpamArg.cli_original "owix" ~doc ~man
    Term.(const create_bundle
          $ OpamArg.global_options cli
          $ Args.term)

let () =
  OpamSystem.init ();
  (* OpamArg.preinit_opam_envvariables (); *)
  OpamCliMain.main_catch_all @@ fun () ->
(*
  for cmdliner 1.2.0
  let term, info = create_bundle (OpamCLIVersion.default, `Default) in
  exit @@ Cmd.eval ~catch:false (Cmd.v info term)
*)
  let terminfo = create_bundle (OpamCLIVersion.default, `Default) in
  match Term.eval ~catch:false terminfo with
  | `Error _ -> exit 1
  | _ -> exit 0


(*
let () =
  match
    Cmd.eval_value ~catch:false (Cmd.v main_info main_term)
  with
  | exception Failure msg ->
    Printf.eprintf "[ERROR] %s\n" msg;
    exit 1
  | exception System.System_error (cmd,out) ->
    Printf.eprintf "[SYSTEM ERROR] %s\n" cmd;
    List.iter (Printf.eprintf "%s\n") out;
    exit 2
  | Error _ -> exit 3
  | _ -> exit 0
*)
