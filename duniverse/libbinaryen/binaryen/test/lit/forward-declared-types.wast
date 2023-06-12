;; NOTE: Assertions have been generated by update_lit_checks.py and should not be edited.
;; Test that types can be used before they are defined

;; RUN: wasm-opt %s -all -S -o - | filecheck %s
;; RUN: wasm-opt %s -all --nominal -S -o - | filecheck %s --check-prefix=NOMNL

(module
  ;; CHECK:      (type $func (func))

  ;; CHECK:      (type $struct (struct (field (ref $array)) (field (ref null $func))))
  ;; NOMNL:      (type $func (func_subtype func))

  ;; NOMNL:      (type $struct (struct_subtype (field (ref $array)) (field (ref null $func)) data))
  (type $struct (struct
    (field (ref $array))
    (field (ref null $func))
  ))
  ;; CHECK:      (type $array (array (rtt 2 $func)))
  ;; NOMNL:      (type $array (array_subtype (rtt 2 $func) data))
  (type $array (array (field (rtt 2 $func))))
  (type $func (func))

  (func (result (ref null $struct))
    (unreachable)
  )
)