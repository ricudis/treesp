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

For the grammar, reader, primitives, and formal semantics, see the [language specification](TREESP.md). This document is the *why*.

---

## The counter-challenge

Now it's adamo's turn.

We counter-challenge him to write an **editor** in TREESP.

Not a toy REPL. Not a hello-world interpreter. An editor — the kind of program that edits things, preferably without secretly being a linked list wearing a trench coat.

Trees editing trees. It's only natural.

---

*TREESP — because lists are for groceries, and code is for branching.*
