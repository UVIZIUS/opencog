;; =============================================================================
;; DeductionRule
;;
;; <LinkType>
;;   A
;;   B
;; <LinkType>
;;   B
;;   C
;; |-
;; <LinkType>
;;   A
;;   C
;;
;; Due to type system limitations, the rule has been divided into 3:
;;       deduction-inheritance-rule
;;       deduction-implication-rule
;;       deduction-subset-rule
;;
;; -----------------------------------------------------------------------------

(use-modules (opencog logger))

(load "formulas.scm")

;; Generate the corresponding deduction rule given its link-type.
(define (gen-deduction-rule link-type)
    (BindLink
        (VariableList
            (VariableNode "$A")
            (VariableNode "$B")
            (VariableNode "$C"))
        (AndLink
            (link-type
                (VariableNode "$A")
                (VariableNode "$B"))
            (link-type
                (VariableNode "$B")
                (VariableNode "$C"))
            (NotLink
                (EqualLink
                    (VariableNode "$A")
                    (VariableNode "$C")
                )))
        (ExecutionOutputLink
            (GroundedSchemaNode "scm: deduction-formula")
            (ListLink
                (link-type
                    (VariableNode "$A")
                    (VariableNode "$B"))
                (link-type
                    (VariableNode "$B")
                    (VariableNode "$C"))
                (link-type
                    (VariableNode "$A")
                    (VariableNode "$C"))))))


(define deduction-inheritance-rule
    (gen-deduction-rule InheritanceLink))

(define deduction-implication-rule
    (gen-deduction-rule ImplicationLink))

(define deduction-subset-rule
    (gen-deduction-rule SubsetLink))

(define (deduction-formula AB BC AC)
    (let*
        ((sA (cog-stv-strength (gar AB)))
         (cA (cog-stv-confidence (gar AB)))
         (sB (cog-stv-strength (gar BC)))
         (cB (cog-stv-confidence (gar BC)))
         (sC (cog-stv-strength (gdr BC)))
         (cC (cog-stv-confidence (gdr BC)))
         (sAB (cog-stv-strength AB))
         (cAB (cog-stv-confidence AB))
         (sBC (cog-stv-strength BC))
         (cBC (cog-stv-confidence BC))
         (alpha 0.9) ; how much confidence is lost at each inference step

         ;; Hacks to overcome the lack of distributional TV. If sB=1
         ;; and cB=0, then assign sB to the mid value satisfying the
         ;; deduction consistency constraint (what a pain, let's use
         ;; 0.25 for now).
         (sB (if (and (< 0.99 sB) (<= cB 0)) 0.25 sB)))
      (if (and
           (conditional-probability-consistency sA sB sAB)
           (conditional-probability-consistency sB sC sBC))
          (if (< 0.99 (* sB cB))
              ;; Hack to overcome for the lack of distributional
              ;; TV. This covers the case where B fully confidently
              ;; tends to 1. See formulas.scm Simple Deduction
              ;; Formula comment for more explanations. This
              ;; overlaps with the implication-construction-rule.
              (let ((sAC sC)
                    (cAC (* alpha cA cC)))
                (if (and (< 1e-8 sAC) (< 1e-8 cAC)) ;; Don't create zero
                                              ;; knowledge. Note that
                                              ;; sAC == 0 is not zero
                                              ;; knowledge but it's
                                              ;; annoying in the
                                              ;; current hacky
                                              ;; situation.
                    (cog-merge-hi-conf-tv! AC (stv sAC cAC))
                    (cog-undefined-handle)))
              (let ((sAC (if (or (< 0.99 (* sAB cAB)) (< 0.99 (* sBC cBC)))
                             ;; Hack to overcome for the lack of
                             ;; distributional TV. This covers the case
                             ;; where little is known about A and B
                             ;; (i.e. their strength is meaningless), yet
                             ;; we can confidently calculate sAC because
                             ;; sAB and sBC are so high anyway.
                             (* sAB sBC)
                             ;; Otherwise fall back on the naive formula
                             (simple-deduction-strength-formula sA sB sC sAB sBC)))
                    (cAC (* alpha (min cAB cBC))))
                (if (and (< 1e-8 sAC) (< 1e-8 cAC)) ;; Don't create zero
                                              ;; knowledge. Note that
                                              ;; sAC == 0 is not zero
                                              ;; knowledge but it's
                                              ;; annoying in the
                                              ;; current hacky
                                              ;; situation.
                    (cog-merge-hi-conf-tv! AC (stv sAC cAC))
                    (cog-undefined-handle))))
          (cog-undefined-handle))))

;; Name the rules
(define deduction-inheritance-rule-name
  (DefinedSchemaNode "deduction-inheritance-rule"))
(DefineLink deduction-inheritance-rule-name
  deduction-inheritance-rule)

(define deduction-implication-rule-name
  (DefinedSchemaNode "deduction-implication-rule"))
(DefineLink deduction-implication-rule-name
  deduction-implication-rule)

(define deduction-subset-rule-name
  (DefinedSchemaNode "deduction-subset-rule"))
(DefineLink deduction-subset-rule-name
  deduction-subset-rule)
