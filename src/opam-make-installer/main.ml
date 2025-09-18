(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Cmdliner

open Opam_wix
open Types

module Args = struct
  open Cmdliner.Arg

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
    let prefix = if Sys.cygwin then "/cygdrive" else "" in
    value & opt string (prefix ^ "/c/Program Files (x86)/WiX Toolset v3.11/bin")
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

  let conf =
    let apply conf_file conf_package conf_path conf_binary conf_wix_version conf_output_dir conf_wix_path conf_package_guid conf_icon_file conf_dlg_bmp conf_ban_bmp conf_keep_wxs =
      { conf_file ; conf_package; conf_path; conf_binary; conf_wix_version; conf_output_dir; conf_wix_path; conf_package_guid; conf_icon_file; conf_dlg_bmp; conf_ban_bmp; conf_keep_wxs }
    in
    Term.(const apply $ conffile $ package $ path $ binary $ wix_version $ output_dir $ wix_path $ package_guid $ icon_file $
      dlg_bmp $ ban_bmp $ keep_wxs)

  let dst_dir =
    required & pos 1 (some dirname) None & info [] ~docv:"BUNDLE_DIR"
      ~doc:"The path to the bundle directory"
end

let create_bundle cli =
  let doc = "Extract package installer bundle" in
  let create_bundle global_options conf dst () =
    Opam_frontend.with_install_bundle cli global_options conf
      (fun _conf installer_conf ~tmp_dir:_ ->
         let bundle_dir = installer_conf.package_dir in
         OpamFilename.move_dir ~src:bundle_dir ~dst;
         let conf_path =
           OpamFilename.Op.(dst // "installer-config.json")
         in
         Installer_config.save installer_conf conf_path)
  in
  OpamArg.mk_command ~cli OpamArg.cli_original "opam-make-installer-bundle"
    ~doc ~man:[]
    Term.(const create_bundle
            $ OpamArg.global_options cli
            $ Args.conf
            $ Args.dst_dir)

let () =
  OpamSystem.init ();
  (* OpamArg.preinit_opam_envvariables (); *)
  OpamCliMain.main_catch_all @@ fun () ->
  let term, info = create_bundle (OpamCLIVersion.default, `Default) in
  exit @@ Cmd.eval ~catch:false (Cmd.v info term)
