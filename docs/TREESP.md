# TREESP Language Specification

**Version:** 0.1 (draft)  
**Status:** Specification only — no reference implementation in this milestone.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Values](#2-values)
3. [Syntax](#3-syntax)
4. [Reader](#4-reader)
5. [Evaluation](#5-evaluation)
6. [Special Forms](#6-special-forms)
7. [Primitives](#7-primitives)
8. [Macros](#8-macros)
9. [Standard Library](#9-standard-library)
10. [Examples](#10-examples)
11. [Rejected LISP Features](#11-rejected-lisp-features)
12. [Open Questions](#12-open-questions)

---

## 1. Introduction

**TREESP** (pronounced *trees-p*) is a homoiconic programming language in the LISP family. Programs are written as S-expressions and evaluated by an `eval`/`apply` interpreter, as in Scheme.

The defining difference: TREESP has **no cons cells**. The sole composite data primitive is the **labeled-edge tree**. There is no `cons`, no `car`, no `cdr`, no dotted pairs, and no proper or improper lists as distinct types. If you do not like lists, you are in the right place.

### 1.1 Goals

- Preserve the pleasant parts of LISP: S-expression syntax, homoiconicity, `quote`, `lambda`, macros, and a small core.
- Make **trees** the universal composite structure — for data, code, environments, and macro expansion.
- Use **labeled branches** so every child of a node has a name, not a position in a chain.
- Keep familiar call syntax `(f a b)` via reader sugar that desugars to labeled branches.

### 1.2 Non-goals (this version)

- Static type system
- Modules or namespaces beyond conceptual library groupings
- Compiler or bytecode VM
- Reference interpreter (future work)

### 1.3 Terminology

| Term | Meaning |
|------|---------|
| **Atom** | A value that is not a tree |
| **Tree** | A tagged node with zero or more labeled branches |
| **Tag** | The symbol identifying a tree node's role or operator |
| **Branch** | A labeled edge from a tree node to a subtree or atom |
| **Void** | The absence value; canonical written form `()` |
| **Branch map** | The set of label → value associations on a tree node |

### 1.4 Relation to LISP

In LISP, `(f a b)` is read as a **list** of three elements. In TREESP, `(f a b)` is read as a **tree** tagged `f` with two branches labeled `arg0` and `arg1`. The surface syntax is the same; the underlying representation and primitives are different.

---

## 2. Values

Every TREESP value is exactly one of:

1. An **atom**
2. A **tree**
3. **Void**

There is no fourth kind of value.

### 2.1 Atoms

| Type | Literal examples | Notes |
|------|------------------|-------|
| Number | `42`, `-3.14`, `0` | IEEE 754 double-precision at the specification level |
| Symbol | `foo`, `+`, `arg0`, `my-var` | Interned identifiers; case-sensitive |
| String | `"hello"`, `""` | Opaque UTF-8 text; not a sequence type |
| Boolean | `#t`, `#f` | Distinct from symbols |
| Void | `()` | See §2.3 |

**Leaves are atoms.** There is no required wrapper (such as `(leaf 42)`) around atomic values. An atom standing alone is a leaf in any tree context.

### 2.2 Trees

A tree is a record:

```
Tree := {
  tag:    Symbol,
  branches: { labelᵢ: Value }   ; finite map, labelᵢ are symbols
}
```

**Tag.** The `tag` is a symbol naming the node's identity — an operator, a data constructor tag, or a user-defined label.

**Branches.** Each branch is a symbol (the label) mapped to a value (atom, tree, or void). Branch labels are unique within a node; duplicate labels are forbidden (see §4.3).

**Order.** Branch order is not semantically significant unless a primitive explicitly documents iteration in insertion order. Implementations should preserve insertion order for deterministic I/O and debugging, but programs must not rely on order for correctness except where stated.

**Tree with no branches.** A tree may have a tag and zero branches: `(tag)` is valid. This is not void; it is an empty branching node.

#### 2.2.1 Explicit tree construction

The primitive `node` constructs a tree explicitly (see §7.3):

```treesp
(node expr
  (op +)
  (left 2)
  (right 3))
```

This yields a tree with `tag = expr` and branches `{ op → +, left → 2, right → 3 }`.

#### 2.2.2 Implicit trees from compound forms

Any compound S-expression is a tree. The first element is the tag; remaining elements are branches (see §3.2 and §4).

### 2.3 Void

**Void** is the absence value. It is written `()` and is distinct from:

- An empty tree node (which has a tag symbol)
- An atom
- An "unbound" variable (which is an evaluation error, not a value)

**Canonical form.** `()` is the only canonical textual representation of void. The symbol `∅` is not a literal; if needed in programs, bind it to void via `define`.

**Uses of void:**

| Context | Meaning |
|---------|---------|
| Result of `(define ...)` | Definition forms return void |
| Result of `(set! ...)` | Assignment returns void |
| Result of `(begin e1 ... en)` when `n = 0` | Empty sequence |
| `(branch tree label)` when label absent | Missing branch |
| Tail of a sequence idiom | End of a user-defined linked tree (see §11.2) |

**Predicates.** Use `void?` to test for void. Do not use `null?` — it does not exist in TREESP.

---

## 3. Syntax

TREESP source text is a sequence of S-expressions. The grammar below describes the surface syntax before reader desugaring.

### 3.1 Atomic forms

```
<atom>     ::= <number> | <symbol> | <string> | "#t" | "#f" | "()"
<number>   ::= ["-"] <digit>+ ["." <digit>+]
<symbol>   ::= <initial> <subsequent>*
<initial>  ::= <letter> | <special-initial>
<subsequent> ::= <initial> | <digit>
<special-initial> ::= "!" | "$" | "%" | "&" | "*" | "/" | ":" | "<" | "="
                    | ">" | "?" | "~" | "_" | "^"
<string>   ::= '"' <any char except " and \>* '"'
```

The empty compound `()` is **void**, not a tree.

### 3.2 Compound forms

```
<compound> ::= "(" <tag> <branch-element>* ")"
<tag>      ::= <atom>          ; typically a symbol; may be any value after quote
<branch-element> ::=
      <subtree>               ; positional sugar (§4.2)
    | "(" <label> <subtree> ")"   ; explicit labeled branch
<label>    ::= <symbol>
<subtree>  ::= <atom> | <compound> | <abbreviated>
```

**Abbreviated forms** (reader expands before desugaring):

| Abbreviation | Expands to |
|--------------|------------|
| `'e` | `(quote e)` |
| `` `e `` | `(quasiquote e)` |
| `,e` | `(unquote e)` |
| `,@e` | `(unquote-splicing e)` |

### 3.3 Comments

`;` starts a comment that continues to the end of the line. Comments are discarded by the reader.

### 3.4 Positional sugar

Bare subtrees after the tag receive implicit labels `arg0`, `arg1`, `arg2`, …:

```treesp
(+ 1 2)
```

is reader-desugared to:

```treesp
(+ (arg0 1) (arg1 2))
```

representing a tree with `tag = +` and branches `{ arg0 → 1, arg1 → 2 }`.

Fully explicit form is always equivalent:

```treesp
(+ (arg0 1) (arg1 2))
```

### 3.5 Explicit labeled branches

When any element after the tag is of the form `(label subtree)` **in source text** — a compound whose first sub-expression is a symbol atom — **all** elements after the tag must use that form, **unless** a bare atom appears among the branches (which forces positional mode for the whole compound; see §4.2). Mixing two-element labeled compounds with three-or-more-element compounds (and no bare atoms) is a reader error (§4.3).

```treesp
(if (test (> x 0))
    (then x)
    (else 0))
```

**Important.** Whether a branch uses explicit label syntax is determined from the **surface** S-expression before positional desugaring runs on that compound's children. A nested positional call is not an explicit labeled branch just because it later desugars to a tree with one branch:

```treesp
(* n (fact (- n 1)))    ; valid — all positional branches at this level
```

Here `(fact (- n 1))` is a positional branch (the second argument to `*`). It desugars to `(fact (arg0 (- (arg0 n) (arg1 1))))`, which is a tree with one branch — but that does **not** make it `(fact (label ...))` explicit syntax at the `*` level.

### 3.6 Quoting

Quoted forms are data, not calls:

```treesp
'(+ 1 2)          ; a tree tagged quote with branch arg0 → tree (+ (arg0 1) (arg1 2))
`(node a (b ,c))  ; quasiquote: template with selective evaluation
```

See §4.4 for quasiquote and splicing rules.

---

## 4. Reader

The **reader** transforms source text into TREESP values (atoms, trees, void). It runs in three phases:

1. **S-expression parse** — text → raw S-expressions (no branch desugaring)
2. **Desugaring** — abbreviations, positional `argN` labels, quasiquote expansion
3. **Value construction** — raw forms become `Tree` / atom values

### 4.1 Algorithm (S-expression parse)

The parser builds **raw S-expressions** first. A raw form is either an atom or a compound `(e0 e1 … en)` whose children are raw forms. No `arg0`/`arg1` desugaring happens during this phase.

```
read-atom stream:
  ... numbers, strings, #t, #f, symbols (see §4.6) ...

read-raw stream:
  if abbreviation (' ` , ,@): expand to (quote …) etc., then read-raw
  if '(': read-raw-compound
  else: read-atom

read-raw-compound stream:
  elements = []
  loop:
    skip whitespace and comments
    if ')': break
    if EOF: error "unclosed ("
    elements.append(read-raw stream)
  if elements is empty: return VOID
  return Compound(elements)

desugar-raw(raw):
  if raw is atom: return atom
  if raw is VOID: return void
  if raw is Compound [tag, b1, …, bn]:
    tag' = desugar-raw(tag)     ; tag is usually a symbol atom
    return desugar-compound(tag', [b1, …, bn])   ; branches still raw
```

Abbreviation expansion (§4.5) runs when `read-raw` sees `'`, `` ` ``, `,`, or `,@`.

### 4.2 Positional desugaring

`desugar-compound` receives the **desugared tag** and a list of **raw** branch S-expressions (not yet desugared values).

```
explicit-label-form?(raw):
  raw is Compound [Atom(symbol), subtree]   ; exactly two elements, first is symbol

use-explicit-mode?(raw-branches):
  raw-branches is non-empty
  AND every element satisfies explicit-label-form?
  AND no bare atoms among branches

desugar-compound(tag, raw-branches):
  if raw-branches is empty:
    return Tree(tag, {})
  if use-explicit-mode?(raw-branches):
    labels = first atom of each branch compound
    if duplicate labels: error "duplicate branch label"
    return Tree(tag, { labelᵢ: desugar-raw(subtreeᵢ) })
  else if any bare atom in raw-branches:
    return Tree(tag, { argᵢ: desugar-raw(branchᵢ) ... })   ; positional
  else if any explicit-label-form? AND any compound with 3+ elements:
    error "mixed explicit and positional branches"
  else:
    return Tree(tag, { argᵢ: desugar-raw(branchᵢ) ... })   ; positional
```

**Disambiguation.** A nested one-argument call `(fact (- n 1))` has the same surface shape as an explicit labeled branch `(fact <subtree>)`. When a **bare atom** appears among the branches (e.g. `n` in `(* n (fact (- n 1)))`), the parent uses **positional** mode and every branch — including two-element compounds — is desugared as a complete sub-form. Explicit mode applies only when **every** branch is a two-element `(symbol subtree)` compound and **none** are bare atoms.

| Parent form | Mode | Reason |
|-------------|------|--------|
| `(if (test x) (then y) (else z))` | explicit | all branches are `(sym subtree)`, no bare atoms |
| `(* n (fact (- n 1)))` | positional | bare atom `n` among branches |
| `(foo (a 1) (b c d))` | error | mix of 2-element and 3+-element compounds |
| `(f a (x 1))` | positional | bare atom `a` forces positional mode |

**Explicit vs positional is a source-syntax rule.** Implementations must not classify branches by inspecting already-desugared trees (e.g. “tree with one branch”). A positional call `(f a)` and an explicit branch `(f (x a))` at the same parent level desugar differently; see table above.

### 4.3 Reader errors

| Condition | Error |
|-----------|-------|
| Unclosed `(` | `read: unexpected EOF` |
| Mixed explicit and positional branches | `read: mixed branch forms` |
| Duplicate explicit label in one compound | `read: duplicate branch label` |
| `,@` outside compound quasiquote | `read: unquote-splicing outside template` |
| Invalid number or string | `read: malformed literal` |

### 4.4 Quasiquote

`quasiquote` is a special form implemented via macro expansion (§8). At the reader level, `` ` ``, `,`, and `,@` abbreviations are expanded first.

**Unquote** `,expr` — evaluate `expr` and insert the result into the template.

**Unquote-splicing** `,@expr` — may appear only inside a compound template node. `expr` must evaluate to a **tree**. The branches of that tree are **grafted** into the surrounding template node. Duplicate labels between spliced branches and sibling branches → error.

Example:

```treesp
(define a 1)
(define b 2)
`(node root (x ,a) ,@(branches (node extra (y ,b) (z 3))))
```

If `(branches t)` returns a view tree of `t`'s branches, the result is:

```treesp
(node root (x 1) (y 2) (z 3))
```

Splicing is **branch grafting**, not list concatenation.

### 4.5 Abbreviation expansion

```
expand-abbrev(form):
  if form is 'e              → (quote e)
  if form is `e              → (quasiquote e)
  if form is ,e               → (unquote e)
  if form is ,@e              → (unquote-splicing e)
  if form is compound:
    return compound with each element recursively expanded
  else:
    return form
```

Abbreviation expansion runs before positional desugaring.

### 4.6 Lexical tokens

| Token | Rule |
|-------|------|
| `#t`, `#f` | Boolean literals (`#` followed by `t` or `f`) |
| Numbers | Optional leading `-` only when immediately followed by digits (e.g. `-3.14`) |
| `-` alone | Symbol (e.g. subtraction in `(- n 1)`) |
| `+` | Symbol (e.g. addition) |
| Other symbols | Letters and the special-initial characters from §3.1 |

A `-` followed by whitespace or `)` is always the symbol `-`, never the start of a number.

---

## 5. Evaluation

TREESP uses a Scheme-style **eval** / **apply** model with dynamic scope (lexical scoping is recommended for implementations but is an open question; see §12). This section specifies dynamic scope as the normative semantics.

### 5.1 Evaluation contexts

- **Environment** — maps symbols to values (see §5.4)
- **Expression** — an atom, tree, or void

### 5.2 Eval

```
eval(expr, env):

  ;; Atoms and void
  if expr is atom:
    if expr is symbol:
      return env-lookup(env, expr)   ; error if unbound
    else:
      return expr
  if expr is void:
    return void

  ;; Compound — must be a tree
  tag-expr = expr.tag
  branch-map = expr.branches

  ;; Special forms: tag is a symbol bound to a special-form handler
  if tag-expr is symbol and is-special-form?(tag-expr):
    return special-form-eval(tag-expr, branch-map, env)

  ;; Macro: tag evaluates to a macro object
  operator = eval(tag-expr, env)
  if is-macro?(operator):
    expanded = macro-expand(operator, branch-map, env)
    return eval(expanded, env)

  ;; Function call
  if is-function?(operator) or is-primitive?(operator):
    evaluated-branches = {}
    for (label, subtree) in branch-map in insertion order:
      evaluated-branches[label] = eval(subtree, env)
    return apply(operator, evaluated-branches, env)

  else:
    error "not callable"
```

**Note on special forms:** Special forms receive **unevaluated** branch subtrees. They are recognized by the symbol in tag position before that symbol is looked up as a variable.

### 5.3 Apply

```
apply(operator, branch-map, env):

  if operator is primitive:
    return primitive-impl(operator, branch-map)

  if operator is closure(closure-env, param-tree, body):
    new-env = extend-env(closure-env, param-tree, branch-map)
    return eval(body, new-env)

  error "apply: not a function"
```

**Closures** capture their defining environment. **Primitives** are built-in functions implemented by the host.

### 5.4 Environments as trees

An environment is not a list of frames. It is a **tree of bindings** with a distinguished structure:

```
Env := Tree {
  tag: env,
  branches: {
    <symbol>: Value,    ; binding
    ...
    parent: Env | void  ; optional parent environment
  }
}
```

**Lookup:**

```
env-lookup(env, symbol):
  if branch?(env, symbol):
    return branch(env, symbol)
  if branch?(env, parent):
    return env-lookup(branch(env, parent), symbol)
  error "unbound variable"
```

**Extend** (for `lambda` and `let`):

```
extend-env(env, param-tree, arg-branch-map):
  bindings = match-params(param-tree, arg-branch-map)
  return graft-tree(env, bindings)   ; new env tree with bindings added
```

`param-tree` for `lambda` is a tree whose branches are parameter names mapping to void (presence indicates a parameter). Arguments are matched by branch label: calling `(f (arg0 1) (arg1 2))` binds `arg0` and `arg1` in the function's parameter tree.

For positional calls, parameters are typically declared as:

```treesp
(lambda (n) ...)          ; param tree: (params (n)) via sugar
```

which desugars to a `params` branch tree with labeled parameters. The exact calling convention for `lambda` is specified in §6.

### 5.5 Evaluation flow

```
Source text
    → Reader
    → Tree (AST / data)
    → eval
        → special form handler
        → macro expand → eval
        → apply
            → primitive
            → closure → eval body
    → Value
```

---

## 6. Special Forms

Special forms are recognized by symbol tag before evaluation. Their branch subtrees are passed **unevaluated** (except where noted).

### 6.1 Summary table

| Form | Expected branches | Result |
|------|-------------------|--------|
| `quote` | `arg0` → expr | `expr` unevaluated |
| `if` | `test`, `then`, `else` (or positional) | Conditional |
| `lambda` | `params`, `body` | Closure |
| `define` | `name`, `value` OR `name`, `params`, `body` | Void; adds binding |
| `set!` | `name`, `value` | Void; mutates binding |
| `begin` | `arg0` … `argN` | Last value, or void |
| `and` | `arg0` … `argN` | Short-circuit boolean |
| `or` | `arg0` … `argN` | Short-circuit boolean |
| `let` | `bindings`, `body` | New scope |
| `cond` | `clause` … | Multi-way conditional |
| `quasiquote` | `arg0` → template | Expanded via macro rules |

### 6.2 `quote`

```treesp
(quote expr)
'expr
```

Returns `expr` without evaluation. All substructure is literal.

### 6.3 `if`

```treesp
(if test then else)
(if (test c) (then t) (else f))   ; explicit
```

1. Evaluate `test`.
2. If truthy, evaluate `then`; else evaluate `else`.

Truthy: any value except `#f`. Void is truthy.

### 6.4 `lambda`

```treesp
(lambda (x y) body)
(lambda (params (x) (y)) (body body-expr))   ; explicit
```

Creates a closure. `params` is a tree listing parameter names as branch labels (values are ignored, typically void or placeholder). On application, argument branch labels are matched to parameter labels.

**Parameter list sugar.** In `(lambda (x y) body)`, the params subtree is the raw S-expression `(x y)` desugared positionally:

| Surface params | Desugared params tree | Parameter names |
|----------------|----------------------|-----------------|
| `(n)` | `(n)` — tag `n`, zero branches | `n` |
| `(x y)` | `(x (arg0 y))` — tag `x`, one branch | `x`, `y` |
| `(params (x) (y))` | explicit branches `x`, `y` | `x`, `y` |

Implementations extract parameter names in order: the tag symbol (if it names a parameter), then each positional `argᵢ` branch value when it is a symbol, or each explicit branch label for `(params (x) (y))` form.

**Arity.** If a required parameter label is missing from the argument branch map → error. Extra argument branches may be ignored or collected per implementation policy (recommend: error on unexpected `argN` for user-defined functions).

### 6.5 `define`

**Variable:**

```treesp
(define name value)
```

Evaluates `value`, binds `name` in the current environment, returns void.

**Function:**

```treesp
(define (f x y) body)
```

Desugars to:

```treesp
(define f (lambda (x y) body))
```

**Function define sugar.** `(define (f x y) body)` is read as a `define` with two positional branches: first `(f x y)` (a positional tree tagged `f`), then `body`. The name `f` is the **tag** of that first branch, not a separate atom.

### 6.6 `set!`

```treesp
(set! name value)
```

Mutates the binding of `name` in the environment chain. Returns void.

### 6.7 `begin`

```treesp
(begin e1 e2 ... en)
```

Evaluates expressions in order; returns the value of `en`, or void if empty.

### 6.8 `and` / `or`

```treesp
(and e1 e2 ... en)
(or e1 e2 ... en)
```

Short-circuit: `and` returns first falsy or last value; `or` returns first truthy or last value.

### 6.9 `let`

```treesp
(let ((x 1) (y 2)) body)
(let (bindings (x 1) (y 2)) (body body-expr))   ; explicit
```

1. Evaluate each binding value in the outer environment.
2. Extend environment with binding labels.
3. Evaluate `body` in the new environment.

### 6.10 `cond`

```treesp
(cond (test1 expr1)
      (test2 expr2)
      (else exprN))
```

Each clause is a branch labeled `arg0`, `arg1`, … or explicit clause labels. Each clause is a tree `(testᵢ exprᵢ)` with branches `test` and `then` (or positional).

Evaluates the first clause whose test is truthy; returns the corresponding expression's value. `else` as test is always truthy.

### 6.11 `quasiquote`

See §4.4 and §8. Implemented as a macro that walks a template tree and inserts `unquote` / graft operations.

---

## 7. Primitives

Primitives are built-in operations. They are invoked via `apply` like user functions but are implemented by the host.

Unless noted, primitives evaluate all argument branches before the primitive runs (they are functions, not special forms).

### 7.1 Predicates

| Primitive | Signature | Description |
|-----------|-----------|-------------|
| `atom?` | `(atom? v)` | `#t` if `v` is an atom |
| `tree?` | `(tree? v)` | `#t` if `v` is a tree |
| `void?` | `(void? v)` | `#t` if `v` is void |
| `number?` | `(number? v)` | `#t` if `v` is a number |
| `symbol?` | `(symbol? v)` | `#t` if `v` is a symbol |
| `string?` | `(string? v)` | `#t` if `v` is a string |
| `boolean?` | `(boolean? v)` | `#t` if `v` is `#t` or `#f` |
| `eq?` | `(eq? a b)` | `#t` if `a` and `b` are the same object (symbols, void) |
| `equal?` | `(equal? a b)` | Structural equality |
| `branch?` | `(branch? tree label)` | `#t` if `tree` has branch `label` |

### 7.2 Accessors

| Primitive | Signature | Description |
|-----------|-----------|-------------|
| `tag` | `(tag tree)` | Returns the tag symbol of `tree` |
| `branch` | `(branch tree label)` | Returns subtree/atom at `label`, or void |
| `branches` | `(branches tree)` | Returns a tree tagged `branches` with one branch per original branch, each labeled by the original label |
| `branch-labels` | `(branch-labels tree)` | Returns a tree tagged `labels` with branches `arg0`, `arg1`, … mapping to label symbols |

`branches` is a **view** for iteration, not a copy of values into a list:

```treesp
(branches (node f (x 1) (y 2)))
;; => (branches (x 1) (y 2))   ; tree tagged 'branches'
```

### 7.3 Construction

| Primitive | Signature | Description |
|-----------|-----------|-------------|
| `node` | `(node tag (l1 v1) (l2 v2) …)` | Construct a new tree |
| `graft` | `(graft tree label subtree)` | Copy `tree`, set `label` to `subtree` |
| `prune` | `(prune tree label)` | Copy `tree`, remove `label` |
| `tag-set` | `(tag-set tree new-tag)` | Copy `tree` with new tag |

All construction primitives return **new** trees; existing trees are immutable.

**`node` and reader desugaring.** Calls such as `(node expr (op +) (left 1))` are read positionally because `expr` is a bare atom (§4.2). `node` is a **special form**: the tag and atomic branch values are literal symbols/atoms; compound branch values are evaluated. See [IMPLEMENTATION.md](IMPLEMENTATION.md).

### 7.4 Traversal

| Primitive | Signature | Description |
|-----------|-----------|-------------|
| `fold-tree` | `(fold-tree tree leaf-fn node-fn)` | Bottom-up fold |
| `walk-tree` | `(walk-tree tree pre-fn post-fn)` | Pre-order and post-order callbacks |
| `map-branches` | `(map-branches tree fn)` | Apply `fn` to each branch value; return new tree |
| `filter-branches` | `(filter-branches tree pred)` | Keep branches where `(pred label value)` is truthy |

**`fold-tree`:**

```
fold-tree(atom, leaf-fn, node-fn):
  if atom is atom or void:
    return leaf-fn(atom)
  else:
    folded-branches = { l: fold-tree(v, ...) for l, v in branches }
    return node-fn(tag(atom), folded-branches)
```

**`map-branches`:** Applies `fn` to each branch value; keys unchanged.

### 7.5 Navigation

| Primitive | Signature | Description |
|-----------|-----------|-------------|
| `path` | `(path tree l1 l2 …)` | Nested `branch`; void if any step missing |

```treesp
(path (node a (x (node b (y 42)))) x y)   ; => 42
```

### 7.6 Pattern matching

| Primitive | Signature | Description |
|-----------|-----------|-------------|
| `match` | `(match value clause …)` | Pattern-match on trees and atoms |

**Pattern grammar:**

```
pattern ::= <atom>                    ; matches equal? atom
          | (?? var)                  ; bind any value to var
          | (tag p1 p2 ...)           ; positional branch patterns → arg0, arg1, …
          | (tag (l1 p1) (l2 p2) …)   ; labeled branch patterns
```

**Clause:** `(pattern result-expr)` or `(pattern (guard g) result-expr)`.

`match` is a special form: patterns are not evaluated; `result-expr` is evaluated in an environment extended with bindings from the pattern.

Example:

```treesp
(match t
  (42 "literal")
  (expr (op +) (left (?? a)) (right (?? b))) (+ a b)
  ((?? x) x))
```

### 7.7 Arithmetic and comparison

Standard numeric primitives, operating on numbers:

| Primitive | Description |
|-----------|-------------|
| `+`, `-`, `*`, `/` | Variadic arithmetic (`+` and `*` accept zero or more args) |
| `=`, `<`, `>`, `<=`, `>=` | Comparisons |
| `not` | Boolean negation |

Branch access for variadic ops: all `arg0`, `arg1`, … branches are collected in order.

### 7.8 I/O (conceptual)

| Primitive | Description |
|-----------|-------------|
| `display` | Write a value to standard output |
| `read` | Read one value from standard input (v0.2: one line per call) |
| `newline` | Write a newline |

`display` prints trees using the canonical S-expression syntax with explicit labels only when necessary for round-trip (implementations may always print desugared form).

### 7.9 Application

| Primitive | Signature | Description |
|-----------|-----------|-------------|
| `apply` | `(apply operator args-tree)` | Invoke `operator` with the branches of `args-tree` as call arguments |

**Semantics** (surface form of §5.3 `apply`):

- `arg0` (`operator`): evaluated; must be a primitive or closure.
- `arg1` (`args-tree`): evaluated; must be a **tree**. Its branches (in insertion order, typically `arg0`…`argN`) form the argument branch map for the call.
- Variadic primitives (`+`, `*`, etc.) collect all positional branches from `args-tree` in order (§7.7).
- Closures bind parameters from `args-tree` branches as in a normal call.
- Macros cannot be applied directly; use macro expansion via call syntax instead.

**Errors:** `apply: not callable`, `apply: args must be a tree`, plus arity errors from the callee.

```treesp
(apply + (node values (arg0 1) (arg1 2) (arg2 3)))   ; => 6
```

See §10.4 for `apply` with `map-branches`.

---

## 8. Macros

A **macro** is a callable object that receives **unevaluated** branch subtrees and returns a **tree** to be evaluated in the calling environment.

### 8.1 Macro definition

```treesp
(define-macro (name param-tree) body)
```

Expands to storing a macro object in the environment. `define-macro` is itself a macro or special form (implementation detail).

### 8.2 Expansion

```
macro-expand(macro, branch-map, env):
  return eval(macro-body, extend-env(macro-env, macro-params, branch-map))
```

The returned tree is then passed to `eval` in the **caller's** environment (hygienic macros are an open question; see §12).

### 8.3 Example: `when`

```treesp
(define-macro (when test . body)
  `(if ,test (begin ,@body)))

;; Usage:
(when (> x 0)
  (display x)
  (newline))
```

Expands to:

```treesp
(if (> x 0) (begin (display x) (newline)))
```

### 8.4 Example: `defun`

```treesp
(define-macro (defun name params . body)
  `(define ,name (lambda ,params (begin ,@body))))

(defun fact (n)
  (if (= n 0) 1 (* n (fact (- n 1)))))
```

### 8.5 Quasiquote macro

`quasiquote` is defined as a macro that walks its template:

- Atoms and void pass through
- `(unquote e)` → evaluate `e`
- `(unquote-splicing e)` → graft branches of evaluated tree into enclosing node
- Otherwise rebuild tree, recursively quasiquoting children

---

## 9. Standard Library

No module system is defined in v0.1. The following **conceptual modules** group primitives and planned library functions for future implementations.

### 9.1 `treesp.core`

Special forms, `define`, `lambda`, `apply`, arithmetic, predicates, `display`, `read`.

### 9.2 `treesp.tree`

`node`, `tag`, `branch`, `branches`, `graft`, `prune`, `tag-set`, `path`, `branch-labels`.

### 9.3 `treesp.walk`

`fold-tree`, `walk-tree`, `map-branches`, `filter-branches`.

### 9.4 `treesp.match`

`match` and pattern helpers.

### 9.5 Planned (non-normative)

| Function | Purpose |
|----------|---------|
| `merge-branches` | Union of branch maps with conflict policy |
| `rename-branch` | Copy tree with one label renamed |
| `depth` | Maximum depth to leaves |
| `size` | Count of nodes |
| `clone` | Deep copy |

---

## 10. Examples

### 10.1 Arithmetic

```treesp
(+ 1 (* 2 3))    ; => 7
(- 10 3 2)       ; => 5
```

Desugared:

```treesp
(+ (arg0 1) (arg1 (* (arg0 2) (arg1 3))))
```

### 10.2 Factorial

```treesp
(define fact
  (lambda (n)
    (if (= n 0)
        1
        (* n (fact (- n 1))))))

(fact 5)    ; => 120
```

### 10.3 Tree construction and navigation

```treesp
(define t
  (node expr
    (op +)
    (left (node expr
            (op *)
            (left 2)
            (right 3)))
    (right 1)))

(tag t)                       ; => expr
(branch t op)                 ; => +
(branch (branch t left) op)   ; => *
(path t left left)            ; => 2
(path t right)                ; => 1
```

### 10.4 `fold-tree` over an AST

Sum all numeric leaves:

```treesp
(define (tree-sum t)
  (if (atom? t)
      (if (number? t) t 0)
      (let ((children (branches t)))
        (fold-tree children
          (lambda (x) (if (number? x) x 0))
          (lambda (tag bs)
            (+ (branch bs arg0)
               (branch bs arg1)
               (branch bs arg2)))))))

;; Simpler version using map-branches on the original tree:
(define (tree-sum t)
  (if (atom? t)
      (if (number? t) t 0)
      (+ (fold-tree t
            (lambda (x) (if (number? x) x 0))
            (lambda (tag branches)
              0))
         (apply + (map-branches t tree-sum)))))
```

Note: `apply` on `+` with multiple numeric branches uses positional `argN` collection (§7.9).

### 10.5 Quasiquote building a tree

```treesp
(define x 10)
(define form
  `(node expr
     (op +)
     (left 1)
     (right ,x)))

;; => (node expr (op +) (left 1) (right 10))
```

### 10.6 `match` on tree shape

```treesp
(define (eval-expr t)
  (match t
    ((?? n) (number? n) n)
    ((+ (?? a) (?? b)) (+ (eval-expr a) (eval-expr b)))
    ((* (?? a) (?? b)) (* (eval-expr a) (eval-expr b)))
    ((?? _) (error "bad expr"))))
```

### 10.7 Grafting and pruning

```treesp
(define t (node root (a 1) (b 2)))
(graft t c 3)        ; => (node root (a 1) (b 2) (c 3))
(prune (graft t a 99) b)  ; => (node root (a 99))
```

### 10.8 Sequence idiom (linked tree)

```treesp
(define empty ())
(define (seq . branches)
  (if (void? branches)
      empty
      (node seq
        (head (branch branches arg0))
        (tail (apply seq (prune branches arg0))))))

;; Building 1 → 2 → 3:
(node seq
  (head 1)
  (tail (node seq
          (head 2)
          (tail (node seq (head 3) (tail empty))))))
```

---

## 11. Rejected LISP Features

TREESP deliberately omits list-centric features. These are **design choices**, not oversights.

### 11.1 Anti-feature list

| LISP feature | TREESP alternative |
|--------------|-------------------|
| Cons cells `(a . b)` | `node`, `graft` |
| `car`, `cdr`, `cadr`, … | `tag`, `branch`, `path` |
| `cons` | `graft` on a tree, or `node` |
| `list`, `list?` | `node` with `arg0`…`argN`; `tree?` |
| `length` on chains | `branch-labels` + count; or `size` library |
| `null?` | `void?` |
| `pair?` | `tree?` |
| Proper/improper lists | Labeled trees; no dotted pairs |
| Association lists as default | Environment and data use branch maps |
| `append`, `reverse` on lists | `graft`, `merge-branches`, tree walks |
| `map` on lists | `map-branches`, `walk-tree` |
| `filter` on lists | `filter-branches` |

### 11.2 Modeling sequences

TREESP has no built-in sequence type. Common idioms:

**Positional branches** — already used for function calls:

```treesp
(node triple (arg0 1) (arg1 2) (arg2 3))
```

**Linked tree** — explicit `head` / `tail` branches (see §10.8).

**Keyed records** — trees with meaningful branch names:

```treesp
(node person (name "Ada") (age 36))
```

Choose the idiom that fits the data; do not reach for list patterns.

### 11.3 What TREESP is not

- Not a "LISP with lists renamed to trees" — semantics differ; `cdr` has no meaning.
- Not JSON with parentheses — evaluation, `lambda`, and macros are first-class.
- Not statically typed — types are an open question (§12).

---

## 12. Open Questions

The following are intentionally left for future specification versions:

| Topic | Question |
|-------|----------|
| Scoping | Normative text uses dynamic scope; lexical scope is recommended for implementations |
| Macro hygiene | Should macros capture identifiers lexically? |
| Rest parameters | Syntax for collecting extra `argN` branches |
| Numeric tower | Integers, rationals, exact vs inexact |
| Module system | `import` / `export` of bindings |
| Error values | Exceptions as trees vs host errors only |
| Compilation | Tree IR, optimization passes |
| Reference implementation | Language choice (Rust, Dart, Scheme, …) |

---

## Appendix A: Canonical desugaring reference

| Surface | Desugared tree |
|---------|----------------|
| `()` | void |
| `(f)` | `(f)` — tree, zero branches |
| `(f a)` | `(f (arg0 a))` |
| `(f a b)` | `(f (arg0 a) (arg1 b))` |
| `(f (x a))` | `(f (x a))` — explicit, no arg0 |
| `'x` | `(quote (arg0 x))` |
| `` `(a ,b) `` | `(quasiquote (arg0 (a (unquote (arg0 b)))))` |

---

## Appendix B: Grammar (EBNF summary)

```ebnf
program     = expression* ;
expression  = atom | compound | abbreviation ;
atom        = number | symbol | string | "#t" | "#f" | "()" ;
compound    = "(" tag branch* ")" ;
tag         = expression ;
branch      = expression | "(" label expression ")" ;
label       = symbol ;
abbreviation= "'" expression
            | "`" expression
            | "," expression
            | ",@" expression ;
```

---

*TREESP — trees all the way down.*
