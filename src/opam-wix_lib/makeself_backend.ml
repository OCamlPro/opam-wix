(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let install_script_name = "install.sh"
let uninstall_script_name = "uninstall.sh"

let check_makeself_installed () =
  match Sys.command "command -v makeself.sh >/dev/null 2>&1" with
  | 0 -> ()
  | _ ->
    failwith
      "Could not find makeself.sh, \
       Please install makeself and run this command again."

let check_run_as_root =
  let open Sh_script in
  if_ Is_not_root
    [ echof "Not running as root. Aborting."
    ; echof "Please run again as root."
    ; exit 1
    ]

let install_script (ic : Installer_config.t) =
  let open Sh_script in
  let (/) = Filename.concat in
  let package = ic.package_name in
  let version = ic.package_version in
  let prefix = "/opt" / package in
  let bin = prefix / "bin" in
  let usrbin = "/usr/local/bin" in
  let setup =
    [ echof "Installing %s.%s to %s" package version prefix
    ; check_run_as_root
    ; mkdir [prefix; bin]
    ]
  in
  let binaries = [ic.package_exec_file] in
  let install_binaries =
    List.map
      (fun binary -> cp ~src:binary ~dst:bin)
      binaries
  in
  let set_permissions =
    [ set_permissions_in prefix ~on:Dirs ~permissions:755
    ; set_permissions_in prefix ~on:Files ~permissions:644
    ; set_permissions_in bin ~on:Files ~permissions:755
    ]
  in
  let add_symlinks_to_usrbin =
    List.concat_map
      (fun binary ->
         [ echof "Adding %s to %s" binary usrbin
         ; symlink ~target:(bin / binary) ~link:(usrbin / binary)
         ]
      )
      binaries
  in
  let install_uninstall_sh =
    [ cp ~src:uninstall_script_name ~dst:prefix
    ; chmod 755 [prefix / uninstall_script_name]
    ]
  in
  let notify_install_complete =
    [ echof "Installation complete!"
    ; echof
        "If you want to safely uninstall %s, please run %s/%s."
        package prefix uninstall_script_name
    ]
  in
  setup
  @ install_binaries
  @ set_permissions
  @ add_symlinks_to_usrbin
  @ install_uninstall_sh
  @ notify_install_complete

let uninstall_script (ic : Installer_config.t) =
  let open Sh_script in
  let (/) = Filename.concat in
  let package = ic.package_name in
  let prefix = "/opt" / package in
  let usrbin = "/usr/local/bin" in
  let binaries = [ic.package_exec_file] in
  let display_symlinks =
    List.map
      (fun binary -> echof "- %s/%s" usrbin binary)
      binaries
  in
  let setup =
    [ check_run_as_root
    ; echof "About to uninstall %s." package
    ; echof "The following files and folders will be removed from the system:"
    ; echof "- %s" prefix
    ]
    @ display_symlinks
  in
  let confirm_uninstall =
    [ prompt ~question:"Proceed? [y/N]" ~varname:"ans"
    ; case "ans"
        [ {pattern  = "[Yy]*"; commands = []}
        ; {pattern = "*"; commands = [echof "Aborted."; exit 1]}
        ]
    ]
  in
  let remove_install_folder =
    [ if_ (Dir_exists prefix)
        [ echof "Removing %s..." prefix
        ; rm_rf [prefix]
        ]
    ]
  in
  let remove_symlinks =
    List.concat_map
      (fun binary ->
         let link = usrbin / binary in
         [ if_ (Link_exists link)
             [ echof "Removink symlink %s..." link
             ; rm [link]
             ]
         ]
      )
      binaries
  in
  let notify_uninstall_complete = [echof "Uninstallation complete!"] in
  setup
  @ confirm_uninstall
  @ remove_install_folder
  @ remove_symlinks
  @ notify_uninstall_complete

let create_installer
    ~(installer_config : Installer_config.t) ~bundle_dir installer =
  check_makeself_installed ();
  OpamConsole.formatted_msg "Preparing makeself archive... \n";
  let install_script = install_script installer_config in
  let uninstall_script = uninstall_script installer_config in
  let install_sh = OpamFilename.Op.(bundle_dir // install_script_name) in
  let uninstall_sh = OpamFilename.Op.(bundle_dir // uninstall_script_name) in
  Sh_script.save install_script install_sh;
  Sh_script.save uninstall_script uninstall_sh;
  System.call_unit Chmod (755, install_sh);
  let args : System.makeself =
    { archive_dir = bundle_dir
    ; installer
    ; description = installer_config.package_name
    ; startup_script = Format.sprintf "./%s" install_script_name
    }
  in
  OpamConsole.formatted_msg
    "Generating standalone installer %s...\n"
    (OpamFilename.to_string installer);
  System.call_unit Makeself args;
  OpamConsole.formatted_msg "Done.\n"
