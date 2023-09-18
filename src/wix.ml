(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Markup

type wxs = signal list

type component_group = string

type directory_ref = string

let xml_declaration = {
  version = "1.0";
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

module type INFO = sig
  val path : string
  val package_name : string
  val package_version : string
  val description : string
  val manufacturer : string
  val package_guid : string option
  val tags : string list
  val exec_file : string
  val dlls : string list
  val icon_file : string
  val dlg_bmp_file : string
  val banner_bmp_file : string
  val embedded_dirs : (string * component_group * directory_ref) list
  val embedded_files : string list
  val environement : (string * string) list
end

let normalize_id =
  String.map (function c ->
    match c with
    | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '.' | '_' -> c
    | _ -> '_'
    )

let component component_name content : signal list =
  match content with
  | [] -> []
  | _ ->
    let component =
      `Start_element ((name "Component"), [
        name "Id", component_name;
        name "Guid", get_uuid mode_rand
      ]);
    in
    component :: (content @ [`End_element])

let main_wxs (module Info : INFO) : wxs =
  let path p = Filename.concat Info.path p in
  let exec_name = Filename.basename Info.exec_file |> Filename.chop_extension in
  [
  `Xml xml_declaration;
  `Start_element ((name "Wix"), [name "xmlns", "http://schemas.microsoft.com/wix/2006/wi"]);

    `Start_element ((name "Product"), [
      name "Name", Info.package_name ^ "." ^ exec_name;
      name "Id", get_uuid @@ mode_package_exe_version Info.package_name exec_name Info.package_version;
      name "UpgradeCode", begin
        match Info.package_guid with
        | Some guid -> guid
        | None -> get_uuid (mode_package_exe Info.package_name exec_name)
      end;
      name "Language", "1033";
      name "Codepage", "1252";
      name "Version",  Info.package_version;
      name "Manufacturer", Info.manufacturer
    ]);

      `Start_element ((name "Package"), [
        name "Id", "*";
        name "Keywords", String.concat " " Info.tags;
        name "Description", Info.description;
        name "Manufacturer", Info.manufacturer;
        name "InstallerVersion", "100";
        name "Languages", "1033";
        name "Compressed", "yes";
        name "SummaryCodepage", "1252"
      ]);
      `End_element;

      `Start_element ((name "Media"), [
        name "Id", "1";
        name "Cabinet", "Sample.cab";
        name "EmbedCab", "yes"
      ]);
      `End_element;

      `Start_element ((name "Directory"), [
        name "Id", "TARGETDIR";
        name "Name", "SourceDir"
      ]);

        `Start_element ((name "Directory"), [
          name "Id", "ProgramFilesFolder";
          name "Name", "PFiles"
        ]);

          `Start_element ((name "Directory"), [
            name "Id", "INSTALLDIR";
            name "Name", Info.package_name ^ "." ^ Info.package_version ^ "-" ^ exec_name
          ]);
          ] @
            component "MainExecutable" [
              `Start_element ((name "File"), [
                name "Id", normalize_id Info.icon_file;
                name "Name", Info.icon_file;
                name "DiskId", "1";
                name "Source", path Info.icon_file;
              ]);
              `End_element;

              `Start_element ((name "File"), [
                name "Id", normalize_id Info.exec_file;
                name "Name", Info.exec_file;
                name "DiskId", "1";
                name "Source", path Info.exec_file;
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
                Info.environement
              |> List.flatten)
            ) @
            component "SetEnviromentPath" [
              `Start_element ((name "CreateFolder"), []);
              `End_element;
              `Start_element ((name "Condition"), []);
              `Text ["ADDTOPATH"];
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
                Info.dlls
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
                Info.embedded_files
              |> List.flatten
            ) @
            (List.map (fun (dirname, _, dir_ref) -> [
              `Start_element ((name "Directory"), [
                name "Id", dir_ref;
                name "Name", dirname;
              ]);
              `End_element])
              Info.embedded_dirs
            |> List.flatten)
            @ [
          `End_element;

        `End_element;

        `Start_element ((name "Directory"), [
          name "Id", "ProgramMenuFolder";
          name "Name", "Programs";
        ]);

          `Start_element ((name "Directory"), [
            name "Id", "ProgramMenuDir";
            name "Name", Info.package_name ^ "." ^ Info.package_version ^ "-" ^ exec_name
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

        `Start_element ((name "Directory"), [
          name "Id", "DesktopFolder";
          name "Name", "Desktop";
        ]);
        ] @
          component "ApplicationShortcutDektop" [
            `Start_element ((name "Condition"),[]);
            `Text ["INSTALLSHORTCUTDESKTOP"];
            `End_element;

            `Start_element ((name "Shortcut"), [
              name "Id", "desktop_" ^ normalize_id Info.exec_file;
              name "Name", exec_name;
              name "WorkingDirectory", "INSTALLDIR";
              name "Icon", Info.icon_file;
              name "Target", "[INSTALLDIR]" ^ Info.exec_file
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

        `Start_element ((name "Directory"), [
          name "Id", "StartMenuFolder";
        ]);
        ] @
          component "ApplicationShortcutStartMenu" [
            `Start_element ((name "Condition"),[]);
            `Text ["INSTALLSHORTCUTSTARTMENU"];
            `End_element;

            `Start_element ((name "Shortcut"), [
              name "Id", "startmenu_" ^ normalize_id Info.exec_file;
              name "Name", exec_name;
              name "WorkingDirectory", "INSTALLDIR";
              name "Icon", Info.icon_file;
              name "Target", "[INSTALLDIR]" ^ Info.exec_file
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

        `Start_element ((name "Directory"), [ name "Id", "WINSYSDIR" ]);
        `End_element;

      `End_element;

    `Start_element ((name "SetDirectory"), [
      name "Id", "WINSYSDIR";
      name "Value", "[SystemFolder]"
    ]);
    `End_element;

    `Start_element ((name "Feature"), [
      name "Id", "Complete";
      name "Title",  Info.package_name ^ "." ^ Info.package_version ^ "-" ^ exec_name;
      name "Description", Info.package_name ^ "." ^ exec_name ^ " complete install.";
      name "Level", "1"
    ]);

      `Start_element ((name "ComponentRef"), [ name "Id", "MainExecutable" ]);
      `End_element;

      `Start_element ((name "ComponentRef"), [ name "Id", "ProgramMenuDir" ]);
      `End_element;
      ] @

     (match Info.dlls with
      | [] -> []
      | _ -> [
        `Start_element ((name "ComponentRef"), [ name "Id", "Dlls" ]);
        `End_element;
      ]) @

      (List.map (fun (_, cg, _) -> [
        `Start_element ((name "ComponentGroupRef"), [
          name "Id", cg;
        ]);
        `End_element])
        Info.embedded_dirs
      |> List.flatten) @

      (match Info.embedded_files with
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
      name "Id", normalize_id Info.icon_file;
      name "SourceFile", path Info.icon_file;
    ]);
    `End_element;

    `Start_element ((name "Property"), [
      name "Id", "ARPPRODUCTICON";
      name "Value", normalize_id Info.icon_file
    ]);
    `End_element;

    `Start_element ((name "Property"), [
      name "Id", "WIXUI_INSTALLDIR";
      name "Value", "INSTALLDIR"
    ]);
    `End_element;

    `Start_element ((name "WixVariable"), [
      name "Id", "WixUIBannerBmp";
      name "Value", path Info.banner_bmp_file
    ]);
    `End_element;

    `Start_element ((name "WixVariable"), [
      name "Id", "WixUIDialogBmp";
      name "Value", path Info.dlg_bmp_file
    ]);
    `End_element;

    `Start_element ((name "UIRef"), [name "Id", "Custom_InstallDir"]);
    `End_element;

    `End_element;

  `End_element;
]

let write_wxs path wxs  =
  let oc = open_out path in
  let stream = pretty_print (of_list wxs) in
  write_xml stream |> to_channel oc;
  close_out oc
