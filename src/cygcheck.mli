(** Investigates binary file dependencies with {i cygcheck} and returns paths to system DLLs *)
val get_dlls : OpamFilename.t -> OpamFilename.t list
