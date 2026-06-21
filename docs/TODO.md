# TREESP TODO — The Future Is Ours

**Lists are for groceries. This document is for conquest.**

We shipped v0.1 (the spec), v0.2 (the interpreter), and v0.3 (the stdlib). The reference implementation runs. The conformance suite passes. The REPL prompts. Trees evaluate. Adamo has been notified.

That was the appetizer. We are still hungry.

What follows is not a backlog — backlogs are lists wearing project-management cosplay. What follows is a **canopy**: branches of ambition, labeled and graftable, waiting for someone ruthless enough to climb them. Some branches are science. Some are art. Some are a credible threat to JSON.

---

## What we already did (so we can be insufferable about it)

| Version | We built | Tag |
|---------|----------|-----|
| v0.1 | A language spec that refuses to apologize for hating `cdr` | — |
| v0.2 | A reference interpreter, REPL, macros, quasiquote, conformance suite | `v0.2` |
| v0.3 | `merge-branches`, `rename-branch`, `depth`, `size`, `clone` | `v0.3` |

See [implementation plans](implementation-plans/README.md) for the war diaries.

The **editor** counter-challenge in [INTRODUCTION.md](INTRODUCTION.md) is **adamo's homework** — not on this roadmap. We will judge him from the sidelines, mercilessly.

---

## Version horizon (where we're going)

| Version | Codename | Essence |
|---------|----------|---------|
| **v1.0** | *Canopy* | Language polished; modules; multi-line read; eval locations; full §10 examples; opam package strangers can install |
| **v1.5** | *Understory* | Self-hosted prelude; `treesp fmt` / `lint` / LSP; property tests and reader fuzz |
| **v2.0** | *Heartwood* | Tree IR, bytecode VM, first compiled programs faster than guilt |
| **v2.5** | *Mycelium* | WASM, embeddable C ABI, Python/Ruby/Node grafts |
| **v3.0** | *Old Growth* | Gradual types optional; match exhaustiveness; numeric tower complete |
| **v4.0** | *Redwood* | Separate production runtime (Rust); OCaml stays the reference conscience |
| **v∞** | *World Tree* | Config, data, build graphs, and CLI flags speak TREESP; lists remain in the grocery aisle where they belong |

---

## Phase 9 — Language, sharpened

The spec left doors open on purpose. Walk through them with intent.

### Reader & errors

- **Multi-line `read`** — one datum may span lines; the scanner should not pretend the universe ends at `\n`.
- **Incremental reader** — parse from a growing buffer; REPL and network protocols deserve partial trees without shame.
- **Reader extensions** — `#| … |#` block comments, `#;` splicing discard, `#n=` circularity for the brave.
- **Eval-time source locations** — reader errors have line/column; runtime errors should point at the tree that betrayed you.
- **Stack traces as trees** — `(node trace (frames …) (cause …))`, not a string salad.
- **Error values as trees** — host exceptions were v0.2 pragmatism; `(raise (node type (message …) (path …)))` is v1.0 aesthetics.
- **`warn` primitive** — non-fatal `(node warn (code …) (hint …))`; compilers love warnings; so will we.

### Semantics

- **Rest parameters** — `(rest args)` in lambdas, not just macros; variadic glory without `arg999`.
- **Keyword / labeled call syntax** — `(f (key val) …)` at eval time, not just reader desugar; named branches all the way down.
- **Hygiene options** — non-hygienic macros won Phase 5; offer hygienic mode for people who sleep at night.
- **Dynamic scope mode** — spec says dynamic; we chose lexical. Support both; let users pick their regret.
- **Tail-call optimization** — trees should recurse to infinity without blowing the stack; civilization depends on it.
- **Proper tail contexts** — document which special forms preserve tail position; `cond`, `match`, `begin` must not lie.
- **Continuations** — `(call/cc …)` as a tree with a `resume` branch. Controversial. Correct.
- **Parameters objects** — environments as first-class `(node env …)` values you can `graft` and pass. Dynamic scope finally earns its keep.

### Standard library — §9 becomes a forest

v0.3 shipped five helpers. The conceptual modules in [TREESP.md §9](TREESP.md) deserve flesh, teeth, and a theme song:

