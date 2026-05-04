let%expect_test "eat_message tests" =
  let test e1 e2 expected =
    let result = Ocaml_lsp_server.Diagnostics.equal_message e1 e2 in
    if result = expected then print_endline "[PASS]" else print_endline "[FAIL]"
  in
  test "foo bar" "foo  bar" true;
  [%expect {| [PASS] |}];
  test " foobar" "foobar" true;
  [%expect {| [PASS] |}];
  test "foobar" "foobar " true;
  [%expect {| [PASS] |}];
  test "foobar" "foobar\t" true;
  [%expect {| [PASS] |}];
  test "foobar" "foobar\n" true;
  [%expect {| [PASS] |}];
  test "foobar" "foo bar" false;
  [%expect {| [PASS] |}];
  test "foo bar" "foo Bar" false;
  [%expect {| [PASS] |}]
;;

let run_fiber fiber = Lev_fiber.run (fun () -> fiber) |> Lev_fiber.Error.ok_exn

let%expect_test "borrowed merlin config is one-shot" =
  let open Ocaml_lsp_server in
  let module Merlin_config = Testing.Merlin_config in
  let module Mconfig = Merlin_kernel.Mconfig in
  let db = Merlin_config.DB.create () in
  let uri = Lsp.Uri.of_path "/tmp/external/smoke_dep.mli" in
  let config =
    let open Mconfig in
    { initial with
      merlin =
        { initial.merlin with source_path = [ "/workspace/app"; "/workspace/_deps/src" ] }
    ; query = { initial.query with filename = "main.ml"; directory = "/workspace/app" }
    }
  in
  Merlin_config.DB.remember_borrowed db ~uri ~config;
  let borrowed = Merlin_config.DB.get db uri |> Merlin_config.config |> run_fiber in
  print_endline (Mconfig.filename borrowed);
  print_endline borrowed.query.directory;
  print_endline (string_of_int (List.length borrowed.merlin.source_path));
  let plain = Merlin_config.DB.get db uri |> Merlin_config.config |> run_fiber in
  print_endline (Mconfig.filename plain);
  print_endline plain.query.directory;
  print_endline (string_of_int (List.length plain.merlin.source_path));
  [%expect
    {|
    smoke_dep.mli
    /tmp/external
    2
    smoke_dep.mli
    /tmp/external
    0
    |}]
;;
