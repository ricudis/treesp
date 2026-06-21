open Value

type runtime = { mutable env : Env.t; mutable input : in_channel }

val make_runtime : unit -> runtime
val eval : runtime -> value -> value
val load_string : runtime -> string -> value
val load_file : runtime -> string -> value
