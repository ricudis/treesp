open Value

type runtime = { mutable env : Env.t; mutable input : in_channel }

type macro_spec = Normal of string | Rest of string

let special_forms =
  [
    "quote"; "if"; "lambda"; "define"; "define-macro"; "begin"; "and"; "or"; "node";
    "let"; "cond"; "set!"; "match"; "quasiquote";
  ]

let is_special_form = function Sym s -> List.mem s special_forms | _ -> false

let get_branch branches label =
  if List.mem_assoc label branches then List.assoc label branches
  else raise (Treesp_error ("missing branch: " ^ label))

let get_branch_opt branches label =
  if List.mem_assoc label branches then Some (List.assoc label branches) else None

let if_branches branches =
  match get_branch_opt branches "test", get_branch_opt branches "then", get_branch_opt branches "else" with
  | Some t, Some th, Some el -> (t, th, el)
  | Some t, Some th, None -> (t, th, Void)
  | _ -> (
      let pos = positional_pairs branches in
      match pos with
      | [ (_, t); (_, th) ] -> (t, th, Void)
      | [ (_, t); (_, th); (_, el) ] -> (t, th, el)
      | _ -> raise (Treesp_error "if: wrong arity"))

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

let is_arg_label label =
  String.length label >= 4
  && String.sub label 0 3 = "arg"
  &&
  let suffix = String.sub label 3 (String.length label - 3) in
  suffix <> "" && (try ignore (int_of_string suffix); true with Failure _ -> false)

let unary_branch_pair = function
  | Tree { tag = Sym label; branches = [ (_, v) ] } -> Some (label, v)
  | _ -> None

let branch_labels_tree tree =
  let labels = List.map (fun (l, _) -> sym l) (tree_branches tree) in
  make_tree (sym "labels") (List.mapi (fun i l -> (arg_label i, l)) labels)

let rec path_follow tree = function
  | [] -> tree
  | Sym label :: rest -> (
      match tree with
      | Tree _ ->
          let next = branch_get tree label in
          if is_void next then Void else path_follow next rest
      | _ -> Void)
  | _ -> raise (Treesp_error "path: label must be a symbol")

let label_prim = function
  | "graft" | "prune" | "branch" | "branch?" -> true
  | _ -> false

let rec apply_prim rt name branches =
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
  | "error" -> (
      match args with
      | [ msg ] ->
          Printer.display msg;
          raise (Treesp_error (Printer.string_of_value msg))
      | _ -> raise (Treesp_error "wrong arity"))
  | "branch?" -> (
      match args with
      | [ tree; Sym label ] -> Bool (branch_has tree label)
      | _ -> raise (Treesp_error "wrong arity"))
  | "tag" -> tree_tag (single args)
  | "branch" -> (
      match args with
      | [ tree; Sym label ] -> branch_get tree label
      | _ -> raise (Treesp_error "wrong arity"))
  | "branches" -> make_tree (sym "branches") (tree_branches (single args))
  | "branch-labels" -> branch_labels_tree (single args)
  | "graft" -> (
      match args with
      | [ tree; Sym label; subtree ] -> graft tree label subtree
      | _ -> raise (Treesp_error "wrong arity"))
  | "prune" -> (
      match args with
      | [ tree; Sym label ] -> prune tree label
      | _ -> raise (Treesp_error "wrong arity"))
  | "tag-set" -> (
      match args with
      | [ tree; tag ] -> tag_set tree tag
      | _ -> raise (Treesp_error "wrong arity"))
  | "path" -> (
      match args with
      | tree :: labels -> path_follow tree labels
      | [] -> raise (Treesp_error "path: wrong arity"))
  | "fold-tree" -> (
      match args with
      | [ tree; leaf_fn; node_fn ] -> fold_tree rt tree leaf_fn node_fn
      | _ -> raise (Treesp_error "wrong arity"))
  | "walk-tree" -> (
      match args with
      | [ tree; pre_fn; post_fn ] ->
          walk_tree rt tree pre_fn post_fn;
          Void
      | _ -> raise (Treesp_error "wrong arity"))
  | "map-branches" -> (
      match args with
      | [ tree; fn ] -> map_branches rt fn tree
      | _ -> raise (Treesp_error "wrong arity"))
  | "filter-branches" -> (
      match args with
      | [ tree; pred ] -> filter_branches rt pred tree
      | _ -> raise (Treesp_error "wrong arity"))
  | _ -> raise (Treesp_error ("unknown primitive: " ^ name))

