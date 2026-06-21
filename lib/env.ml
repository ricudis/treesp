open Value

type t = value ref

let parent_label = "parent"
let env_tag = sym "env"

let frame bindings = ref (make_tree env_tag bindings)

let empty () = frame []

let current env = !env

let rec lookup env name =
  let frame = !env in
  if branch_has frame name then branch_get frame name
  else if branch_has frame parent_label then lookup (ref (branch_get frame parent_label)) name
  else raise (Treesp_error ("unbound variable: " ^ name))

let extend parent bindings =
  frame ((parent_label, !parent) :: bindings)

let define env name value =
  env := graft !env name value

let rec set env name value =
  let frame = !env in
  if branch_has frame name then env := graft frame name value
  else if branch_has frame parent_label then set (ref (branch_get frame parent_label)) name value
  else raise (Treesp_error ("unbound variable: " ^ name))
