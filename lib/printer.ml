open Value

let needs_quote s =
  s = ""
  || (match s.[0] with
     | '(' | ')' | '"' | ';' | '#' | '\'' | '`' | ',' -> true
     | c when c <= ' ' -> true
     | _ -> false)
  || String.exists (fun c -> c = '(' || c = ')' || c = '"' || c <= ' ') s

let escape_string s =
  let buf = Buffer.create (String.length s + 2) in
  Buffer.add_char buf '"';
  String.iter
    (function
      | '"' -> Buffer.add_string buf "\\\""
      | '\\' -> Buffer.add_string buf "\\\\"
      | c -> Buffer.add_char buf c)
    s;
  Buffer.add_char buf '"';
  Buffer.contents buf

let rec format_value v =
  match v with
  | Void -> "()"
  | Bool true -> "#t"
  | Bool false -> "#f"
  | Num n ->
      let s = Printf.sprintf "%.12g" n in
      if String.contains s '.' then s else s ^ ".0"
  | Str s -> escape_string s
  | Sym s -> if needs_quote s then raise (Treesp_error ("cannot print symbol: " ^ s)) else s
  | Callable (Macro _) -> "#<macro>"
  | Callable _ -> "#<callable>"
  | Tree { tag; branches } -> format_tree tag branches

and format_tree tag branches =
  let tag_s = format_value tag in
  if branches = [] then "(" ^ tag_s ^ ")"
  else
    let parts =
      List.mapi
        (fun i (label, v) ->
          if label = arg_label i then format_value v else "(" ^ label ^ " " ^ format_value v ^ ")")
        branches
    in
    "(" ^ tag_s ^ " " ^ String.concat " " parts ^ ")"

let string_of_value v = format_value v

let display v = print_string (format_value v)

let newline () = print_newline ()
