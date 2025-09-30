(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type wxs = Markup.signal list

type component_group = string

type directory_ref = string



(** Information module used to generated main wxs document. *)
type info = {
  (* Path to the bundle containing all required files. Every relative file path will be concatenated to this path *)
  wix_path : string;

  (* Package name used as product name. Deduced from opam file *)
  wix_name : string;

  (* Package version used as part of product name. Deduced from opam file *)
  wix_version : string;

  (* Package description. Deduced from opam file *)
  wix_description : string;

  (* Product manufacturer. Deduced from field {i maintainer} in opam file *)
  wix_manufacturer : string;

  (* Package UID. Should be equal for every version of given
     package. If not specified, generated new UID *)
  wix_guid : string option;

  (* Package tags. Deduced from opam file *)
  wix_tags : string list;

  (* Filename of bundled .exe binary. *)
  wix_exec_file : string;

  (* Filenames for all bundled DLLs. *)
  wix_dlls : string list;

  (* Icon filename. *)
  wix_icon_file : string;

  (* Dialog bmp filename. *)
  wix_dlg_bmp_file : string;

  (* Banner bmp filename. *)
  wix_banner_bmp_file : string;

  (* Embedded directories information (reference another wxs file) *)
  wix_embedded_dirs : (string * component_group * directory_ref * string) list;

  (* Embedded files *)
  wix_embedded_files : string list;

  (* Environement variables to set/unset in Windows terminal on install/uninstall respectively. *)
  wix_environment : (string * string) list;
}

module Version = struct
type t = string
let to_string s = s
let of_string s =
  String.iter (function
      | '0'..'9' | '.' -> ()
      | c ->
        failwith
          (Printf.sprintf "Invalid character '%c' in WIX version %S" c s))
    s;
  s
end


let xml_declaration = {
  Markup.version = "1.0";
  encoding = Some "windows-1252";
  standalone = None;
}

let name s = ("", s)

let get_uuid mode =
  match System.(call Uuidgen mode) with
  | uuid::_ -> uuid
  | _ -> raise (Failure "uuidgen produces unexpected output")

let mode_package_exe_version p e v = System.Exec (p, e, (Some v))
let mode_package_exe p e = System.Exec (p, e, None)
let mode_rand = System.Rand

let normalize_id =
  String.map (function c ->
    match c with
    | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '.' | '_' -> c
    | _ -> '_'
    )

let component component_name ?condition content : Markup.signal list =
  match content with
  | [] -> []
  | _ ->
    let cond =
      match condition with
      | None -> []
      | Some c -> [ name "Condition", c ]
    in
    let component =
      `Start_element ((name "Component"), [
        name "Id", component_name;
        name "Guid", get_uuid mode_rand
      ] @ cond);
    in
    component :: (content @ [`End_element])

