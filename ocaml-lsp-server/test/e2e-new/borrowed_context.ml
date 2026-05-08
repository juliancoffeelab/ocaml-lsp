open Test.Import

module Merlin_config = Ocaml_lsp_server__Merlin_config

let write_file path contents =
  let oc = open_out_bin path in
  output_string oc contents;
  close_out oc
;;

let read_file_exn path =
  let ic = open_in_bin path in
  try
    let length = in_channel_length ic in
    let contents = really_input_string ic length in
    close_in ic;
    contents
  with
  | exn ->
    close_in_noerr ic;
    raise exn
;;

let build_system_script =
  String.concat
    ~sep:"\n"
    [ "#!/usr/bin/env python3"
    ; "import os"
    ; "import sys"
    ; ""
    ; "LOG = os.environ[\"PR6_LOG\"]"
    ; "TMP_ROOT = os.environ[\"PR6_TMP_ROOT\"]"
    ; ""
    ; "def read_atom(first):"
    ; "    length_digits = [first]"
    ; "    while True:"
    ; "        ch = sys.stdin.buffer.read(1)"
    ; "        if ch == b\":\":"
    ; "            break"
    ; "        if not ch:"
    ; "            raise EOFError"
    ; "        length_digits.append(ch)"
    ; "    length = int(b\"\".join(length_digits))"
    ; "    data = sys.stdin.buffer.read(length)"
    ; "    if len(data) != length:"
    ; "        raise EOFError"
    ; "    return data.decode()"
    ; ""
    ; "def read_expr(first):"
    ; "    if first == b\"(\":"
    ; "        items = []"
    ; "        while True:"
    ; "            peek = sys.stdin.buffer.read(1)"
    ; "            if not peek:"
    ; "                raise EOFError"
    ; "            if peek == b\")\":"
    ; "                return items"
    ; "            items.append(read_expr(peek))"
    ; "    if first.isdigit():"
    ; "        return read_atom(first)"
    ; "    raise ValueError(first)"
    ; ""
    ; "def read_sexp():"
    ; "    ch = sys.stdin.buffer.read(1)"
    ; "    if not ch:"
    ; "        return None"
    ; "    return read_expr(ch)"
    ; ""
    ; "def write_response(payload):"
    ; "    sys.stdout.buffer.write(payload)"
    ; "    sys.stdout.buffer.flush()"
    ; ""
    ; "def normalize(path):"
    ; "    prefixes = [TMP_ROOT, \"/private\" + TMP_ROOT]"
    ; "    for prefix in prefixes:"
    ; "        if path == prefix:"
    ; "            return \"$TMP\""
    ; "        if path.startswith(prefix + os.sep):"
    ; "            return \"$TMP\" + path[len(prefix):]"
    ; "    return path"
    ; ""
    ; "while True:"
    ; "    request = read_sexp()"
    ; "    if request is None:"
    ; "        break"
    ; "    if request == \"Halt\":"
    ; "        break"
    ; "    if request[0] != \"File\":"
    ; "        write_response(b\"((5:ERROR7:unknown))\")"
    ; "        continue"
    ; "    path = request[1]"
    ; "    context = \"-\""
    ; "    if len(request) == 4 and request[2] == \"Context\":"
    ; "        context = request[3]"
    ; "    with open(LOG, \"a\", encoding=\"utf-8\") as log:"
    ; "        log.write(f\"path={normalize(path)};context={normalize(context)}\\n\")"
    ; "    if context == \"-\":"
    ; "        write_response(b\"((5:ERROR5:first))\")"
    ; "    else:"
    ; "        write_response(b\"()\")"
    ; ""
    ]
;;

