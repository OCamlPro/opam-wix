(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Cmdliner
open OpamTypes
open OpamStateTypes

type config = {
  conf: OpamFilename.t option;
  package : OpamPackage.Name.t;
  path : filename option;
  binary: string option;
  output_dir : dirname;
  wix_path : dirname;
  package_guid: string option;
  icon_file : filename option;
  dlg_bmp : filename option;
  ban_bmp : filename option
}

let get_data o filename =
  try Option.get o with
  | Invalid_argument _ -> OpamConsole.error_and_exit `Configuration_error
  "Seems like you moved your %s. This file is required since it is used by default. \
  If you want to replace it by your default choice, but keep the same name and path."
  (OpamConsole.colorise `bold filename)

(** Data directory with crunched content. Every pair value within represents filename and its content. *)
module DataDir = struct
  open DataDir
  module Images = struct
    let logo = "logo.ico", get_data (read "images/logo.ico") "data/images/logo.ico"
    let dlgbmp = "dlgbmp.bmp", get_data (read "images/dlgbmp.bmp") "data/images/dlgbmp.bmp"
    let banbmp = "bannrbmp.bmp", get_data (read "images/bannrbmp.bmp") "data/images/bannrbmp.bmp"
  end
  module Wix = struct
    let custom_install_dir =
      "CustomInstallDir.wxs",
      get_data (read "wix/CustomInstallDir.wxs") "data/wix/CustomInstallDir.wxs"
    let custom_install_dir_dlg =
      "CustomInstallDirDlg.wxs",
      get_data (read "wix/CustomInstallDirDlg.wxs") "data/wix/CustomInstallDirDlg.wxs"
  end
end

module Args = struct
  open Arg

  module Section = struct
    let package_arg = "PACKAGE ARGUMENT"
    let bin_args = "BINARY ARGUMENT"
  end

  let conffile =
    value & opt (some OpamArg.filename) None & info ["conf";"c"] ~docv:"PATH" ~docs:Section.bin_args
    ~doc:"Configuration file for the binary to install. See $(i,Configuration) section"

  let package =
    required & pos 0 (some OpamArg.package_name) None & info [] ~docv:"PACKAGE" ~docs:Section.package_arg
    ~doc:"The package to create an installer"

  let path =
    value & opt (some OpamArg.filename) None & info ["binary-path";"bp"] ~docs:Section.bin_args ~docv:"PATH" ~doc:
    "The path to the binary file to handle"

  let binary =
    value & opt (some string) None & info ["binary";"b"] ~docs:Section.bin_args ~docv:"NAME" ~doc:
    "The binary name to handle. Specified package should contain the binary with the same name."

  let output_dir =
    value & opt OpamArg.dirname (OpamFilename.Dir.of_string ".") & info ["o";"output"] ~docv:"DIR" ~doc:
    "The output directory where bundle will be stored"

  let wix_path =
    value & opt OpamArg.dirname (OpamFilename.Dir.of_string "/cygdrive/c/Program Files (x86)/WiX Toolset v3.11/bin")
    & info ["wix-path"] ~docv:"DIR" ~doc:
    "The path where WIX tools are stored. The path should be full."

  let package_guid =
    value & opt (some string) None & info ["pkg-guid"] ~docv:"UID" ~doc:
    "The package GUID that will be used to update the same package with different version without processing throught \
    Windows Apps & features panel."

  let icon_file =
    value & opt (some OpamArg.filename) None & info ["ico"] ~docv:"FILE" ~doc:
    "Logo icon that will be used for application."

  let dlg_bmp =
    value & opt (some OpamArg.filename) None & info ["dlg-bmp"] ~docv:"FILE" ~doc:
    "BMP file that is used as background for dialog window for installer."

  let ban_bmp =
    value & opt (some OpamArg.filename) None & info ["ban-bmp"] ~docv:"FILE" ~doc:
    "BMP file that is used as background for banner for installer."

  let term =
    let apply conf package path binary output_dir wix_path package_guid icon_file dlg_bmp ban_bmp =
      { conf; package; path; binary; output_dir; wix_path; package_guid; icon_file; dlg_bmp; ban_bmp }
    in
    Term.(const apply $ conffile $ package $ path $ binary $ output_dir $ wix_path $ package_guid $ icon_file $
      dlg_bmp $ ban_bmp)

end

