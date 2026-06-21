open Alcotest
open Treesp.Value
open Treesp.Eval

let fresh () = make_runtime ()

let eval_string s =
  let rt = fresh () in
  load_string rt s

let check_num msg expected got =
  match num_val got with
  | Some n when n = expected -> ()
  | Some n -> Alcotest.failf "%s: expected %g, got %g" msg expected n
  | None -> Alcotest.failf "%s: expected number, got %s" msg (Treesp.Printer.string_of_value got)

let arithmetic_tests =
  [ test_case "(+ 1 2)" `Quick (fun () -> check_num "(+ 1 2)" 3.0 (eval_string "(+ 1 2)"));
    test_case "(+ 1 (* 2 3))" `Quick (fun () ->
       check_num "(+ 1 (* 2 3))" 7.0 (eval_string "(+ 1 (* 2 3))"));
    test_case "(= 5 0)" `Quick (fun () ->
       match eval_string "(= 5 0)" with Bool false -> () | v -> Alcotest.failf "got %s" (Treesp.Printer.string_of_value v));
    test_case "(- 5 1)" `Quick (fun () -> check_num "(- 5 1)" 4.0 (eval_string "(- 5 1)"));
    test_case "(- 10 3 2)" `Quick (fun () ->
       check_num "(- 10 3 2)" 5.0 (eval_string "(- 10 3 2)"))
  ]

let factorial_test =
  test_case "factorial" `Quick (fun () ->
      let rt = fresh () in
      ignore
        (load_string rt
           "(define fact (lambda (n) (if (= n 0) 1 (* n (fact (- n 1))))))");
      check_num "(fact 5)" 120.0 (eval rt (Treesp.Reader.read_one "(fact 5)")))

let special_form_tests =
  [ test_case "quote" `Quick (fun () ->
       let v = eval_string "'(+ 1 2)" in
       check bool "tree?" true (is_tree v);
       check bool "tag +" true (equal (tree_tag v) (sym "+")));
    test_case "if false branch" `Quick (fun () ->
       check_num "if" 2.0 (eval_string "(if #f 1 2)"));
    test_case "and short-circuit" `Quick (fun () ->
       match eval_string "(and #f 999)" with
       | Bool false -> ()
       | v -> Alcotest.failf "expected #f, got %s" (Treesp.Printer.string_of_value v));
    test_case "or short-circuit" `Quick (fun () ->
       check_num "or" 1.0 (eval_string "(or #f 1 999)"))
  ]

let () =
  run "eval"
    [
      ("arithmetic", arithmetic_tests);
      ("factorial", [ factorial_test ]);
      ("special forms", special_form_tests);
    ]
