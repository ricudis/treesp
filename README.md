# TREESP

*TREESP — because lists are for groceries, and code is for branching.*

A LISP dialect whose sole composite data primitive is the **labeled-edge tree**. No `cons`. No `car`. No `cdr`. No lists.

## Getting started

```bash
opam install . --deps-only   # or: dune pkg deps
dune build
dune exec treesp             # REPL
dune test                    # unit + conformance tests
dune exec treesp -- test     # §10 examples
```

## Documentation

- [Introduction](docs/INTRODUCTION.md) — why TREESP exists, and a counter-challenge to adamo
- [Language specification](docs/TREESP.md) — syntax, semantics, primitives, and examples
- [Implementation notes](docs/IMPLEMENTATION.md) — reference interpreter decisions (v0.2)
- [Examples](examples/) — programs from the spec §10 conformance suite