let normalize_conf conf file =
  let open File.Conf in
  (* argument has precedence over config *)
  let merge_opt first second =
    match first with
    | None -> second
    | _ -> first
  in
  {
    conf with
    path = merge_opt conf.path file.c_binary_path;
    binary = merge_opt conf.binary file.c_binary;
    icon_file = merge_opt conf.icon_file file.c_images.ico;
    dlg_bmp = merge_opt conf.dlg_bmp file.c_images.dlg;
    ban_bmp = merge_opt conf.ban_bmp file.c_images.ban
  }

let create_bundle cli =
  let create_bundle global_options conf () =
    let conffile =
      let file = OpamStd.Option.default File.conf_default conf.conf in
      File.Conf.safe_read (OpamFile.make file)
    in
    let conf = normalize_conf conf conffile in
    System.check_avalable_commands (OpamFilename.Dir.to_string conf.wix_path);
    OpamConsole.header_msg "Initialising opam";
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
    let bin_path = OpamPath.Switch.bin gt.root st.switch st.switch_config in
    let changes =
      OpamPath.Switch.changes gt.root st.switch conf.package
      |> OpamFile.Changes.safe_read
      |> OpamStd.String.Map.keys
    in
    let binaries =
      List.filter_map (fun name ->
        let bin = OpamStd.String.remove_prefix ~prefix:"bin/" name in
        if String.equal bin name then None
        else Some bin) changes
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
            "opam-wix don't handle yet several binaries, \
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
    let copy_data data_path (name, content) =
      match data_path with
      | Some path -> OpamFilename.copy_in path bundle_dir
      | None -> OpamFilename.write OpamFilename.Op.(bundle_dir // name) content
    in
    OpamFilename.copy ~src:binary_path ~dst:(OpamFilename.create bundle_dir exe_base);
    copy_data conf.icon_file DataDir.Images.logo;
    copy_data conf.dlg_bmp DataDir.Images.dlgbmp;
    copy_data conf.ban_bmp DataDir.Images.banbmp;
    let switch_prefix = OpamPath.Switch.root gt.root st.switch in
    (* search and copy embedded dirs *)
    let embedded_dirs = List.map (fun (name, dirname) ->
      let in_changes =
        List.exists (fun install_item ->
          OpamFilename.Dir.of_string install_item = dirname)
          changes
      in
      let src =
        if not in_changes
        then begin
          OpamConsole.warning
            "Directory %s couldn't be found in opam switch. \
            Searching in current working directory..."
            (OpamFilename.Dir.to_string dirname);
          dirname
        end else
          OpamFilename.Op.(switch_prefix /
            OpamFilename.Dir.to_string dirname)
      in
      if not @@ OpamFilename.exists_dir src then
        OpamConsole.error_and_exit `Not_found
          "Directory %s doesn't exists"
          (OpamFilename.Dir.to_string dirname);
      let dst = OpamFilename.Op.(bundle_dir /
        OpamFilename.Base.to_string name)
      in
      OpamFilename.copy_dir ~src ~dst;
      OpamFilename.basename_dir dst, dst ) conffile.File.Conf.c_embbed_dir
    in
    (* search and copy embedded files *)
    let embedded_files = List.map (fun filename ->
      let in_changes =
        List.exists (fun install_item ->
          OpamFilename.of_string install_item = filename)
          changes
      in
      let src =
        if not in_changes
        then begin
          OpamConsole.warning
            "File %s couldn't be found in opam switch. \
            Searching in current working directory..."
            (OpamFilename.to_string filename);
          filename
        end else
          OpamFilename.Op.(switch_prefix //
            OpamFilename.to_string filename)
      in
      if not @@ OpamFilename.exists src then
        OpamConsole.error_and_exit `Not_found
          "File %s doesn't exists"
          (OpamFilename.to_string filename);
      let dst = OpamFilename.Op.(bundle_dir //
        OpamFilename.to_string filename)
      in
      OpamFilename.copy ~src ~dst;
      OpamFilename.basename dst) conffile.File.Conf.c_embbed_file
    in
    OpamConsole.formatted_msg "Bundle created.";
    OpamConsole.header_msg "WiX setup";
    let data_basename data (name,_) =
      match data with
      | Some data ->
        OpamFilename.basename data
        |> OpamFilename.Base.to_string
      | None -> name
    in
    let component_group basename =
      String.mapi
        (fun i c -> if i = 0 then Char.uppercase_ascii c else c)
        basename
      ^ "CG"
    in
    let dir_ref basename = basename ^ "_REF" in
    let module Info = struct
      open OpamStd.Option.Op
      let path =
        Filename.basename @@ OpamFilename.Dir.to_string bundle_dir
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
      let manufacturer =
        String.concat ", "
          (OpamFile.OPAM.maintainer opam)
      let package_guid = conf.package_guid
      let tags = match OpamFile.OPAM.tags opam with [] -> ["ocaml"] | ts -> ts
      let exec_file =
        OpamFilename.Base.to_string exe_base
      let dlls = List.map (fun dll -> OpamFilename.basename dll|> OpamFilename.Base.to_string) dlls
      let icon_file = data_basename conf.icon_file DataDir.Images.logo
      let dlg_bmp_file = data_basename conf.dlg_bmp DataDir.Images.dlgbmp
      let banner_bmp_file = data_basename conf.ban_bmp DataDir.Images.banbmp
      let embedded_dirs = List.map (fun (base,_) ->
        let base = OpamFilename.Base.to_string base in
        base, component_group base, dir_ref base) embedded_dirs
      let embedded_files = List.map OpamFilename.Base.to_string embedded_files
    end in
    System.call_list @@ List.map (fun (basename, dirname) ->
      let basename = OpamFilename.Base.to_string basename in
      let heat = System.{
        heat_wix_path = OpamFilename.Dir.to_string conf.wix_path;
        heat_dir = OpamFilename.Dir.to_string dirname;
        heat_out = Filename.concat (OpamFilename.Dir.to_string tmp_dir) basename ^ ".wxs";
        heat_component_group = component_group basename;
        heat_directory_ref = dir_ref basename
      } in
      System.Heat, heat
      ) embedded_dirs;
    let wxs = Wix.main_wxs (module Info) in
    let name = Filename.chop_extension (OpamFilename.Base.to_string exe_base) in
    let (addwxs1,content1),(addwxs2,content2)  =
      DataDir.Wix.custom_install_dir,
      DataDir.Wix.custom_install_dir_dlg
    in
    OpamFilename.write OpamFilename.Op.(tmp_dir//addwxs1) content1;
    OpamFilename.write OpamFilename.Op.(tmp_dir//addwxs2) content2;
    let additional_wxs = List.map
      (fun d -> OpamFilename.to_string d |> System.cyg_win_path `WinAbs)
      OpamFilename.Op.[ tmp_dir//addwxs1; tmp_dir//addwxs2 ]
    in
    let main_path = OpamFilename.Op.(tmp_dir // (name ^ ".wxs")) in
    Wix.write_wxs (OpamFilename.to_string main_path) wxs;
    OpamConsole.formatted_msg "Compiling WiX components...\n";
    let wxs_files =
      let embedded_wxs =
        List.map (fun (base, _) ->
          let base = OpamFilename.Base.to_string base in
          Filename.concat (OpamFilename.Dir.to_string tmp_dir) base ^ ".wxs"
          ) embedded_dirs
      in
      (OpamFilename.to_string main_path |> System.cyg_win_path `WinAbs)
      :: additional_wxs @ embedded_wxs
    in
    let candle = System.{
      candle_wix_path = OpamFilename.Dir.to_string conf.wix_path;
      candle_files = wxs_files
    }
    in
    System.call_unit System.Candle candle;
    OpamFilename.remove (OpamFilename.of_string (name ^ ".wxs"));
    OpamFilename.remove (OpamFilename.of_string addwxs1);
    OpamFilename.remove (OpamFilename.of_string addwxs2);
    let main_obj = name ^ ".wixobj" in
    let addwxs1_obj = Filename.chop_extension addwxs1 ^ ".wixobj" in
    let addwxs2_obj = Filename.chop_extension addwxs2 ^ ".wixobj" in
    let embedded_obj = List.map (fun (base,_) ->
      OpamFilename.Base.to_string base ^ ".wixobj"
      ) embedded_dirs
    in
    OpamFilename.move ~src:(OpamFilename.of_string main_obj)
      ~dst:OpamFilename.Op.(tmp_dir // main_obj);
    OpamFilename.move ~src:(OpamFilename.of_string addwxs1_obj)
      ~dst:OpamFilename.Op.(tmp_dir // addwxs1_obj);
    OpamFilename.move ~src:(OpamFilename.of_string addwxs2_obj)
      ~dst:OpamFilename.Op.(tmp_dir // addwxs2_obj);
    List.iter (fun obj ->
      OpamFilename.move
        ~src:(OpamFilename.of_string obj)
        ~dst:OpamFilename.Op.(tmp_dir // obj)
      ) embedded_obj;
    let wixobj_files = [
      Filename.concat (OpamFilename.Dir.to_string tmp_dir) main_obj
        |> System.cyg_win_path `WinAbs;
      Filename.concat (OpamFilename.Dir.to_string tmp_dir) addwxs1_obj
        |> System.cyg_win_path `WinAbs;
      Filename.concat (OpamFilename.Dir.to_string tmp_dir) addwxs2_obj
        |> System.cyg_win_path `WinAbs
    ]
    in
    let light = System.{
      light_wix_path = OpamFilename.Dir.to_string conf.wix_path;
      light_files = wixobj_files;
      light_exts = ["WixUIExtension"; "WixUtilExtension"];
      light_out = (name ^ ".msi")
    }
    in
    OpamConsole.formatted_msg "Producing final msi...\n";
    System.call_unit System.Light light;
    OpamFilename.remove (OpamFilename.of_string (name ^ ".wixpdb"));
    OpamFilename.move
      ~src:(OpamFilename.of_string (name ^ ".msi"))
      ~dst:OpamFilename.Op.(conf.output_dir // (name ^ ".msi"));
    OpamConsole.formatted_msg "Done.\n";
    OpamSwitchState.drop st;
    OpamGlobalState.drop gt
  in
  let doc =
    "Windows MSI installer generation for opam packages"
  in
  let man = [
    `S Manpage.s_synopsis;
    `P "$(b,opam-wix) $(i,PACKAGE) [-b $(i,NAME)|--bp $(i,PATH)] [$(i,OTHER OPTION)]… ";
    `S Manpage.s_description;
    `P "This utility is an opam plugin that generates a standalone MSI file. This file is \
    used by Windows Installer to make available a chosen executable from an opam package \
    throughout the entire system.";
    `P "Generated MSI indicates to system to create an installation directory named \
    '$(b,Package Version.Executable)' under \"Program Files\" folder and to store there \
    the following items:";
    `I ("$(i,executable.exe)",
      "The selected executable file from package 'PACK'. There are two options how to indicate \
      where to find this binary. First, is to let opam find binary with the same name for you with \
      $(b,-b) option. Second, is to use the path to binary with $(b,--bp) option. In this case binary \
      will be considered as a part of package and its metadata.");
    `I ("$(i,*.dll)",
      "All executable's dependencies libriries found with $(b,cygcheck).");
    `I ("$(i,icon and *.bmp)",
      "Additional files used by installer to customise GUI. Options $(b,--ico), $(b,--dlg-bmp) and \
      $(b,--ban-bmp) could be used to bundle custom files.");
    `P "Additionnaly, installer gives to user a possibility to create a shortcut on Desktop and Start \
    menu as well as adding installation folder to the PATH.";
    `S "Configuration";
    `P "Despite arguments allowing partial configuration of the utility, for complete support of installing \
    complex programs and non self-contained binaries, it is necessary to provide a config file with \
    $(b,opam-format syntax) (See https://opam.ocaml.org/doc/Manual.html). Such a file allows opam-wix to \
    determine which additional files and directories should be installed along with the program, as well \
    as which environment variables need to be set in the Windows Terminal.";
    `P "To specify paths to specific files, you can use variables defined by opam, for example, \
    $(i,%{share}%/path), which adds the necessary prefix. For more information about variables, \
    refer to https://opam.ocaml.org/doc/Manual.html#Variables. The config file can contain the following \
    fields:";
    `I ("$(i,opamwix-version)","The version of the config file. The current version is $(b,0.1).");
    `I ("$(i,ico, bng, ban)","These are the same as their respective arguments.");
    `I ("$(i,binary-path, binary)","These are the same as their respective arguments.");
    `I ("$(i,embed-file)","A list of file paths to include in the installation directory.");
    `I ("$(i,embed-dir)", "A list of directory paths to include in the installation directory. \
     Each element in this list should be a list of two elements: the first being the destination \
    basename (the name of the directory in the installation directory), and the second being the \
    path to the directory itself. For example: $(i,[\"data\" \"path/to/data\"]).");
    `I ("$(i,envvar)", "A list of environment variables to set/unset in the Windows Terminal during \
    install/uninstall. Each element in this list should be a list of two elements: the name and the \
    value of the variable.");
  ]
  in
  OpamArg.mk_command ~cli OpamArg.cli_original "opam-wix" ~doc ~man
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
