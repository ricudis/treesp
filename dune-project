(lang dune 3.0)
(name treesp)
(generate_opam_files true)

(package
 (name treesp)
 (synopsis "TREESP reference interpreter")
 (depends
  ocaml
  dune
  (alcotest :with-test)))
