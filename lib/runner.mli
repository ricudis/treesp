open Value

val project_root : unit -> string
val examples_dir : unit -> string
val run_program : ?rt:Eval.runtime -> string -> value list * string
val run_file : string -> value list * string
val expected_path : string -> string
val compare_stdout : expected:string -> actual:string -> (unit, string) result