and apply_callable rt callable args =
  let branches = List.mapi (fun i v -> (arg_label i, v)) args in
  match callable with
  | Callable (Prim name) -> apply_prim rt name branches
  | Callable (Closure { env; params; body }) -> apply_closure rt env params body branches
  | Callable (Macro _) -> raise (Treesp_error "macro called without expansion")
  | _ -> raise (Treesp_error "not callable")

and fold_tree rt v leaf_fn node_fn =
  match v with
  | Tree { tag; branches } ->
      let folded =
        List.map (fun (label, child) -> (label, fold_tree rt child leaf_fn node_fn)) branches
      in
      let folded_map = make_tree (sym "branches") folded in
      apply_callable rt node_fn [ tag; folded_map ]
  | _ -> apply_callable rt leaf_fn [ v ]

and map_branches rt fn v =
  match v with
  | Tree { tag; branches } ->
      let mapped =
        List.map
          (fun (label, child) -> (label, apply_callable rt fn [ child ]))
          branches
      in
      make_tree tag mapped
  | _ -> raise (Treesp_error "map-branches: expected tree")

and filter_branches rt pred v =
  match v with
  | Tree { tag; branches } ->
      let kept =
        List.filter
          (fun (label, child) -> truthy (apply_callable rt pred [ sym label; child ]))
          branches
      in
      make_tree tag kept
  | _ -> raise (Treesp_error "filter-branches: expected tree")

and walk_tree rt pre_fn post_fn v =
  ignore (apply_callable rt pre_fn [ v ]);
  (match v with
  | Tree { branches; _ } ->
      List.iter (fun (_, child) -> walk_tree rt pre_fn post_fn child) branches
  | _ -> ());
  ignore (apply_callable rt post_fn [ v ])

and eval_data rt expr =
  match expr with
  | Sym _ | Void | Bool _ | Num _ | Str _ -> expr
  | Tree { tag; branches } ->
      make_tree (eval_data rt tag) (List.map (fun (l, e) -> (l, eval_data rt e)) branches)
  | Callable _ -> eval_expr rt expr

and eval_prim_arg rt name index expr =
  let literal =
    match name with
    | "path" -> index > 0
    | n when label_prim n -> index = 1
    | _ -> false
  in
  if literal then eval_data rt expr else eval_expr rt expr

and eval_prim_args rt name branches =
  let pos = positional_pairs branches in
  List.mapi
    (fun i (_, expr) -> (arg_label i, eval_prim_arg rt name i expr))
    pos
  @ (List.filter (fun (l, _) -> not (is_arg_label l)) branches
    |> List.map (fun (l, e) -> (l, eval_prim_arg rt name (-1) e)))

and eval_node_branch_value rt v =
  match v with
  | Tree _ -> eval_expr rt v
  | _ -> eval_data rt v

and eval_expr rt expr =
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
        let evaluated = eval_prim_args rt name branches in
        apply_prim rt name evaluated
    | Callable (Macro { env; params; body }) ->
        let expanded = apply_macro rt env params body branches in
        eval_expr rt expanded
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
  | "node" -> eval_node rt branches
  | "let" -> eval_let rt branches
  | "cond" -> eval_cond rt branches
  | "set!" -> eval_set rt branches
  | "match" -> eval_match rt branches
  | "quasiquote" -> Quasiquote.expand eval_expr rt (get_branch branches (arg_label 0))
  | "define-macro" -> eval_define_macro rt branches
  | _ -> raise (Treesp_error ("unknown special form: " ^ name))

