type callable =
  | Prim of string
  | Closure of { env : value ref; params : value; body : value }
  | Macro of { env : value ref; params : value; body : value }

and value =
  | Void
  | Bool of bool
  | Num of float
  | Str of string
  | Sym of string
  | Tree of { tag : value; branches : (string * value) list }
  | Callable of callable

exception Treesp_error of string

let sym_table = Hashtbl.create 256

let intern name =
  try Hashtbl.find sym_table name with Not_found ->
    let v = Sym name in
    Hashtbl.add sym_table name v;
    v

let sym name = intern name
let void = Void

let is_void = function Void -> true | _ -> false

let is_atom = function
  | Void | Bool _ | Num _ | Str _ | Sym _ -> true
  | Callable _ | Tree _ -> false

let is_tree = function Tree _ -> true | _ -> false
let is_sym = function Sym _ -> true | _ -> false
let is_callable = function Callable _ -> true | _ -> false

let is_macro = function Callable (Macro _) -> true | _ -> false

let sym_name = function Sym s -> s | _ -> raise (Treesp_error "expected symbol")

let bool_val = function Bool b -> Some b | _ -> None
let num_val = function Num n -> Some n | _ -> None
let str_val = function Str s -> Some s | _ -> None
let callable_val = function Callable c -> Some c | _ -> None

let tree_tag = function
  | Tree { tag; _ } -> tag
  | _ -> raise (Treesp_error "expected tree")

let tree_branches = function
  | Tree { branches; _ } -> branches
  | _ -> raise (Treesp_error "expected tree")

let branch_get tree label =
  match tree with
  | Tree { branches; _ } -> (
      try List.assoc label branches with Not_found -> Void)
  | _ -> Void

let branch_has tree label =
  match tree with
  | Tree { branches; _ } -> List.mem_assoc label branches
  | _ -> false

let make_tree tag branches = Tree { tag; branches }

let graft tree label subtree =
  match tree with
  | Tree { tag; branches } ->
      let branches =
        if List.mem_assoc label branches then
          List.map (fun (l, v) -> if l = label then (l, subtree) else (l, v)) branches
        else branches @ [ (label, subtree) ]
      in
      Tree { tag; branches }
  | _ -> raise (Treesp_error "graft: expected tree")

let prune tree label =
  match tree with
  | Tree { tag; branches } ->
      Tree { tag; branches = List.filter (fun (l, _) -> l <> label) branches }
  | _ -> raise (Treesp_error "prune: expected tree")

let tag_set tree new_tag =
  match tree with
  | Tree { branches; _ } -> Tree { tag = new_tag; branches }
  | _ -> raise (Treesp_error "tag-set: expected tree")

let arg_label i = "arg" ^ string_of_int i

let collect_arg_branches branches =
  let rec loop i acc =
    let label = arg_label i in
    if List.mem_assoc label branches then
      loop (i + 1) (List.assoc label branches :: acc)
    else List.rev acc
  in
  loop 0 []

let positional_pairs branches =
  let rec loop i acc =
    let label = arg_label i in
    if List.mem_assoc label branches then
      loop (i + 1) ((label, List.assoc label branches) :: acc)
    else List.rev acc
  in
  loop 0 []

let param_name = function
  | Sym s -> s
  | Tree { tag = Sym s; branches = [] } -> s
  | _ -> raise (Treesp_error "invalid parameter list")

let param_labels params =
  match params with
  | Sym s -> [ s ]
  | Tree { tag = Sym t; branches = [] } -> [ t ]
  | Tree { tag = Sym "params"; branches } -> (
      let pos = positional_pairs branches in
      if pos <> [] then List.map (fun (_, v) -> param_name v) pos
      else List.map fst branches)
  | Tree { tag = Sym t; branches } ->
      let rest =
        positional_pairs branches
        |> List.filter_map (fun (_, v) ->
               match v with Sym s -> Some s | _ -> None)
      in
      t :: rest
  | _ -> raise (Treesp_error "invalid parameter list")

let rec equal a b =
  match (a, b) with
  | Void, Void -> true
  | Bool x, Bool y -> x = y
  | Num x, Num y -> x = y
  | Str x, Str y -> x = y
  | Sym x, Sym y -> x = y
  | Callable c1, Callable c2 -> callable_equal c1 c2
  | Tree { tag = t1; branches = b1 }, Tree { tag = t2; branches = b2 } ->
      equal t1 t2 && branches_equal b1 b2
  | _ -> false

and callable_equal c1 c2 =
  match (c1, c2) with
  | Prim a, Prim b -> a = b
  | Closure { env = _; params = p1; body = b1 }, Closure { env = _; params = p2; body = b2 } ->
      equal p1 p2 && equal b1 b2
  | Macro { env = _; params = p1; body = b1 }, Macro { env = _; params = p2; body = b2 } ->
      equal p1 p2 && equal b1 b2
  | _ -> false

and branches_equal b1 b2 =
  List.length b1 = List.length b2
  && List.for_all2 (fun (l1, v1) (l2, v2) -> l1 = l2 && equal v1 v2) b1 b2

let eq_phys a b =
  match (a, b) with
  | Void, Void -> true
  | Sym x, Sym y -> x = y
  | _ -> a == b

let truthy = function Bool false -> false | _ -> true
