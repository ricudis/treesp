# Introduction to TREESP

**Trees all the way down. No lists. No regrets.**

---

Yesterday, **adamo** — a friend of ours — challenged us to write some LISP slop.

Fair enough. We like parentheses. We like homoiconicity. We like `eval`. We even like calling things *slop* with affection, the way you might refer to your cat as a *little guy* while it knocks a glass off the table.

The problem is: **we hate lists**.

Lists remind us of supermarkets — fluorescent lights, numbered aisles, the slow parade of carts. Lists remind us of targeted political pogroms — roll calls, registries, names crossed off one by one. Lists remind us of TODOs — infinite, guilt-ridden, never quite done.

Clearly, lists are the root of all evil.

But we love **trees**.

Trees branch. Trees shade. Trees hold nests. Trees do not demand that every idea march in single file behind a `cdr`. Trees let you name your children `left` and `right` instead of `first` and *whatever comes after first, good luck*.

So we built **TREESP**.

TREESP is a LISP in spirit: S-expressions, `quote`, `lambda`, macros, the whole homoiconic deal. But its only composite data primitive is the **labeled-edge tree**. There is no `cons`. There is no `car`. There is no `cdr`. There are no dotted pairs lurking in the shadows, no improper lists pretending to be something they're not.

In LISP, `(f a b)` is a list of three things. In TREESP, `(f a b)` is a tree tagged `f` with branches `a` and `b`. Same syntax. Better ontology.

We also have an error message no other language has bothered to invent: **`read: mixed branch forms`**. You will meet it when you write `(foo (a 1) (b c d))` — one branch that looks labeled, one that looks like a proper call, neither bare atom to break the tie — and the reader refuses to guess. Other languages silently pick a interpretation, or worse, parse it wrong and let you debug the wreckage at runtime. TREESP stops you at the door and says *nice try*. We are insufferably proud of this. See §4.3 of the [language specification](TREESP.md).

For the grammar, reader, primitives, and formal semantics, see the [language specification](TREESP.md). This document is the *why*.

---

## The counter-challenge

Now it's adamo's turn.

We counter-challenge him to write an **editor** in TREESP.

Not a toy REPL. Not a hello-world interpreter. An editor — the kind of program that edits things, preferably without secretly being a linked list wearing a trench coat. Trees editing trees. It's only natural.

There is already an editor out there — you know the one — that has been written in Lisp since the mid-1980s, extensible in Lisp, configured in Lisp, and occasionally accused of *being* Lisp with a text widget glued on. It spent decades pretending a thousand tiny `cons` cells were a document. TREESP offers adamo a chance at redemption. Some ideas we will absolutely judge him on:

- **Buffer as tree.** The document is not a line list. It is a labeled tree — paragraphs, expressions, branches. Navigate with `path`, not `cdr`. `forward-sexp` should walk the tree, not skip to the next comma in a JSON file.
- **Structural editing.** `kill-branch` instead of `kill-line`. `graft` instead of `yank`. The kill-ring should be a forest, not a deque pretending to be noble.
- **A major mode for TREESP.** Syntax highlighting that respects tree shape. Parenthesis matching that follows branches, not a stack of lonely `(`.
- **Eval at point.** Point is not a cursor offset into a string. Point is a position in the tree. `C-x C-e` should evaluate the subtree under point. If the whole buffer is wrong, that's a user configuration issue — and we expect a large one, probably in a dotfile with parentheses.
- **The one-line prompt at the bottom speaks TREESP.** Commands invoked via `M-x` are trees. `(find-file (path projects treesp README.md))` — readable, graftable, no alist in sight.
- **Tree-sitter, but honest.** That other editor finally bolted on a parse-tree library last decade and called it progress. Adamo can skip the adapter layer and just... be the tree.

That editor has been asking for this since 1985. The request was filed under a `TODO` in a list somewhere. We find that offensive.

---

*TREESP — because lists are for groceries, and code is for branching.*