and eval_node rt branches =
  let tag =
    match get_branch branches "arg0" with
    | (Sym _ | Tree _) as t -> eval_data rt t
    | e -> eval_expr rt e
  in
  let pairs =
    List.fold_left
      (fun acc (label, subtree) ->
        if label = "arg0" then acc
        else if is_arg_label label then (
          match unary_branch_pair subtree with
          | None -> raise (Treesp_error "node: invalid branch form")
          | Some (l, inner) -> (l, eval_node_branch_value rt inner) :: acc)
        else (label, eval_expr rt subtree) :: acc)
      [] branches
    |> List.rev
  in
  let labels = List.map fst pairs in
  if List.length labels <> List.length (List.sort_uniq String.compare labels) then
    raise (Treesp_error "node: duplicate branch label");
  make_tree tag pairs

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

and macro_specs params =
  match params with
  | Tree { tag = Sym "params"; branches } ->
      List.filter_map
        (fun (_, v) ->
          match v with
          | Tree { tag = Sym "rest"; branches = [ (_, name) ] } -> Some (Rest (param_name name))
          | Tree { tag = Sym "_"; _ } -> None
          | Tree { branches = [ (_, Sym "_") ]; _ } -> None
          | Tree { tag = Sym s; branches = [] } -> Some (Normal s)
          | Sym s -> Some (Normal s)
          | _ -> raise (Treesp_error "define-macro: invalid parameter"))
        (positional_pairs branches)
  | Tree { tag = Sym t; branches } ->
      Normal t
      :: List.filter_map
           (fun (_, v) ->
             match v with
             | Tree { tag = Sym "rest"; branches = [ (_, name) ] } -> Some (Rest (param_name name))
             | Tree { tag = Sym "_"; _ } -> None
             | Tree { branches = [ (_, Sym "_") ]; _ } -> None
             | Tree { tag = Sym s; branches = [] } -> Some (Normal s)
             | Sym s -> Some (Normal s)
             | _ -> None)
           (positional_pairs branches)
  | Sym s -> [ Normal s ]
  | _ -> raise (Treesp_error "define-macro: invalid parameter list")

and macro_name_from_params params =
  match params with
  | Tree { tag = Sym "params"; branches } -> (
      match positional_pairs branches with
      | (_, Tree { tag = Sym name; branches = [] }) :: _ -> name
      | (_, Sym name) :: _ -> name
      | _ -> raise (Treesp_error "define-macro: missing macro name"))
  | Tree { tag = Sym name; _ } -> name
  | Sym name -> name
  | _ -> raise (Treesp_error "define-macro: invalid macro name")

and make_begin_tree values =
  make_tree (sym "begin") (List.mapi (fun i v -> (arg_label i, v)) values)

and apply_macro rt env params body call_branches =
  let specs = macro_specs params in
  let args = collect_arg_branches call_branches in
  let rec bind specs args acc =
    match (specs, args) with
    | [], [] -> List.rev acc
    | [], _ :: _ -> raise (Treesp_error "macro: too many arguments")
    | Rest name :: _, rest -> List.rev ((name, make_begin_tree rest) :: acc)
    | Normal name :: specs, arg :: args -> bind specs args ((name, arg) :: acc)
    | Normal _ :: _, [] -> raise (Treesp_error "macro: wrong arity")
  in
  let bindings = bind specs args [] in
  let saved = rt.env in
  rt.env <- Env.extend env bindings;
  let result = eval_expr rt body in
  rt.env <- saved;
  result

and binding_pair = function
  | Tree { tag = Sym name; branches = [ (_, init) ] } -> (name, init)
  | _ -> raise (Treesp_error "let: invalid binding")

