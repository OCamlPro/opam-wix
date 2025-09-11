(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Types


let create_bundle conf (desc : Installer_config.t) ~tmp_dir =
  let wix_path = System.normalize_path conf.conf_wix_path in
  System.check_available_commands wix_path;
  OpamConsole.header_msg "WiX setup";
  let component_group basename =
    String.capitalize_ascii basename ^ "CG"
  in
  let dir_ref basename = basename ^ "_REF" in
  let info =
    {
      Wix.wix_path =
        Filename.basename @@ OpamFilename.Dir.to_string desc.package_dir ;
      wix_name = desc.package_name;
      wix_version = desc.package_version ;
      wix_description = desc.package_description ;
      wix_manufacturer = desc.package_manufacturer ;
      wix_guid = conf.conf_package_guid ;
      wix_tags = desc.package_tags ;
      wix_exec_file = desc.package_exec_file ;
      wix_dlls = desc.package_dlls ;
      wix_icon_file = desc.package_icon_file ;
      wix_dlg_bmp_file = desc.package_dlg_bmp_file ;
      wix_banner_bmp_file = desc.package_banner_bmp_file ;
      wix_environment = desc.package_environment ;
      wix_embedded_dirs =
        List.map (fun base ->
            base, component_group base, dir_ref base)
          ((List.map (fun (b,_)-> OpamFilename.Base.to_string b)
              desc.package_embedded_dirs)
           @ desc.package_additional_embedded_name ) ;
      wix_embedded_files =
        List.map (fun (base,_) ->
            OpamFilename.Base.to_string base)
          desc.package_embedded_files ;
    } in
  let wix_path = System.normalize_path conf.conf_wix_path in
  System.call_list @@
    List.map (fun (basename, dirname) ->
        let basename = OpamFilename.Base.to_string basename in
        let heat = System.{
              heat_wix_path = wix_path;
              heat_dir = OpamFilename.Dir.to_string dirname
                         |> System.cyg_win_path `WinAbs;
              heat_out = Filename.concat
                           (OpamFilename.Dir.to_string tmp_dir)
                           basename ^ ".wxs"
                         |> System.cyg_win_path `WinAbs;
              heat_component_group = component_group basename;
              heat_directory_ref = dir_ref basename;
              heat_var = Format.sprintf "var.%sDir" basename
                   } in
        System.Heat, heat
      ) (desc.package_embedded_dirs @
           List.map (fun dir ->
               OpamFilename.basename_dir dir,dir)
             desc.package_additional_embedded_dir);
  let wxs = Wix.main_wxs info in
  let name = Filename.chop_extension desc.package_exec_file in
  let (addwxs1,content1) = Data.WIX.custom_install_dir in
  OpamFilename.write OpamFilename.Op.(tmp_dir//addwxs1) content1;
  let (addwxs2,content2) = Data.WIX.custom_install_dir_dlg in
  OpamFilename.write OpamFilename.Op.(tmp_dir//addwxs2) content2;
  let additional_wxs =
    List.map
      (fun d ->
        OpamFilename.to_string d |> System.cyg_win_path `WinAbs)
      OpamFilename.Op.[ tmp_dir//addwxs1; tmp_dir//addwxs2 ]
  in
  let main_path = OpamFilename.Op.(tmp_dir // (name ^ ".wxs")) in
  Wix.write_wxs (OpamFilename.to_string main_path) wxs;
  OpamConsole.formatted_msg "Compiling WiX components...\n";
  let embedded_dirs = (List.map (fun (b,_) ->
                           OpamFilename.Base.to_string b)
                         desc.package_embedded_dirs)
                      @ desc.package_additional_embedded_name
  in
  System.call_list @@
    List.map (fun basename ->
        let candle_defines = [ Format.sprintf "%sDir=%s\\%s"
                                 basename
                                 desc.package_fullname basename ]
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
  let candle = {
      System.candle_wix_path = wix_path;
      candle_files = System.Many wxs_files;
      candle_defines = []
    } in
  System.call_unit System.Candle candle;
  if conf.conf_keep_wxs
  then begin
      List.iter (fun file ->
          OpamFilename.copy_in (OpamFilename.of_string file)
          @@ OpamFilename.cwd ()) (* we are altering current dir !! *)
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
    ] @ List.map (fun base ->
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
    ~dst:OpamFilename.Op.(conf.conf_output_dir // (name ^ ".msi"));
  OpamConsole.formatted_msg "Done.\n";
