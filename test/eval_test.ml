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

let check_sym msg expected got =
  match got with
  | Sym s when s = expected -> ()
  | Sym s -> Alcotest.failf "%s: expected symbol %s, got %s" msg expected s
  | v -> Alcotest.failf "%s: expected symbol, got %s" msg (Treesp.Printer.string_of_value v)

let check_equal msg expected got =
  if equal expected got then ()
  else
    Alcotest.failf "%s: values differ@.got:  %s@.want: %s" msg
      (Treesp.Printer.string_of_value got) (Treesp.Printer.string_of_value expected)

let navigation_tests =
  [ test_case "§10.3 tag and branch" `Quick (fun () ->
       let rt = fresh () in
       ignore
         (load_string rt
            "(define t (node expr (op +) (left (node expr (op *) (left 2) (right 3))) (right \
             1)))");
       check_sym "tag t" "expr" (eval rt (Treesp.Reader.read_one "(tag t)"));
       check_sym "branch t op" "+" (eval rt (Treesp.Reader.read_one "(branch t op)"));
       check_sym "nested branch op" "*"
         (eval rt (Treesp.Reader.read_one "(branch (branch t left) op)"));
       check_num "path left left" 2.0 (eval rt (Treesp.Reader.read_one "(path t left left)"));
       check_num "path right" 1.0 (eval rt (Treesp.Reader.read_one "(path t right)")));
    test_case "branches and branch-labels" `Quick (fun () ->
       let v = eval_string "(branches (node f (x 1) (y 2)))" in
       check_equal "branches view"
         (make_tree (sym "branches") [ ("x", Num 1.0); ("y", Num 2.0) ])
         v;
       let labels = eval_string "(branch-labels (node f (x 1) (y 2)))" in
       check_equal "branch-labels"
         (make_tree (sym "labels") [ ("arg0", sym "x"); ("arg1", sym "y") ])
         labels;
       match eval_string "(branch? (node f (x 1)) x)" with
       | Bool true -> ()
       | v -> Alcotest.failf "branch? x: got %s" (Treesp.Printer.string_of_value v))
  ]

let graft_prune_tests =
  [ test_case "§10.7 graft and prune" `Quick (fun () ->
       let rt = fresh () in
       ignore (load_string rt "(define t (node root (a 1) (b 2)))");
       let grafted = eval rt (Treesp.Reader.read_one "(graft t c 3)") in
       check_equal "graft adds branch"
         (make_tree (sym "root") [ ("a", Num 1.0); ("b", Num 2.0); ("c", Num 3.0) ])
         grafted;
       let pruned = eval rt (Treesp.Reader.read_one "(prune (graft t a 99) b)") in
       check_equal "prune after graft"
         (make_tree (sym "root") [ ("a", Num 99.0) ])
         pruned)
  ]

let traversal_tests =
  [ test_case "map-branches" `Quick (fun () ->
       let v =
         eval_string
           "(map-branches (node t (x 5)) (lambda (v) (if (number? v) (+ v 1) v)))"
       in
       check_equal "map-branches" (make_tree (sym "t") [ ("x", Num 6.0) ]) v);
    test_case "fold-tree leaf" `Quick (fun () ->
       check_num "fold-tree atom"
         42.0
         (eval_string
            "(fold-tree 42 (lambda (x) x) (lambda (tag bs) 0))"));
    test_case "fold-tree over tree" `Quick (fun () ->
       check_num "fold-tree node-fn zero"
         0.0
         (eval_string
            "(fold-tree (node t (x 10)) (lambda (x) (if (number? x) x 0)) (lambda (tag bs) 0))"));
    test_case "filter-branches" `Quick (fun () ->
       let v =
         eval_string
           "(filter-branches (node t (keep 1) (drop 2)) (lambda (params (lbl) (val)) (equal? lbl 'keep)))"
       in
       check_equal "filter-branches" (make_tree (sym "t") [ ("keep", Num 1.0) ]) v)
  ]

let () =
  run "eval"
    [
      ("arithmetic", arithmetic_tests);
      ("factorial", [ factorial_test ]);
      ("special forms", special_form_tests);
      ("navigation", navigation_tests);
      ("graft/prune", graft_prune_tests);
      ("traversal", traversal_tests);
    ]
