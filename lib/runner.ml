open Value

let rec find_project_root dir =
  if Sys.file_exists (Filename.concat dir "examples") then dir
  else if Filename.dirname dir = dir then dir
  else find_project_root (Filename.dirname dir)

let project_root () =
  match Sys.getenv_opt "TREESP_ROOT" with
  | Some root -> root
  | None -> find_project_root (Sys.getcwd ())

let examples_dir () = Filename.concat (project_root ()) "examples"

let run_program ?rt source =
  let rt =
    match rt with
    | Some rt -> rt
    | None -> Eval.make_runtime ()
  in
  let buf = Buffer.create 256 in
  let results =
    Printer.with_output_buffer buf (fun () ->
        let forms = Reader.read_all source in
        List.map
          (fun form ->
            let v = Eval.eval rt form in
            if not (is_void v) then (
              Printer.emit (Printer.string_of_value v);
              Printer.emitln ());
            v)
          forms)
  in
  (results, Buffer.contents buf)

let run_file path =
  let source = In_channel.with_open_text path In_channel.input_all in
  run_program source

let expected_path treesp_path =
  if Filename.check_suffix treesp_path ".treesp" then treesp_path ^ ".expected"
  else treesp_path ^ ".expected"

let trim_lines s =
  let lines = String.split_on_char '\n' s in
  let rec drop_blank = function
    | [] -> []
    | "" :: rest -> drop_blank rest
    | lines -> lines
  in
  let rec drop_trailing = function
    | [] -> []
    | lines when List.hd (List.rev lines) = "" -> drop_trailing (List.rev (List.tl (List.rev lines)))
    | lines -> lines
  in
  drop_trailing (drop_blank lines)

let compare_stdout ~expected ~actual =
  let exp = trim_lines expected in
  let act = trim_lines actual in
  if exp = act then Ok ()
  else
    Error
      (Printf.sprintf "stdout mismatch@.expected:@.%s@.got:@.%s"
         (String.concat "\n" exp)
         (String.concat "\n" act))
