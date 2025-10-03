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
  let info = Wix.{
      wix_path = (*Filename.basename @@*) OpamFilename.Dir.to_string desc.package_dir;
      wix_name = desc.package_name;
      wix_version = desc.package_version;
      wix_description = desc.package_description;
      wix_manufacturer = desc.package_manufacturer;
      wix_guid = conf.conf_package_guid;
      wix_tags = desc.package_tags;
      wix_exec_file = desc.package_exec_file;
      wix_dlls = desc.package_dlls;
      wix_icon_file = desc.package_icon_file;
      wix_dlg_bmp_file = desc.package_dlg_bmp_file;
      wix_banner_bmp_file = desc.package_banner_bmp_file;
      wix_environment = desc.package_environment;
      wix_embedded_dirs =
        List.map (fun (base, dir) ->
            (* FIXME: do we need absolute dir ? *)
            let base = OpamFilename.Base.to_string base in
            base, component_group base, dir_ref base, OpamFilename.Dir.to_string dir)
          (desc.package_embedded_dirs @
           List.map2 (fun base dir -> OpamFilename.Base.of_string base, dir)
             desc.package_additional_embedded_name
             desc.package_additional_embedded_dir);
      wix_embedded_files =
        List.map (fun (base, _) ->
            OpamFilename.Base.to_string base)
          desc.package_embedded_files;
    }
  in
  let wxs = Wix.main_wxs info in
  let name = Filename.chop_extension desc.package_exec_file in
  let (addwxs1, content1) = Data.WIX.custom_install_dir in
  OpamFilename.write OpamFilename.Op.(tmp_dir//addwxs1) content1;
  let (addwxs2, content2) = Data.WIX.custom_install_dir_dlg in
  OpamFilename.write OpamFilename.Op.(tmp_dir//addwxs2) content2;
  let additional_wxs =
    List.map (fun d ->
        OpamFilename.to_string d |> System.cyg_win_path `WinAbs)
      OpamFilename.Op.[ tmp_dir//addwxs1; tmp_dir//addwxs2 ]
  in
  let main_path = OpamFilename.Op.(tmp_dir // (name ^ ".wxs")) in
  OpamConsole.formatted_msg "Preparing main WiX file...\n";
  Wix.write_wxs (OpamFilename.to_string main_path) wxs;
  let wxs_files =
    (OpamFilename.to_string main_path |> System.cyg_win_path `WinAbs)
    :: additional_wxs
  in
  if conf.conf_keep_wxs then
    List.iter (fun file ->
        OpamFilename.copy_in (OpamFilename.of_string file)
        @@ OpamFilename.cwd ()) (* we are altering current dir !! *)
      wxs_files;
  let wix = System.{
      wix_wix_path = wix_path;
      wix_files = wxs_files;
      wix_exts = ["WixToolset.UI.wixext"; "WixToolset.Util.wixext"];
      wix_out = (name ^ ".msi")
    }
  in
  OpamConsole.formatted_msg "Producing final msi...\n";
  System.call_unit System.Wix wix;
  OpamFilename.remove (OpamFilename.of_string (name ^ ".wixpdb"));
  OpamFilename.move
    ~src:(OpamFilename.of_string (name ^ ".msi"))
    ~dst:OpamFilename.Op.(conf.conf_output_dir // (name ^ ".msi"));
  OpamConsole.formatted_msg "Done.\n"