let build_system_context_fallback_script =
  String.concat
    ~sep:"\n"
    [ "#!/usr/bin/env python3"
    ; "import os"
    ; "import sys"
    ; ""
    ; "LOG = os.environ[\"PR6_LOG\"]"
    ; "TMP_ROOT = os.environ[\"PR6_TMP_ROOT\"]"
    ; ""
    ; "def read_atom(first):"
    ; "    length_digits = [first]"
    ; "    while True:"
    ; "        ch = sys.stdin.buffer.read(1)"
    ; "        if ch == b\":\":"
    ; "            break"
    ; "        if not ch:"
    ; "            raise EOFError"
    ; "        length_digits.append(ch)"
    ; "    length = int(b\"\".join(length_digits))"
    ; "    data = sys.stdin.buffer.read(length)"
    ; "    if len(data) != length:"
    ; "        raise EOFError"
    ; "    return data.decode()"
    ; ""
    ; "def read_expr(first):"
    ; "    if first == b\"(\":"
    ; "        items = []"
    ; "        while True:"
    ; "            peek = sys.stdin.buffer.read(1)"
    ; "            if not peek:"
    ; "                raise EOFError"
    ; "            if peek == b\")\":"
    ; "                return items"
    ; "            items.append(read_expr(peek))"
    ; "    if first.isdigit():"
    ; "        return read_atom(first)"
    ; "    raise ValueError(first)"
    ; ""
    ; "def read_sexp():"
    ; "    ch = sys.stdin.buffer.read(1)"
    ; "    if not ch:"
    ; "        return None"
    ; "    return read_expr(ch)"
    ; ""
    ; "def write_response(payload):"
    ; "    sys.stdout.buffer.write(payload)"
    ; "    sys.stdout.buffer.flush()"
    ; ""
    ; "def normalize(path):"
    ; "    prefixes = [TMP_ROOT, \"/private\" + TMP_ROOT]"
    ; "    for prefix in prefixes:"
    ; "        if path == prefix:"
    ; "            return \"$TMP\""
    ; "        if path.startswith(prefix + os.sep):"
    ; "            return \"$TMP\" + path[len(prefix):]"
    ; "    return path"
    ; ""
    ; "while True:"
    ; "    request = read_sexp()"
    ; "    if request is None:"
    ; "        break"
    ; "    if request == \"Halt\":"
    ; "        break"
    ; "    if request[0] != \"File\":"
    ; "        write_response(b\"((5:ERROR7:unknown))\")"
    ; "        continue"
    ; "    path = request[1]"
    ; "    context = \"-\""
    ; "    if len(request) == 4 and request[2] == \"Context\":"
    ; "        context = request[3]"
    ; "    with open(LOG, \"a\", encoding=\"utf-8\") as log:"
    ; "        log.write(f\"path={normalize(path)};context={normalize(context)}\\n\")"
    ; "    if context == \"-\":"
    ; "        write_response(b\"()\")"
    ; "    else:"
    ; "        write_response(b\"((5:ERROR7:context))\")"
    ; ""
    ]
;;

