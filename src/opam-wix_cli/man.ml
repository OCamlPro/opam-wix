(**************************************************************************)
(*                                                                        *)
(*    Copyright 2025 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

module Section = struct
  let package_arg = "PACKAGE ARGUMENT"
  let bin_args = "BINARY ARGUMENT"
end

let configuration =
  [
    `S "Configuration";
    `P
      "Despite arguments allowing partial configuration of the utility, for \
       complete support of installing complex programs and non self-contained \
       binaries, it is necessary to provide a config file with $(b,opam-format \
       syntax) (See https://opam.ocaml.org/doc/Manual.html). Such a file \
       allows opam-wix to determine which additional files and directories \
       should be installed along with the program, as well as which \
       environment variables need to be set in the Windows Terminal.";
    `P
      "To specify paths to specific files, you can use variables defined by \
       opam, for example, $(i,%{share}%/path), which adds the necessary \
       prefix. For more information about variables, refer to \
       https://opam.ocaml.org/doc/Manual.html#Variables. The config file can \
       contain the following fields:";
    `I
      ( "$(i,opamwix-version)",
        "The version of the config file. The current version is $(b,0.1)." );
    `I
      ("$(i,ico, bng, ban)", "These are the same as their respective arguments.");
    `I
      ( "$(i,binary-path, binary)",
        "These are the same as their respective arguments." );
    `I
      ( "$(i,wix_version)",
        "The version to use to generate the MSI, in a dot separated number \
         format." );
    `I
      ( "$(i,embedded)",
        "A list of files or directories paths to include in the installation \
         directory. There are 3 different ways to specify the paths, each of \
         them implies its own installation place in the target directory: \
         First way to install files is by giving a list of two elements: the \
         first being the destination basename (the name of the file in the \
         installation directory), and the second being the path to the file \
         itself. For example: $(b,[\"file.txt\" \"path/to/file\"]). The second \
         way is to include any file/directory under opam prefix. In this case, \
         variables like $(i,%{share}%) or $(i,%{lib}%) could be very usefull. \
         You should just give a list with one string that represents path \
         which prefix is the same with your current switch prefix. For \
         example, $(b,[\"/absolute-path-to-your-prefix/lib/odoc/odoc.cmi\"]) \
         or just $(b,[\"/%{odoc:lib}%/odoc.cmi\"]). Those files would be \
         installed in the directory \"opam\" at the root of installation \
         directory conserving entire path (it would be \
         $(b,INSTALLDIR/opam/lib/odoc/odoc.cmi) for previous example). The \
         last way to specify path is very similar with previous, but it takes \
         into account only external to opam files. The paths to thoses files \
         should be relative and implicit. For example, \
         $(b,[\"dir1/dir2/file.txt\"]). The file (or directory) will be \
         installed in \"external\" directory under the root of target \
         installation directory the same way as for opam files (it would be \
         $(b,INSTALLDIR/external/dir1/dir2/file.txt) for previous example)." );
    `I
      ( "$(i,envvar)",
        "A list of environment variables to set/unset in the Windows Terminal \
         during install/uninstall. Each element in this list should be a list \
         of two elements: the name and the value of the variable. Basenames \
         defined with $(b,embedded) field could be used as variables, to \
         reference absolute installed path. For example: $(b,embedded: [ \
         \"mydoc\" \"%{package:doc}%\"] envvar: [ \"DOC\" \"%{mydoc}%\"]) will \
         install directory referenced by $(i,package:doc) opam variable in \
         $(i,<install-dir>/mydoc) and set $(i,DOC) environment variable to the \
         $(i,<install-dir>/mydoc) absolute path." );
  ]
