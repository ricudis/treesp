open Value

type pos = { line : int; col : int }

exception Read_error of pos * string

type stream = {
  s : string;
  mutable i : int;
  mutable line : int;
  mutable col : int;
}

let make_stream s = { s; i = 0; line = 1; col = 1 }

let eof st = st.i >= String.length st.s

let peek st = if eof st then '\000' else st.s.[st.i]

let pos st = { line = st.line; col = st.col }

let advance st =
  if not (eof st) then (
    if st.s.[st.i] = '\n' then (
      st.line <- st.line + 1;
      st.col <- 1)
    else st.col <- st.col + 1;
    st.i <- st.i + 1)

let error st msg = raise (Read_error (pos st, msg))

let rec skip_ws st =
  if eof st then ()
  else
    match peek st with
    | ' ' | '\t' | '\r' | '\n' -> (
        advance st;
        skip_ws st)
    | ';' ->
        advance st;
        while not (eof st) && peek st <> '\n' do
          advance st
        done;
        skip_ws st
    | _ -> ()

let is_digit c = c >= '0' && c <= '9'

let is_initial c =
  (c >= 'a' && c <= 'z')
  || (c >= 'A' && c <= 'Z')
  || String.contains "!$%&*/:<=>?~_^" c

let is_subsequent c = is_initial c || is_digit c

let read_string st =
  advance st;
  let buf = Buffer.create 16 in
  while not (eof st) && peek st <> '"' do
    if peek st = '\\' then (
      advance st;
      if eof st then error st "read: malformed literal";
      Buffer.add_char buf (peek st);
      advance st)
    else (
      Buffer.add_char buf (peek st);
      advance st)
  done;
  if eof st then error st "read: malformed literal";
  advance st;
  Str (Buffer.contents buf)

let read_number st =
  let start = st.i in
  if peek st = '-' then advance st;
  if eof st then error st "read: malformed literal";
  if not (is_digit (peek st)) then error st "read: malformed literal";
  while not (eof st) && is_digit (peek st) do
    advance st
  done;
  if not (eof st) && peek st = '.' then (
    advance st;
    if eof st || not (is_digit (peek st)) then error st "read: malformed literal";
    while not (eof st) && is_digit (peek st) do
      advance st
    done);
  let s = String.sub st.s start (st.i - start) in
  try Num (float_of_string s) with _ -> error st "read: malformed literal"

let read_symbol st =
  let buf = Buffer.create 8 in
  while
    not (eof st)
    && (is_subsequent (peek st)
       || peek st = '.'
       || peek st = '+'
       || peek st = '-')
    && peek st <> '('
    && peek st <> ')'
    && peek st <> '"'
    && peek st <> ';'
    && peek st <> '\''
    && peek st <> '`'
    && peek st <> ','
  do
    Buffer.add_char buf (peek st);
    advance st
  done;
  let name = Buffer.contents buf in
  if name = "#t" then Bool true
  else if name = "#f" then Bool false
  else intern name

let is_explicit_label_form v =
  match v with
  | Tree { tag = Sym _; branches = [ (_, _) ] } -> true
  | _ -> false

let desugar_compound tag branches =
  if branches = [] then make_tree tag []
  else if List.exists is_explicit_label_form branches then (
    if List.exists (fun v -> not (is_explicit_label_form v)) branches then
      raise (Treesp_error "read: mixed branch forms");
    let labels =
      List.map
        (function
          | Tree { tag = Sym l; _ } -> l
          | _ -> raise (Treesp_error "read: mixed branch forms"))
        branches
    in
    if List.length labels <> List.length (List.sort_uniq compare labels) then
      raise (Treesp_error "read: duplicate branch label");
    let pairs =
      List.map
        (function
          | Tree { tag = Sym l; branches = [ (_, v) ] } -> (l, v)
          | _ -> raise (Treesp_error "read: mixed branch forms"))
        branches
    in
    make_tree tag pairs)
  else
    let pairs = List.mapi (fun i v -> (arg_label i, v)) branches in
    make_tree tag pairs

let rec read_form st =
  skip_ws st;
  if eof st then error st "read: unexpected EOF";
  match peek st with
  | '(' -> read_compound st
  | '"' -> read_string st
  | '\'' ->
      advance st;
      let e = read_form st in
      make_tree (intern "quote") [ (arg_label 0, e) ]
  | '`' ->
      advance st;
      let e = read_form st in
      make_tree (intern "quasiquote") [ (arg_label 0, e) ]
  | ',' ->
      advance st;
      if not (eof st) && peek st = '@' then (
        advance st;
        let e = read_form st in
        make_tree (intern "unquote-splicing") [ (arg_label 0, e) ])
      else
        let e = read_form st in
        make_tree (intern "unquote") [ (arg_label 0, e) ]
  | c when c = '-' || is_digit c -> read_number st
  | c when is_initial c -> read_symbol st
  | _ -> error st "read: malformed literal"

and read_compound st =
  advance st;
  skip_ws st;
  if not (eof st) && peek st = ')' then (
    advance st;
    Void)
  else (
    let rec gather acc =
      skip_ws st;
      if eof st then error st "read: unexpected EOF";
      if peek st = ')' then (
        advance st;
        acc)
      else gather (read_form st :: acc)
    in
    let elements = List.rev (gather []) in
    match elements with
    | [] -> Void
    | tag :: branches -> desugar_compound tag branches)

let read_one s =
  let st = make_stream s in
  let v = read_form st in
  skip_ws st;
  if not (eof st) then error st "read: trailing input";
  v

let read_all s =
  let st = make_stream s in
  let rec loop acc =
    skip_ws st;
    if eof st then List.rev acc else loop (read_form st :: acc)
  in
  loop []

let read_error_message = function
  | Read_error ({ line; col }, msg) -> Printf.sprintf "%s at line %d, column %d" msg line col
  | Treesp_error msg -> msg
  | exn -> Printexc.to_string exn