let build_system_module_resolution_script =
  String.concat
    ~sep:"\n"
    [ "#!/usr/bin/env python3"
    ; "import os"
    ; "import sys"
    ; ""
    ; "FMT_ROOT = os.environ[\"PR6_FMT_ROOT\"]"
    ; "FMT_TARGET = os.environ[\"PR6_FMT_TARGET\"]"
    ; "STDLIB_ROOT = os.environ[\"PR6_STDLIB_ROOT\"]"
    ; "STDLIB_TARGET = os.environ[\"PR6_STDLIB_TARGET\"]"
    ; "OCAML_STDLIB = os.environ[\"PR6_OCAML_STDLIB\"]"
    ; ""
    ; "def atom(text):"
    ; "    data = text.encode()"
    ; "    return str(len(data)).encode() + b\":\" + data"
    ; ""
    ; "def sexp_list(items):"
    ; "    return b\"(\" + b\"\".join(items) + b\")\""
    ; ""
    ; "def directive(tag, value=None):"
    ; "    if value is None:"
    ; "        return sexp_list([atom(tag)])"
    ; "    return sexp_list([atom(tag), atom(value)])"
    ; ""
    ; "def read_atom(first):"
    ; "    length_digits = [first]"
    ; "    while True:"
    ; "        ch = sys.stdin.buffer.read(1)"
    ; "        if ch == b\":\":"
    ; "            break"
    ; "        if not ch:"
    ; "            raise EOFError"
    ; "        length_digits.append(ch)"
    ; "    length = int(b\"\".join(length_digits))"
    ; "    data = sys.stdin.buffer.read(length)"
    ; "    if len(data) != length:"
    ; "        raise EOFError"
    ; "    return data.decode()"
    ; ""
    ; "def read_expr(first):"
    ; "    if first == b\"(\":"
    ; "        items = []"
    ; "        while True:"
    ; "            peek = sys.stdin.buffer.read(1)"
    ; "            if not peek:"
    ; "                raise EOFError"
    ; "            if peek == b\")\":"
    ; "                return items"
    ; "            items.append(read_expr(peek))"
    ; "    if first.isdigit():"
    ; "        return read_atom(first)"
    ; "    raise ValueError(first)"
    ; ""
    ; "def read_sexp():"
    ; "    ch = sys.stdin.buffer.read(1)"
    ; "    if not ch:"
    ; "        return None"
    ; "    return read_expr(ch)"
    ; ""
    ; "def write_response(payload):"
    ; "    sys.stdout.buffer.write(payload)"
    ; "    sys.stdout.buffer.flush()"
    ; ""
    ; "def respond_with_source(path, root, unit_name):"
    ; "    path_dir = os.path.dirname(path)"
    ; "    directives = ["
    ; "        directive(\"STDLIB\", OCAML_STDLIB),"
    ; "        directive(\"SOURCE_ROOT\", root),"
    ; "        directive(\"S\", root),"
    ; "    ]"
    ; "    if path_dir != root:"
    ; "        directives.append(directive(\"S\", path_dir))"
    ; "    directives.append(directive(\"UNIT_NAME\", unit_name))"
    ; "    write_response(sexp_list(directives))"
    ; ""
    ; "while True:"
    ; "    request = read_sexp()"
    ; "    if request is None:"
    ; "        break"
    ; "    if request == \"Halt\":"
    ; "        break"
    ; "    if request[0] != \"File\":"
    ; "        write_response(sexp_list([directive(\"ERROR\", \"unknown\")]))"
    ; "        continue"
    ; "    path = request[1]"
    ; "    context = None"
    ; "    if len(request) == 4 and request[2] == \"Context\":"
    ; "        context = request[3]"
    ; "    if context is None:"
    ; "        write_response(sexp_list([directive(\"ERROR\", \"need context\")]))"
    ; "    elif path == FMT_TARGET:"
    ; "        respond_with_source(path, FMT_ROOT, \"fmt\")"
    ; "    elif path == STDLIB_TARGET:"
    ; "        respond_with_source(path, STDLIB_ROOT, \"list\")"
    ; "    else:"
    ; "        write_response(sexp_list([directive(\"ERROR\", \"unknown file\")]))"
    ; ""
    ]
;;

let setup_dir prefix =
  let dir = Stdlib.Filename.temp_file prefix "" in
  Stdlib.Sys.remove dir;
  Unix.mkdir dir 0o700;
  dir
;;

let mkdir_p path =
  let rec loop path =
    if Sys.file_exists path
    then ()
    else (
      let parent = Filename.dirname path in
      if not (String.equal parent path) then loop parent;
      Unix.mkdir path 0o700)
  in
  loop path
;;

let setup_fixture () =
  let tmp_root = setup_dir "ocamllsp-pr6-" in
  let project_root = Stdlib.Filename.concat tmp_root "project" in
  Unix.mkdir project_root 0o700;
  let origin = Stdlib.Filename.concat project_root "foo.ml" in
  let target = Stdlib.Filename.concat tmp_root "external.ml" in
  let log_path = Stdlib.Filename.concat tmp_root "requests.log" in
  let build_system = Stdlib.Filename.concat tmp_root "build-system.py" in
  write_file (Stdlib.Filename.concat project_root "dune-project") "(lang dune 3.20)\n";
  write_file origin "let _ = List.map\n";
  write_file target "let external_value = 1\n";
  write_file build_system build_system_script;
  Unix.chmod build_system 0o755;
  tmp_root, build_system, log_path, origin, target
;;

