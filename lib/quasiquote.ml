open Value

let is_unquote = function Tree { tag = Sym "unquote"; _ } -> true | _ -> false

let is_unquote_splicing = function
  | Tree { tag = Sym "unquote-splicing"; _ } -> true
  | _ -> false

let unquote_expr = function
  | Tree { branches = [ (_, e) ]; _ } -> e
  | _ -> raise (Treesp_error "quasiquote: malformed unquote")

let merge_branches existing incoming =
  let labels = List.map fst existing @ List.map fst incoming in
  if List.length labels <> List.length (List.sort_uniq String.compare labels) then
    raise (Treesp_error "quasiquote: duplicate branch label on splice");
  existing @ incoming

let rec expand eval rt v =
  match v with
  | Void | Bool _ | Num _ | Str _ | Sym _ -> v
  | Callable _ -> v
  | Tree { tag = Sym "unquote"; _ } as t -> eval rt (unquote_expr t)
  | Tree { tag; branches } -> expand_tree eval rt tag branches

and expand_tree eval rt tag branches =
  let rec loop acc = function
    | [] -> List.rev acc
    | (label, subtree) :: rest -> (
        if is_unquote_splicing subtree then (
          let splice = eval rt (expand eval rt (unquote_expr subtree)) in
          match splice with
          | Tree { branches = splice_branches; _ } ->
              loop (merge_branches acc splice_branches) rest
          | _ -> raise (Treesp_error "quasiquote: splice value must be a tree"))
        else loop ((label, expand eval rt subtree) :: acc) rest)
  in
  make_tree tag (loop [] branches)
