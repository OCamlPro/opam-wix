
type wxs

module type INFO = sig
    val path : string
    val package_name : string
    val package_version : string
    val description : string
    val manufacter : string
    val package_guid : string option
    val tags : string list
    val exec_file : string
    val dlls : string list
    val icon_file : string
    val dlg_bmp_file : string
    val banner_bmp_file : string
end

val main_wxs : (module INFO) -> wxs

val write_wxs : string -> wxs -> unit
