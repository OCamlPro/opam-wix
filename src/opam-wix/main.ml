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
open OpamStateTypes

open Opam_wix
open Types

let create_bundle cli =
    let doc =
      "Windows MSI installer generation for opam packages"
    in
    let man =
      [
        `S Manpage.s_synopsis;
        `P "$(b,opam-wix) $(i,PACKAGE) [-b $(i,NAME)|--bp $(i,PATH)] [$(i,OTHER OPTION)]… ";
        `S Manpage.s_description;
        `P "This utility is an opam plugin that generates a standalone MSI file. This file is \
            used by Windows Installer to make available a chosen executable from an opam package \
            throughout the entire system.";
        `P "Generated MSI indicates to system to create an installation directory named \
            '$(b,Package Version.Executable)' under \"Program Files\" folder and to store there \
            the following items:";
        `I ("$(i,executable.exe)",
            "The selected executable file from package 'PACK'. There are two options how to indicate \
             where to find this binary. First, is to let opam find binary with the same name for you with \
             $(b,-b) option. Second, is to use the path to binary with $(b,--bp) option. In this case binary \
             will be considered as a part of package and its metadata. ");
        `I ("$(i,*.dll)",
            "All executable's dependencies libriries found with $(b,cygcheck).");
        `I ("$(i,icon and *.bmp)",
            "Additional files used by installer to customise GUI. Options $(b,--ico), $(b,--dlg-bmp) and \
             $(b,--ban-bmp) could be used to bundle custom files.");
        `P "Additionnaly, installer gives to user a possibility to create a shortcut on Desktop and Start \
            menu as well as adding installation folder to the PATH.";
      ]
      @ Opam_wix_cli.Man.configuration

    in
    let create_bundle global_options conf () =
      Opam_frontend.with_install_bundle cli global_options conf
        Wix_backend.create_bundle
    in
    OpamArg.mk_command ~cli OpamArg.cli_original "opam-wix" ~doc ~man
      Term.(const create_bundle
            $ OpamArg.global_options cli
            $ Opam_wix_cli.Args.config)

let () =
  OpamSystem.init ();
  (* OpamArg.preinit_opam_envvariables (); *)
  OpamCliMain.main_catch_all @@ fun () ->
  let term, info = create_bundle (OpamCLIVersion.default, `Default) in
  exit @@ Cmd.eval ~catch:false (Cmd.v info term)