| Module | Ambition |
|--------|----------|
| `treesp.tree` | `diff-branches`, `subtree?`, `ancestor?`, `lowest-common-ancestor`, `subtree-at`, `replace-subtree` |
| `treesp.walk` | `reduce-tree`, `for-each-branch`, `zip-branches`, parallel walks (why not) |
| `treesp.match` | `match?` predicate, pattern compiler, exhaustiveness checker, `match-lambda` |
| `treesp.seq` | Linked trees done *right* — `snoc`, `reverse-tree`, `append-trees`, O(n) honesty |
| `treesp.io` | `write`, `read-all`, port trees, structured logging as labeled branches |
| `treesp.hash` | Persistent maps as trees of buckets — still no alists, we have standards |
| `treesp.time` | `(node instant (seconds …) (nanos …))` — time is a labeled tree, fight us |
| `treesp.test` | `assert`, `check-equal?`, `example` blocks for the conformance suite on steroids |

**Full §10.4 `tree-sum`** — recursive, obscene, beautiful. The simplified example was a truce; write the real thing and add it to `examples/` with golden output.

**Prelude macros worth shipping** — `defmacro`, `let*`, `letrec`, `case`, `do`, all as trees, all expandable, all judged.

### Modules

No `import` in v0.1 was wisdom. No `import` forever is cowardice.

