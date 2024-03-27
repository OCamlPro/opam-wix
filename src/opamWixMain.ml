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
  wix_version: Wix.Version.t option;
  output_dir : dirname;
  wix_path : string;
  package_guid: string option;
  icon_file : filename option;
  dlg_bmp : filename option;
  ban_bmp : filename option;
  keep_wxs : bool;
}

type embedded =
  | Copy_alias of string * string
  | Copy_external of string
  | Copy_opam of string

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

  let wix_version_conv =
    let parse str =
      try `Ok (Wix.Version.of_string str)
      with Failure s -> `Error s
    in
    let print ppf wxv = Format.pp_print_string ppf (Wix.Version.to_string wxv) in
    parse, print

  module Section = struct
    let package_arg = "PACKAGE ARGUMENT"
    let bin_args = "BINARY ARGUMENT"
  end

  let filename =
    let conv, pp = OpamArg.filename in
    (fun filename_arg -> 
      System.normalize_path filename_arg |> conv),
    pp
  
  let dirname =
    let conv, pp = OpamArg.dirname in
    (fun dirname_arg -> 
      System.normalize_path dirname_arg |> conv),
    pp

  let conffile =
    value & opt (some filename) None & info ["conf";"c"] ~docv:"PATH" ~docs:Section.bin_args
    ~doc:"Configuration file for the binary to install. See $(i,Configuration) section"

  let package =
    required & pos 0 (some OpamArg.package_name) None & info [] ~docv:"PACKAGE" ~docs:Section.package_arg
    ~doc:"The package to create an installer"

  let path =
    value & opt (some filename) None & info ["binary-path";"bp"] ~docs:Section.bin_args ~docv:"PATH" ~doc:
    "The path to the binary file to handle"

  let binary =
    value & opt (some string) None & info ["binary";"b"] ~docs:Section.bin_args ~docv:"NAME" ~doc:
    "The binary name to handle. Specified package should contain the binary with the same name."

  let wix_version =
    value & opt (some wix_version_conv) None & info ["with-version"] ~docv:"VERSION"
    ~doc:"The version to use for the installer, in an msi format, i.e. numbers and dots, [0-9.]+"

  let output_dir =
    value & opt dirname (OpamFilename.Dir.of_string ".") & info ["o";"output"] ~docv:"DIR" ~doc:
    "The output directory where bundle will be stored"

  let wix_path =
    value & opt string "/cygdrive/c/Program Files (x86)/WiX Toolset v3.11/bin"
    & info ["wix-path"] ~docv:"DIR" ~doc:
    "The path where WIX tools are stored. The path should be full and should use linux format path (with $(i,/) as delimiter) \
    since presence of such binaries are checked with $(b,which) tool that accepts only this type of path."

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

  let keep_wxs =
    value & flag & info ["keep-wxs"] ~doc:"Keep Wix source files."

  let term =
    let apply conf package path binary wix_version output_dir wix_path package_guid icon_file dlg_bmp ban_bmp keep_wxs =
      { conf; package; path; binary; wix_version; output_dir; wix_path; package_guid; icon_file; dlg_bmp; ban_bmp; keep_wxs }
    in
    Term.(const apply $ conffile $ package $ path $ binary $ wix_version $ output_dir $ wix_path $ package_guid $ icon_file $
      dlg_bmp $ ban_bmp $ keep_wxs)

end

module type FILE_INTF = sig
  type t
  val name : string
  val to_string : t -> string
  val of_string : string -> t
  val (/) : dirname -> string -> t
  val copy : src:t -> dst:t -> unit
  val exists : t -> bool
  val basename : t -> basename
end

module Dir_impl : FILE_INTF
  with type t = OpamFilename.Dir.t = struct
  include OpamFilename.Dir
  let name = "directory"
  let (/) = OpamFilename.Op.(/)
  let copy = OpamFilename.copy_dir
  let exists = OpamFilename.exists_dir
  let basename = OpamFilename.basename_dir
end

