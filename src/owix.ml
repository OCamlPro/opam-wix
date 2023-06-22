open Cmdliner

type config = {
  path : string;
  output_dir : string;
  wix_path : string;
  package_guid: string option;
  icon_file : string;
  dlg_bmp : string;
  ban_bmp : string
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
    let apply path output_dir wix_path package_guid icon_file dlg_bmp ban_bmp =
      { path; output_dir; wix_path; package_guid; icon_file; dlg_bmp; ban_bmp }
    in
    Term.(const apply $ path $ output_dir $ wix_path $ package_guid $ icon_file $
      dlg_bmp $ ban_bmp)

end

let write_to_file path content =
  let oc = open_out path in
  Out_channel.output_string oc content;
  close_out oc

let create_bundle conf =
  let dlls =Cygcheck.get_dlls conf.path in
  let bundle_dir = Filename.concat conf.output_dir
    (Filename.basename conf.path) in
  if Sys.file_exists bundle_dir then begin
    System.call_unit System.Remove (true, bundle_dir)
  end;
  System.call_unit System.Mkdir (true, bundle_dir);
  List.iter (fun dll ->
    System.call_unit System.Copy (dll, bundle_dir)
    ) dlls;
  let exe_file =
    let base = Filename.basename conf.path in
    if not (Filename.extension base = "exe")
    then base ^ ".exe"
    else base
  in
    System.call_unit System.Copy (conf.path, Filename.concat bundle_dir exe_file);
    System.call_unit System.Copy (conf.icon_file, bundle_dir);
    System.call_unit System.Copy (conf.dlg_bmp, bundle_dir);
    System.call_unit System.Copy (conf.ban_bmp, bundle_dir);
    let module Info = struct
      let path = bundle_dir
      let package_name = "frama-c"
      let package_version = "2.8.1"
      let description = "Pipiska"
      let manufacter = "OcamlPro"
      let package_guid = conf.package_guid
      let tags = ["Huy"; "Prosto"; "Ser"]
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
      ["WixUIExtension"; "WixUtilExtension"], Filename.concat conf.output_dir "frama-c.msi")
(*     System.call_unit System.Remove (false, "frama-c-gui.wxs");
    System.call_unit System.Remove (false, "frama-c-gui.wixobj");
    System.call_unit System.Remove (false, "CustomInstallDir.wixobj");
    System.call_unit System.Remove (false, "CustomInstallDirDlg.wixobj")
 *)
(*     System.call_unit System.Remove (true, bundle_dir);
 *)


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
  | exception System.System_error (cmd,out) ->
    Printf.eprintf "[SYSTEM ERROR] %s\n" cmd;
    List.iter (Printf.eprintf "%s\n") out;
    exit 2
  | Error _ -> exit 3
  | _ -> exit 0
