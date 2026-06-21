open Alcotest
open Treesp.Value
open Treesp.Reader

let read_ok s = read_one s

let expect_error s =
  match read_one s with
  | exception Read_error _ -> ()
  | exception Treesp_error _ -> ()
  | v -> Alcotest.failf "expected read error, got %s" (Treesp.Printer.string_of_value v)

let appendix_a =
  [ test_case "void" `Quick (fun () -> check bool "void" true (is_void (read_ok "()")));
    test_case "positional desugar" `Quick (fun () ->
       let v = read_ok "(f a b)" in
       check bool "tree?" true (is_tree v);
       check bool "arg0" true (equal (branch_get v "arg0") (sym "a"));
       check bool "arg1" true (equal (branch_get v "arg1") (sym "b")));
    test_case "explicit label" `Quick (fun () ->
       let v = read_ok "(f (x a))" in
       check bool "x branch" true (equal (branch_get v "x") (sym "a"));
       check bool "no arg0" false (branch_has v "arg0"));
    test_case "quote abbrev" `Quick (fun () ->
       let v = read_ok "'x" in
       check bool "quote tag" true (equal (tree_tag v) (sym "quote"));
       check bool "quoted x" true (equal (branch_get v "arg0") (sym "x")));
    test_case "nested unary call not explicit" `Quick (fun () ->
       let v = read_ok "(* n (fact (- n 1)))" in
       check bool "tree?" true (is_tree v);
       ignore v)
  ]

let reader_errors =
  [ test_case "unclosed paren" `Quick (fun () -> expect_error "(f 1");
    test_case "mixed branches" `Quick (fun () -> expect_error "(foo (a 1) (b c d))");
    test_case "mixed branches position" `Quick (fun () ->
       match read_one "(f (x 1) (y c d))" with
       | exception Read_error ({ line; col }, msg) ->
           check int "line" 1 line;
           check bool "col > 0" true (col > 0);
           check bool "message" true (msg = "read: mixed branch forms")
       | exception Treesp_error msg ->
           Alcotest.failf "expected Read_error, got Treesp_error: %s" msg
       | v ->
           Alcotest.failf "expected read error, got %s"
             (Treesp.Printer.string_of_value v));
    test_case "duplicate label" `Quick (fun () -> expect_error "(f (x 1) (x 2))");
    test_case "malformed number" `Quick (fun () -> expect_error "(f .)");
    test_case "trailing input" `Quick (fun () -> expect_error "() ()")
  ]

let extras =
  [ test_case "empty tree node" `Quick (fun () ->
       let v = read_ok "(tag)" in
       check bool "not void" false (is_void v);
       check bool "zero branches" true (tree_branches v = []));
    test_case "read_all" `Quick (fun () ->
       let vs = read_all "1 2 3" in
       check int "count" 3 (List.length vs));
    test_case "comment skipped" `Quick (fun () ->
       check bool "num" true (equal (read_ok "42 ; comment") (Num 42.0)));
    test_case "unquote not explicit label" `Quick (fun () ->
       let v = read_ok "`,x" in
       check bool "quasiquote tag" true (equal (tree_tag v) (sym "quasiquote"));
       match branch_get v "arg0" with
       | Tree { tag = Sym "unquote"; branches = [ ("arg0", Sym "x") ] } -> ()
       | other -> Alcotest.failf "expected unquote tree, got %s" (Treesp.Printer.string_of_value other))
  ]

let () =
  run "reader"
    [
      ("appendix A", appendix_a);
      ("errors", reader_errors);
      ("extras", extras);
    ]