let setup_fixture_with_build_system ~build_system_script =
  let tmp_root = setup_dir "ocamllsp-pr6-" in
  let project_root = Stdlib.Filename.concat tmp_root "project" in
  Unix.mkdir project_root 0o700;
  let origin = Stdlib.Filename.concat project_root "foo.ml" in
  let target = Stdlib.Filename.concat tmp_root "external.ml" in
  let log_path = Stdlib.Filename.concat tmp_root "requests.log" in
  let build_system = Stdlib.Filename.concat tmp_root "build-system.py" in
  write_file (Stdlib.Filename.concat project_root "dune-project") "(lang dune 3.20)\n";
  write_file origin "let _ = List.map\n";
  write_file target "let external_value = 1\n";
  write_file build_system build_system_script;
  Unix.chmod build_system 0o755;
  tmp_root, build_system, log_path, origin, target
;;

let setup_module_resolution_fixture () =
  let tmp_root = setup_dir "ocamllsp-pr6-" in
  let project_root = Filename.concat tmp_root "project" in
  let fmt_root = Filename.concat tmp_root "_build/_private/default/.pkg/fmt.fake/source" in
  let stdlib_root =
    Filename.concat tmp_root "_build/_private/default/.pkg/ocaml-compiler.fake/source"
  in
  let fmt_dir = Filename.concat fmt_root "src" in
  let stdlib_dir = Filename.concat stdlib_root "stdlib" in
  let origin = Filename.concat project_root "foo.ml" in
  let fmt_target = Filename.concat fmt_dir "fmt.ml" in
  let stdlib_target = Filename.concat stdlib_dir "list.ml" in
  let build_system = Filename.concat tmp_root "build-system.py" in
  mkdir_p project_root;
  mkdir_p fmt_dir;
  mkdir_p stdlib_dir;
  write_file (Filename.concat project_root "dune-project") "(lang dune 3.20)\n";
  write_file origin "let _ = ()\n";
  write_file fmt_target "let x = Format.printf\n";
  write_file stdlib_target "let x = Seq.Cons (1, fun () -> Seq.Nil)\n";
  write_file build_system build_system_module_resolution_script;
  Unix.chmod build_system 0o755;
  tmp_root, build_system, origin, fmt_root, fmt_target, stdlib_root, stdlib_target
;;

let ocaml_stdlib_dir () =
  let ic = Unix.open_process_in "ocamlc.opt -where" in
  Fun.protect
    ~finally:(fun () ->
      match Unix.close_process_in ic with
      | WEXITED 0 -> ()
      | WEXITED n ->
        failwith (Printf.sprintf "ocamlc.opt -where exited with %d" n)
      | WSIGNALED n | WSTOPPED n ->
        failwith (Printf.sprintf "ocamlc.opt -where failed with signal %d" n))
    (fun () ->
      input_line ic |> String.trim)
;;

let run_config_with_borrowed_context ~build_system ~origin ~target =
  Unix.putenv "OCAMLLSP_PROJECT_BUILD_SYSTEM" build_system;
  let db = Merlin_config.DB.create () in
  let config = Merlin_config.DB.get db (DocumentUri.of_path target) in
  Merlin_config.DB.remember_origin
    db
    ~target:(DocumentUri.of_path target)
    ~origin:(DocumentUri.of_path origin);
  Lev_fiber.run (fun () ->
    Fiber.fork_and_join_unit
      (fun () -> Merlin_config.DB.run db)
      (fun () ->
         let* _ = Merlin_config.config config in
         let* () = Merlin_config.destroy config in
         Merlin_config.DB.stop db))
  |> Lev_fiber.Error.ok_exn
;;

let load_config_with_borrowed_context ~build_system ~origin ~target =
  Unix.putenv "OCAMLLSP_PROJECT_BUILD_SYSTEM" build_system;
  let db = Merlin_config.DB.create () in
  let config = Merlin_config.DB.get db (DocumentUri.of_path target) in
  Merlin_config.DB.remember_origin
    db
    ~target:(DocumentUri.of_path target)
    ~origin:(DocumentUri.of_path origin);
  Lev_fiber.run (fun () ->
    Fiber.fork_and_join_unit
      (fun () -> Merlin_config.DB.run db)
      (fun () ->
         let* mconfig = Merlin_config.config config in
         let* () = Merlin_config.destroy config in
         let+ () = Merlin_config.DB.stop db in
         mconfig))
  |> Lev_fiber.Error.ok_exn
;;

