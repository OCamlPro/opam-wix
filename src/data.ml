(**************************************************************************)
(*                                                                        *)
(*    Copyright 2023 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let get_data o filename =
  match o with
  | Some v -> v
  | None -> OpamConsole.error_and_exit `Configuration_error
              "Seems like you moved your %s. This file is required since it is used by default. \
               If you want to replace it by your default choice, but keep the same name and path."
              (OpamConsole.colorise `bold filename)

(** Data directory with crunched content. Every pair value within represents filename and its content. *)

let get basename subdir =
  let filename = String.concat "/" [subdir; basename] in
  basename,
  get_data (DataDir.read filename) (String.concat "/" ["data"; filename])

module IMAGES = struct
  let logo = get "logo.ico" "images"
  let dlgbmp = get "dlgbmp.bmp" "images"
  let banbmp = get "bannrbmp.bmp" "images"
end
module WIX = struct
  let custom_install_dir = get "CustomInstallDir.wxs" "wix"
  let custom_install_dir_dlg = get "CustomInstallDirDlg.wxs" "wix"
end
