(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Opam_wix

let make_config
    ?(package_name="")
    ?(package_version="")
    ?(package_exec_file="")
    () : Installer_config.t
  =
  { package_name
  ; package_version
  ; package_exec_file
  ; package_dir = OpamFilename.Dir.of_string ""
  ; package_fullname = ""
  ; package_description = ""
  ; package_manufacturer = ""
  ; package_guid = None
  ; package_tags = []
  ; package_dlls = []
  ; package_icon_file = ""
  ; package_dlg_bmp_file = ""
  ; package_banner_bmp_file = ""
  ; package_embedded_dirs = []
  ; package_additional_embedded_name = []
  ; package_additional_embedded_dir = []
  ; package_embedded_files = []
  ; package_environment = []
  }

let%expect_test "install_script: one binary" =
  let config =
    make_config
      ~package_name:"aaa"
      ~package_version:"x.y.z"
      ~package_exec_file:"aaa-command"
      ()
  in
  let install_script = Makeself_backend.install_script config in
  Format.printf "%a" Sh_script.pp_sh install_script;
  [%expect {|
    #!/bin/sh
    set -e
    echo "Installing aaa.x.y.z to /opt/aaa"
    if [ "$(id -u)" -ne 0 ]; then
      echo "Not running as root. Aborting."
      echo "Please run again as root."
      exit 1
    fi
    mkdir -p /opt/aaa /opt/aaa/bin
    cp aaa-command /opt/aaa/bin
    find /opt/aaa -type d -exec chmod 755 {} +
    find /opt/aaa -type f -exec chmod 644 {} +
    find /opt/aaa/bin -type f -exec chmod 755 {} +
    echo "Adding aaa-command to /usr/local/bin"
    ln -s /opt/aaa/bin/aaa-command /usr/local/bin/aaa-command
    cp uninstall.sh /opt/aaa
    chmod 755 /opt/aaa/uninstall.sh
    echo "Installation complete!"
    echo "If you want to safely uninstall aaa, please run /opt/aaa/uninstall.sh."
    |}]

let%expect_test "uninstall_script: one binary" =
  let config =
    make_config
      ~package_name:"aaa"
      ~package_exec_file:"aaa-command"
      ()
  in
  let uninstall_script = Makeself_backend.uninstall_script config in
  Format.printf "%a" Sh_script.pp_sh uninstall_script;
  [%expect {|
    #!/bin/sh
    set -e
    if [ "$(id -u)" -ne 0 ]; then
      echo "Not running as root. Aborting."
      echo "Please run again as root."
      exit 1
    fi
    echo "About to uninstall aaa."
    echo "The following files and folders will be removed from the system:"
    echo "- /opt/aaa"
    echo "- /usr/local/bin/aaa-command"
    printf "Proceed? [y/N] "
    read "$ans"
    case "$ans" in
      [Yy]*) ;;
      *)
        echo "Aborted."
        exit 1
      ;;
    esac
    if [ -d "/opt/aaa" ]; then
      echo "Removing /opt/aaa..."
      rm -rf /opt/aaa
    fi
    if [ -L "/usr/local/bin/aaa-command" ]; then
      echo "Removink symlink /usr/local/bin/aaa-command..."
      rm -f /usr/local/bin/aaa-command
    fi
    echo "Uninstallation complete!"
    |}]

