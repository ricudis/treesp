open Alcotest
open Treesp.Value
open Treesp.Eval

let eval_string s =
  let rt = make_runtime () in
  load_string rt s

let check_num msg expected got =
  match num_val got with
  | Some n when n = expected -> ()
  | Some n -> Alcotest.failf "%s: expected %g, got %g" msg expected n
  | None -> Alcotest.failf "%s: expected number, got %s" msg (Treesp.Printer.string_of_value got)

let expect_error s =
  match eval_string s with
  | exception Treesp_error _ -> ()
  | v ->
      Alcotest.failf "expected error, got %s" (Treesp.Printer.string_of_value v)

let merge_tests =
  [ test_case "merge-branches ok" `Quick (fun () ->
       let v =
         eval_string
           "(merge-branches (node t (a 1) (b 2)) (node t (c 3)))"
       in
       check bool "tree?" true (is_tree v);
       check int "branch count" 3 (List.length (tree_branches v));
       check_num "a" 1.0 (branch_get v "a");
       check_num "b" 2.0 (branch_get v "b");
       check_num "c" 3.0 (branch_get v "c"));
    test_case "merge-branches conflict" `Quick (fun () ->
       expect_error
         "(merge-branches (node t (a 1)) (node t (a 2)))");
    test_case "merge-branches tag mismatch" `Quick (fun () ->
       expect_error
         "(merge-branches (node t (a 1)) (node u (b 2)))")
  ]

let rename_tests =
  [     test_case "rename-branch" `Quick (fun () ->
       let v =
         eval_string "(rename-branch (node r (x 1) (y 2)) x z)"
       in
       check bool "has z" true (branch_has v "z");
       check bool "no x" false (branch_has v "x");
       check_num "z value" 1.0 (branch_get v "z");
       check_num "y value" 2.0 (branch_get v "y"));
    test_case "rename-branch missing" `Quick (fun () ->
       expect_error "(rename-branch (node r (y 2)) x z)")
  ]

let metric_tests =
  [ test_case "depth atom" `Quick (fun () -> check_num "depth atom" 0.0 (eval_string "(depth 42)"));
    test_case "depth shallow tree" `Quick (fun () ->
       check_num "depth shallow" 1.0 (eval_string "(depth (node t (x 1)))"));
    test_case "depth nested" `Quick (fun () ->
       check_num "depth nested"
         3.0
         (eval_string
            "(depth (node a (x (node b (y (node c (z 1)))))))"));
    test_case "size atom" `Quick (fun () -> check_num "size atom" 1.0 (eval_string "(size 42)"));
    test_case "size tree" `Quick (fun () ->
       check_num "size tree" 3.0 (eval_string "(size (node a (x 1) (y 2)))"))
  ]

let clone_tests =
  [ test_case "clone equal not eq" `Quick (fun () ->
       let original = eval_string "(node t (x (node u (y 1))))" in
       let copied = eval_string "(clone (node t (x (node u (y 1)))))" in
       check bool "equal?" true (equal original copied);
       check bool "eq?" false (eq_phys original copied))
  ]

let () =
  run "stdlib"
    [
      ("merge-branches", merge_tests);
      ("rename-branch", rename_tests);
      ("depth and size", metric_tests);
      ("clone", clone_tests);
    ]
