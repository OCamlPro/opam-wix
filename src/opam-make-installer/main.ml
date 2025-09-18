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

let dst_dir =
  let open Arg in
  required
  & pos 1 (some Opam_wix_cli.Args.opam_dirname) None
  & info [] ~docv:"BUNDLE_DIR" ~doc:"Where to write the bundle"

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
          $ Opam_wix_cli.Args.config
          $ dst_dir)

let () =
  OpamSystem.init ();
  (* OpamArg.preinit_opam_envvariables (); *)
  OpamCliMain.main_catch_all @@ fun () ->
  let term, info = create_bundle (OpamCLIVersion.default, `Default) in
  exit @@ Cmd.eval ~catch:false (Cmd.v info term)
