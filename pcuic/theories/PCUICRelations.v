Require Import ssreflect.
Require Export CRelationClasses.
Require Export Equations.Type.Relation Equations.Type.Relation_Properties.


Section Flip.
  Local Set Universe Polymorphism.
  Context {A : Type} (R : crelation A).

  Lemma flip_Reflexive : Reflexive R -> Reflexive (flip R).
  Proof.
    intros HR x. unfold flip. apply reflexivity.
  Qed.

  Lemma flip_Symmetric : Symmetric R -> Symmetric (flip R).
  Proof.
    intros HR x y. unfold flip. apply symmetry.
  Qed.

  Lemma flip_Transitive : Transitive R -> Transitive (flip R).
  Proof.
    intros HR x y z xy yz.
    unfold flip in *. eapply HR; eassumption.
  Qed.

End Flip.




Definition commutes {A} (R S : relation A) :=
  forall x y z, R x y -> S x z -> { w & S y w * R z w}%type.


Lemma clos_t_rt {A} {R : A -> A -> Type} x y : trans_clos R x y -> clos_refl_trans R x y.
Proof.
  induction 1; try solve [econstructor; eauto].
Qed.


Arguments rt_step {A} {R} {x y}.
Polymorphic Hint Resolve rt_refl rt_step : core.


Definition clos_rt_monotone {A} (R S : relation A) :
  inclusion R S -> inclusion (clos_refl_trans R) (clos_refl_trans S).
Proof.
  move => incls x y.
  induction 1; solve [econstructor; eauto].
Qed.

Lemma relation_equivalence_inclusion {A} (R S : relation A) :
  inclusion R S -> inclusion S R -> relation_equivalence R S.
Proof. firstorder. Qed.

Lemma clos_rt_disjunction_left {A} (R S : relation A) :
  inclusion (clos_refl_trans R)
            (clos_refl_trans (relation_disjunction R S)).
Proof.
  apply clos_rt_monotone.
  intros x y H; left; exact H.
Qed.

Lemma clos_rt_disjunction_right {A} (R S : relation A) :
  inclusion (clos_refl_trans S)
            (clos_refl_trans (relation_disjunction R S)).
Proof.
  apply clos_rt_monotone.
  intros x y H; right; exact H.
Qed.

Global Instance clos_rt_trans A R : Transitive (@clos_refl_trans A R).
Proof.
  intros x y z H H'. econstructor 3; eauto.
Qed.

Global Instance clos_rt_refl A R : Reflexive (@clos_refl_trans A R).
Proof. intros x. constructor 2. Qed.

Lemma clos_refl_trans_prod_l {A B} (R : relation A) (S : relation (A * B)) :
  (forall x y b, R x y -> S (x, b) (y, b)) ->
  forall (x y : A) b,
    clos_refl_trans R x y ->
    clos_refl_trans S (x, b) (y, b).
Proof.
  intros. induction X0; try solve [econstructor; eauto].
Qed.

Lemma clos_refl_trans_prod_r {A B} (R : relation B) (S : relation (A * B)) a :
  (forall x y, R x y -> S (a, x) (a, y)) ->
  forall (x y : B),
    clos_refl_trans R x y ->
    clos_refl_trans S (a, x) (a, y).
Proof.
  intros. induction X0; try solve [econstructor; eauto].
Qed.

Lemma clos_rt_t_incl {A} {R : relation A} `{Reflexive A R} :
  inclusion (clos_refl_trans R) (trans_clos R).
Proof.
  intros x y. induction 1; try solve [econstructor; eauto].
Qed.

Lemma clos_t_rt_incl {A} {R : relation A} `{Reflexive A R} :
  inclusion (trans_clos R) (clos_refl_trans R).
Proof.
  intros x y. induction 1; try solve [econstructor; eauto].
Qed.

Lemma clos_t_rt_equiv {A} {R} `{Reflexive A R} :
  relation_equivalence (trans_clos R) (clos_refl_trans R).
Proof.
  apply relation_equivalence_inclusion.
  apply clos_t_rt_incl.
  apply clos_rt_t_incl.
Qed.

Global Instance relation_disjunction_refl_l {A} {R S : relation A} :
  Reflexive R -> Reflexive (relation_disjunction R S).
Proof.
  intros HR x. left; auto.
Qed.

Global Instance relation_disjunction_refl_r {A} {R S : relation A} :
  Reflexive S -> Reflexive (relation_disjunction R S).
Proof.
  intros HR x. right; auto.
Qed.
