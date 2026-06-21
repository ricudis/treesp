open Value

type runtime = { mutable env : Env.t; mutable input : in_channel }

let special_forms =
  [ "quote"; "if"; "lambda"; "define"; "begin"; "and"; "or" ]

let is_special_form = function Sym s -> List.mem s special_forms | _ -> false

let get_branch branches label =
  if List.mem_assoc label branches then List.assoc label branches
  else raise (Treesp_error ("missing branch: " ^ label))

let get_branch_opt branches label =
  if List.mem_assoc label branches then Some (List.assoc label branches) else None

let if_branches branches =
  match get_branch_opt branches "test", get_branch_opt branches "then", get_branch_opt branches "else" with
  | Some t, Some th, Some el -> (t, th, el)
  | _ -> (
      let pos = positional_pairs branches in
      if List.length pos < 3 then raise (Treesp_error "if: wrong arity");
      let _, t = List.nth pos 0 in
      let _, th = List.nth pos 1 in
      let _, el = List.nth pos 2 in
      (t, th, el))

let lambda_parts branches =
  match get_branch_opt branches "params", get_branch_opt branches "body" with
  | Some p, Some b -> (p, b)
  | _ -> (
      let pos = positional_pairs branches in
      if List.length pos < 2 then raise (Treesp_error "lambda: wrong arity");
      let _, p = List.nth pos 0 in
      let _, b = List.nth pos 1 in
      (p, b))

let num_of v =
  match num_val v with Some n -> n | None -> raise (Treesp_error "expected number")

let single = function
  | [ v ] -> v
  | _ -> raise (Treesp_error "wrong arity")

let apply_prim name branches =
  let args = collect_arg_branches branches in
  match name with
  | "atom?" -> Bool (is_atom (single args))
  | "tree?" -> Bool (is_tree (single args))
  | "void?" -> Bool (is_void (single args))
  | "number?" -> (
      match single args with Num _ -> Bool true | _ -> Bool false)
  | "symbol?" -> Bool (is_sym (single args))
  | "string?" -> (
      match single args with Str _ -> Bool true | _ -> Bool false)
  | "boolean?" -> (
      match single args with Bool _ -> Bool true | _ -> Bool false)
  | "eq?" -> (
      match args with
      | [ a; b ] -> Bool (eq_phys a b)
      | _ -> raise (Treesp_error "wrong arity"))
  | "equal?" -> (
      match args with
      | [ a; b ] -> Bool (equal a b)
      | _ -> raise (Treesp_error "wrong arity"))
  | "+" -> Num (List.fold_left (fun acc v -> acc +. num_of v) 0.0 args)
  | "*" -> Num (List.fold_left (fun acc v -> acc *. num_of v) 1.0 args)
  | "-" -> (
      match args with
      | [] -> raise (Treesp_error "-: wrong arity")
      | [ x ] -> Num (-. num_of x)
      | x :: rest -> Num (List.fold_left (fun acc v -> acc -. num_of v) (num_of x) rest))
  | "/" -> (
      match args with
      | [ x; y ] -> Num (num_of x /. num_of y)
      | _ -> raise (Treesp_error "/: wrong arity"))
  | "=" -> (
      match args with
      | [ a; b ] -> Bool (num_of a = num_of b)
      | _ -> raise (Treesp_error "wrong arity"))
  | "<" -> (
      match args with
      | [ a; b ] -> Bool (num_of a < num_of b)
      | _ -> raise (Treesp_error "wrong arity"))
  | ">" -> (
      match args with
      | [ a; b ] -> Bool (num_of a > num_of b)
      | _ -> raise (Treesp_error "wrong arity"))
  | "<=" -> (
      match args with
      | [ a; b ] -> Bool (num_of a <= num_of b)
      | _ -> raise (Treesp_error "wrong arity"))
  | ">=" -> (
      match args with
      | [ a; b ] -> Bool (num_of a >= num_of b)
      | _ -> raise (Treesp_error "wrong arity"))
  | "not" -> Bool (not (truthy (single args)))
  | "display" ->
      Printer.display (single args);
      Void
  | "newline" ->
      Printer.newline ();
      Void
  | _ -> raise (Treesp_error ("unknown primitive: " ^ name))

