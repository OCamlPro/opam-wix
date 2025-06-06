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
open Types

let get_data o filename =
  match o with
  | Some v -> v
  | None -> OpamConsole.error_and_exit `Configuration_error
  "Seems like you moved your %s. This file is required since it is used by default. \
  If you want to replace it by your default choice, but keep the same name and path."
  (OpamConsole.colorise `bold filename)

(** Data directory with crunched content. Every pair value within represents filename and its content. *)
module DATADIR = struct

  let get basename subdir =
    let filename = Filename.concat subdir basename in
    basename,
    get_data (DataDir.read filename) (Filename.concat "data" filename)

  module IMAGES = struct
    let logo = get "logo.ico" "images"
    let dlgbmp = get "dlgbmp.bmp" "images"
    let banbmp = get "bannrbmp.bmp" "images"
  end
  module WIX = struct
    let custom_install_dir = get "CustomInstallDir.wxs" "wix"
    let custom_install_dir_dlg = get "CustomInstallDirDlg.wxs" "wix"
  end
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

module DIR_IMPL : FILE_INTF
  with type t = OpamFilename.Dir.t = struct
  include OpamFilename.Dir
  let name = "directory"
  let (/) = OpamFilename.Op.(/)
  let copy = OpamFilename.copy_dir
  let exists = OpamFilename.exists_dir
  let basename = OpamFilename.basename_dir
end

module FILE_IMPL : FILE_INTF
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
             (Option.map (resolve_path env (module FILE_IMPL)) file.c_binary_path);
    icon_file = merge_opt conf.icon_file
                  (Option.map (resolve_path env (module FILE_IMPL)) file.c_images.ico);
    dlg_bmp = merge_opt conf.dlg_bmp
                (Option.map (resolve_path env (module FILE_IMPL)) file.c_images.dlg);
    ban_bmp = merge_opt conf.ban_bmp
                (Option.map (resolve_path env (module FILE_IMPL)) file.c_images.ban);
  }


let create_bundle cli global_options conf () =
  let conffile =
    let file = OpamStd.Option.default File.conf_default conf.conf in
    File.Conf.safe_read (OpamFile.make file)
  in
  let wix_path = System.normalize_path conf.wix_path in
  System.check_available_commands wix_path;
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
  copy_data conf.icon_file DATADIR.IMAGES.logo;
  copy_data conf.dlg_bmp DATADIR.IMAGES.dlgbmp;
  copy_data conf.ban_bmp DATADIR.IMAGES.banbmp;
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
          let dir =  copy_embedded (module DIR_IMPL) dirname alias in
          (dir::dirs, files)
        | Copy_alias (filename, alias) ->
          let file = copy_embedded (module FILE_IMPL) filename alias in
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
    let opam_base, opam_dir = match OpamFilename.dir_is_empty opam_dir with
      | None | Some (true) -> [], []
      | Some (false) -> ["opam"], [ opam_dir ]
    and external_base, external_dir = match OpamFilename.dir_is_empty external_dir with
      | None | Some (true) -> [], []
      | Some (false) -> ["external"], [ external_dir ]
    in (opam_base @ external_base), (opam_dir @ external_dir)
  in
  let info =
    let open OpamStd.Option.Op in
    {
      Wix.path =
        Filename.basename @@ OpamFilename.Dir.to_string bundle_dir ;
      package_name =
        OpamPackage.Name.to_string (OpamPackage.name package) ;
      package_version = package_version ;
      description =
        (OpamFile.OPAM.synopsis opam)
        ++ (OpamFile.OPAM.descr_body opam)
        +! (Printf.sprintf "Package %s - binary %s"
              (OpamPackage.to_string package)
              (OpamFilename.to_string binary_path)) ;
      manufacturer =
        String.concat ", "
          (OpamFile.OPAM.maintainer opam) ;
      package_guid = conf.package_guid ;
      tags = (match OpamFile.OPAM.tags opam with [] -> ["ocaml"] | ts -> ts );
      exec_file =
        OpamFilename.Base.to_string exe_base ;
      dlls = List.map (fun dll -> OpamFilename.basename dll|> OpamFilename.Base.to_string) dlls ;
      icon_file = data_basename conf.icon_file DATADIR.IMAGES.logo ;
      dlg_bmp_file = data_basename conf.dlg_bmp DATADIR.IMAGES.dlgbmp ;
      banner_bmp_file = data_basename conf.ban_bmp DATADIR.IMAGES.banbmp ;
      environment =
        (let all_paths =
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
           conffile.File.Conf.c_envvar) ;
      embedded_dirs =
        List.map (fun base ->
            base, component_group base, dir_ref base)
          ((List.map (fun (b,_)-> OpamFilename.Base.to_string b) embedded_dirs)
           @ additional_embedded_name ) ;
      embedded_files =
        List.map (fun (base,_) ->
            OpamFilename.Base.to_string base)
          embedded_files ;
    } in
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
  let wxs = Wix.main_wxs info in
  let name = Filename.chop_extension (OpamFilename.Base.to_string exe_base) in
  let (addwxs1,content1),(addwxs2,content2) =
    DATADIR.WIX.custom_install_dir,
    DATADIR.WIX.custom_install_dir_dlg
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
