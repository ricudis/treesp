type value =
  | Void
  | Bool of bool
  | Num of float
  | Str of string
  | Sym of string
  | Tree of { tag : value; branches : (string * value) list }

exception Treesp_error of string

val intern : string -> value
val sym : string -> value
val void : value
val is_void : value -> bool
val is_atom : value -> bool
val is_tree : value -> bool
val is_sym : value -> bool
val sym_name : value -> string
val bool_val : value -> bool option
val num_val : value -> float option
val str_val : value -> string option
val tree_tag : value -> value
val tree_branches : value -> (string * value) list
val branch_get : value -> string -> value
val branch_has : value -> string -> bool
val make_tree : value -> (string * value) list -> value
val graft : value -> string -> value -> value
val prune : value -> string -> value
val tag_set : value -> value -> value
val arg_label : int -> string
val collect_arg_branches : (string * value) list -> value list
val positional_pairs : (string * value) list -> (string * value) list
val equal : value -> value -> bool
val truthy : value -> bool
