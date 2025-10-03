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
open Cmdliner.Arg
open Opam_wix
open Opam_wix.Types

let wix_version_conv =
  let parse str =
    try `Ok (Wix.Version.of_string str) with Failure s -> `Error s
  in
  let print ppf wxv = Format.pp_print_string ppf (Wix.Version.to_string wxv) in
  (parse, print)

let opam_filename =
  let conv, pp = OpamArg.filename in
  ((fun filename_arg -> System.normalize_path filename_arg |> conv), pp)

let opam_dirname =
  let conv, pp = OpamArg.dirname in
  ((fun dirname_arg -> System.normalize_path dirname_arg |> conv), pp)

let conffile =
  value
  & opt (some opam_filename) None
  & info [ "conf"; "c" ] ~docv:"PATH" ~docs:Man.Section.bin_args
      ~doc:
        "Configuration file for the binary to install. See $(i,Configuration) \
         section"

let package =
  required
  & pos 0 (some OpamArg.package_name) None
  & info [] ~docv:"PACKAGE" ~docs:Man.Section.package_arg
      ~doc:"The package to create an installer"

let path =
  value
  & opt (some opam_filename) None
  & info [ "binary-path"; "bp" ] ~docs:Man.Section.bin_args ~docv:"PATH"
      ~doc:"The path to the binary file to handle"

let binary =
  value
  & opt (some string) None
  & info [ "binary"; "b" ] ~docs:Man.Section.bin_args ~docv:"NAME"
      ~doc:
        "The binary name to handle. Specified package should contain the \
         binary with the same name."

let wix_version =
  value
  & opt (some wix_version_conv) None
  & info [ "with-version" ] ~docv:"VERSION"
      ~doc:
        "The version to use for the installer, in an msi format, i.e. numbers \
         and dots, [0-9.]+"

let output_dir =
  value
  & opt opam_dirname (OpamFilename.Dir.of_string ".")
  & info [ "o"; "output" ] ~docv:"DIR"
      ~doc:"The output directory where bundle will be stored"

let wix_path =
  (* FIXME: that won't work when using a MinGW ocaml compiler under a Cygwin env... *)
  (* NOTE1: we could retrieve this using the WIX6 environment variable *)
  (* NOTE2: or we could rely in wix.exe to be in the PATH (the installer sets it) *)
  let prefix = if Sys.cygwin || true then "/cygdrive" else "" in
  value
  & opt string (prefix ^ "/c/Program Files/WiX Toolset v6.0/bin")
  & info [ "wix-path" ] ~docv:"DIR"
      ~doc:
        "The path where WIX tools are stored. The path should be full and \
         should use linux format path (with $(i,/) as delimiter) since \
         presence of such binaries are checked with $(b,which) tool that \
         accepts only this type of path."

let package_guid =
  value
  & opt (some string) None
  & info [ "pkg-guid" ] ~docv:"UID"
      ~doc:
        "The package GUID that will be used to update the same package with \
         different version without processing throught Windows Apps & features \
         panel."

let icon_file =
  value
  & opt (some OpamArg.filename) None
  & info [ "ico" ] ~docv:"FILE"
      ~doc:"Logo icon that will be used for application."

let dlg_bmp =
  value
  & opt (some OpamArg.filename) None
  & info [ "dlg-bmp" ] ~docv:"FILE"
      ~doc:
        "BMP file that is used as background for dialog window for installer."

let ban_bmp =
  value
  & opt (some OpamArg.filename) None
  & info [ "ban-bmp" ] ~docv:"FILE"
      ~doc:"BMP file that is used as background for banner for installer."

let keep_wxs = value & flag & info [ "keep-wxs" ] ~doc:"Keep Wix source files."

let config =
  let apply conf_file conf_package conf_path conf_binary conf_wix_version
      conf_output_dir conf_wix_path conf_package_guid conf_icon_file
      conf_dlg_bmp conf_ban_bmp conf_keep_wxs =
    {
      conf_file;
      conf_package;
      conf_path;
      conf_binary;
      conf_wix_version;
      conf_output_dir;
      conf_wix_path;
      conf_package_guid;
      conf_icon_file;
      conf_dlg_bmp;
      conf_ban_bmp;
      conf_keep_wxs;
    }
  in
  Term.(
    const apply $ conffile $ package $ path $ binary $ wix_version $ output_dir
    $ wix_path $ package_guid $ icon_file $ dlg_bmp $ ban_bmp $ keep_wxs)

type backend = Wix | Makeself
type 'a choice = Autodetect | Forced of 'a option

let backend =
  let open Arg in
  let parse s =
    match String.lowercase_ascii s with
    | "wix" -> Ok (Forced (Some Wix))
    | "makeself" -> Ok (Forced (Some Makeself))
    | "none" -> Ok (Forced None)
    | _ -> Error (Format.sprintf "Unsupported backend %S" s)
  in
  let print fmt t =
    match t with
    | Autodetect -> Fmt.pf fmt "autodetect"
    | Forced None -> Fmt.pf fmt "none"
    | Forced (Some Wix) -> Fmt.pf fmt "wix"
    | Forced (Some Makeself) -> Fmt.pf fmt "makeself"
  in
  let docv = "BACKEND" in
  let conv = Cmdliner.Arg.conv' ~docv (parse, print) in
  let doc =
    "($(b,wix)|$(b,makeself)|$(b,none)). Overwrites the default $(docv). \
     Without this option, it is determined from the system: WiX to produce msi \
     installers on Windows, makeself to produce self extracting/installing \
     .run archives on Unix. When $(b,none), disables backend, making the \
     command generate a bundle with an installer config that can later be fed \
     into any of the existing backends."
  in
  value & opt conv Autodetect & info [ "backend" ] ~doc ~docv
