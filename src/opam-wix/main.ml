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
open OpamTypes
open OpamStateTypes

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

  let term =
    let apply conf_file conf_package conf_path conf_binary conf_wix_version conf_output_dir conf_wix_path conf_package_guid conf_icon_file conf_dlg_bmp conf_ban_bmp conf_keep_wxs =
      { conf_file ; conf_package; conf_path; conf_binary; conf_wix_version; conf_output_dir; conf_wix_path; conf_package_guid; conf_icon_file; conf_dlg_bmp; conf_ban_bmp; conf_keep_wxs }
    in
    Term.(const apply $ conffile $ package $ path $ binary $ wix_version $ output_dir $ wix_path $ package_guid $ icon_file $
      dlg_bmp $ ban_bmp $ keep_wxs)

end

let create_bundle cli =
    let doc =
      "Windows MSI installer generation for opam packages"
    in
    let man = [
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
        `S "Configuration";
        `P "Despite arguments allowing partial configuration of the utility, for complete support of installing \
            complex programs and non self-contained binaries, it is necessary to provide a config file with \
            $(b,opam-format syntax) (See https://opam.ocaml.org/doc/Manual.html). Such a file allows opam-wix to \
            determine which additional files and directories should be installed along with the program, as well \
            as which environment variables need to be set in the Windows Terminal.";
        `P "To specify paths to specific files, you can use variables defined by opam, for example, \
            $(i,%{share}%/path), which adds the necessary prefix. For more information about variables, \
            refer to https://opam.ocaml.org/doc/Manual.html#Variables. The config file can contain the following \
            fields:";
        `I ("$(i,opamwix-version)","The version of the config file. The current version is $(b,0.1).");
        `I ("$(i,ico, bng, ban)","These are the same as their respective arguments.");
        `I ("$(i,binary-path, binary)","These are the same as their respective arguments.");
        `I ("$(i,wix_version)","The version to use to generate the MSI, in a dot separated number format.");
        `I ("$(i,embedded)", "A list of files or directories paths to include in the installation directory. \
                              There are 3 different ways to specify the paths, each of them implies its own installation place in \
                              the target directory: \
                              First way to install files is by giving a list of two elements: the first being the destination \
                              basename (the name of the file in the installation directory), and the second being the \
                              path to the file itself. For example: $(b,[\"file.txt\" \"path/to/file\"]). \
                              The second way is to include any file/directory under opam prefix. In this case, variables like \
                              $(i,%{share}%) or $(i,%{lib}%) could be very usefull. You should just give a list with one string that \
                              represents path which prefix is the same with your current switch prefix. For example, \
                              $(b,[\"/absolute-path-to-your-prefix/lib/odoc/odoc.cmi\"]) or just $(b,[\"/%{odoc:lib}%/odoc.cmi\"]). \
                              Those files would be installed in the directory \"opam\" at the root of installation directory conserving \
                              entire path (it would be $(b,INSTALLDIR/opam/lib/odoc/odoc.cmi) for previous example). \
                              The last way to specify path is very similar with previous, but it takes into account only external to opam files. \
                              The paths to thoses files should be relative and implicit. For example, $(b,[\"dir1/dir2/file.txt\"]). \
                              The file (or directory) will be installed in \"external\" directory under the root of target installation directory \
                              the same way as for opam files (it would be $(b,INSTALLDIR/external/dir1/dir2/file.txt) for previous example).");
        `I ("$(i,envvar)", "A list of environment variables to set/unset in the Windows Terminal during \
                            install/uninstall. Each element in this list should be a list of two elements: the name and the \
                            value of the variable. Basenames defined with $(b,embedded) field could be used as variables, to reference \
                            absolute installed path. For example: $(b,embedded: [ \"mydoc\" \"%{package:doc}%\"] envvar: [ \"DOC\" \"%{mydoc}%\"]) \
                            will install directory referenced by $(i,package:doc) opam variable in $(i,<install-dir>/mydoc) \
                            and set $(i,DOC) environment variable to the $(i,<install-dir>/mydoc) absolute path.");
      ]
    in
    let create_bundle global_options conf () =
      Opam_frontend.with_install_bundle cli global_options conf
        Wix_backend.create_bundle
    in
    OpamArg.mk_command ~cli OpamArg.cli_original "opam-wix" ~doc ~man
      Term.(const create_bundle
            $ OpamArg.global_options cli
            $ Args.term)

let () =
  OpamSystem.init ();
  (* OpamArg.preinit_opam_envvariables (); *)
  OpamCliMain.main_catch_all @@ fun () ->
  let term, info = create_bundle (OpamCLIVersion.default, `Default) in
  exit @@ Cmd.eval ~catch:false (Cmd.v info term)