let rec eval_expr rt expr =
  match expr with
  | Void | Bool _ | Num _ | Str _ -> expr
  | Sym s -> Env.lookup rt.env s
  | Callable _ -> expr
  | Tree { tag; branches } -> eval_tree rt tag branches

and eval_tree rt tag branches =
  if is_special_form tag then eval_special rt (sym_name tag) branches
  else
    let op = eval_expr rt tag in
    match op with
    | Callable (Prim name) ->
        let evaluated = List.map (fun (l, e) -> (l, eval_expr rt e)) branches in
        apply_prim name evaluated
    | Callable (Closure { env; params; body }) ->
        let evaluated = List.map (fun (l, e) -> (l, eval_expr rt e)) branches in
        apply_closure rt env params body evaluated
    | _ -> raise (Treesp_error "not callable")

and eval_special rt name branches =
  match name with
  | "quote" -> get_branch branches (arg_label 0)
  | "if" ->
      let test, then_, else_ = if_branches branches in
      if truthy (eval_expr rt test) then eval_expr rt then_ else eval_expr rt else_
  | "lambda" ->
      let params, body = lambda_parts branches in
      Callable (Closure { env = rt.env; params; body })
  | "define" -> eval_define rt branches
  | "begin" -> eval_begin rt branches
  | "and" -> eval_and rt branches
  | "or" -> eval_or rt branches
  | _ -> raise (Treesp_error ("unknown special form: " ^ name))

and eval_define rt branches =
  let pos = positional_pairs branches in
  match pos with
  | [ (_, Sym name); (_, value) ] ->
      let v = eval_expr rt value in
      Env.define rt.env name v;
      Void
  | [ (_, fn_tree); (_, body) ] -> (
      match fn_tree with
      | Tree { tag = Sym name; _ } as param_tree ->
          let closure = Callable (Closure { env = rt.env; params = param_tree; body }) in
          Env.define rt.env name closure;
          Void
      | _ -> raise (Treesp_error "define: invalid function form"))
  | _ -> raise (Treesp_error "define: invalid form")

and eval_begin rt branches =
  let exprs = collect_arg_branches branches in
  match exprs with
  | [] -> Void
  | es -> List.fold_left (fun _ e -> eval_expr rt e) Void es

and eval_and rt branches =
  let exprs = collect_arg_branches branches in
  let rec loop = function
    | [] -> Bool true
    | [ e ] -> eval_expr rt e
    | e :: es ->
        let v = eval_expr rt e in
        if truthy v then loop es else v
  in
  loop exprs

and eval_or rt branches =
  let exprs = collect_arg_branches branches in
  let rec loop = function
    | [] -> Bool false
    | [ e ] -> eval_expr rt e
    | e :: es ->
        let v = eval_expr rt e in
        if truthy v then v else loop es
  in
  loop exprs

and apply_closure rt env params body branches =
  let param_names = param_labels params in
  let arg_values = collect_arg_branches branches in
  if List.length arg_values <> List.length param_names then
    raise (Treesp_error "wrong arity");
  if List.length branches > List.length param_names then
    List.iter
      (fun (label, _) ->
        if label <> Env.parent_label && not (List.mem label param_names) then
          raise (Treesp_error ("unexpected argument: " ^ label)))
      branches;
  let bindings =
    List.mapi (fun i name -> (name, List.nth arg_values i)) param_names
  in
  let saved = rt.env in
  rt.env <- Env.extend env bindings;
  let result = eval_expr rt body in
  rt.env <- saved;
  result

let primitive_names =
  [
    "atom?";
    "tree?";
    "void?";
    "number?";
    "symbol?";
    "string?";
    "boolean?";
    "eq?";
    "equal?";
    "+";
    "-";
    "*";
    "/";
    "=";
    "<";
    ">";
    "<=";
    ">=";
    "not";
    "display";
    "newline";
  ]

let install_primitives env =
  List.iter (fun name -> Env.define env name (Callable (Prim name))) primitive_names

let make_runtime () =
  let rt = { env = Env.empty (); input = stdin } in
  install_primitives rt.env;
  rt

let eval rt expr = eval_expr rt expr

let load_string rt source =
  let forms = Reader.read_all source in
  List.fold_left (fun _ form -> eval rt form) Void forms

let load_file rt path =
  let source = In_channel.with_open_text path In_channel.input_all in
  load_string rt source
