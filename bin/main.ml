open Treesp.Value
open Treesp.Eval
open Treesp.Printer
open Treesp.Runner

let print_result v = if is_void v then () else print_endline (string_of_value v)

let repl () =
  let rt = make_runtime () in
  print_endline "TREESP — trees all the way down.";
  let rec loop () =
    print_string "treesp> ";
    flush stdout;
    match read_line () with
    | exception End_of_file -> print_newline ()
    | line when String.trim line = "" -> loop ()
    | line -> (
        try
          let forms = Treesp.Reader.read_all line in
          List.iter (fun form -> print_result (eval rt form)) forms;
          loop ()
        with
        | Treesp.Reader.Read_error (pos, msg) ->
            Printf.eprintf "error: %s at line %d, column %d\n%!" msg pos.line pos.col;
            loop ()
        | Treesp_error msg ->
            Printf.eprintf "error: %s\n%!" msg;
            loop ()
        | exn ->
            Printf.eprintf "error: %s\n%!" (Printexc.to_string exn);
            loop ())
  in
  loop ()

let list_example_files () =
  let dir = examples_dir () in
  if not (Sys.file_exists dir) then []
  else
    Sys.readdir dir
    |> Array.to_list
    |> List.filter (String.ends_with ~suffix:".treesp")
    |> List.sort compare
    |> List.map (Filename.concat dir)

let run_one path =
  try
    let _, stdout = run_file path in
    let expected_file = expected_path path in
    if not (Sys.file_exists expected_file) then
      Error (Printf.sprintf "%s: missing %s" path expected_file)
    else (
      let expected = In_channel.with_open_text expected_file In_channel.input_all in
      match compare_stdout ~expected ~actual:stdout with
      | Ok () -> Ok ()
      | Error msg -> Error (Printf.sprintf "%s: %s" path msg))
  with
  | Treesp.Reader.Read_error (pos, msg) ->
      Error (Printf.sprintf "%s: read error at %d:%d: %s" path pos.line pos.col msg)
  | Treesp_error msg -> Error (Printf.sprintf "%s: %s" path msg)
  | exn -> Error (Printf.sprintf "%s: %s" path (Printexc.to_string exn))

let run_tests paths =
  let results = List.map (fun path -> (path, run_one path)) paths in
  let failures = List.filter_map (fun (_, r) -> match r with Error msg -> Some msg | Ok () -> None) results in
  let passed = List.length results - List.length failures in
  if failures = [] then (
    Printf.printf "%d/%d examples passed\n%!" passed (List.length results);
    0)
  else (
    List.iter (fun msg -> Printf.eprintf "FAIL %s\n%!" msg) failures;
    Printf.eprintf "%d/%d examples passed\n%!" passed (List.length results);
    1)

let test_cmd args =
  match args with
  | [] -> run_tests (list_example_files ())
  | paths -> run_tests paths

let record_examples () =
  List.iter
    (fun path ->
       let _, stdout = run_file path in
       let out = expected_path path in
       let oc = open_out out in
       output_string oc stdout;
       close_out oc;
       Printf.printf "recorded %s\n%!" out)
    (list_example_files ());
  0

let () =
  match Sys.argv with
  | [| _ |] -> repl ()
  | [| _; "repl" |] -> repl ()
  | [| _; "test" |] -> exit (test_cmd [])
  | [| _; "test"; file |] -> exit (test_cmd [ file ])
  | [| _; "record" |] -> exit (record_examples ())
  | _ ->
      Printf.eprintf "usage: treesp [repl] | treesp test [FILE ...] | treesp record\n%!";
      exit 1