module File_impl : FILE_INTF
  with type t = OpamFilename.t = struct
  include OpamFilename
  let name = "file"
  let (/) = OpamFilename.Op.(//)
  let copy = OpamFilename.copy
  let exists = OpamFilename.exists
  let basename = OpamFilename.basename
end

let resolve_path_aux env path =
  let expanded_path = OpamFilter.expand_string env path in
  if not @@ Filename.is_relative expanded_path
  then expanded_path
  else begin
    OpamConsole.warning
      "Specified in config path %s is relative. Searching in current directory..."
        (OpamConsole.colorise `bold path);
    Filename.concat (Sys.getcwd ()) expanded_path
  end

let resolve_path (type a) env
  (module F : FILE_INTF with type t = a) path =
  F.of_string @@ resolve_path_aux env path

let normalize_conf env conf file =
  let open File.Conf in
  (* argument has precedence over config *)
  let merge_opt first second =
    match first with
    | None -> second
    | _ -> first
  in
  {
    conf with
    binary = merge_opt conf.binary file.c_binary;
    wix_version = merge_opt conf.wix_version file.c_wix_version;
    path = merge_opt conf.path
      (Option.map (resolve_path env (module File_impl)) file.c_binary_path);
    icon_file = merge_opt conf.icon_file
      (Option.map (resolve_path env (module File_impl)) file.c_images.ico);
    dlg_bmp = merge_opt conf.dlg_bmp
      (Option.map (resolve_path env (module File_impl)) file.c_images.dlg);
    ban_bmp = merge_opt conf.ban_bmp
      (Option.map (resolve_path env (module File_impl)) file.c_images.ban);
  }

let create_bundle cli =
  let create_bundle global_options conf () =
    let conffile =
      let file = OpamStd.Option.default File.conf_default conf.conf in
      File.Conf.safe_read (OpamFile.make file)
    in
    let wix_path = System.normalize_path conf.wix_path in
    System.check_avalable_commands wix_path;
    OpamConsole.header_msg "Initialising opam";
    OpamArg.apply_global_options cli global_options;
    OpamGlobalState.with_ `Lock_read @@ fun gt ->
    OpamSwitchState.with_ `Lock_read gt @@ fun st ->
    let env = OpamPackageVar.resolve ?opam:None ?local:None st in
    let conf = normalize_conf env conf conffile in
    let package =
      try OpamSwitchState.find_installed_package_by_name st conf.package
      with Not_found -> OpamConsole.error_and_exit `Not_found
      "Package %s isn't found in your current switch. Please, run %s and retry."
      (OpamConsole.colorise `bold (OpamPackage.Name.to_string conf.package))
      (OpamConsole.colorise `bold ("opam install " ^ (OpamPackage.Name.to_string conf.package)))
    in
    let package_version =
      match conf.wix_version with
      | Some v -> v
      | None ->
        let pkg_version =
          OpamPackage.Version.to_string (OpamPackage.version package)
        in
        try Wix.Version.of_string pkg_version
        with Failure _ ->
          (OpamConsole.warning
             "Package version %s contains characters not accepted by MSI."
             (OpamConsole.colorise `underline pkg_version);
           let use = "use config file to set it or option --with-version" in
           let version =
             let n =
               OpamStd.String.find_from (function '0'..'9' | '.' -> false | _ -> true)
                 pkg_version 0
             in
             if n = 0 then
               OpamConsole.error_and_exit `Not_found
                 "No version can be retrieved from '%s', %s."
                 pkg_version use
             else
               String.sub pkg_version 0 n
           in
           OpamConsole.msg
             "It must be only dot separated numbers. You can %s.\n" use;
           if
             OpamConsole.confirm "Do you want to use simplified version %s?"
               (OpamConsole.colorise `underline version)
           then version
           else OpamStd.Sys.exit_because `Aborted)
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
        let prefix, suffix =
          if Sys.cygwin
          then "bin/","" else "bin\\",".exe"
        in
        let bin =
          OpamStd.String.remove_prefix ~prefix name
          |> OpamStd.String.remove_suffix ~suffix
        in
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
              "File %s is not executable" (OpamConsole.colorise
              `bold (OpamFilename.to_string path))
          else begin
            path
          end
        else
          OpamConsole.error_and_exit `Not_found
            "File not found at %s" (OpamConsole.colorise
            `bold (OpamFilename.to_string path))
      | None, Some binary ->
        if List.exists (String.equal binary) binaries then
          let binary = if Sys.cygwin then binary else binary ^ ".exe" in
          OpamFilename.Op.(bin_path // binary)
        else
          OpamConsole.error_and_exit `Not_found
            "Binary %s not found in opam installation"
            (OpamConsole.colorise `bold binary)
      | None, None ->
        match binaries with
        | [bin] ->
          let bin = if Sys.cygwin then bin else bin ^ ".exe" in
          OpamFilename.Op.(bin_path // bin)
        | [] ->
          OpamConsole.error_and_exit `Not_found
            "No binary file found at package installation %s"
            (OpamConsole.colorise `bold (OpamPackage.to_string package))
        | _::_ ->
          OpamConsole.error_and_exit `False
            "opam-wix don't handle yet several binaries, \
             choose one in the list and give it in argument \
             with option '--binary'."
    in
    OpamConsole.formatted_msg "Path to the selected binary file : %s"
      (OpamConsole.colorise `bold (System.path_str binary_path));
    OpamConsole.header_msg "Creating installation bundle";
    OpamFilename.with_tmp_dir @@ fun tmp_dir ->
    let dlls = Cygcheck.get_dlls binary_path in
    OpamConsole.formatted_msg "Getting dlls:\n%s"
      (OpamStd.Format.itemize OpamFilename.to_string dlls);
    let bundle_dir = OpamFilename.Op.(tmp_dir / OpamPackage.to_string package) in
    OpamFilename.mkdir bundle_dir;
    let opam_dir = OpamFilename.Op.(bundle_dir / "opam") in
    let external_dir = OpamFilename.Op.(bundle_dir / "external") in
    OpamFilename.mkdir opam_dir;
    OpamFilename.mkdir external_dir;
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
    (* search and copy embedded elements *)
    let copy_embedded (type a) (module F : FILE_INTF with type t = a) path dst_base =
      let src = resolve_path env (module F) path in
      if not @@ F.exists src
      then OpamConsole.error_and_exit `Not_found
            "Couldn't find %s %s." (OpamConsole.colorise
            `bold (F.to_string src)) F.name;
      let dst = F.(bundle_dir / dst_base) in
      F.copy ~src ~dst;
      F.basename dst, dst
    in
    let copy_include path src_dir dst_dir =
      let sep = if Sys.cygwin then '/' else '\\' in
      let dirs = OpamStd.String.split path sep in
      let rec aux src dst files =
        match files with
        | [] -> ()
        | [ file ] when Sys.is_directory @@
          Filename.concat (OpamFilename.Dir.to_string src) file ->
            let src = OpamFilename.Op.(src/file) in
            let dst = OpamFilename.Op.(dst/file) in
            OpamFilename.copy_dir ~src ~dst;
        | [ file ] ->
          let src' = OpamFilename.Op.(src//file) in
          OpamFilename.copy_in src' dst;
        | file :: files ->
          let src =  OpamFilename.Op.(src/file) in
          let dst = OpamFilename.Op.(dst/file) in
          if not @@ OpamFilename.exists_dir dst then OpamFilename.mkdir dst;
          aux src dst files
      in
      aux src_dir dst_dir dirs
    in
    let emb_modes = List.filter_map (fun (path,alias) ->
        let path = OpamFilter.expand_string env path in
        let prefix = OpamPath.Switch.root gt.root st.switch |> OpamFilename.Dir.to_string in
        match alias with
        | Some alias -> Some (Copy_alias (path, alias))
        | _ when OpamStd.String.starts_with ~prefix path ->
          if not @@ Sys.file_exists path then
            OpamConsole.error_and_exit `Not_found "Couldn't find embedded %s \
            in switch prefix." (OpamConsole.colorise `bold path);
          let path =
            OpamStd.String.remove_prefix
              ~prefix:Filename.dir_sep @@
                OpamStd.String.remove_prefix ~prefix path
          in
          begin
            match String.trim path with
            | "" ->
              OpamConsole.warning "Specify a subdirectory of opam-prefix to \
              include in your installtion. Skipping...";
              None
            | _ -> Some (Copy_opam path)
          end
        | _ when not (Filename.is_relative path && Filename.is_implicit path) ->
          OpamConsole.warning "Path %s is absolute or starts with \"..\" or \".\". You should specify \
          alias with absolute path. Skipping..." path;
          None
        | _ ->
          if not @@ Sys.file_exists path
          then OpamConsole.error_and_exit `Not_found
            "Couldn't find relative path to embed: %s." (OpamConsole.colorise `bold path);
          Some (Copy_external path))
      conffile.File.Conf.c_embedded
    in
    let (embedded_dirs : (basename * dirname) list),
        (embedded_files : (basename * filename) list) =
      List.fold_left (fun (dirs, files) -> function
          | Copy_alias (dirname, alias) when Sys.is_directory dirname ->
              let dir =  copy_embedded (module Dir_impl) dirname alias in
              (dir::dirs, files)
          | Copy_alias (filename, alias) ->
            let file = copy_embedded (module File_impl) filename alias in
            (dirs, file::files)
          | Copy_opam path ->
            let prefix = OpamPath.Switch.root gt.root st.switch in
            copy_include path prefix opam_dir;
            (dirs, files)
          | Copy_external path ->
            copy_include path (OpamFilename.Dir.of_string ".") external_dir;
            (dirs, files))
        ([],[]) emb_modes
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
    let additional_embedded_name, additional_embedded_dir =
      let opam_base, opam_dir = if OpamFilename.dir_is_empty opam_dir
        then [], []
        else ["opam"], [ opam_dir ]
      and external_base, external_dir = if OpamFilename.dir_is_empty external_dir
        then [], []
        else ["external"], [ external_dir ]
      in (opam_base @ external_base), (opam_dir @ external_dir)
    in
    let module Info = struct
      open OpamStd.Option.Op
      let path =
        Filename.basename @@ OpamFilename.Dir.to_string bundle_dir
      let package_name =
        OpamPackage.Name.to_string (OpamPackage.name package)
      let package_version = package_version
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
      let environement =
        let all_paths =
          let paths =
            List.fold_left (fun paths (base, _dirname) ->
                let base = OpamFilename.Base.to_string base in
                OpamStd.String.Map.add base ("[INSTALLDIR]"^base)
                  paths)
              OpamStd.String.Map.empty embedded_dirs
          in
          List.fold_left (fun paths (base, _filename) ->
                let base = OpamFilename.Base.to_string base in
                OpamStd.String.Map.add base ("[INSTALLDIR]"^base)
                  paths)
            paths embedded_files
        in
        let env var =
          assert (OpamVariable.Full.scope var = OpamVariable.Full.Global);
          let svar = OpamVariable.Full.to_string var in
          match OpamStd.String.Map.find_opt svar all_paths with
          | None -> None
          | Some path -> Some (OpamVariable.string path)
        in
        List.map (fun (var,content) ->
            let content =
              OpamFilter.expand_string ~partial:false ~default:(fun x -> x)
                env content
            in
            var, content)
          conffile.File.Conf.c_envvar
      let embedded_dirs =
          List.map (fun base ->
              base, component_group base, dir_ref base)
            ((List.map (fun (b,_)-> OpamFilename.Base.to_string b) embedded_dirs)
            @ additional_embedded_name )
      let embedded_files =
        List.map (fun (base,_) ->
          OpamFilename.Base.to_string base)
        embedded_files
    end in
    System.call_list @@ List.map (fun (basename, dirname) ->
      let basename = OpamFilename.Base.to_string basename in
      let heat = System.{
        heat_wix_path = wix_path;
        heat_dir = OpamFilename.Dir.to_string dirname
          |> System.cyg_win_path `WinAbs;
        heat_out = Filename.concat (OpamFilename.Dir.to_string tmp_dir) basename ^ ".wxs"
          |> System.cyg_win_path `WinAbs;
        heat_component_group = component_group basename;
        heat_directory_ref = dir_ref basename;
        heat_var = Format.sprintf "var.%sDir" basename
      } in
      System.Heat, heat
      ) (embedded_dirs @
        List.map (fun dir ->
            OpamFilename.basename_dir dir,dir)
          additional_embedded_dir);
    let wxs = Wix.main_wxs (module Info) in
    let name = Filename.chop_extension (OpamFilename.Base.to_string exe_base) in
    let (addwxs1,content1),(addwxs2,content2) =
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
    let embedded_dirs = (List.map (fun (b,_) ->
        OpamFilename.Base.to_string b)
      embedded_dirs)
      @ additional_embedded_name
    in
    System.call_list @@ List.map (fun basename ->
        let candle_defines = [ Format.sprintf "%sDir=%s\\%s"
          basename (OpamPackage.to_string package) basename ]
        in
        let prefix = Filename.concat (OpamFilename.Dir.to_string tmp_dir) basename in
        let candle = System.{
          candle_wix_path = wix_path;
          candle_files = One (prefix ^ ".wxs" |> cyg_win_path `WinAbs,
            prefix ^ ".wixobj" |> cyg_win_path `WinAbs);
          candle_defines
        } in
        System.Candle, candle
      ) embedded_dirs ;
    let wxs_files =
      (OpamFilename.to_string main_path |> System.cyg_win_path `WinAbs)
        :: additional_wxs
    in
    let candle = System.{
      candle_wix_path = wix_path;
      candle_files = Many wxs_files;
      candle_defines = []
    } in
    System.call_unit System.Candle candle;
    if conf.keep_wxs
    then begin
      List.iter (fun file ->
        OpamFilename.copy_in (OpamFilename.of_string file)
        @@ OpamFilename.cwd ())
      wxs_files
    end;
    let main_obj = name ^ ".wixobj" in
    let addwxs1_obj = Filename.chop_extension addwxs1 ^ ".wixobj" in
    let addwxs2_obj = Filename.chop_extension addwxs2 ^ ".wixobj" in
    OpamFilename.move ~src:(OpamFilename.of_string main_obj)
      ~dst:OpamFilename.Op.(tmp_dir // main_obj);
    OpamFilename.move ~src:(OpamFilename.of_string addwxs1_obj)
      ~dst:OpamFilename.Op.(tmp_dir // addwxs1_obj);
    OpamFilename.move ~src:(OpamFilename.of_string addwxs2_obj)
      ~dst:OpamFilename.Op.(tmp_dir // addwxs2_obj);
    let wixobj_files = [
      Filename.concat (OpamFilename.Dir.to_string tmp_dir) main_obj
        |> System.cyg_win_path `WinAbs;
      Filename.concat (OpamFilename.Dir.to_string tmp_dir) addwxs1_obj
        |> System.cyg_win_path `WinAbs;
      Filename.concat (OpamFilename.Dir.to_string tmp_dir) addwxs2_obj
        |> System.cyg_win_path `WinAbs;
    ] @
    List.map (fun base ->
      Filename.concat (OpamFilename.Dir.to_string tmp_dir)
        base ^ ".wixobj"
      |> System.cyg_win_path `WinAbs ) embedded_dirs
    in
    let light = System.{
      light_wix_path = wix_path;
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
      will be considered as a part of package and its metadata. ");
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
    `I ("$(i,wix_version)","The version to use to generate the MSI, in a dot separated number format.");
    `I ("$(i,embedded)", "A list of files or directories paths to include in the installation directory. \
    There are 3 different ways to specify the paths, each of them implies its own installation place in \
    the target directory: \
    First way to install files is by giving a list of two elements: the first being the destination \
    basename (the name of the file in the installation directory), and the second being the \
    path to the file itself. For example: $(b,[\"file.txt\" \"path/to/file\"]). \
    The second way is to include any file/directory under opam prefix. In this case, variables like \
    $(i,%{share}%) or $(i,%{lib}%) could be very usefull. You should just give a list with one string that \
    represents path which prefix is the same with your current switch prefix. For example, \
    $(b,[\"/absolute-path-to-your-prefix/lib/odoc/odoc.cmi\"]) or just $(b,[\"/%{odoc:lib}%/odoc.cmi\"]). \
    Those files would be installed in the directory \"opam\" at the root of installation directory conserving \
    entire path (it would be $(b,INSTALLDIR/opam/lib/odoc/odoc.cmi) for previous example). \
    The last way to specify path is very similar with previous, but it takes into account only external to opam files. \
    The paths to thoses files should be relative and implicit. For example, $(b,[\"dir1/dir2/file.txt\"]). \
    The file (or directory) will be installed in \"external\" directory under the root of target installation directory \
    the same way as for opam files (it would be $(b,INSTALLDIR/external/dir1/dir2/file.txt) for previous example).");
    `I ("$(i,envvar)", "A list of environment variables to set/unset in the Windows Terminal during \
    install/uninstall. Each element in this list should be a list of two elements: the name and the \
    value of the variable. Basenames defined with $(b,embedded) field could be used as variables, to reference \
    absolute installed path. For example: $(b,embedded: [ \"mydoc\" \"%{package:doc}%\"] envvar: [ \"DOC\" \"%{mydoc}%\"]) \
    will install directory referenced by $(i,package:doc) opam variable in $(i,<install-dir>/mydoc) \
    and set $(i,DOC) environment variable to the $(i,<install-dir>/mydoc) absolute path.");
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
  let terminfo = create_bundle (OpamCLIVersion.current, `Default) in
  match Term.eval ~catch:false terminfo with
  | exception System.System_error err ->
    OpamConsole.error_and_exit `Aborted "%s" err
  | `Error _ -> exit 1
  | _ -> exit 0
