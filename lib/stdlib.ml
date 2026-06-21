open Value

let rec clone = function
  | Tree { tag; branches } ->
      make_tree (clone tag) (List.map (fun (l, v) -> (l, clone v)) branches)
  | v -> v

let merge_branches t1 t2 =
  match (t1, t2) with
  | Tree { tag = tag1; branches = b1 }, Tree { tag = tag2; branches = b2 } ->
      if not (equal tag1 tag2) then raise (Treesp_error "merge-branches: tag mismatch");
      List.iter
        (fun (label, v2) ->
           match List.assoc_opt label b1 with
           | Some v1 when not (equal v1 v2) ->
               raise (Treesp_error ("merge-branches: conflicting label " ^ label))
           | _ -> ())
        b2;
      let extra = List.filter (fun (label, _) -> not (List.mem_assoc label b1)) b2 in
      make_tree tag1 (b1 @ extra)
  | _ -> raise (Treesp_error "merge-branches: expected tree")

let rename_branch tree old_label new_label =
  match tree with
  | Tree { tag; branches } ->
      if List.mem_assoc new_label branches then
        raise (Treesp_error "rename-branch: new label already exists");
      if not (List.mem_assoc old_label branches) then
        raise (Treesp_error "rename-branch: label not found");
      let branches =
        List.map
          (fun (label, v) ->
             if label = old_label then (new_label, clone v) else (label, clone v))
          branches
      in
      make_tree (clone tag) branches
  | _ -> raise (Treesp_error "rename-branch: expected tree")

let rec depth = function
  | Tree { branches; _ } ->
      (match branches with
      | [] -> 1.0
      | bs ->
          1.0
          +. List.fold_left (fun acc (_, child) -> max acc (depth child)) 0.0 bs)
  | _ -> 0.0

let rec size = function
  | Tree { branches; _ } ->
      1.0 +. List.fold_left (fun acc (_, child) -> acc +. size child) 0.0 branches
  | _ -> 1.0