and let_bindings tree =
  let rec extract = function
    | Tree { tag = Sym name; branches = [ (_, init) ] } -> [ (name, init) ]
    | Tree { tag; branches = [] } -> [ binding_pair tag ]
    | Tree { tag; branches } ->
        let tag_bindings =
          match tag with
          | Tree { tag = Sym _; branches = [ _ ] } -> extract tag
          | _ -> []
        in
        let explicit_bindings =
          List.filter_map
            (fun (label, init) ->
              if is_arg_label label then None else Some (label, init))
            branches
        in
        let nested =
          List.concat_map
            (fun (label, b) -> if is_arg_label label then extract b else [])
            branches
        in
        tag_bindings @ explicit_bindings @ nested
    | _ -> raise (Treesp_error "let: invalid bindings")
  in
  extract tree

and eval_let rt branches =
  let pos = positional_pairs branches in
  match pos with
  | [ (_, bindings_tree); (_, body) ] ->
      let saved = rt.env in
      let bindings =
        List.map
          (fun (name, init) ->
            let v = eval_expr rt init in
            (name, v))
          (let_bindings bindings_tree)
      in
      rt.env <- Env.extend rt.env bindings;
      let result = eval_expr rt body in
      rt.env <- saved;
      result
  | _ -> raise (Treesp_error "let: invalid form")

and eval_cond_clause rt clause =
  match clause with
  | Tree { tag = Sym "else"; branches } -> (
      match collect_arg_branches branches with
      | [ e ] -> Some e
      | _ -> raise (Treesp_error "cond: invalid else clause"))
  | Tree { tag = test; branches } -> (
      match collect_arg_branches branches with
      | [ e ] when truthy (eval_expr rt test) -> Some e
      | [ _ ] -> None
      | _ -> raise (Treesp_error "cond: invalid clause"))
  | _ -> raise (Treesp_error "cond: invalid clause")

and eval_cond rt branches =
  let clauses = collect_arg_branches branches in
  let rec loop = function
    | [] -> raise (Treesp_error "cond: no matching clause")
    | clause :: rest -> (
        match eval_cond_clause rt clause with
        | Some e -> eval_expr rt e
        | None -> loop rest)
  in
  loop clauses

and eval_set rt branches =
  match positional_pairs branches with
  | [ (_, Sym name); (_, value) ] ->
      Env.set rt.env name (eval_expr rt value);
      Void
  | _ -> raise (Treesp_error "set!: invalid form")

and pattern_explicit branches =
  List.exists (fun (label, _) -> not (is_arg_label label)) branches

and parse_clause clause =
  match clause with
  | Tree { tag = pattern; branches } -> (
      match collect_arg_branches branches with
      | [ result ] -> (pattern, None, result)
      | [ guard; result ] -> (pattern, Some guard, result)
      | _ -> raise (Treesp_error "match: invalid clause"))
  | _ -> raise (Treesp_error "match: invalid clause")