- `(module name (export …) (import …) (body …))`
- Separate compilation units as `.treesp` files on disk
- `(include "path")` for textual graft at read time — use sparingly, document the shame
- Prelude stays small; stdlib loads on demand
- **Package manifest** — `(node package (name treesp-foo) (deps …) (exports …))`; dependencies are a tree, not a flat list (okay, it's a tree of lists of trees; we contain multitudes)

### Numeric tower

IEEE doubles were fine for bootstrapping. The tower rises:

- **Exact integers** — bignum branches on `(node integer (sign …) (digits …))` or host-backed; either way `(+ 1 2)` is `3`, not `3.0`, when exactness demands it.
- **Rationals** — `(node rational (num …) (den …))` for people who miss Scheme and correctness.
- **Complex** — `(node complex (real …) (imag …))` because some algorithms branch in two dimensions.
- **Exact / inexact flags** — on the value or on branches; never silent float contagion again.
- **Mixed-type arithmetic** — promote with explicit rules; document the promotions in [IMPLEMENTATION.md](IMPLEMENTATION.md), not in tribal knowledge.

### Spec v1.0 ratification

- Close [TREESP.md §12](TREESP.md) open questions we have answered in practice.
- Normative lexical scoping; dynamic as optional chapter.
- Formal operational semantics appendix — evaluation rules as inference trees (meta, but honest).
- **Conformance levels** — Level 1 (reader + eval), Level 2 (+ macros), Level 3 (+ full prelude); certify implementations like civilized people.

---

## Phase 10 — Compiler & runtime (yes, really)

Interpretation was the proof. Compilation is the point. The CPU wants labeled branches; we will oblige.

### Tree IR

- **Explicit labels preserved** through every lowering pass — `argN` is not an implementation detail, it's a design commitment.
- **IR as trees** — `(node ir-app (op …) (args (branch …) …))`; optimizations are `walk-tree` over IR.
- **Constant folding** — `(+ 1 2)` dies at compile time so runtime never sees your embarrassment.
- **Inline `Prim`** — small primitives open-coded; `branch?` should not call itself recursively forever.
- **Dead branch elimination** — prune unreachable labels; the compiler uses our own `prune` metaphor and we will not apologize.

### Bytecode VM

- Tagged value representation matching [value.ml](../lib/value.ml) semantics.
- Branch tables for call dispatch — `apply` becomes one instruction and a branch map.
- **`walk-tree` opcode** — pre/post hooks in the VM; traversal without interpreter overhead.
- **Calling convention** — arguments passed as a tree, not a register dump pretending to be modern.

### AOT & JIT

- **OCaml reference** stays interpretable forever — the conscience of the project.
- **Rust (or C) production runtime** — for people who need speed and fear the garbage collector less than they fear `cdr`.
- **JIT tier** — interpret first, compile hot `(node …)` subtrees; PGO guided by `walk-tree` profiles.
- **WASM** — run TREESP in the browser so JavaScript can feel inadequate in its own home.
- **Native interop** — `(foreign "sin" (float -> float))`; graft C functions onto the tree of callables.

### Self-hosting

- Rewrite `quasiquote` expansion in TREESP. Then `match`. Then the reader desugar. Then look in the mirror and keep going.
- **Bootstrap path** — OCaml generates stage-0; stage-1 is TREESP; stage-2 is TREESP compiling TREESP; stage-3 is smugness.

Deferred in v0.1. Deferred is not denied. Denied is for lists.

---

## Phase 11 — Tooling empire

Languages without tooling are hobbies. We are not hobbies. We are a lifestyle.

| Tool | Purpose |
|------|---------|
| **`treesp fmt`** | Canonical desugared output; fight about `argN` vs explicit labels in chat, not in diffs |
| **`treesp lint`** | Mixed branch forms at *write* time; unused branches; shadowed labels in `let` |
| **`treesp doc`** | Extract `(doc "…")` branches from definitions; generate API trees → HTML |
| **`treesp repl`** | Syntax highlighting in the REPL; multi-line paste; `:load`, `:trace`, `:time` |
| **`treesp profile`** | Hot paths by tree tag; flame graphs where the flames are branch labels |
| **`treesp lsp`** | Jump-to-branch, rename-branch across files, eval hover, incremental parse |
| **`treesp debug`** | Step through tree paths; inspect environment as `(node env …)`; breakpoints on `(match …)` clauses |
| **`treesp test`** | Already exists; add property tests, snapshot tests, reader fuzz for 24h runs |
| **`treesp pkg`** | Resolve deps from package trees; lockfile as an immutable graft |
| **CI / opam publish** | Green builds on every push; `opam install treesp` for strangers |
| **Grammar export** | TextMate, tree-sitter, Lezer — generated from the *actual* reader, not hand-waved |

### Developer experience

- **`dune` rules** — `(treesp_library)` and `(treesp_test)` stanzas; first-class in the OCaml ecosystem we inhabit.
- **Watch mode** — re-run tests on save; the feedback loop should be faster than your doubt.
- **Pretty errors** — colorized `read_error_message`; underline the branch that broke the reader's heart.
- **Tree visualizer** — TUI or web: collapse branches, show `path`, export to Graphviz DOT because graphs are trees if you squint.

---

## Phase 12 — Ecosystem & world domination

We don't want market share. We want **terrain**.

### Embeddings & hosts

- **C ABI** — `treesp_eval`, `treesp_read`, `treesp_print`; stable enough to embed in games, databases, firmware.
- **Python / Ruby / Node / Lua** — bindings; every host gets a tree grafted onto its soul.
- **PostgreSQL extension** — store documents as trees; query with `path` and `match`; JSON column types weep.
- **Redis module** — `(graft key branch value)` as a native command; finally, truth in advertising.

### Replace bad formats

- **Configuration** — `.treesp` config files; `merge-branches` for layered overrides; YAML retirement party.
- **Build systems** — dependency graph is a tree you `walk-tree` over; targets are tags, edges are branches.
- **Data interchange** — TREESP as JSON-but-honest; schemas as `match` patterns; validate on read.
- **Logging** — structured logs as trees; grep by `(path log level)` not regex necromancy.
- **CLI flags** — `(node argv (verbose #t) (file "main.treesp"))`; getopt is a linked list and we know it.

### Education & culture

- **"Structure and Interpretation of Trees"** — SICP retold; every figure a tree; zero `cons` cells martyred.
- **Interactive tutorial** — built into the REPL; `(tutorial (step 1) (goal "factorial"))`.
- **Zine** — "Lists Are Political"; sold at conferences; proceeds fund the numeric tower.
- **Conference talk** — "We Deleted `cdr` and Nothing Bad Happened (We Lied Once About Nothing Bad)."
- **Podcast** — *Branch Factor*; interviews with people who still use `car` and why they're wrong.

### Community infrastructure

- **Package registry** — `treesp.pkg`; packages are signed trees; no left-pad if the graph is acyclic.
- **RFC process** — proposals as `.treesp` files; comments as grafted `(review …)` branches.
- **Logo merch** — shirt: `(node treesp (tagline "no cdr") (branch shame none))`.

---

## Phase 13 — Types, proofs, and the cathedral

Optional. Heavy. Worth it.

- **Gradual types** — `(node : (lambda (n : Num) : Num) …)` or surface annotations on branches; infer what you can, shame what you can't.
- **Tree-shaped row polymorphism** — records are trees; absence of a branch is the type error, not an afterthought.
- **Refinement types** — `(node Num (where (> n 0)))` for the righteous.
- **Exhaustive `match`** — compile-time check that patterns cover all branches; `error` becomes unreachable in well-typed programs.
- **Effect system** — pure vs `(io …)` vs `(mutable …)` on callable tags; no silent side effects through `display`.
- **Formal semantics in Coq/Lean** — machine-checked progress and preservation; the spec stops being vibes and becomes law.
- **Extract verified evaluator** — from proof assistant to OCaml; reference implementation with a certificate.

Static types in v1 were deferred. The cathedral takes time. Lists built cathedrals too, but they used flying buttresses made of `cdr`.

---

## Phase 14 — Distributed trees & merge at scale

`merge-branches` was the prototype. The world is concurrent.

- **CRDT trees** — conflict-free replicated labeled trees; concurrent `graft` without losing branches.
- **Operational transform on branches** — collaborative editing of tree documents (adamo may borrow this; we won't stop him).
- **Event sourcing** — history as a tree of `(node event (op graft) (label x) (value …))`; replay to any point.
- **P2P sync** — replicate `(node doc …)` across nodes; anti-entropy via `walk-tree` and branch hashes.
- **Blockchain joke that got out of hand** — merkle trees were always the good part; the rest is optional.

---

## Phase 15 — Research programs (unhinged but serious)

Long-horizon bets. Most will fail. One will eat a industry.

| Program | Thesis |
|---------|--------|
| **Tree query language** | SQL but `path` and `match`; indexes on branch labels; `SELECT tag FROM forest WHERE (path n left right) = Num` |
| **Tree-native OS** | Processes as trees; capabilities as branches; no flat PID table; scheduler `walk-tree`s the ready queue |
| **Hardware branch unit** | FPGA prototype: tagged memory, branch-indirect jump, `graft` in silicon (grant proposal writes itself) |
| **LLM native format** | Models emit TREESP, not JSON; schemas are patterns; fewer hallucinated commas |
| **Verifiable computation** | compile to IR + proof; `(node result (value …) (proof …))` |
| **Biological metaphor** | phylogenetic trees as literal data; `lowest-common-ancestor` for real; gag paper at PLDI |

---

## Phase 16 — The propaganda wing

Ideas need evangelists. We have parentheses and confidence.

- **"Down with cons" manifesto** — pinned on the repo; translated to every language that still has a `List` module.
- **Comparison benchmarks** — TREESP vs JSON parse vs XML vs YAML; win on honesty, tie on speed, win on aesthetics.
- **Migration guides** — from JSON (lossy), from S-expressions (upgrade), from Haskell ADTs (you're almost there).
- **Adversarial interop** — read JSON, represent as trees, never go back; write JSON only at border crossings with explicit shame flags.
- **Annual State of the Tree** — blog post; branch count metrics; `depth` of the codebase; `size` of the community.

---

## Open questions we will answer with violence

From [TREESP.md §12](TREESP.md):

| Topic | Our eventual answer (preview) |
|-------|-------------------------------|
| Scoping | Both; default lexical; dynamic for people who want 1975 back |
| Macro hygiene | Optional tiers; document the blood |
| Rest parameters | Yes, everywhere |
| Module system | Yes, tree-shaped |
| Error values | Trees, obviously |
| Compilation | Tree IR → bytecode → native → WASM |
| Reference implementation | OCaml reference; Rust production; others welcome |
| Types | Gradual, optional, branch-aware |
| Concurrency | Shared-nothing + CRDT merge; threads are not lists |
| Self-hosting | Yes, on a long enough timeline |

---

## Explicit non-goals (we said what we said)

- **`cons`, `car`, `cdr`** — never. not negotiable. write your own language.
- **Lists as the universal substrate** — see above. forever.
- **The editor** — adamo's counter-challenge; see [INTRODUCTION.md](INTRODUCTION.md). We will critique it harshly when it ships.
- **Apologizing for parentheses** — never.
- **Becoming JSON with extra steps** — if you want untyped text soup, JSON is free.
- **Corporate blockchain integration** — unless it's funny.

---

## Immediate next actions (if you must start Monday)

1. Tag `v0.1` on the spec-only commit — archaeology matters.
2. Push tags and cut GitHub releases for `v0.2` / `v0.3`.
3. Write the **full recursive `tree-sum`** example and add it to `examples/`.
4. Multi-line **`read`** and **eval-time source locations** — first language polish targets.
5. Sketch **`treesp fmt`** — one canonical printer rulebook; stop arguing in PR comments.
6. Link [TODO.md](TODO.md) from [README.md](../README.md) — the bold must be discoverable.

---

## The line

We built a LISP that looked at forty years of list propaganda and said **no**.

v0.3 was the reference interpreter. v1.0 is the sharpened language and tooling. v2.0 is the compiler. v3.0 is the type system knocking. v4.0 is the production runtime. v∞ is the world where configuration, logs, build graphs, and CLI flags are trees you can `path` into — and if you want an editor, **ask adamo**.

We are not finished. We are not even close. We are **branching**.

**The future is not a list. The future is a forest. The future is ours.**

*— TREESP, trees all the way down*