let main_wxs info : wxs =
  let path p = Filename.concat info.wix_path p in
  let exec_name = Filename.basename info.wix_exec_file
                  |> Filename.chop_extension in
  [
    `Xml xml_declaration;
    `Start_element ((name "Wix"), [name "xmlns", "http://wixtoolset.org/schemas/v4/wxs" ;
                                   name "xmlns:ui", "http://wixtoolset.org/schemas/v4/wxs/ui" ;
                                   name "xmlns:util", "http://wixtoolset.org/schemas/v4/wxs/util" ]);

    `Start_element ((name "Package"), [
        (* FIXME: Wix6 allows to give a descriptive package id instead and
           build the ProductCode and UpgradeCode GUIDs from it: so should
           use that (but then we have to provide this id as input) *)
                      name "Manufacturer", info.wix_manufacturer;
                      name "Name", info.wix_name ^ "." ^ exec_name;
                      name "Version",  info.wix_version;
                      name "Language", "1033";
                      name "Codepage", "1252";
                      name "InstallerVersion", "100";
                      name "Compressed", "yes";
                      name "UpgradeStrategy", "majorUpgrade";
                      name "ProductCode", get_uuid @@ mode_package_exe_version info.wix_name exec_name info.wix_version;
                      name "UpgradeCode", begin
                          match info.wix_guid with
                          | Some guid -> guid
                          | None -> get_uuid (mode_package_exe info.wix_name exec_name)
                        end
      ]);

    `Start_element ((name "SummaryInformation"), [
                      name "Manufacturer", info.wix_manufacturer;
                      name "Description", info.wix_description;
                      name "Keywords", String.concat " " info.wix_tags;
                      name "Codepage", "1252"
      ]);
    `End_element;

    `Start_element ((name "Media"), [
                      name "Id", "1";
                      name "Cabinet", "Sample.cab";
                      name "EmbedCab", "yes"
      ]);
    `End_element;

    `Start_element ((name "StandardDirectory"), [
                      name "Id", "ProgramFilesFolder"
      ]);

    `Start_element ((name "Directory"), [
                      name "Id", "INSTALLDIR";
                      name "Name", info.wix_name ^ "." ^ info.wix_version ^ "-" ^ exec_name
      ]);
  ] @
    component "MainExecutable" [
        `Start_element ((name "File"), [
                          name "Id", normalize_id info.wix_icon_file;
                          name "Name", info.wix_icon_file;
                          name "DiskId", "1";
                          name "Source", path info.wix_icon_file;
          ]);
        `End_element;

        `Start_element ((name "File"), [
                          name "Id", normalize_id info.wix_exec_file;
                          name "Name", info.wix_exec_file;
                          name "DiskId", "1";
                          name "Source", path info.wix_exec_file;
                          name "KeyPath", "yes"
          ]);
        `End_element;
      ] @
      component "SetEnviroment" (
          `Start_element ((name "CreateFolder"), [])
          :: `End_element
          :: (List.mapi (fun id (var,value) -> [
                    `Start_element ((name "Environment"), [
                                      name "Id", "var" ^ string_of_int id;
                                      name "Name", var;
                                      name "Value", value;
                                      name "Permanent", "no";
                                      name "Part", "last";
                                      name "Action", "set";
                                      name "System", "yes"
                      ]);
                    `End_element])
                info.wix_environment
              |> List.flatten)
        ) @
        component "SetEnviromentPath" ~condition:"ADDTOPATH" [
            `Start_element ((name "CreateFolder"), []);
            `End_element;
            `Start_element ((name "Environment"), [
                              name "Id", "PATH";
                              name "Name", "PATH";
                              name "Value", "[INSTALLDIR]";
                              name "Permanent", "no";
                              name "Part", "last";
                              name "Action", "set";
                              name "System", "yes"
              ]);
            `End_element;
          ] @
          component "Dlls" (
              List.map (fun dll -> [
                    `Start_element ((name "File"), [
                                      name "Id", normalize_id dll;
                                      name "Name", dll;
                                      name "DiskId", "1";
                                      name "Source", path dll;
                      ]);
                    `End_element])
                info.wix_dlls
              |> List.flatten
            ) @
            component "Embedded" (
                List.map (fun base -> [
                      `Start_element ((name "File"), [
                                        name "Id", normalize_id base;
                                        name "Name", base;
                                        name "DiskId", "1";
                                        name "Source", path base;
                        ]);
                      `End_element])
                  info.wix_embedded_files
                |> List.flatten
              ) @
              (List.map (fun (dirname, _, dir_ref, _) -> [
                     `Start_element ((name "Directory"), [
                                       name "Id", dir_ref;
                                       name "Name", dirname;
                       ]);
                     `End_element])
                 info.wix_embedded_dirs
               |> List.flatten)
              @ [
                `End_element;

                `End_element;

                `Start_element ((name "StandardDirectory"), [
                                  name "Id", "ProgramMenuFolder"
                  ]);

                `Start_element ((name "Directory"), [
                                  name "Id", "ProgramMenuDir";
                                  name "Name", info.wix_name ^ "." ^
                                                 info.wix_version ^ "-" ^ exec_name
                  ]);
              ] @
                component "ProgramMenuDir" [
                    `Start_element ((name "RemoveFolder"), [
                                      name "Id", "ProgramMenuDir";
                                      name "On", "uninstall";
                      ]);
                    `End_element;

                    `Start_element ((name "RegistryValue"), [
                                      name "Root", "HKCU";
                                      name "Key", "Software\\[Manufacturer]\\[ProductName]";
                                      name "Type", "string";
                                      name "Value", "";
                                      name "KeyPath", "yes"
                      ]);
                    `End_element;
                  ]
                @ [
                  `End_element;

                  `End_element;

                  `Start_element ((name "StandardDirectory"), [
                                    name "Id", "DesktopFolder"
                    ]);
                ] @
                  component "ApplicationShortcutDektop" ~condition:"INSTALLSHORTCUTDESKTOP" [

                      `Start_element ((name "Shortcut"), [
                                        name "Id", "desktop_" ^ normalize_id info.wix_exec_file;
                                        name "Name", exec_name;
                                        name "WorkingDirectory", "INSTALLDIR";
                                        name "Icon", info.wix_icon_file;
                                        name "Target", "[INSTALLDIR]" ^ info.wix_exec_file
                        ]);
                      `End_element;

                      `Start_element ((name "RemoveFolder"), [
                                        name "Id", "DesktopDir";
                                        name "On", "uninstall";
                        ]);
                      `End_element;

                      `Start_element ((name "RegistryValue"), [
                                        name "Root", "HKCU";
                                        name "Key", "Software\\[Manufacturer]\\[ProductName]";
                                        name "Name", "installed";
                                        name "Type", "integer";
                                        name "Value", "1";
                                        name "KeyPath", "yes"
                        ]);
                      `End_element;
                    ]
                  @ [

                    `End_element;

                    `Start_element ((name "StandardDirectory"), [
                                      name "Id", "StartMenuFolder"
                      ]);
                  ] @
                    component "ApplicationShortcutStartMenu" ~condition:"INSTALLSHORTCUTSTARTMENU" [

                        `Start_element ((name "Shortcut"), [
                                          name "Id", "startmenu_" ^ normalize_id info.wix_exec_file;
                                          name "Name", exec_name;
                                          name "WorkingDirectory", "INSTALLDIR";
                                          name "Icon", info.wix_icon_file;
                                          name "Target", "[INSTALLDIR]" ^ info.wix_exec_file
                          ]);
                        `End_element;

                        `Start_element ((name "RemoveFolder"), [
                                          name "Id", "ApplicationProgramsFolder";
                                          name "On", "uninstall";
                          ]);
                        `End_element;

                        `Start_element ((name "RegistryValue"), [
                                          name "Root", "HKCU";
                                          name "Key", "Software\\[Manufacturer]\\[ProductName]";
                                          name "Name", "installed";
                                          name "Type", "integer";
                                          name "Value", "1";
                                          name "KeyPath", "yes"
                          ]);
                        `End_element;
                      ]
                    @ [
                      `End_element;
                      ] @

                       (List.map (fun (_dirname, cg, dir_ref, srcdir) -> [
                            `Start_element ((name "ComponentGroup"), [
                                name "Id", cg;
                              ]);
                            `Start_element ((name "Files"), [
                                name "Directory", dir_ref;
                                name "Include", srcdir ^ "\\**";
                              ]);
                            `End_element;
                            `End_element])
                          info.wix_embedded_dirs
                        |> List.flatten)

                    @ [
                      `Start_element ((name "Directory"), [ name "Id", "WINSYSDIR" ]);
                      `End_element;

                      `Start_element ((name "SetDirectory"), [
                                        name "Id", "WINSYSDIR";
                                        name "Value", "[SystemFolder]"
                        ]);
                      `End_element;

                      `Start_element ((name "Feature"), [
                                        name "Id", "Complete";
                                        name "Title",  info.wix_name ^ "." ^ info.wix_version ^ "-" ^ exec_name;
                                        name "Description", info.wix_name ^ "." ^ exec_name ^ " complete install.";
                                        name "Level", "1"
                        ]);

                      `Start_element ((name "ComponentRef"), [ name "Id", "MainExecutable" ]);
                      `End_element;

                      `Start_element ((name "ComponentRef"), [ name "Id", "ProgramMenuDir" ]);
                      `End_element;
                    ] @

                      (match info.wix_dlls with
                      | [] -> []
                      | _ -> [
                          `Start_element ((name "ComponentRef"), [ name "Id", "Dlls" ]);
                          `End_element;
                      ]) @

                        (List.map (fun (_, cg, _, _srcdir) -> [
                               `Start_element ((name "ComponentGroupRef"), [
                                                 name "Id", cg;
                                 ]);
                               `End_element])
                           info.wix_embedded_dirs
                         |> List.flatten) @

                          (match info.wix_embedded_files with
                          | [] -> []
                          | _ -> [
                              `Start_element ((name "ComponentRef"), [ name "Id", "Embedded" ]);
                              `End_element;
                          ])

                          @ [
                            `Start_element ((name "ComponentRef"), [ name "Id", "ApplicationShortcutDektop" ]);
                            `End_element;

                            `Start_element ((name "ComponentRef"), [ name "Id", "ApplicationShortcutStartMenu" ]);
                            `End_element;

                            `Start_element ((name "ComponentRef"), [ name "Id", "SetEnviroment" ]);
                            `End_element;

                            `Start_element ((name "ComponentRef"), [ name "Id", "SetEnviromentPath" ]);
                            `End_element;

                            `End_element;

                            `Start_element ((name "Property"), [
                                              name "Id", "INSTALLSHORTCUTDESKTOP";
                                              name "Value", "1";
                              ]);
                            `End_element;

                            `Start_element ((name "Property"), [
                                              name "Id", "INSTALLSHORTCUTSTARTMENU";
                                              name "Value", "1";
                              ]);
                            `End_element;

                            `Start_element ((name "Property"), [
                                              name "Id", "ADDTOPATH";
                                              name "Value", "0";
                              ]);
                            `End_element;

                            `Start_element ((name "Icon"), [
                                              name "Id", normalize_id info.wix_icon_file;
                                              name "SourceFile", path info.wix_icon_file;
                              ]);
                            `End_element;

                            `Start_element ((name "Property"), [
                                              name "Id", "ARPPRODUCTICON";
                                              name "Value", normalize_id info.wix_icon_file
                              ]);
                            `End_element;

                            `Start_element ((name "Property"), [
                                              name "Id", "WIXUI_INSTALLDIR";
                                              name "Value", "INSTALLDIR"
                              ]);
                            `End_element;

                            `Start_element ((name "WixVariable"), [
                                              name "Id", "WixUIBannerBmp";
                                              name "Value", path info.wix_banner_bmp_file
                              ]);
                            `End_element;

                            `Start_element ((name "WixVariable"), [
                                              name "Id", "WixUIDialogBmp";
                                              name "Value", path info.wix_dlg_bmp_file
                              ]);
                            `End_element;

                            `Start_element ((name "ui:WixUI"), [name "Id", "Custom_InstallDir"]);
                            `End_element;

                            `End_element;

                            `End_element;
                          ]

let write_wxs path wxs  =
  let oc = open_out path in
  let stream = Markup.pretty_print (Markup.of_list wxs) in
  Markup.write_xml stream |> Markup.to_channel oc;
  close_out oc
