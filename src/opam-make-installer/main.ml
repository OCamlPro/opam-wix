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

let dst =
  let open Arg in
  required
  & pos 1 (some string) None
  & info [] ~docv:"OUTPUT" ~doc:"Where to write the installer or bundle"

let autodetect_backend () : Opam_wix_cli.Args.backend =
  match Sys.unix with
  | true ->
    OpamConsole.formatted_msg
      "Detected UNIX system: using makeself.sh backend.\n";
    Makeself
  | false ->
    OpamConsole.formatted_msg "Detected Windows system: using WiX backend.\n";
    Wix

let choose_backend backend_choice =
  let open Opam_wix_cli.Args in
  match backend_choice with
  | Autodetect -> Some (autodetect_backend ())
  | Forced opt -> opt

let save_bundle_and_conf ~(installer_config : Installer_config.t) ~bundle_dir
    dst =
  OpamFilename.move_dir ~src:bundle_dir ~dst;
  let conf_path = OpamFilename.Op.(dst // "installer-config.json") in
  Installer_config.save installer_config conf_path

let create_bundle cli =
  let doc = "Extract package installer bundle" in
  let create_bundle global_options conf backend dst () =
    Opam_frontend.with_install_bundle cli global_options conf
      (fun conf installer_config ~tmp_dir ->
         let bundle_dir = installer_config.package_dir in
         match choose_backend backend with
         | None ->
           let dst = OpamFilename.Dir.of_string dst in
           save_bundle_and_conf ~installer_config ~bundle_dir dst
         | Some Wix -> Wix_backend.create_bundle ~tmp_dir conf installer_config
         | Some Makeself ->
           let dst = OpamFilename.of_string dst in
           Makeself_backend.create_installer ~installer_config ~bundle_dir dst)

  in
  OpamArg.mk_command ~cli OpamArg.cli_original "opam-make-installer"
    ~doc ~man:[]
    Term.(const create_bundle
          $ OpamArg.global_options cli
          $ Opam_wix_cli.Args.config
          $ Opam_wix_cli.Args.backend
          $ dst)

let () =
  OpamSystem.init ();
  (* OpamArg.preinit_opam_envvariables (); *)
  OpamCliMain.main_catch_all @@ fun () ->
  let term, info = create_bundle (OpamCLIVersion.default, `Default) in
  exit @@ Cmd.eval ~catch:false (Cmd.v info term)
