open Value

type t = value ref

val parent_label : string
val empty : unit -> t
val current : t -> value
val lookup : t -> string -> value
val extend : t -> (string * value) list -> t
val define : t -> string -> value -> unit
val set : t -> string -> value -> unit
