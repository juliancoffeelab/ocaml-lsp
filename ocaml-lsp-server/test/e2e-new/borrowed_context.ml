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
    ; "    return path.replace(TMP_ROOT, \"$TMP\")"
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
    ; "    return path.replace(TMP_ROOT, \"$TMP\")"
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

let setup_dir prefix =
  let dir = Stdlib.Filename.temp_file prefix "" in
  Stdlib.Sys.remove dir;
  Unix.mkdir dir 0o700;
  dir
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
      ; "path=$TMP/external.ml;context=-\n"
      ]
  in
  if not (String.equal log expected)
  then
    failwith
      (Printf.sprintf "unexpected borrowed-context log\nexpected:\n%s\nactual:\n%s" expected log)
;;
