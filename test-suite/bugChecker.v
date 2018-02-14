(* -*- coq-prog-args : ("-debug" "-type-in-type") -*-  *)

From Template Require Import Template Typing Checker Ast.
Require Import List String. Import ListNotations.
Set Printing Universes.

Definition T := Type.
Definition T' := T.
(* Definition foo' := (T : T'). *)
Fail Definition foo' := let T := Type in (T : T).

Quote Recursively Definition p := foo'.
(* Template Check foo'. *)
Eval lazy in (let '(Σ, t) := decompose_program p ([], init_graph) in
    (* infer_term Σ t). *)
let t := (tSort (Universe.super (Level.Level "Top.10"))) in
let u := (tSort (Universe.make (Level.Level "Top.10"))) in
let Γ := [] in
(* leq_term (snd Σ) t u). *)
isconv Σ fuel Cumul Γ t [] u []).
