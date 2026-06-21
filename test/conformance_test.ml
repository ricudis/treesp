open Alcotest
open Treesp.Value
open Treesp.Runner

let example_files () =
  let dir = examples_dir () in
  if not (Sys.file_exists dir) then []
  else
    Sys.readdir dir
    |> Array.to_list
    |> List.filter (String.ends_with ~suffix:".treesp")
    |> List.sort compare
    |> List.map (Filename.concat dir)

let run_example path =
  let _, stdout = run_file path in
  let expected = In_channel.with_open_text (expected_path path) In_channel.input_all in
  match compare_stdout ~expected ~actual:stdout with
  | Ok () -> ()
  | Error msg -> Alcotest.fail msg

let example_tests =
  List.map
    (fun path ->
       let name = Filename.basename path in
       test_case name `Quick (fun () -> run_example path))
    (example_files ())

let apply_error_test =
  test_case "apply not callable" `Quick (fun () ->
      match
        Treesp.Eval.load_string (Treesp.Eval.make_runtime ())
          "(apply 1 (node a (arg0 2)))"
      with
      | exception Treesp_error msg when String.contains msg 'c' -> ()
      | v -> Alcotest.failf "expected apply error, got %s" (Treesp.Printer.string_of_value v))

let () = run "conformance" [ ("§10 examples", example_tests); ("apply", [ apply_error_test ]) ]
