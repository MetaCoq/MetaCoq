(* Distributed under the terms of the MIT license.   *)
Set Warnings "-notation-overridden".

From Coq Require Import Bool List Program Lia CRelationClasses Arith.
From MetaCoq.Template Require Import config utils.
From MetaCoq.PCUIC Require Import PCUICAst PCUICAstUtils PCUICLiftSubst PCUICUnivSubst PCUICTyping
     PCUICInduction PCUICReduction PCUICClosed.
Require Import String.
Local Open Scope string_scope.
Set Asymmetric Patterns.

Require Import ssreflect ssrbool.

From Equations Require Import Equations.

Local Ltac inv H := inversion H; subst.

(** Closed single substitution: no lifting involved and one term at a time. *)

Fixpoint csubst t k u :=
  match u with
  | tRel n =>
     match Nat.compare k n with
    | Datatypes.Eq => t
    | Gt => tRel n
    | Lt => tRel (Nat.pred n)
    end
  | tEvar ev args => tEvar ev (List.map (csubst t k) args)
  | tLambda na T M => tLambda na (csubst t k T) (csubst t (S k) M)
  | tApp u v => tApp (csubst t k u) (csubst t k v)
  | tProd na A B => tProd na (csubst t k A) (csubst t (S k) B)
  | tLetIn na b ty b' => tLetIn na (csubst t k b) (csubst t k ty) (csubst t (S k) b')
  | tCase ind p c brs =>
    let brs' := List.map (on_snd (csubst t k)) brs in
    tCase ind (csubst t k p) (csubst t k c) brs'
  | tProj p c => tProj p (csubst t k c)
  | tFix mfix idx =>
    let k' := List.length mfix + k in
    let mfix' := List.map (map_def (csubst t k) (csubst t k')) mfix in
    tFix mfix' idx
  | tCoFix mfix idx =>
    let k' := List.length mfix + k in
    let mfix' := List.map (map_def (csubst t k) (csubst t k')) mfix in
    tCoFix mfix' idx
  | x => x
  end.

(** It is equivalent to general substitution on closed terms. *)  
Lemma closed_subst t k u : closed t ->
    csubst t k u = subst [t] k u.
Proof.
  revert k; induction u using term_forall_list_ind; intros k Hs; 
    simpl; try f_equal; eauto with pcuic; solve_all.
  - destruct (PeanoNat.Nat.compare_spec k n).
    + subst k.
      rewrite PeanoNat.Nat.leb_refl minus_diag /=.
      now rewrite lift_closed.
    + destruct (leb_spec_Set k n); try lia.
      destruct (nth_error_spec [t] (n - k) ).
      simpl in l0; lia.
      now rewrite Nat.sub_1_r.
    + now destruct (Nat.leb_spec k n); try lia.
Qed.