and match_pattern pattern value =
  let rec go pat v =
    match pat with
    | Void | Bool _ | Num _ | Str _ | Sym _ -> if equal pat v then Some [] else None
    | Callable _ -> None
    | Tree { tag = Sym "??"; branches = [ (_, Sym name) ] } -> Some [ (name, v) ]
    | Tree { tag; branches } -> (
        match v with
        | Tree { tag = vtag; branches = vbranches } ->
            if not (equal tag vtag) then None
            else if pattern_explicit branches then match_labeled branches vbranches
            else match_positional branches vbranches
        | _ -> None)
  and match_positional pbranches vbranches =
    let pvals = collect_arg_branches pbranches in
    let vvals = collect_arg_branches vbranches in
    if List.length pvals <> List.length vvals then None
    else merge_matches (List.map2 go pvals vvals)
  and match_labeled pbranches vbranches =
    List.fold_left
      (fun acc (label, psub) ->
        match acc with
        | None -> None
        | Some bindings -> (
            match List.assoc_opt label vbranches with
            | None -> None
            | Some vsub -> (
                match go psub vsub with
                | None -> None
                | Some b2 -> merge_bindings bindings b2)))
      (Some []) pbranches
  and merge_matches results =
    List.fold_left
      (fun acc r ->
        match (acc, r) with
        | None, _ | _, None -> None
        | Some bs1, Some bs2 -> merge_bindings bs1 bs2)
      (Some []) results
  and merge_bindings bs1 bs2 =
    try
      Some (List.fold_left (fun acc (n, v) -> bind_name acc n v) bs1 bs2)
    with Treesp_error _ -> None
  and bind_name bindings name value =
    if List.mem_assoc name bindings then
      let v' = List.assoc name bindings in
      if not (equal v' value) then raise (Treesp_error "match: inconsistent binding")
      else bindings
    else (name, value) :: bindings
  in
  go pattern value

and eval_match rt branches =
  match positional_pairs branches with
  | (_, scrutinee) :: clause_pairs ->
      let value = eval_expr rt scrutinee in
      let rec try_clauses = function
        | [] -> raise (Treesp_error "match: no matching clause")
        | (_, clause) :: rest -> (
            let pattern, guard, result = parse_clause clause in
            match match_pattern pattern value with
            | None -> try_clauses rest
            | Some bindings -> (
                let saved = rt.env in
                rt.env <- Env.extend rt.env bindings;
                let ok =
                  match guard with
                  | None -> true
                  | Some g -> truthy (eval_expr rt g)
                in
                if ok then (
                  let r = eval_expr rt result in
                  rt.env <- saved;
                  r)
                else (
                  rt.env <- saved;
                  try_clauses rest)))
      in
      try_clauses clause_pairs
  | _ -> raise (Treesp_error "match: invalid form")

and eval_define_macro rt branches =
  let pos = positional_pairs branches in
  match pos with
  | [ (_, Sym name); (_, body) ] ->
      let macro = Callable (Macro { env = rt.env; params = Sym name; body }) in
      Env.define rt.env name macro;
      Void
  | [ (_, params_tree); (_, body) ] ->
      let name = macro_name_from_params params_tree in
      let macro = Callable (Macro { env = rt.env; params = params_tree; body }) in
      Env.define rt.env name macro;
      Void
  | _ -> raise (Treesp_error "define-macro: invalid form")

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
    "branch?";
    "tag";
    "branch";
    "branches";
    "branch-labels";
    "graft";
    "prune";
    "tag-set";
    "path";
    "fold-tree";
    "walk-tree";
    "map-branches";
    "filter-branches";
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
    "error";
  ]

let install_primitives env =
  List.iter (fun name -> Env.define env name (Callable (Prim name))) primitive_names

let install_prelude env =
  let when_params = Reader.read_one "(params (when _) (test) (rest body))" in
  let when_body = Reader.read_one "(quasiquote (if (test (unquote test)) (then (begin ,@body)) (else ())))" in
  Env.define env "when" (Callable (Macro { env; params = when_params; body = when_body }));
  let defun_params = Reader.read_one "(params (defun _) (name) (params) (rest body))" in
  let defun_body =
    Reader.read_one
      "(node define (arg0 (unquote name)) (arg1 (lambda (params (unquote params)) (body (begin \
       ,@body)))))"
  in
  Env.define env "defun" (Callable (Macro { env; params = defun_params; body = defun_body }))

let eval rt expr = eval_expr rt expr

let load_string rt source =
  let forms = Reader.read_all source in
  List.fold_left (fun _ form -> eval rt form) Void forms

let make_runtime () =
  let rt = { env = Env.empty (); input = stdin } in
  install_primitives rt.env;
  install_prelude rt.env;
  rt

let load_file rt path =
  let source = In_channel.with_open_text path In_channel.input_all in
  load_string rt source
