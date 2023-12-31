;; NOTE: Assertions have been generated by update_lit_checks.py --output=fuzz-exec and should not be edited.

;; RUN: wasm-opt %s --vacuum --fuzz-exec -q -o /dev/null 2>&1 | filecheck %s
;; RUN: wasm-opt %s --ignore-implicit-traps --vacuum --fuzz-exec -q -o /dev/null 2>&1 | filecheck %s --check-prefix=IIT
;; RUN: wasm-opt %s --traps-never-happen --vacuum --fuzz-exec -q -o /dev/null 2>&1 | filecheck %s --check-prefix=TNH

(module
  ;; CHECK:      [fuzz-exec] calling trap
  ;; CHECK-NEXT: [trap unreachable]
  ;; IIT:      [fuzz-exec] calling trap
  ;; IIT-NEXT: [trap unreachable]
  ;; TNH:      [fuzz-exec] calling trap
  ;; TNH-NEXT: [trap unreachable]
  (func "trap"
    (unreachable)
  )

  (memory 1 1)
  ;; CHECK:      [fuzz-exec] calling load-trap
  ;; CHECK-NEXT: [trap highest > memory: 65536 > 65532]
  ;; IIT:      [fuzz-exec] calling load-trap
  ;; IIT-NEXT: [trap highest > memory: 65536 > 65532]
  ;; TNH:      [fuzz-exec] calling load-trap
  ;; TNH-NEXT: [trap highest > memory: 65536 > 65532]
  (func "load-trap"
    ;; This load traps, so this cannot be removed. But if either of
    ;; --ignore-implicit-traps or --traps-never-happen is set, this load is
    ;; assumed not to trap and we end up optimizing this out with --vacuum,
    ;; causes the trap behavior to change. This should not result in [fuzz-exec]
    ;; comparison failure.
    (drop
      (i32.load (i32.const 65536))
    )
  )
)
;; CHECK:      [fuzz-exec] calling trap
;; CHECK-NEXT: [trap unreachable]

;; CHECK:      [fuzz-exec] calling load-trap
;; CHECK-NEXT: [trap highest > memory: 65536 > 65532]
;; CHECK-NEXT: [fuzz-exec] comparing load-trap
;; CHECK-NEXT: [fuzz-exec] comparing trap

;; IIT:      [fuzz-exec] calling trap
;; IIT-NEXT: [trap unreachable]

;; IIT:      [fuzz-exec] calling load-trap
;; IIT-NEXT: [fuzz-exec] comparing load-trap
;; IIT-NEXT: [fuzz-exec] comparing trap

;; TNH:      [fuzz-exec] calling trap

;; TNH:      [fuzz-exec] calling load-trap
;; TNH-NEXT: [fuzz-exec] comparing load-trap
;; TNH-NEXT: [fuzz-exec] comparing trap