let locate_path_exn ~source ~line ~character config =
  let pipeline =
    Merlin_kernel.Mpipeline.make
      config
      (Merlin_kernel.Msource.make source)
  in
  let position = Position.create ~line ~character |> Position.logical in
  match
    Merlin_kernel.Mpipeline.with_pipeline pipeline (fun () ->
      Query_commands.dispatch pipeline (Query_protocol.Locate (None, `ML, position)))
  with
  | `Found (Some path, _) -> path
  | `Found (None, _) -> failwith "expected locate result to include a path"
  | `At_origin -> failwith "expected locate query to move to another file"
  | `Builtin s -> failwith (Printf.sprintf "expected file result, got builtin %S" s)
  | `File_not_found s ->
    failwith (Printf.sprintf "expected file result, got missing file %S" s)
  | `Invalid_context -> failwith "expected valid locate context"
  | `Not_found (ident, where) ->
    let where =
      match where with
      | None -> ""
      | Some where -> Printf.sprintf " in %s" where
    in
    failwith (Printf.sprintf "identifier %S was not found%s" ident where)
  | `Not_in_env modname ->
    failwith (Printf.sprintf "module %s was not found in the environment" modname)
;;

let%test_unit "borrowed origin reuses the project context for external files" =
  let tmp_root, build_system, log_path, origin, target = setup_fixture () in
  Unix.putenv "PR6_LOG" log_path;
  Unix.putenv "PR6_TMP_ROOT" tmp_root;
  run_config_with_borrowed_context ~build_system ~origin ~target;
  let log = read_file_exn log_path in
  let expected = "path=$TMP/external.ml;context=$TMP/project/foo.ml\n" in
  if not (String.equal log expected)
  then
    failwith
      (Printf.sprintf "unexpected borrowed-context log\nexpected:\n%s\nactual:\n%s" expected log)
;;

let%test_unit "borrowed origin falls back to plain queries when context is rejected" =
  let tmp_root, build_system, log_path, origin, target =
    setup_fixture_with_build_system ~build_system_script:build_system_context_fallback_script
  in
  Unix.putenv "PR6_LOG" log_path;
  Unix.putenv "PR6_TMP_ROOT" tmp_root;
  run_config_with_borrowed_context ~build_system ~origin ~target;
  let log = read_file_exn log_path in
  let expected =
    String.concat
      ~sep:""
      [ "path=$TMP/external.ml;context=$TMP/project/foo.ml\n"
      ; "path=$TMP/external.ml;context=$TMP/project/foo.ml\n"
      ; "path=$TMP/external.ml;context=-\n"
      ]
  in
  if not (String.equal log expected)
  then
    failwith
      (Printf.sprintf "unexpected borrowed-context log\nexpected:\n%s\nactual:\n%s" expected log)
;;

let%test_unit "borrowed origin resolves stdlib modules in external package sources" =
  let tmp_root, build_system, origin, fmt_root, fmt_target, stdlib_root, stdlib_target =
    setup_module_resolution_fixture ()
  in
  Unix.putenv "PR6_FMT_ROOT" fmt_root;
  Unix.putenv "PR6_FMT_TARGET" fmt_target;
  Unix.putenv "PR6_STDLIB_ROOT" stdlib_root;
  Unix.putenv "PR6_STDLIB_TARGET" stdlib_target;
  Unix.putenv "PR6_OCAML_STDLIB" (ocaml_stdlib_dir ());
  let fmt_config =
    load_config_with_borrowed_context ~build_system ~origin ~target:fmt_target
  in
  let format_path =
    locate_path_exn ~source:"let x = Format.printf\n" ~line:0 ~character:8 fmt_config
  in
  if not (Filename.check_suffix format_path "format.ml")
  then failwith (Printf.sprintf "expected format.ml, got %s" format_path);
  let stdlib_config =
    load_config_with_borrowed_context ~build_system ~origin ~target:stdlib_target
  in
  let seq_path =
    locate_path_exn
      ~source:"let x = Seq.Cons (1, fun () -> Seq.Nil)\n"
      ~line:0
      ~character:8
      stdlib_config
  in
  if not (Filename.check_suffix seq_path "seq.ml")
  then failwith (Printf.sprintf "expected seq.ml, got %s" seq_path);
  ignore tmp_root
;;
