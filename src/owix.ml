open Cmdliner
open OpamTypes
open OpamStateTypes

type config = {
  package : OpamPackage.Name.t;
  path : filename option;
  binary: string option;
  output_dir : dirname;
  wix_path : dirname;
  package_guid: string option;
  icon_file : filename;
  dlg_bmp : filename;
  ban_bmp : filename
}

module Args = struct
  open Arg

  let package =
    required & pos 0 (some OpamArg.package_name) None & info [] ~docv:"PACKAGE"
    ~doc:"The package to create an installer"

  let path =
    value & opt (some OpamArg.filename) None & info ["binary-path";"bp"] ~docv:"PROGRAM" ~doc:
    "The path to the binary file to handle"

  let binary =
    value & opt (some string) None & info ["binary";"b"] ~docv:"PROGRAM" ~doc:
    "The binary name to handle. Specified package should contain the binary with the same name."

  let output_dir =
    value & opt OpamArg.dirname (OpamFilename.Dir.of_string ".") & info ["output"] ~docv:"DIR" ~doc:
    "The output directory where bundle will be stored"

  let wix_path =
    value & opt OpamArg.dirname (OpamFilename.Dir.of_string "/cygdrive/c/Program Files (x86)/WiX Toolset v3.11/bin")
    & info ["wix-path"] ~docv:"DIR" ~doc:
    "The path where WIX tools are stored. The path should be full."

  let package_guid =
    value & opt (some string) None & info ["pkg-guid"] ~docv:"UID" ~doc:
    "The package GUID that will be used to update the same package with different version without processing throught Windows Apps & features panel."

  let icon_file =
    value & opt OpamArg.filename (OpamFilename.of_string "data/images/logo.ico") & info ["ico"] ~docv:"FILE" ~doc:
    "Logo icon that will be used for application."

  let dlg_bmp =
    value & opt OpamArg.filename (OpamFilename.of_string "data/images/dlgbmp.bmp") & info ["dlg-bmp"] ~docv:"FILE" ~doc:
    "BMP file that is used as background for dialog window for installer."

  let ban_bmp =
    value & opt OpamArg.filename (OpamFilename.of_string "data/images/bannrbmp.bmp") & info ["ban-bmp"] ~docv:"FILE" ~doc:
    "BMP file that is used as background for banner for installer."

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
    OpamConsole.header_msg "Checking prerequistes";
    System.check_avalable_commands (OpamFilename.Dir.to_string conf.wix_path);
    OpamConsole.header_msg "Initialising Opam";
    OpamArg.apply_global_options cli global_options;
    OpamGlobalState.with_ `Lock_read @@ fun gt ->
    OpamSwitchState.with_ `Lock_read gt @@ fun st ->
    let package =
      try OpamSwitchState.find_installed_package_by_name st conf.package
      with Not_found -> OpamConsole.error_and_exit `Not_found
      "Package %s isn't found in your current switch. Please, run %s and retry."
      (OpamConsole.colorise `bold (OpamPackage.Name.to_string conf.package))
      (OpamConsole.colorise `bold ("opam install " ^ (OpamPackage.Name.to_string conf.package)))
    in
    let opam = OpamSwitchState.opam st package in
    let bin_path = OpamPath.Switch.bin gt.root st.switch st.switch_config
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
    OpamConsole.formatted_msg "Package %s found with binaries:\n%s"
      (OpamConsole.colorise `bold (OpamPackage.to_string package))
      (OpamStd.Format.itemize (fun x -> x) binaries);
    let binary_path =
      match conf.path, conf.binary with
      | Some _, Some _ ->
        OpamConsole.error_and_exit `Bad_arguments
          "Options --binary-path and --binary can't be used together"
      | Some path, None ->
        if OpamFilename.exists path then
          if not (OpamFilename.is_exec path) then
            OpamConsole.error_and_exit `Bad_arguments
              "File %s is not executable" (OpamFilename.to_string path)
          else begin
            path
          end
        else
          OpamConsole.error_and_exit `Not_found
            "File not found at %s" (OpamFilename.to_string path)
      | None, Some binary ->
        if List.exists (String.equal binary) binaries then
          OpamFilename.Op.(bin_path // binary)
        else
          OpamConsole.error_and_exit `Not_found
            "Binary %s not found in opam installation" binary
      | None, None ->
        match binaries with
        | [bin] ->
          OpamFilename.Op.(bin_path // bin)
        | [] ->
          OpamConsole.error_and_exit `Not_found
            "No binary file found at package installation %s"
            (OpamPackage.to_string package)
        | _::_ ->
          OpamConsole.error_and_exit `False
            "owix don't handle yet several binaries, \
             choose one in the list and give it in argument \
             with option '--binary'."
    in
    OpamConsole.formatted_msg "Path to the selected binary file : %s"
      (OpamConsole.colorise `bold (OpamFilename.to_string binary_path));
    OpamConsole.header_msg "Creating installation bundle";
    OpamFilename.with_tmp_dir @@ fun tmp_dir ->
    let dlls = Cygcheck.get_dlls binary_path in
    OpamConsole.formatted_msg "Getting dlls:\n%s"
      (OpamStd.Format.itemize OpamFilename.to_string dlls);
    let bundle_dir = OpamFilename.Op.(tmp_dir / OpamPackage.to_string package) in
    OpamFilename.mkdir bundle_dir;
    List.iter (fun dll -> OpamFilename.copy_in dll bundle_dir) dlls;
    let exe_base =
      let base = OpamFilename.basename binary_path in
      if not (OpamFilename.Base.check_suffix base "exe")
      then OpamFilename.Base.add_extension base "exe"
      else base
    in
    OpamFilename.copy ~src:binary_path ~dst:(OpamFilename.create bundle_dir exe_base);
    OpamFilename.copy_in conf.icon_file bundle_dir;
    OpamFilename.copy_in conf.dlg_bmp bundle_dir;
    OpamFilename.copy_in conf.ban_bmp bundle_dir;
    OpamConsole.formatted_msg "Bundle created.";
    let module Info = struct
      open OpamStd.Option.Op
      let path =
        OpamFilename.Dir.to_string bundle_dir
      let package_name =
        OpamPackage.Name.to_string (OpamPackage.name package)
      let package_version =
        OpamPackage.Version.to_string (OpamPackage.version package)
      let description =
        (OpamFile.OPAM.synopsis opam)
        ++ (OpamFile.OPAM.descr_body opam)
        +! (Printf.sprintf "Package %s - binary %s"
              (OpamPackage.to_string package)
              (OpamFilename.to_string binary_path))
      let manufacter =
        String.concat ", "
          (OpamFile.OPAM.maintainer opam)
      let package_guid = conf.package_guid
      let tags = match OpamFile.OPAM.tags opam with [] -> ["ocaml"] | ts -> ts
      let exec_file =
        OpamFilename.Base.to_string exe_base
      let dlls = List.map (fun dll -> OpamFilename.basename dll|> OpamFilename.Base.to_string) dlls
      let icon_file = OpamFilename.basename conf.icon_file |> OpamFilename.Base.to_string
      let dlg_bmp_file = OpamFilename.basename conf.dlg_bmp |> OpamFilename.Base.to_string
      let banner_bmp_file = OpamFilename.basename conf.ban_bmp |> OpamFilename.Base.to_string
    end in
    OpamConsole.header_msg "WiX setup";
    let wxs = Wix.main_wxs (module Info) in
    let name = Filename.chop_extension (OpamFilename.Base.to_string exe_base) in
    Wix.write_wxs (name ^ ".wxs") wxs;
    OpamConsole.formatted_msg "Compiling WiX components...\n";
    let candle = System.{
      candle_wix_path = OpamFilename.Dir.to_string conf.wix_path;
      candle_files = [name ^ ".wxs"; "data/wix/CustomInstallDir.wxs"; "data/wix/CustomInstallDirDlg.wxs"];
    }
    in
    System.call_unit System.Candle candle;
    let light = System.{
      light_wix_path = OpamFilename.Dir.to_string conf.wix_path;
      light_files = [name ^ ".wixobj"; "CustomInstallDir.wixobj"; "CustomInstallDirDlg.wixobj"];
      light_exts = ["WixUIExtension"; "WixUtilExtension"];
      light_out = OpamFilename.to_string OpamFilename.Op.(conf.output_dir // (name ^ ".msi"))
    }
    in
    OpamConsole.formatted_msg "Producing final msi...\n";
    System.call_unit System.Light light;
    OpamConsole.formatted_msg "Done.\n";
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
  | exception System.System_error err ->
    OpamConsole.error_and_exit `Aborted "%s" err
  | `Error _ -> exit 1
  | _ -> exit 0
