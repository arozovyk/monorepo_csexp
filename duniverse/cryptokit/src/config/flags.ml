(* Compute compilation and linking flags *)

open Printf
open Config_vars

module Configurator = Configurator.V1

(* Compile and link a dummy C program with the given flags. *)
let test ~cfg ~c_flags ~link_flags =
  let test_program = "int main() { return 0; }" in
  Configurator.c_test cfg test_program ~c_flags ~link_flags

(* Check that a list of header files declare a list of identifiers. *)
let provides ~cfg ~c_flags ~link_flags ~headers ~functions =
  let test_program =
      List.map (fun h -> sprintf "#include <%s>\n" h) headers
    @ ["int main() {\n"]
    @ List.map (fun f -> sprintf "  void * ptr_%s = &%s;\n" f f) functions
    @ ["}\n"] in
  Configurator.c_test cfg (String.concat "" test_program) ~c_flags ~link_flags

let () = Configurator.main ~name:"cryptokit" @@ fun cfg ->
  let os_type = Configurator.ocaml_config_var_exn cfg "os_type" in
  let system = Configurator.ocaml_config_var_exn cfg "system" in
  let architecture = Configurator.ocaml_config_var_exn cfg "architecture" in
  let zlib = match enable_zlib with
    | This bool -> bool
    | Auto -> os_type <> "Win32"
  in
  let hardware_support = match enable_hardware_support with
    | This bool -> bool
    | Auto -> (architecture = "amd64" || architecture = "i386")
              && test ~cfg ~c_flags:[ "-maes"; "-mpclmul" ] ~link_flags:[]
  in
  let has_getentropy =
    provides ~cfg ~c_flags:[] ~link_flags:[]
             ~headers:["unistd.h"] ~functions:["getentropy"]
  in
  let append_if c y x = if c then x @ [ y ] else x in
  let flags =
    []
    |> append_if has_getentropy "-DHAVE_GETENTROPY"
    |> append_if zlib "-DHAVE_ZLIB"
    |> append_if hardware_support "-maes"
    |> append_if hardware_support "-mpclmul"
  in
  let library_flags =
    []
    |> append_if (zlib && (system = "win32" || system = "win64")) "zlib.lib"
    |> append_if (zlib && system <> "win32" && system <> "win64") "-lz"
    |> append_if (system = "win32" || system = "win64") "advapi32.lib"
    |> append_if (system = "mingw" || system = "mingw64") "-ladvapi32"
  in
  Configurator.Flags.write_sexp "flags.sexp" flags;
  Configurator.Flags.write_sexp "library_flags.sexp" library_flags;
  let describe_bool = function
    | true -> "enabled"
    | false -> "disabled"
  in
  printf "ZLib: ............................... %s\n" (describe_bool zlib);
  printf "Hardware support for AES and GCM: ... %s\n" (describe_bool hardware_support);
  printf "getentropy():........................ %s\n" (describe_bool has_getentropy)

