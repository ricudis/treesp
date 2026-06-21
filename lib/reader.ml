open Value

type pos = { line : int; col : int }

exception Read_error of pos * string

type stream = {
  s : string;
  mutable i : int;
  mutable line : int;
  mutable col : int;
}

type raw =
  | Raw_void
  | Raw_atom of value
  | Raw_compound of raw list

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

let is_explicit_raw = function
  | Raw_compound [ Raw_atom (Sym _); _ ] -> true
  | _ -> false

let is_unquote_marker = function
  | Raw_compound [ Raw_atom (Sym "unquote"); _ ] -> true
  | Raw_compound [ Raw_atom (Sym "unquote-splicing"); _ ] -> true
  | _ -> false

let use_explicit_mode branches =
  branches <> []
  && List.for_all is_explicit_raw branches
  && not (List.exists (function Raw_atom _ -> true | _ -> false) branches)
  && not (List.exists is_unquote_marker branches)

let has_bare_atom branches =
  List.exists (function Raw_atom _ -> true | _ -> false) branches

let has_multi_compound branches =
  List.exists (function Raw_compound lst -> List.length lst > 2 | _ -> false) branches

let rec desugar_raw st = function
  | Raw_void -> Void
  | Raw_atom v -> v
  | Raw_compound [] -> Void
  | Raw_compound (tag :: branches) -> desugar_compound st (desugar_raw st tag) branches

and desugar_compound st tag branches =
  if branches = [] then make_tree tag []
  else if use_explicit_mode branches then (
    let labels =
      List.map
        (function
          | Raw_compound [ Raw_atom (Sym l); _ ] -> l
          | _ -> error st "read: mixed branch forms")
        branches
    in
    if List.length labels <> List.length (List.sort_uniq compare labels) then
      error st "read: duplicate branch label";
    let pairs =
      List.map
        (function
          | Raw_compound [ Raw_atom (Sym l); subtree ] -> (l, desugar_raw st subtree)
          | _ -> error st "read: mixed branch forms")
        branches
    in
    make_tree tag pairs)
  else if has_bare_atom branches then
    let pairs = List.mapi (fun i b -> (arg_label i, desugar_raw st b)) branches in
    make_tree tag pairs
  else if List.exists is_explicit_raw branches && has_multi_compound branches then
    error st "read: mixed branch forms"
  else
    let pairs = List.mapi (fun i b -> (arg_label i, desugar_raw st b)) branches in
    make_tree tag pairs

let rec read_raw st =
  skip_ws st;
  if eof st then error st "read: unexpected EOF";
  match peek st with
  | '(' -> read_raw_compound st
  | '"' -> Raw_atom (read_string st)
  | '\'' ->
      advance st;
      let e = read_raw st in
      Raw_compound [ Raw_atom (intern "quote"); e ]
  | '`' ->
      advance st;
      let e = read_raw st in
      Raw_compound [ Raw_atom (intern "quasiquote"); e ]
  | ',' ->
      advance st;
      if not (eof st) && peek st = '@' then (
        advance st;
        let e = read_raw st in
        Raw_compound [ Raw_atom (intern "unquote-splicing"); e ])
      else
        let e = read_raw st in
        Raw_compound [ Raw_atom (intern "unquote"); e ]
  | '#' ->
      advance st;
      (match peek st with
      | 't' ->
          advance st;
          Raw_atom (Bool true)
      | 'f' ->
          advance st;
          Raw_atom (Bool false)
      | _ -> error st "read: malformed literal")
  | '-' ->
      if not (eof st) && is_digit (peek st) then Raw_atom (read_number st)
      else Raw_atom (read_symbol st)
  | c when is_digit c -> Raw_atom (read_number st)
  | '+' -> Raw_atom (read_symbol st)
  | c when is_initial c -> Raw_atom (read_symbol st)
  | _ -> error st "read: malformed literal"

and read_raw_compound st =
  advance st;
  skip_ws st;
  if not (eof st) && peek st = ')' then (
    advance st;
    Raw_void)
  else (
    let rec gather acc =
      skip_ws st;
      if eof st then error st "read: unexpected EOF";
      if peek st = ')' then (
        advance st;
        acc)
      else gather (read_raw st :: acc)
    in
    Raw_compound (List.rev (gather [])))

let read_one s =
  let st = make_stream s in
  let v = desugar_raw st (read_raw st) in
  skip_ws st;
  if not (eof st) then error st "read: trailing input";
  v

let read_all s =
  let st = make_stream s in
  let rec loop acc =
    skip_ws st;
    if eof st then List.rev acc else loop (desugar_raw st (read_raw st) :: acc)
  in
  loop []

let read_channel_line ic =
  try read_one (input_line ic) with End_of_file -> raise End_of_file

let read_error_message = function
  | Read_error ({ line; col }, msg) -> Printf.sprintf "%s at line %d, column %d" msg line col
  | Treesp_error msg -> msg
  | exn -> Printexc.to_string exn
