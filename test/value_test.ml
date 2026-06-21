open Alcotest
open Treesp.Value
open Treesp.Printer

let test_equal name got want =
  if equal got want then ()
  else
    Alcotest.failf "values differ for %s@.got:  %s@.want: %s" name (string_of_value got)
      (string_of_value want)

let void_tests =
  [ test_case "void is void" `Quick (fun () -> check bool "void?" true (is_void void));
    test_case "empty tree is not void" `Quick (fun () ->
       check bool "void?" false (is_void (make_tree (sym "tag") [])))
  ]

let equal_tests =
  [ test_case "void equals void" `Quick (fun () -> test_equal "void" void void);
    test_case "numbers equal" `Quick (fun () -> test_equal "num" (Num 42.0) (Num 42.0));
    test_case "trees with arg branches" `Quick (fun () ->
       let got = make_tree (sym "f") [ ("arg0", sym "a"); ("arg1", sym "b") ] in
       let want = make_tree (sym "f") [ ("arg0", sym "a"); ("arg1", sym "b") ] in
       test_equal "tree" got want);
    test_case "graft adds branch" `Quick (fun () ->
       let t = make_tree (sym "root") [ ("a", Num 1.0) ] in
       let got = graft t "b" (Num 2.0) in
       let want = make_tree (sym "root") [ ("a", Num 1.0); ("b", Num 2.0) ] in
       test_equal "graft" got want)
  ]

let printer_tests =
  [ test_case "void prints as ()" `Quick (fun () -> check string "()" "()" (string_of_value void));
    test_case "desugared tree" `Quick (fun () ->
       let v = make_tree (sym "+") [ ("arg0", Num 1.0); ("arg1", Num 2.0) ] in
       check string "(+ 1.0 2.0)" "(+ 1.0 2.0)" (string_of_value v));
    test_case "explicit label" `Quick (fun () ->
       let v = make_tree (sym "f") [ ("x", sym "a") ] in
       check string "(f (x a))" "(f (x a))" (string_of_value v))
  ]

let () =
  run "value"
    [
      ("void", void_tests);
      ("equal", equal_tests);
      ("printer", printer_tests);
    ]
