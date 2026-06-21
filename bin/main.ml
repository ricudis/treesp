open Treesp.Value
open Treesp.Eval
open Treesp.Printer

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

let () =
  match Sys.argv with
  | [| _ |] -> repl ()
  | [| _; "repl" |] -> repl ()
  | _ ->
      Printf.eprintf "usage: treesp [repl]\n%!";
      exit 1
