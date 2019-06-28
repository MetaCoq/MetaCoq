(* Distributed under the terms of the MIT license.   *)

From Coq Require Import Bool String List Program BinPos Compare_dec Arith Lia
     Classes.RelationClasses Omega.
From MetaCoq.Template Require Import config Universes monad_utils utils BasicAst
     AstUtils UnivSubst.
From MetaCoq.PCUIC Require Import PCUICAst PCUICAstUtils PCUICInduction
     PCUICReflect PCUICLiftSubst PCUICUnivSubst PCUICTyping
     PCUICCumulativity PCUICSR PCUICPosition PCUICEquality PCUICNameless
     PCUICNormal PCUICInversion PCUICCumulativity.
From Equations Require Import Equations.

Require Import Equations.Prop.DepElim.

Import MonadNotation.

Set Equations With UIP.

Inductive conv_pb :=
| Conv
| Cumul.

Notation "∥ T ∥" := (squash T) (at level 10).
Arguments sq {_} _.

Notation "( x ; y )" := (existT _ x y).

Ltac rdestruct H :=
  match type of H with
  | _ /\ _ => let H' := fresh H in
            destruct H as [H H']; rdestruct H; rdestruct H'
  | _ × _ => let H' := fresh H in
            destruct H as [H H']; rdestruct H; rdestruct H'
  | sigT _ => let H' := fresh H in
             destruct H as [H H']; rdestruct H; rdestruct H'
  | _ => idtac
  end.

Definition conv leq Σ Γ u v :=
  match leq with
  | Conv => ∥ Σ ;;; Γ |- u = v ∥
  | Cumul => ∥ Σ ;;; Γ |- u <= v ∥
  end.

Definition nodelta_flags := RedFlags.mk true true true false true true.

Inductive dlexprod {A} {B : A -> Type}
          (leA : A -> A -> Prop) (leB : forall x, B x -> B x -> Prop)
  : sigT B -> sigT B -> Prop :=
| left_lex : forall x x' y y', leA x x' -> dlexprod leA leB (x;y) (x';y')
| right_lex : forall x y y', leB x y y' -> dlexprod leA leB (x;y) (x;y').

Derive Signature for dlexprod.

Definition lexprod := Subterm.lexprod.
Arguments lexprod {_ _} _ _ _ _.

Notation "x ⊩ R1 ⨶ R2" :=
  (dlexprod R1 (fun x => R2)) (at level 20, right associativity).
Notation "R1 ⊗ R2" :=
  (lexprod R1 R2) (at level 20, right associativity).

Lemma acc_dlexprod :
  forall A B leA leB,
    (forall x, well_founded (leB x)) ->
    forall x,
      Acc leA x ->
      forall y,
        Acc (leB x) y ->
        Acc (@dlexprod A B leA leB) (x;y).
Proof.
  intros A B leA leB hw.
  induction 1 as [x hx ih1].
  intros y.
  induction 1 as [y hy ih2].
  constructor.
  intros [x' y'] h. simple inversion h.
  - intro hA. inversion H0. inversion H1. subst.
    eapply ih1.
    + assumption.
    + apply hw.
  - intro hB. rewrite <- H0.
    pose proof (projT2_eq H1) as p2.
    set (projT1_eq H1) as p1 in *; cbn in p1.
    destruct p1; cbn in p2; destruct p2.
    eapply ih2. assumption.
Qed.

Lemma dlexprod_Acc :
  forall A B leA leB,
    (forall x, well_founded (leB x)) ->
    forall x y,
      Acc leA x ->
      Acc (@dlexprod A B leA leB) (x;y).
Proof.
  intros A B leA leB hB x y hA.
  eapply acc_dlexprod ; try assumption.
  apply hB.
Qed.

Lemma dlexprod_trans :
  forall A B RA RB,
    transitive RA ->
    (forall x, transitive (RB x)) ->
    transitive (@dlexprod A B RA RB).
Proof.
  intros A B RA RB hA hB [u1 u2] [v1 v2] [w1 w2] h1 h2.
  revert w1 w2 h2. induction h1 ; intros w1 w2 h2.
  - dependent induction h2.
    + left. eapply hA ; eassumption.
    + left. assumption.
  - dependent induction h2.
    + left. assumption.
    + right. eapply hB ; eassumption.
Qed.

Section DestArity.
  Lemma destArity_app_aux {Γ Γ' t}
    : destArity (Γ ,,, Γ') t = option_map (fun '(ctx, s) => (Γ ,,, ctx, s))
                                          (destArity Γ' t).
  Proof.
    revert Γ'.
    induction t; cbn; intro Γ'; try reflexivity.
    - rewrite <- app_context_cons. now eapply IHt2.
    - rewrite <- app_context_cons. now eapply IHt3.
  Qed.

  Lemma destArity_app {Γ t}
    : destArity Γ t = option_map (fun '(ctx, s) => (Γ ,,, ctx, s))
                                          (destArity [] t).
  Proof.
    exact (@destArity_app_aux Γ [] t).
  Qed.

  Lemma destArity_app_Some {Γ t ctx s}
    : destArity Γ t = Some (ctx, s)
      -> ∑ ctx', destArity [] t = Some (ctx', s) /\ ctx = Γ ,,, ctx'.
  Proof.
    intros H. rewrite destArity_app in H.
    destruct (destArity [] t) as [[ctx' s']|]; cbn in *.
    exists ctx'. inversion H. now subst.
    discriminate H.
  Qed.

  Lemma destArity_tFix {mfix idx args} :
    destArity [] (mkApps (tFix mfix idx) args) = None.
  Proof.
    induction args. reflexivity.
    rewrite mkApps_nonempty. reflexivity.
    intros e; discriminate e.
  Qed.

  Lemma destArity_tApp {t u l} :
    destArity [] (mkApps (tApp t u) l) = None.
  Proof.
    induction l. reflexivity.
    rewrite mkApps_nonempty. reflexivity.
    intros e; discriminate e.
  Qed.
End DestArity.


Section Lemmata.

  Context (flags : RedFlags.t).
  Context (Σ : global_context).
  Context (hΣ : wf Σ).

  (* red is the reflexive transitive closure of one-step reduction and thus
     can't be used as well order. We thus define the transitive closure,
     but we take the symmetric version.
   *)
  Inductive cored Σ Γ: term -> term -> Prop :=
  | cored1 : forall u v, red1 Σ Γ u v -> cored Σ Γ v u
  | cored_trans : forall u v w, cored Σ Γ v u -> red1 Σ Γ v w -> cored Σ Γ w u.

  Derive Signature for cored.

  Inductive welltyped Σ Γ t : Prop :=
  | iswelltyped A : Σ ;;; Γ |- t : A -> welltyped Σ Γ t.

  Arguments iswelltyped {Σ Γ t A} h.

  Definition wellformed Σ Γ t :=
    welltyped Σ Γ t \/ ∥ isWfArity typing Σ Γ t ∥.

  Lemma lookup_env_ConstantDecl_inv :
    forall k k' ty bo uni,
      Some (ConstantDecl k' {| cst_type := ty ; cst_body := bo; cst_universes := uni |})
      = lookup_env Σ k ->
      k = k'.
  Proof.
    intros k k' ty bo uni h.
    destruct Σ as [Σ' φ].
    induction Σ' in h |- *.
    - cbn in h. discriminate.
    - cbn in h. destruct (ident_eq_spec k (global_decl_ident a)).
      + subst. inversion h. reflexivity.
      + apply IHΣ' in h. assumption.
  Qed.

  Lemma fresh_global_nl :
    forall Σ' k,
      fresh_global k Σ' ->
      fresh_global k (map nl_global_decl Σ').
  Proof.
    intros Σ' k h. eapply Forall_map.
    eapply Forall_impl ; try eassumption.
    intros x hh. cbn in hh.
    destruct x ; assumption.
  Qed.

  Lemma wf_nlg :
    wf (nlg Σ).
  Proof.
    destruct Σ as [Σ' φ].
    unfold nlg. unfold wf in *. unfold on_global_env in *. simpl in *.
    induction Σ'.
    - assumption.
    - simpl. inversion hΣ. subst.
      constructor.
      + eapply IHΣ'. assumption.
      + destruct a.
        * simpl in *. eapply fresh_global_nl. assumption.
        * simpl in *. eapply fresh_global_nl. assumption.
      + destruct a.
        * simpl in *. destruct c as [ty [bo |] uni].
          -- cbn in *.
             (* Need type_nl or something *)
             admit.
          -- cbn in *. (* same *)
             admit.
        * simpl in *. destruct m. admit.
  Admitted.

  Lemma welltyped_nlg :
    forall Γ t,
      welltyped Σ Γ t ->
      welltyped (nlg Σ) Γ t.
  Admitted.

  Lemma wellformed_nlg :
    forall Γ t,
      wellformed Σ Γ t ->
      wellformed (nlg Σ) Γ t.
  Admitted.

  Lemma type_rename :
    forall Γ u v A,
      Σ ;;; Γ |- u : A ->
      eq_term (snd Σ) u v ->
      Σ ;;; Γ |- v : A.
  Admitted.

  Lemma welltyped_rename :
    forall Γ u v,
      welltyped Σ Γ u ->
      eq_term (snd Σ) u v ->
      welltyped Σ Γ v.
  Proof.
    intros Γ u v [A h] e.
    exists A. eapply type_rename ; eauto.
  Qed.

  Lemma wellformed_rename :
    forall Γ u v,
      wellformed Σ Γ u ->
      eq_term (snd Σ) u v ->
      wellformed Σ Γ v.
  Proof.
  Admitted.

  Lemma red_cored_or_eq :
    forall Γ u v,
      red Σ Γ u v ->
      cored Σ Γ v u \/ u = v.
  Proof.
    intros Γ u v h.
    induction h.
    - right. reflexivity.
    - destruct IHh.
      + left. eapply cored_trans ; eassumption.
      + subst. left. constructor. assumption.
  Qed.

  Lemma cored_it_mkLambda_or_LetIn :
    forall Γ Δ u v,
      cored Σ (Γ ,,, Δ) u v ->
      cored Σ Γ (it_mkLambda_or_LetIn Δ u)
               (it_mkLambda_or_LetIn Δ v).
  Proof.
    intros Γ Δ u v h.
    induction h.
    - constructor. apply red1_it_mkLambda_or_LetIn. assumption.
    - eapply cored_trans.
      + eapply IHh.
      + apply red1_it_mkLambda_or_LetIn. assumption.
  Qed.

  Lemma red_it_mkLambda_or_LetIn :
    forall Γ Δ u v,
      red Σ (Γ ,,, Δ) u v ->
      red Σ Γ (it_mkLambda_or_LetIn Δ u)
              (it_mkLambda_or_LetIn Δ v).
  Proof.
    intros Γ Δ u v h.
    induction h.
    - constructor.
    - econstructor.
      + eassumption.
      + eapply red1_it_mkLambda_or_LetIn. assumption.
  Qed.

  Lemma cored_welltyped :
    forall {Γ u v},
      welltyped Σ Γ u ->
      cored (fst Σ) Γ v u ->
      welltyped Σ Γ v.
  Proof.
    intros Γ u v h r.
    revert h. induction r ; intros h.
    - destruct h as [A h]. exists A.
      eapply sr_red1 ; eauto with wf.
    - specialize IHr with (1 := ltac:(eassumption)).
      destruct IHr as [A ?]. exists A.
      eapply sr_red1 ; eauto with wf.
  Qed.

  Lemma cored_trans' :
    forall {Γ u v w},
      cored Σ Γ u v ->
      cored Σ Γ v w ->
      cored Σ Γ u w.
  Proof.
    intros Γ u v w h1 h2. revert w h2.
    induction h1 ; intros z h2.
    - eapply cored_trans ; eassumption.
    - eapply cored_trans.
      + eapply IHh1. assumption.
      + assumption.
  Qed.

  (* This suggests that this should be the actual definition.
     ->+ = ->*.->
   *)
  Lemma cored_red_trans :
    forall Γ u v w,
      red Σ Γ u v ->
      red1 Σ Γ v w ->
      cored Σ Γ w u.
  Proof.
    intros Γ u v w h1 h2.
    revert w h2. induction h1 ; intros w h2.
    - constructor. assumption.
    - eapply cored_trans.
      + eapply IHh1. eassumption.
      + assumption.
  Qed.

  Lemma red_case_c :
    forall Γ indn p c brs c',
      red Σ Γ c c' ->
      red Σ Γ (tCase indn p c brs) (tCase indn p c' brs).
  Proof.
    intros Γ indn p c brs c' h.
    induction h.
    - constructor.
    - econstructor ; try eassumption.
      constructor. assumption.
  Qed.

  Lemma cored_case :
    forall Γ ind p c c' brs,
      cored Σ Γ c c' ->
      cored Σ Γ (tCase ind p c brs) (tCase ind p c' brs).
  Proof.
    intros Γ ind p c c' brs h.
    revert ind p brs. induction h ; intros ind p brs.
    - constructor. constructor. assumption.
    - eapply cored_trans.
      + eapply IHh.
      + econstructor. assumption.
  Qed.

  Lemma welltyped_context :
    forall Γ t,
      welltyped Σ Γ (zip t) ->
      welltyped Σ (Γ ,,, stack_context (snd t)) (fst t).
  Proof.
    intros Γ [t π] h.
    destruct h as [T h].
    revert Γ t T h.
    induction π ; intros Γ u T h.
    - cbn. cbn in h. eexists. eassumption.
    - cbn. cbn in h. cbn in IHπ. apply IHπ in h.
      destruct h as [B h].
      apply inversion_App in h as hh.
      destruct hh as [na [A' [B' [? [? ?]]]]].
      eexists. eassumption.
    - cbn. cbn in h. cbn in IHπ. apply IHπ in h.
      destruct h as [B h].
            apply inversion_App in h as hh.
      destruct hh as [na [A' [B' [? [? ?]]]]].
      eexists. eassumption.
    - cbn. cbn in h. cbn in IHπ. apply IHπ in h.
      destruct h as [B h].
            apply inversion_App in h as hh.
      destruct hh as [na [A' [B' [? [? ?]]]]].
      eexists. eassumption.
    - cbn. cbn in h. cbn in IHπ. apply IHπ in h.
      destruct h as [B h].
      destruct indn.
      apply inversion_Case in h as hh.
      destruct hh
        as [uni [args [mdecl [idecl [pty [indctx [pctx [ps [btys [? [? [? [? [? [? [ht0 [? ?]]]]]]]]]]]]]]]]].
      eexists. eassumption.
    - cbn. cbn in h. cbn in IHπ. apply IHπ in h.
      destruct h as [T' h].
      apply inversion_Proj in h
        as [uni [mdecl [idecl [pdecl [args [? [? [? ?]]]]]]]].
      eexists. eassumption.
    - cbn. cbn in h. cbn in IHπ. apply IHπ in h.
      destruct h as [T' h].
      apply inversion_Prod in h as hh.
      destruct hh as [s1 [s2 [? [? ?]]]].
      eexists. eassumption.
    - cbn. cbn in h. cbn in IHπ. apply IHπ in h.
      destruct h as [T' h].
      apply inversion_Prod in h as hh.
      destruct hh as [s1 [s2 [? [? ?]]]].
      eexists. eassumption.
    - cbn. cbn in h. cbn in IHπ. apply IHπ in h.
      destruct h as [T' h].
      apply inversion_Lambda in h as hh.
      destruct hh as [s1 [B [? [? ?]]]].
      eexists. eassumption.
    - cbn. cbn in h. cbn in IHπ. apply IHπ in h.
      destruct h as [T' h].
      apply inversion_Lambda in h as hh.
      destruct hh as [s1 [B [? [? ?]]]].
      eexists. eassumption.
    - cbn. cbn in h. cbn in IHπ. apply IHπ in h.
      destruct h as [B h].
      apply inversion_App in h as hh.
      destruct hh as [na [A' [B' [? [? ?]]]]].
      eexists. eassumption.
  Qed.

  Lemma wellformed_context :
    forall Γ t,
      wellformed Σ Γ (zip t) ->
      wellformed Σ (Γ ,,, stack_context (snd t)) (fst t).
  Proof.
    intros Γ [t π] [[A h]|h].
    - destruct (welltyped_context Γ (t, π) (iswelltyped h)) as [A' X].
      left; econstructor; eassumption.
    - revert t h; induction π; intros t0 h; (try specialize (IHπ _ h)); cbn in *.
      now right.
      all: destruct IHπ as [[AA HA]|[[ctx [s [h1 h2]]]]]; [|try discriminate].
      all: try (apply inversion_App in HA; rdestruct HA;
                left; econstructor; eassumption).
      + destruct indn; apply inversion_Case in HA; cbn in HA; rdestruct HA;
          left; econstructor; eassumption.
      + apply inversion_Proj in HA; rdestruct HA; left; econstructor; eassumption. 
      + apply inversion_Prod in HA; rdestruct HA; left; econstructor; eassumption. 
      + cbn in h1; apply destArity_app_Some in h1. destruct h1 as [ctx' [h1 h1']].
        subst. left. rewrite app_context_assoc in h2; cbn in *.
        apply wf_local_app in h2. inversion h2; subst; cbn in *.
        destruct X0; econstructor; eassumption.
      + apply inversion_Prod in HA; rdestruct HA; left; econstructor; eassumption. 
      + cbn in h1; apply destArity_app_Some in h1. destruct h1 as [ctx' [h1 h1']].
        subst. right; constructor; exists ctx', s.
        rewrite app_context_assoc in h2; cbn in h2.
        now split.
      + apply inversion_Lambda in HA; rdestruct HA;
          left; econstructor; eassumption. 
      + apply inversion_Lambda in HA; rdestruct HA;
          left; econstructor; eassumption. 
  Qed.

  Lemma cored_red :
    forall Γ u v,
      cored Σ Γ v u ->
      ∥ red Σ Γ u v ∥.
  Proof.
    intros Γ u v h.
    induction h.
    - constructor. econstructor.
      + constructor.
      + assumption.
    - destruct IHh as [r].
      constructor. econstructor ; eassumption.
  Qed.

  Lemma cored_context :
    forall Γ t u π,
      cored Σ (Γ ,,, stack_context π) t u ->
      cored Σ Γ (zip (t, π)) (zip (u, π)).
  Proof.
    intros Γ t u π h. induction h.
    - constructor. eapply red1_context. assumption.
    - eapply cored_trans.
      + eapply IHh.
      + eapply red1_context. assumption.
  Qed.

  Lemma cored_zipx :
    forall Γ u v π,
      cored Σ (Γ ,,, stack_context π) u v ->
      cored Σ [] (zipx Γ u π) (zipx Γ v π).
  Proof.
    intros Γ u v π h.
    eapply cored_it_mkLambda_or_LetIn.
    eapply cored_context.
    rewrite app_context_nil_l.
    assumption.
  Qed.

  Lemma red_zipx :
    forall Γ u v π,
      red Σ (Γ ,,, stack_context π) u v ->
      red Σ [] (zipx Γ u π) (zipx Γ v π).
  Proof.
    intros Γ u v π h.
    eapply red_it_mkLambda_or_LetIn.
    eapply red_context.
    rewrite app_context_nil_l.
    assumption.
  Qed.

  Lemma red_trans :
    forall Γ u v w,
      red (fst Σ) Γ u v ->
      red (fst Σ) Γ v w ->
      red (fst Σ) Γ u w.
  Proof.
    intros Γ u v w h1 h2.
    revert u h1. induction h2 ; intros u h1.
    - assumption.
    - specialize IHh2 with (1 := h1).
      eapply trans_red.
      + eapply IHh2.
      + assumption.
  Qed.

  Lemma conv_refl' :
    forall leq Γ t,
      conv leq Σ Γ t t.
  Proof.
    intros leq Γ t.
    destruct leq.
    - cbn. constructor. apply conv_refl.
    - cbn. constructor. apply cumul_refl'.
  Qed.

  Lemma conv_sym :
    forall Γ u v,
      Σ ;;; Γ |- u = v ->
      Σ ;;; Γ |- v = u.
  Proof.
    intros Γ u v [h1 h2].
    econstructor ; assumption.
  Qed.

  Lemma conv_conv :
    forall {Γ leq u v},
      ∥ Σ ;;; Γ |- u = v ∥ ->
      conv leq Σ Γ u v.
  Proof.
    intros Γ leq u v h.
    destruct leq.
    - assumption.
    - destruct h as [[h1 h2]]. cbn.
      constructor. assumption.
  Qed.

  Lemma eq_term_conv :
    forall {Γ u v},
      eq_term (snd Σ) u v ->
      Σ ;;; Γ |- u = v.
  Proof.
    intros Γ u v e.
    constructor.
    - eapply cumul_refl.
      eapply eq_term_leq_term. assumption.
    - eapply cumul_refl.
      eapply eq_term_leq_term.
      eapply eq_term_sym.
      assumption.
  Qed.

  Lemma conv_trans :
    forall Γ u v w,
      Σ ;;; Γ |- u = v ->
      Σ ;;; Γ |- v = w ->
      Σ ;;; Γ |- u = w.
  Proof.
    intros Γ u v w h1 h2.
    destruct h1, h2. constructor ; eapply cumul_trans ; eassumption.
  Qed.

  Lemma conv_trans' :
    forall leq Γ u v w,
      conv leq Σ Γ u v ->
      conv leq Σ Γ v w ->
      conv leq Σ Γ u w.
  Proof.
    intros leq Γ u v w h1 h2.
    destruct leq.
    - cbn in *. destruct h1, h2. constructor.
      eapply conv_trans ; eassumption.
    - cbn in *. destruct h1, h2. constructor. eapply cumul_trans ; eassumption.
  Qed.

  Lemma red_conv_l :
    forall leq Γ u v,
      red (fst Σ) Γ u v ->
      conv leq Σ Γ u v.
  Proof.
    intros leq Γ u v h.
    induction h.
    - apply conv_refl'.
    - eapply conv_trans' ; try eassumption.
      destruct leq.
      + simpl. constructor. constructor.
        * eapply cumul_red_l.
          -- eassumption.
          -- eapply cumul_refl'.
        * eapply cumul_red_r.
          -- eapply cumul_refl'.
          -- assumption.
      + simpl. constructor.
        eapply cumul_red_l.
        * eassumption.
        * eapply cumul_refl'.
  Qed.

  Lemma red_conv_r :
    forall leq Γ u v,
      red (fst Σ) Γ u v ->
      conv leq Σ Γ v u.
  Proof.
    intros leq Γ u v h.
    induction h.
    - apply conv_refl'.
    - eapply conv_trans' ; try eassumption.
      destruct leq.
      + simpl. constructor. constructor.
        * eapply cumul_red_r.
          -- eapply cumul_refl'.
          -- assumption.
        * eapply cumul_red_l.
          -- eassumption.
          -- eapply cumul_refl'.
      + simpl. constructor.
        eapply cumul_red_r.
        * eapply cumul_refl'.
        * assumption.
  Qed.

  Lemma conv_conv_l :
    forall leq Γ u v,
        Σ ;;; Γ |- u = v ->
        conv leq Σ Γ u v.
  Proof.
    intros [] Γ u v [h1 h2].
    - cbn. constructor. constructor ; assumption.
    - cbn. constructor. assumption.
  Qed.

  Lemma conv_conv_r :
    forall leq Γ u v,
        Σ ;;; Γ |- u = v ->
        conv leq Σ Γ v u.
  Proof.
    intros [] Γ u v [h1 h2].
    - cbn. constructor. constructor ; assumption.
    - cbn. constructor. assumption.
  Qed.

  Lemma cumul_App_l :
    forall {Γ f g x},
      Σ ;;; Γ |- f <= g ->
      Σ ;;; Γ |- tApp f x <= tApp g x.
  Proof.
    intros Γ f g x h.
    induction h.
    - eapply cumul_refl. constructor.
      + assumption.
      + apply eq_term_refl.
    - eapply cumul_red_l ; try eassumption.
      econstructor. assumption.
    - eapply cumul_red_r ; try eassumption.
      econstructor. assumption.
  Qed.

  Lemma cumul_App_r :
    forall {Γ f u v},
      Σ ;;; Γ |- u = v ->
      Σ ;;; Γ |- tApp f u <= tApp f v.
  (* Proof. *)
  (*   intros Γ f u v h. *)
  (*   induction h. *)
  (*   - eapply cumul_refl. constructor. *)
  (*     + apply leq_term_refl. *)
  (*     + assumption. *)
  (*   - eapply cumul_red_l ; try eassumption. *)
  (*     econstructor. assumption. *)
  (*   - eapply cumul_red_r ; try eassumption. *)
  (*     econstructor. assumption. *)
  (* Qed. *)
  Admitted.

  Lemma conv_App_r :
    forall {Γ f x y},
      Σ ;;; Γ |- x = y ->
      Σ ;;; Γ |- tApp f x = tApp f y.
  Proof.
    intros Γ f x y [h1 h2].
  Admitted.

  Lemma conv_Prod_l :
    forall {Γ na A1 A2 B},
      Σ ;;; Γ |- A1 = A2 ->
      Σ ;;; Γ |- tProd na A1 B = tProd na A2 B.
  Proof.
  Admitted.

  Lemma cumul_Prod_r :
    forall {Γ na A B1 B2},
      Σ ;;; Γ ,, vass na A |- B1 <= B2 ->
      Σ ;;; Γ |- tProd na A B1 <= tProd na A B2.
  Proof.
    intros Γ na A B1 B2 h.
    induction h.
    - eapply cumul_refl. constructor.
      + apply eq_term_refl.
      + assumption.
    - eapply cumul_red_l ; try eassumption.
      econstructor. assumption.
    - eapply cumul_red_r ; try eassumption.
      econstructor. assumption.
  Qed.

  Lemma conv_Prod :
    forall leq Γ na na' A1 A2 B1 B2,
      Σ ;;; Γ |- A1 = A2 ->
      conv leq Σ (Γ,, vass na A1) B1 B2 ->
      conv leq Σ Γ (tProd na A1 B1) (tProd na' A2 B2).
  Admitted.

  Lemma cumul_Case_c :
    forall Γ indn p brs u v,
      Σ ;;; Γ |- u = v ->
      Σ ;;; Γ |- tCase indn p u brs <= tCase indn p v brs.
  (* Proof. *)
  (*   intros Γ indn p brs u v h. *)
  (*   induction h. *)
  (*   - eapply cumul_refl. destruct indn. constructor. *)
  (*     + eapply eq_term_refl. *)
  (*     + assumption. *)
  (*     + eapply Forall_Forall2. eapply Forall_True. *)
  (*       intros x. split ; auto. *)
  (*       eapply eq_term_refl. *)
  (*   - eapply cumul_red_l ; try eassumption. *)
  (*     econstructor. assumption. *)
  (*   - eapply cumul_red_r ; try eassumption. *)
  (*     econstructor. assumption. *)
  (* Qed. *)
  Admitted.

  Lemma cumul_Proj_c :
    forall Γ p u v,
      Σ ;;; Γ |- u = v ->
      Σ ;;; Γ |- tProj p u <= tProj p v.
  (* Proof. *)
  (*   intros Γ p u v h. *)
  (*   induction h. *)
  (*   - eapply cumul_refl. constructor. assumption. *)
  (*   - eapply cumul_red_l ; try eassumption. *)
  (*     econstructor. assumption. *)
  (*   - eapply cumul_red_r ; try eassumption. *)
  (*     econstructor. assumption. *)
  (* Qed. *)
  Admitted.

  (* TODO We only use this to prove conv_context, the latter seems to be true,
     but not this one. FIXME.
   *)
  (* Lemma cumul_context : *)
  (*   forall Γ u v ρ, *)
  (*     Σ ;;; Γ |- u = v -> *)
  (*     Σ ;;; Γ |- zipc u ρ <= zipc v ρ. *)
  (* Proof. *)
  (*   intros Γ u v ρ h. *)
  (*   revert u v h. induction ρ ; intros u v h. *)
  (*   - cbn. assumption. *)
  (*   - cbn. apply IHρ. *)
  (*     eapply cumul_App_l. assumption. *)
  (*   - cbn. eapply IHρ. *)
  (*     eapply cumul_App_r. assumption. *)
  (*   - cbn. eapply IHρ. *)
  (*     eapply cumul_App_r. assumption. *)
  (*   - cbn. eapply IHρ. *)
  (*     eapply cumul_Case_c. assumption. *)
  (*   - cbn. eapply IHρ. *)
  (*     eapply cumul_Proj_c. assumption. *)
  (*   - cbn. eapply IHρ. *)
  (*     (* eapply cumul_Prod_l. assumption. *) *)
  (*     (* This is WRONG isn't it?? *) *)
  (* Admitted. *)

  Lemma conv_context :
    forall Γ u v ρ,
      Σ ;;; Γ |- u = v ->
      Σ ;;; Γ |- zipc u ρ = zipc v ρ.
  (* Proof. *)
  (*   intros Γ u v ρ []. *)
  (*   constructor ; eapply cumul_context ; assumption. *)
  (* Qed. *)
  Admitted.

  (* Lemma conv_context' : *)
  (*   forall Γ leq u v ρ, *)
  (*     conv leq Σ Γ u v -> *)
  (*     conv leq Σ Γ (zipc u ρ) (zipc v ρ). *)
  (* Proof. *)
  (*   intros Γ leq u v ρ h. *)
  (*   destruct leq. *)
  (*   - cbn in *. destruct h as [[h1 h2]]. constructor. *)
  (*     constructor ; eapply cumul_context ; assumption. *)
  (*   - cbn in *. destruct h. constructor. *)
  (*     eapply cumul_context. assumption. *)
  (* Qed. *)

  Lemma cumul_it_mkLambda_or_LetIn :
    forall Δ Γ u v,
      Σ ;;; (Δ ,,, Γ) |- u <= v ->
      Σ ;;; Δ |- it_mkLambda_or_LetIn Γ u <= it_mkLambda_or_LetIn Γ v.
  Proof.
    intros Δ Γ u v h. revert Δ u v h.
    induction Γ as [| [na [b|] A] Γ ih ] ; intros Δ u v h.
    - assumption.
    - simpl. cbn. eapply ih.
      (* Need cumul for LetIn *)
      admit.
    - simpl. cbn. eapply ih.
      (* Need cumul for Lambda *)
      admit.
  Admitted.

  Lemma cumul_zippx :
    forall Γ u v ρ,
      Σ ;;; (Γ ,,, stack_context ρ) |- u <= v ->
      Σ ;;; Γ |- zippx u ρ <= zippx v ρ.
  Proof.
    intros Γ u v ρ h.
    revert u v h. induction ρ ; intros u v h.
    - cbn. assumption.
    - unfold zippx. simpl.
      case_eq (decompose_stack ρ). intros l π e.
      unfold zippx in IHρ. rewrite e in IHρ.
      apply IHρ.
      eapply cumul_App_l. assumption.
    - unfold zippx. simpl.
      eapply cumul_it_mkLambda_or_LetIn.
      assumption.
    - unfold zippx. simpl.
      eapply cumul_it_mkLambda_or_LetIn.
      assumption.
    - unfold zippx. simpl.
      eapply cumul_it_mkLambda_or_LetIn.
      assumption.
    - unfold zippx. simpl.
      eapply cumul_it_mkLambda_or_LetIn.
      assumption.
    - unfold zippx. simpl.
      eapply cumul_it_mkLambda_or_LetIn.
      assumption.
    - unfold zippx. simpl.
      eapply cumul_it_mkLambda_or_LetIn. cbn.
      (* Need cumul for Lambda again *)
      admit.
    - unfold zippx. simpl.
      eapply cumul_it_mkLambda_or_LetIn.
      assumption.
    - unfold zippx. simpl.
      eapply cumul_it_mkLambda_or_LetIn. cbn.
      (* cumul lambda *)
      admit.
    - unfold zippx. simpl.
      eapply cumul_it_mkLambda_or_LetIn. assumption.
  Admitted.

  Lemma conv_zippx :
    forall Γ u v ρ,
      Σ ;;; Γ ,,, stack_context ρ |- u = v ->
      Σ ;;; Γ |- zippx u ρ = zippx v ρ.
  Proof.
    intros Γ u v ρ [].
    constructor ; eapply cumul_zippx ; assumption.
  Qed.

  Lemma conv_zippx' :
    forall Γ leq u v ρ,
      conv leq Σ (Γ ,,, stack_context ρ) u v ->
      conv leq Σ Γ (zippx u ρ) (zippx v ρ).
  Proof.
    intros Γ leq u v ρ h.
    destruct leq.
    - cbn in *. destruct h as [[h1 h2]]. constructor.
      constructor ; eapply cumul_zippx ; assumption.
    - cbn in *. destruct h. constructor.
      eapply cumul_zippx. assumption.
  Qed.

  (* TODO MOVE *)
  Lemma eq_term_upto_univ_isApp :
    forall Re Rle u v,
      eq_term_upto_univ Re Rle u v ->
      isApp u = isApp v.
  Proof.
    intros Re Rle u v h.
    induction h.
    all: reflexivity.
  Qed.

  (* TODO MOVE *)
  Lemma isApp_mkApps :
    forall u l,
      isApp u ->
      isApp (mkApps u l).
  Proof.
    intros u l h.
    induction l in u, h |- *.
    - cbn. assumption.
    - cbn. apply IHl. reflexivity.
  Qed.

  Lemma decompose_app_rec_notApp :
    forall t l u l',
      decompose_app_rec t l = (u, l') ->
      isApp u = false.
  Proof.
    intros t l u l' e.
    induction t in l, u, l', e |- *.
    all: try (cbn in e ; inversion e ; reflexivity).
    cbn in e. eapply IHt1. eassumption.
  Qed.

  Lemma decompose_app_notApp :
    forall t u l,
      decompose_app t = (u, l) ->
      isApp u = false.
  Proof.
    intros t u l e.
    eapply decompose_app_rec_notApp. eassumption.
  Qed.

  Fixpoint nApp t :=
    match t with
    | tApp u _ => S (nApp u)
    | _ => 0
    end.

  Lemma isApp_false_nApp :
    forall u,
      isApp u = false ->
      nApp u = 0.
  Proof.
    intros u h.
    destruct u.
    all: try reflexivity.
    discriminate.
  Qed.

  Lemma nApp_mkApps :
    forall t l,
      nApp (mkApps t l) = nApp t + #|l|.
  Proof.
    intros t l.
    induction l in t |- *.
    - simpl. omega.
    - simpl. rewrite IHl. cbn. omega.
  Qed.

  Lemma decompose_app_eq_mkApps :
    forall t u l l',
      decompose_app t = (mkApps u l', l) ->
      l' = [].
  Proof.
    intros t u l l' e.
    apply decompose_app_notApp in e.
    apply isApp_false_nApp in e.
    rewrite nApp_mkApps in e.
    destruct l' ; cbn in e ; try omega.
    reflexivity.
  Qed.

  Lemma mkApps_nApp_inj :
    forall u u' l l',
      nApp u = nApp u' ->
      mkApps u l = mkApps u' l' ->
      u = u' /\ l = l'.
  Proof.
    intros u u' l l' h e.
    induction l in u, u', l', h, e |- *.
    - cbn in e. subst.
      destruct l' ; auto.
      exfalso.
      rewrite nApp_mkApps in h. cbn in h. omega.
    - destruct l'.
      + cbn in e. subst. exfalso.
        rewrite nApp_mkApps in h. cbn in h. omega.
      + cbn in e. apply IHl in e.
        * destruct e as [e1 e2].
          inversion e1. subst. auto.
        * cbn. f_equal. auto.
  Qed.

  (* TODO MOVE *)
  Lemma mkApps_notApp_inj :
    forall u u' l l',
      isApp u = false ->
      isApp u' = false ->
      mkApps u l = mkApps u' l' ->
      u = u' /\ l = l'.
  Proof.
    intros u u' l l' h h' e.
    eapply mkApps_nApp_inj.
    - rewrite 2!isApp_false_nApp by assumption. reflexivity.
    - assumption.
  Qed.

  (* TODO MOVE *)
  Lemma eq_term_upto_univ_mkApps_inv :
    forall Re u l u' l',
      isApp u = false ->
      isApp u' = false ->
      eq_term_upto_univ Re Re (mkApps u l) (mkApps u' l') ->
      eq_term_upto_univ Re Re u u' /\ Forall2 (eq_term_upto_univ Re Re) l l'.
  Proof.
    intros Re u l u' l' hu hu' h.
    apply eq_term_upto_univ_mkApps_l_inv in h as hh.
    destruct hh as [v [args [h1 [h2 h3]]]].
    apply eq_term_upto_univ_isApp in h1 as hh1. rewrite hu in hh1.
    apply mkApps_notApp_inj in h3 ; auto.
    destruct h3 as [? ?]. subst. split ; auto.
  Qed.

  (* TODO MOVE? *)
  Lemma isConstruct_app_eq_term_l :
    forall Re Rle u v,
      isConstruct_app u ->
      eq_term_upto_univ Re Rle u v ->
      isConstruct_app v.
  Proof.
    intros Re Rle u v h e.
    case_eq (decompose_app u). intros t1 l1 e1.
    case_eq (decompose_app v). intros t2 l2 e2.
    unfold isConstruct_app in *.
    rewrite e1 in h. cbn in h.
    rewrite e2. cbn.
    destruct t1 ; try discriminate.
    apply PCUICConfluence.decompose_app_inv in e1 as ?. subst.
    apply PCUICConfluence.decompose_app_inv in e2 as ?. subst.
  (*   apply eq_term_upto_univ_mkApps_inv in e as hh. *)
  (*   - destruct hh as [h1 h2]. *)
  (*     dependent destruction h1. reflexivity. *)
  (*   - reflexivity. *)
  (*   - eapply decompose_app_notApp. eassumption. *)
  (* Qed. *)
  Admitted.

  (* TODO Duplicate of tactic in PCUICEquality *)
  Local Ltac sih :=
    lazymatch goal with
    | ih : forall Rle v n x y, _ -> eq_term_upto_univ _ _ ?u _ -> _ -> _
      |- eq_term_upto_univ _ _ (subst _ _ ?u) _ => eapply ih
    end.

  (* TODO Is it correct now? *)
  (* TODO MOVE *)
  (* Subsumes the other lemma? *)
  Lemma eq_term_upto_univ_substs :
    forall Re Rle u v n l l',
      eq_term_upto_univ Re Rle u v ->
      Forall2 (eq_term_upto_univ Re Rle) l l' ->
      eq_term_upto_univ Re Rle (subst l n u) (subst l' n v).
  Proof.
    intros Re Rle u v n l l' hu hl.
    induction u in v, n, l, l', hu, hl, Rle |- * using term_forall_list_ind.
    all: dependent destruction hu.
    all: try (cbn ; constructor ; try sih ; assumption).
(*     - cbn. destruct (Nat.leb_spec0 n n0). *)
(*       + destruct (eqb_spec n0 n). *)
(*         * subst. replace (n - n) with 0 by omega. *)
(*           destruct hl. *)
(*           -- cbn. constructor. *)
(*           -- cbn. eapply eq_term_upto_univ_lift. assumption. *)
(*         * replace (n0 - n) with (S (n0 - (S n))) by omega. *)
(*           destruct hl. *)
(*           -- cbn. constructor. *)
(*           -- cbn.  *)

(* induction hl in n |- *. *)
(*       + rewrite subst_empty. constructor. *)
(*       + cbn. destruct (Nat.leb_spec0 n n0). *)
(*         * destruct (eqb_spec n0 n). *)
(*           -- subst. replace (n - n) with 0 by omega. cbn. *)
(*              eapply eq_term_upto_univ_lift. assumption. *)
(*           -- replace (n0 - n) with (S (n0 - (S n))) by omega. cbn. *)
(*              cbn in IHhl. specialize (IHhl (S n)). *)
(*              revert IHhl. *)
(*              destruct (Nat.leb_spec0 (S n) n0) ; try (exfalso ; omega). *)
(*              case_eq (nth_error l (n0 - S n)). *)
(*              ++ intros b e. *)
(*                 case_eq (nth_error l' (n0 - S n)). *)
(*                 ** intros b' e' ih. *)



(* cbn. destruct (Nat.leb_spec0 n n0). *)
(*       + destruct (eqb_spec n0 n). *)
(*         * subst. replace (n - n) with 0 by omega. *)
(*           destruct hl. *)
(*           -- cbn. constructor. *)
(*           -- cbn. eapply eq_term_upto_univ_lift. assumption. *)
(*         * replace (n0 - n) with (S (n0 - (S n))) by omega. *)
(*           destruct hl. *)
(*           -- cbn. constructor. *)
(*           -- cbn. *)

(*           eapply eq_term_upto_univ_lift. assumption. *)
(*         * replace (n0 - n) with (S (n0 - (S n))) by omega. cbn. *)
(*           rewrite nth_error_nil. constructor. *)
(*       + constructor. *)

    (* - admit. *)
    (* - cbn. constructor. *)
    (*   eapply Forall2_map. eapply Forall2_impl' ; [ eassumption |]. *)
    (*   eapply All_Forall. *)
    (*   eapply All_impl ; [ eassumption |]. *)
    (*   intros x0 H1 y0 H2. cbn in H1. *)
    (*   eapply H1. all: assumption. *)
    (* - cbn. constructor ; try sih ; try assumption. *)
    (*   eapply Forall2_map. eapply Forall2_impl' ; [ eassumption |]. *)
    (*   eapply All_Forall. eapply All_impl ; [ eassumption |]. *)
    (*   intros ? H0 ? [? ?]. cbn in H0. repeat split ; auto. *)
    (*   eapply H0. all: assumption. *)
    (* - cbn. constructor. *)
    (*   eapply Forall2_map. eapply Forall2_impl' ; [ eassumption |]. *)
    (*   eapply All_Forall. eapply All_impl ; [ eassumption |]. *)
    (*   intros ? [h1 h2] ? [? [? ?]]. *)
    (*   repeat split ; auto. *)
    (*   + eapply h1. all: assumption. *)
    (*   + apply Forall2_length in H. rewrite H. *)
    (*     eapply h2. all: assumption. *)
    (* - cbn. constructor. *)
    (*   eapply Forall2_map. eapply Forall2_impl' ; [ eassumption |]. *)
    (*   eapply All_Forall. eapply All_impl ; [ eassumption |]. *)
    (*   intros ? [h1 h2] ? [? [? ?]]. *)
    (*   repeat split ; auto. *)
    (*   + eapply h1. all: assumption. *)
    (*   + apply Forall2_length in H. rewrite H. *)
    (*     eapply h2. all: assumption. *)
  Admitted.

  (* TODO MOVE *)
  Lemma red1_eq_term_upto_univ_l :
    forall Re Rle Γ u v u',
      Reflexive Re ->
      Reflexive Rle ->
      (forall u u' : universe, Re u u' -> Rle u u') ->
      eq_term_upto_univ Re Rle u u' ->
      red1 Σ Γ u v ->
      exists v',
        ∥ red1 Σ Γ u' v' ∥ /\
        eq_term_upto_univ Re Rle v v'.
  Proof.
    intros Re Rle Γ u v u' he hle hR e h.
    induction h in u', e, Rle, hle, hR |- *.
    - dependent destruction e. dependent destruction e1.
      eexists. split.
      + constructor. constructor.
      + eapply eq_term_upto_univ_subst ; eauto.
        eapply eq_term_upto_univ_leq ; eauto.
    - dependent destruction e.
      eexists. split.
      + constructor. constructor.
      + eapply eq_term_upto_univ_subst ; assumption.
    - dependent destruction e.
      eexists. split.
      + constructor. constructor. eassumption.
      + eapply eq_term_upto_univ_refl. assumption.
    (* - dependent destruction e. *)
    (*   apply eq_term_upto_univ_mkApps_l_inv in e2 as [? [? [h1 [h2 h3]]]]. subst. *)
    (*   dependent destruction h1. *)
    (*   eexists. split. *)
    (*   + constructor. constructor. *)
    (*   + eapply eq_term_upto_univ_mkApps. *)
    (*     * eapply Forall2_nth with (P := fun x y => eq_term_upto_univ R (snd x) (snd y)). *)
    (*       -- eapply Forall2_impl ; [ eassumption |]. *)
    (*          intros x y [? ?]. assumption. *)
    (*       -- cbn. eapply eq_term_upto_univ_refl. assumption. *)
    (*     * eapply Forall2_skipn. assumption. *)
    (* - apply eq_term_upto_univ_mkApps_l_inv in e as [? [? [h1 [h2 h3]]]]. subst. *)
    (*   dependent destruction h1. *)
    (*   unfold unfold_fix in e0. *)
    (*   case_eq (nth_error mfix idx) ; *)
    (*     try (intros e ; rewrite e in e0 ; discriminate e0). *)
    (*   intros d e. rewrite e in e0. inversion e0. subst. clear e0. *)
    (*   eapply Forall2_nth_error_Some_l in H as hh ; try eassumption. *)
    (*   destruct hh as [d' [e' [? [? erarg]]]]. *)
    (*   unfold is_constructor in e1. *)
    (*   case_eq (nth_error args (rarg d)) ; *)
    (*     try (intros bot ; rewrite bot in e1 ; discriminate e1). *)
    (*   intros a ea. rewrite ea in e1. *)
    (*   eapply Forall2_nth_error_Some_l in h2 as hh ; try eassumption. *)
    (*   destruct hh as [a' [ea' ?]]. *)
    (*   eexists. split. *)
    (*   + constructor. eapply red_fix. *)
    (*     * unfold unfold_fix. rewrite e'. reflexivity. *)
    (*     * unfold is_constructor. rewrite <- erarg. rewrite ea'. *)
    (*       eapply isConstruct_app_eq_term_l ; eassumption. *)
    (*   + eapply eq_term_upto_univ_mkApps. *)
    (*     * eapply eq_term_upto_univ_substs. *)
    (*       -- assumption. *)
    (*       -- *)
  Admitted.

  Lemma cored_eq_term_upto_univ_r :
    forall Re Rle Γ u v u',
      Reflexive Re ->
      Reflexive Rle ->
      (forall u u' : universe, Re u u' -> Rle u u') ->
      eq_term_upto_univ Re Rle u u' ->
      cored Σ Γ v u ->
      exists v',
        cored Σ Γ v' u' /\
        eq_term_upto_univ Re Rle v v'.
  Proof.
    intros Re Rle Γ u v u' he hle hR e h.
    induction h.
    - eapply red1_eq_term_upto_univ_l in X ; try exact e ; eauto.
      destruct X as [v' [[r] e']].
      exists v'. split ; auto.
      constructor. assumption.
    - specialize (IHh e). destruct IHh as [v' [c ev]].
      eapply red1_eq_term_upto_univ_l in X ; try exact ev ; eauto.
      destruct X as [w' [[?] ?]].
      exists w'. split ; auto.
      eapply cored_trans ; eauto.
  Qed.

  Lemma cored_nl :
    forall Γ u v,
      cored Σ Γ u v ->
      cored (nlg Σ) (nlctx Γ) (nl u) (nl v).
  Admitted.

  Lemma red_nl :
    forall Γ u v,
      red Σ Γ u v ->
      red (nlg Σ) (nlctx Γ) (nl u) (nl v).
  Admitted.

  Derive Signature for Acc.

  Lemma wf_fun :
    forall A (R : A -> A -> Prop) B (f : B -> A),
      well_founded R ->
      well_founded (fun x y => R (f x) (f y)).
  Proof.
    intros A R B f h x.
    specialize (h (f x)).
    dependent induction h.
    constructor. intros y h.
    eapply H0 ; try reflexivity. assumption.
  Qed.

  Lemma Acc_fun :
    forall A (R : A -> A -> Prop) B (f : B -> A) x,
      Acc R (f x) ->
      Acc (fun x y => R (f x) (f y)) x.
  Proof.
    intros A R B f x h.
    dependent induction h.
    constructor. intros y h.
    eapply H0 ; try reflexivity. assumption.
  Qed.

  Lemma welltyped_it_mkLambda_or_LetIn :
    forall Γ Δ t,
      welltyped Σ Γ (it_mkLambda_or_LetIn Δ t) ->
      welltyped Σ (Γ ,,, Δ) t.
  Proof.
    intros Γ Δ t h.
    revert Γ t h.
    induction Δ as [| [na [b|] A] Δ ih ] ; intros Γ t h.
    - assumption.
    - simpl. apply ih in h. cbn in h.
      destruct h as [T h].
      apply inversion_LetIn in h as hh.
      destruct hh as [s1 [A' [? [? [? ?]]]]].
      exists A'. assumption.
    - simpl. apply ih in h. cbn in h.
      destruct h as [T h].
      apply inversion_Lambda in h as hh.
      pose proof hh as [s1 [B [? [? ?]]]].
      exists B. assumption.
  Qed.

  (* Lemma welltyped_zipp : *)
  (*   forall Γ t ρ, *)
  (*     welltyped Σ Γ (zipp t ρ) -> *)
  (*     welltyped Σ Γ t. *)
  (* Proof. *)
  (*   intros Γ t ρ [A h]. *)
  (*   unfold zipp in h. *)
  (*   case_eq (decompose_stack ρ). intros l π e. *)
  (*   rewrite e in h. clear - h. *)
  (*   revert t A h. *)
  (*   induction l ; intros t A h. *)
  (*   - eexists. cbn in h. eassumption. *)
  (*   - cbn in h. apply IHl in h. *)
  (*     destruct h as [T h]. *)
  (*     apply inversion_App in h as hh. *)
  (*     destruct hh as [na [A' [B' [? [? ?]]]]]. *)
  (*     eexists. eassumption. *)
  (* Qed. *)

  (* Lemma welltyped_zippx : *)
  (*   forall Γ t ρ, *)
  (*     welltyped Σ Γ (zippx t ρ) -> *)
  (*     welltyped Σ (Γ ,,, stack_context ρ) t. *)
  (* Proof. *)
  (*   intros Γ t ρ h. *)
  (*   unfold zippx in h. *)
  (*   case_eq (decompose_stack ρ). intros l π e. *)
  (*   rewrite e in h. *)
  (*   apply welltyped_it_mkLambda_or_LetIn in h. *)
  (*   pose proof (decompose_stack_eq _ _ _ e). subst. *)
  (*   rewrite stack_context_appstack. *)
  (*   clear - h. destruct h as [A h]. *)
  (*   revert t A h. *)
  (*   induction l ; intros t A h. *)
  (*   - eexists. eassumption. *)
  (*   - cbn in h. apply IHl in h. *)
  (*     destruct h as [B h]. *)
  (*     apply inversion_App in h as hh. *)
  (*     destruct hh as [na [A' [B' [? [? ?]]]]]. *)
  (*     eexists. eassumption. *)
  (* Qed. *)

  Derive NoConfusion NoConfusionHom for list.

  Lemma it_mkLambda_or_LetIn_welltyped :
    forall Γ Δ t,
      welltyped Σ (Γ ,,, Δ) t ->
      welltyped Σ Γ (it_mkLambda_or_LetIn Δ t).
  Proof.
    intros Γ Δ t h.
    revert Γ t h.
    induction Δ as [| [na [b|] B] Δ ih ] ; intros Γ t h.
    - assumption.
    - simpl. eapply ih. cbn.
      destruct h as [A h].
      pose proof (typing_wf_local h) as hc.
      cbn in hc. dependent destruction hc.
      + cbn in H. inversion H.
      + cbn in H. symmetry in H. inversion H. subst. clear H.
        cbn in l.
        eexists. econstructor ; try eassumption.
        (* FIXME We need to sort B, but we only know it's a type.
           It might be a problem with the way context are wellformed.
           Let typing asks for the type to be sorted so it should
           also hold in the context.
           At least they should be synchronised.
         *)
        admit.
    - simpl. eapply ih. cbn.
      destruct h as [A h].
      pose proof (typing_wf_local h) as hc.
      cbn in hc. dependent destruction hc.
      + cbn in H. symmetry in H. inversion H. subst. clear H.
        destruct l as [s hs].
        eexists. econstructor ; eassumption.
      + cbn in H. inversion H.
  Admitted.

  (* Lemma zipx_welltyped : *)
  (*   forall {Γ t π}, *)
  (*     welltyped Σ Γ (zipc t π) -> *)
  (*     welltyped Σ [] (zipx Γ t π). *)
  (* Proof. *)
  (*   intros Γ t π h. *)
  (*   eapply it_mkLambda_or_LetIn_welltyped. *)
  (*   rewrite app_context_nil_l. *)
  (*   assumption. *)
  (* Qed. *)

  (* Lemma welltyped_zipx : *)
  (*   forall {Γ t π}, *)
  (*     welltyped Σ [] (zipx Γ t π) -> *)
  (*     welltyped Σ Γ (zipc t π). *)
  (* Proof. *)
  (*   intros Γ t π h. *)
  (*   apply welltyped_it_mkLambda_or_LetIn in h. *)
  (*   rewrite app_context_nil_l in h. *)
  (*   assumption. *)
  (* Qed. *)

  (* Lemma welltyped_zipc_zippx : *)
  (*   forall Γ t π, *)
  (*     welltyped Σ Γ (zipc t π) -> *)
  (*     welltyped Σ Γ (zippx t π). *)
  (* Proof. *)
  (*   intros Γ t π h. *)
  (*   unfold zippx. *)
  (*   case_eq (decompose_stack π). intros l ρ e. *)
  (*   pose proof (decompose_stack_eq _ _ _ e). subst. *)
  (*   eapply it_mkLambda_or_LetIn_welltyped. *)
  (*   rewrite zipc_appstack in h. zip fold in h. *)
  (*   apply welltyped_context in h ; auto. *)
  (* Qed. *)


  Lemma wellformed_it_mkLambda_or_LetIn :
    forall Γ Δ t,
      wellformed Σ Γ (it_mkLambda_or_LetIn Δ t) ->
      wellformed Σ (Γ ,,, Δ) t.
  Proof.
    intros Γ Δ t h. 
  Admitted.

  Lemma wellformed_zipp :
    forall Γ t ρ,
      wellformed Σ Γ (zipp t ρ) ->
      wellformed Σ Γ t.
  Proof.
    intros Γ t ρ h.
    unfold zipp in h.
    case_eq (decompose_stack ρ). intros l π e.
    rewrite e in h. clear - h.
    destruct h as [[A h]|[h]].
    - left. revert t A h.
      induction l ; intros t A h.
      + eexists. eassumption.
      + apply IHl in h.
        destruct h as [T h].
        apply inversion_App in h as hh.
        rdestruct hh; econstructor; eassumption.
    - right; constructor. destruct l. assumption.
      destruct h as [ctx [s [h1 _]]].
      rewrite destArity_tApp in h1; discriminate.
  Qed.

  Lemma wellformed_zippx :
    forall Γ t ρ,
      wellformed Σ Γ (zippx t ρ) ->
      wellformed Σ (Γ ,,, stack_context ρ) t.
  Proof.
    intros Γ t ρ h.
    unfold zippx in h.
    case_eq (decompose_stack ρ). intros l π e.
    rewrite e in h.
    apply wellformed_it_mkLambda_or_LetIn in h.
    pose proof (decompose_stack_eq _ _ _ e). subst.
    rewrite stack_context_appstack.
    clear - h. destruct h as [[A h]|h].
    - left. revert t A h.
      induction l ; intros t A h.
      + rdestruct h; econstructor; eassumption.
      + cbn in h. apply IHl in h.
        destruct h as [B h].
        apply inversion_App in h as hh.
        destruct hh as [na [A' [B' [? [? ?]]]]].
        eexists. eassumption.
    - right. destruct l. assumption.
      destruct h as [[ctx [s [h1 _]]]].
      rewrite destArity_tApp in h1; discriminate.
  Qed.

  Lemma it_mkLambda_or_LetIn_wellformed :
    forall Γ Δ t,
      wellformed Σ (Γ ,,, Δ) t ->
      wellformed Σ Γ (it_mkLambda_or_LetIn Δ t).
  Admitted.

  Lemma zipx_wellformed :
    forall {Γ t π},
      wellformed Σ Γ (zipc t π) ->
      wellformed Σ [] (zipx Γ t π).
  Proof.
    intros Γ t π h.
    eapply it_mkLambda_or_LetIn_wellformed.
    rewrite app_context_nil_l.
    assumption.
  Qed.

  Lemma wellformed_zipx :
    forall {Γ t π},
      wellformed Σ [] (zipx Γ t π) ->
      wellformed Σ Γ (zipc t π).
  Proof.
    intros Γ t π h.
    apply wellformed_it_mkLambda_or_LetIn in h.
    rewrite app_context_nil_l in h.
    assumption.
  Qed.

  Lemma wellformed_zipc_zippx :
    forall Γ t π,
      wellformed Σ Γ (zipc t π) ->
      wellformed Σ Γ (zippx t π).
  Proof.
    intros Γ t π h.
    unfold zippx.
    case_eq (decompose_stack π). intros l ρ e.
    pose proof (decompose_stack_eq _ _ _ e). subst.
    eapply it_mkLambda_or_LetIn_wellformed.
    rewrite zipc_appstack in h. zip fold in h.
    apply wellformed_context in h ; auto.
  Qed.


  Lemma lookup_env_const_name :
    forall {c c' d},
      lookup_env Σ c' = Some (ConstantDecl c d) ->
      c' = c.
  Proof.
    intros c c' d e. clear hΣ.
    destruct Σ as [Σ' ?]. cbn in e.
    induction Σ'.
    - cbn in e. discriminate.
    - destruct a.
      + cbn in e. destruct (ident_eq_spec c' k).
        * subst. inversion e. reflexivity.
        * apply IHΣ'. assumption.
      + cbn in e. destruct (ident_eq_spec c' k).
        * inversion e.
        * apply IHΣ'. assumption.
  Qed.

  Lemma red_const :
    forall {Γ n c u cty cb cu},
      Some (ConstantDecl n {| cst_type := cty ; cst_body := Some cb ; cst_universes := cu |})
      = lookup_env Σ c ->
      red (fst Σ) Γ (tConst c u) (subst_instance_constr u cb).
  Proof.
    intros Γ n c u cty cb cu e.
    symmetry in e.
    pose proof (lookup_env_const_name e). subst.
    econstructor.
    - econstructor.
    - econstructor.
      + exact e.
      + reflexivity.
  Qed.

  Lemma cored_const :
    forall {Γ n c u cty cb cu},
      Some (ConstantDecl n {| cst_type := cty ; cst_body := Some cb ; cst_universes := cu |})
      = lookup_env Σ c ->
      cored (fst Σ) Γ (subst_instance_constr u cb) (tConst c u).
  Proof.
    intros Γ n c u cty cb cu e.
    symmetry in e.
    pose proof (lookup_env_const_name e). subst.
    econstructor.
    econstructor.
    - exact e.
    - reflexivity.
  Qed.

  Derive Signature for cumul.
  Derive Signature for red1.

  Lemma context_conversion :
    forall {Γ t T Γ'},
      Σ ;;; Γ |- t : T ->
      PCUICSR.conv_context Σ Γ Γ' ->
      Σ ;;; Γ' |- t : T.
  Admitted.

  Lemma app_reds_r :
    forall Γ u v1 v2,
      red Σ Γ v1 v2 ->
      red Σ Γ (tApp u v1) (tApp u v2).
  Proof.
    intros Γ u v1 v2 h.
    revert u. induction h ; intros u.
    - constructor.
    - econstructor.
      + eapply IHh.
      + constructor. assumption.
  Qed.

  Lemma app_cored_r :
    forall Γ u v1 v2,
      cored Σ Γ v1 v2 ->
      cored Σ Γ (tApp u v1) (tApp u v2).
  Proof.
    intros Γ u v1 v2 h.
    induction h.
    - constructor. constructor. assumption.
    - eapply cored_trans.
      + eapply IHh.
      + constructor. assumption.
  Qed.

  Fixpoint isAppProd (t : term) : bool :=
    match t with
    | tApp t l => isAppProd t
    | tProd na A B => true
    | _ => false
    end.

  Fixpoint isProd t :=
    match t with
    | tProd na A B => true
    | _ => false
    end.

  Lemma isAppProd_isProd :
    forall Γ t,
      isAppProd t ->
      welltyped Σ Γ t ->
      isProd t.
  Proof.
    intros Γ t hp hw.
    revert Γ hp hw.
    induction t ; intros Γ hp hw.
    all: try discriminate hp.
    - reflexivity.
    - simpl in hp.
      specialize IHt1 with (1 := hp).
      assert (welltyped Σ Γ t1) as h.
      { destruct hw as [T h].
        apply inversion_App in h as hh.
        destruct hh as [na [A' [B' [? [? ?]]]]].
        eexists. eassumption.
      }
      specialize IHt1 with (1 := h).
      destruct t1.
      all: try discriminate IHt1.
      destruct hw as [T hw'].
      apply inversion_App in hw' as ihw'.
      destruct ihw' as [na' [A' [B' [hP [? ?]]]]].
      apply inversion_Prod in hP as [s1 [s2 [? [? bot]]]].
      (* dependent destruction bot. *)
      (* + discriminate e. *)
      (* + dependent destruction r. *)
      admit.
  Admitted.

  Lemma isAppProd_mkApps :
    forall t l, isAppProd (mkApps t l) = isAppProd t.
  Proof.
    intros t l. revert t.
    induction l ; intros t.
    - reflexivity.
    - cbn. rewrite IHl. reflexivity.
  Qed.

  Lemma isProdmkApps :
    forall t l,
      isProd (mkApps t l) ->
      l = [].
  Proof.
    intros t l h.
    revert t h.
    induction l ; intros t h.
    - reflexivity.
    - cbn in h. specialize IHl with (1 := h). subst.
      cbn in h. discriminate h.
  Qed.

  Lemma mkApps_Prod_nil :
    forall Γ na A B l,
      welltyped Σ Γ (mkApps (tProd na A B) l) ->
      l = [].
  Proof.
    intros Γ na A B l h.
    pose proof (isAppProd_isProd) as hh.
    specialize hh with (2 := h).
    rewrite isAppProd_mkApps in hh.
    specialize hh with (1 := eq_refl).
    apply isProdmkApps in hh. assumption.
  Qed.

  (* TODO MOVE or even replace old lemma *)
  Lemma decompose_stack_noStackApp :
    forall π l ρ,
      decompose_stack π = (l,ρ) ->
      isStackApp ρ = false.
  Proof.
    intros π l ρ e.
    destruct ρ. all: auto.
    exfalso. eapply decompose_stack_not_app. eassumption.
  Qed.

  (* TODO MOVE *)
  Lemma stack_context_decompose :
    forall π,
      stack_context (snd (decompose_stack π)) = stack_context π.
  Proof.
    intros π.
    case_eq (decompose_stack π). intros l ρ e.
    cbn. pose proof (decompose_stack_eq _ _ _ e). subst.
    rewrite stack_context_appstack. reflexivity.
  Qed.

  Lemma eq_term_trans :
    forall G u v w,
      eq_term G u v ->
      eq_term G v w ->
      eq_term G u w.
  Admitted.

  Lemma it_mkLambda_or_LetIn_inj :
    forall Γ u v,
      it_mkLambda_or_LetIn Γ u =
      it_mkLambda_or_LetIn Γ v ->
      u = v.
  Proof.
    intros Γ u v e.
    revert u v e.
    induction Γ as [| [na [b|] A] Γ ih ] ; intros u v e.
    - assumption.
    - simpl in e. cbn in e.
      apply ih in e.
      inversion e. reflexivity.
    - simpl in e. cbn in e.
      apply ih in e.
      inversion e. reflexivity.
  Qed.

  Lemma nleq_term_zipc :
    forall u v π,
      nleq_term u v ->
      nleq_term (zipc u π) (zipc v π).
  Proof.
    intros u v π h.
    eapply ssrbool.introT.
    - eapply reflect_nleq_term.
    - cbn. rewrite 2!nl_zipc. f_equal.
      eapply ssrbool.elimT.
      + eapply reflect_nleq_term.
      + assumption.
  Qed.

  Lemma nleq_term_zipx :
    forall Γ u v π,
      nleq_term u v ->
      nleq_term (zipx Γ u π) (zipx Γ v π).
  Proof.
    intros Γ u v π h.
    unfold zipx.
    eapply nleq_term_it_mkLambda_or_LetIn.
    eapply nleq_term_zipc.
    assumption.
  Qed.

  Lemma type_it_mkLambda_or_LetIn :
    forall Γ Δ t A,
      Σ ;;; Γ ,,, Δ |- t : A ->
      Σ ;;; Γ |- it_mkLambda_or_LetIn Δ t : it_mkProd_or_LetIn Δ A.
  Proof.
    intros Γ Δ t A h.
    induction Δ as [| [na [b|] B] Δ ih ] in t, A, h |- *.
    - assumption.
    - simpl. cbn. eapply ih.
      simpl in h. pose proof (typing_wf_local h) as hc.
      dependent induction hc ; inversion H. subst.
      econstructor ; try eassumption.
      (* FIXME *)
      admit.
    - simpl. cbn. eapply ih.
      pose proof (typing_wf_local h) as hc. cbn in hc.
      dependent induction hc ; inversion H. subst.
      econstructor ; try eassumption.
      (* FIXME *)
      admit.
  Admitted.

  Lemma Lambda_conv_inv :
    forall leq Γ na1 na2 A1 A2 b1 b2,
      conv leq Σ Γ (tLambda na1 A1 b1) (tLambda na2 A2 b2) ->
      ∥ Σ ;;; Γ |- A1 = A2 ∥ /\ conv leq Σ (Γ ,, vass na1 A1) b1 b2.
  Admitted.

  (* Let bindings are not injective, so it_mkLambda_or_LetIn is not either.
     However, when they are all lambdas they become injective for conversion.
     stack_contexts only produce lambdas so we can use this property on them.
   *)
  Fixpoint let_free_context (Γ : context) :=
    match Γ with
    | [] => true
    | {| decl_name := na ; decl_body := Some b ; decl_type := B |} :: Γ => false
    | {| decl_name := na ; decl_body := None ; decl_type := B |} :: Γ =>
      let_free_context Γ
    end.

  Lemma it_mkLambda_or_LetIn_let_free_conv_inv :
    forall Γ Δ1 Δ2 t1 t2,
      let_free_context Δ1 ->
      let_free_context Δ2 ->
      Σ ;;; Γ |- it_mkLambda_or_LetIn Δ1 t1 = it_mkLambda_or_LetIn Δ2 t2 ->
      PCUICSR.conv_context Σ (Γ ,,, Δ1) (Γ ,,, Δ2) × Σ ;;; Γ ,,, Δ1 |- t1 = t2.
  Admitted.

  Lemma let_free_stack_context :
    forall π,
      let_free_context (stack_context π).
  Proof.
    intros π.
    induction π.
    all: (simpl ; rewrite ?IHπ ; reflexivity).
  Qed.

  Lemma it_mkLambda_or_LetIn_stack_context_conv_inv :
    forall Γ π1 π2 t1 t2,
      Σ ;;; Γ |- it_mkLambda_or_LetIn (stack_context π1) t1
              = it_mkLambda_or_LetIn (stack_context π2) t2 ->
      PCUICSR.conv_context Σ (Γ ,,, stack_context π1) (Γ ,,, stack_context π2) ×
      Σ ;;; Γ ,,, stack_context π1 |- t1 = t2.
  Proof.
    intros Γ π1 π2 t1 t2 h.
    eapply it_mkLambda_or_LetIn_let_free_conv_inv.
    - eapply let_free_stack_context.
    - eapply let_free_stack_context.
    - assumption.
  Qed.

  Lemma it_mkLambda_or_LetIn_let_free_conv'_inv :
    forall leq Γ Δ1 Δ2 t1 t2,
      let_free_context Δ1 ->
      let_free_context Δ2 ->
      conv leq Σ Γ (it_mkLambda_or_LetIn Δ1 t1) (it_mkLambda_or_LetIn Δ2 t2) ->
      ∥ PCUICSR.conv_context Σ (Γ ,,, Δ1) (Γ ,,, Δ2) ∥ /\ conv leq Σ (Γ ,,, Δ1) t1 t2.
  Admitted.

  Lemma it_mkLambda_or_LetIn_stack_context_conv'_inv :
    forall leq Γ π1 π2 t1 t2,
      conv leq Σ Γ (it_mkLambda_or_LetIn (stack_context π1) t1)
                   (it_mkLambda_or_LetIn (stack_context π2) t2) ->
      ∥ PCUICSR.conv_context Σ (Γ ,,, stack_context π1) (Γ ,,, stack_context π2) ∥ /\
      conv leq Σ (Γ ,,, stack_context π1) t1 t2.
  Proof.
    intros leq Γ π1 π2 t1 t2 h.
    eapply it_mkLambda_or_LetIn_let_free_conv'_inv.
    - eapply let_free_stack_context.
    - eapply let_free_stack_context.
    - assumption.
  Qed.

  Lemma it_mkLambda_or_LetIn_conv' :
    forall leq Γ Δ1 Δ2 t1 t2,
      PCUICSR.conv_context Σ (Γ ,,, Δ1) (Γ ,,, Δ2) ->
      conv leq Σ (Γ ,,, Δ1) t1 t2 ->
      conv leq Σ Γ (it_mkLambda_or_LetIn Δ1 t1) (it_mkLambda_or_LetIn Δ2 t2).
  Admitted.

  Lemma Prod_conv :
    forall leq Γ na1 A1 B1 na2 A2 B2,
      Σ ;;; Γ |- A1 = A2 ->
      conv leq Σ (Γ ,, vass na1 A1) B1 B2 ->
      conv leq Σ Γ (tProd na1 A1 B1) (tProd na2 A2 B2).
  Admitted.

  Lemma it_mkLambda_or_LetIn_conv :
    forall Γ Δ1 Δ2 t1 t2,
      PCUICSR.conv_context Σ (Γ ,,, Δ1) (Γ ,,, Δ2) ->
      Σ ;;; Γ ,,, Δ1 |- t1 = t2 ->
      Σ ;;; Γ |- it_mkLambda_or_LetIn Δ1 t1 = it_mkLambda_or_LetIn Δ2 t2.
  Admitted.

  Lemma App_conv :
    forall Γ t1 t2 u1 u2,
      Σ ;;; Γ |- t1 = t2 ->
      Σ ;;; Γ |- u1 = u2 ->
      Σ ;;; Γ |- tApp t1 u1 = tApp t2 u2.
  Admitted.

  Lemma mkApps_conv_weak :
    forall Γ u1 u2 l,
      Σ ;;; Γ |- u1 = u2 ->
      Σ ;;; Γ |- mkApps u1 l = mkApps u2 l.
  Admitted.

  Lemma cored_red_cored :
    forall Γ u v w,
      cored Σ Γ w v ->
      red Σ Γ u v ->
      cored Σ Γ w u.
  Proof.
    intros Γ u v w h1 h2.
    revert u h2. induction h1 ; intros t h2.
    - eapply cored_red_trans ; eassumption.
    - eapply cored_trans.
      + eapply IHh1. assumption.
      + assumption.
  Qed.

  Lemma red_neq_cored :
    forall Γ u v,
      red Σ Γ u v ->
      u <> v ->
      cored Σ Γ v u.
  Proof.
    intros Γ u v r n.
    destruct r.
    - exfalso. apply n. reflexivity.
    - eapply cored_red_cored ; try eassumption.
      constructor. assumption.
  Qed.

  Lemma red_proj_c :
    forall Γ p c c',
      red Σ Γ c c' ->
      red Σ Γ (tProj p c) (tProj p c').
  Proof.
    intros Γ p c c' h.
    induction h in p |- *.
    - constructor.
    - econstructor.
      + eapply IHh.
      + econstructor. assumption.
  Qed.

  Lemma red_welltyped :
    forall {Γ u v},
      welltyped Σ Γ u ->
      ∥ red (fst Σ) Γ u v ∥ ->
      welltyped Σ Γ v.
  Proof.
    intros Γ u v h [r].
    revert h. induction r ; intros h.
    - assumption.
    - specialize IHr with (1 := ltac:(eassumption)).
      destruct IHr as [A ?]. exists A.
      eapply sr_red1 ; eauto with wf.
  Qed.

  Lemma red_cored_cored :
    forall Γ u v w,
      red Σ Γ v w ->
      cored Σ Γ v u ->
      cored Σ Γ w u.
  Proof.
    intros Γ u v w h1 h2.
    revert u h2. induction h1 ; intros t h2.
    - assumption.
    - eapply cored_trans.
      + eapply IHh1. assumption.
      + assumption.
  Qed.

  Lemma subject_conversion :
    forall Γ u v A B,
      Σ ;;; Γ |- u : A ->
      Σ ;;; Γ |- v : B ->
      Σ ;;; Γ |- u = v ->
      ∑ C,
        Σ ;;; Γ |- u : C ×
        Σ ;;; Γ |- v : C.
  Proof.
    intros Γ u v A B hu hv h.
    apply conv_conv_alt in h.
    apply conv_alt_red in h as [u' [v' [? [? ?]]]].
    pose proof (subject_reduction _ Γ _ _ _ hΣ hu r) as hu'.
    pose proof (subject_reduction _ Γ _ _ _ hΣ hv r0) as hv'.
    pose proof (type_rename _ _ _ _ hu' e) as hv''.
    pose proof (principal_typing _ hv' hv'') as [C [? [? hvC]]].
    apply eq_term_sym in e as e'.
    pose proof (type_rename _ _ _ _ hvC e') as huC.
    (* Not clear.*)
  Abort.

  Lemma welltyped_zipc_replace :
    forall Γ u v π,
      welltyped Σ Γ (zipc v π) ->
      welltyped Σ (Γ ,,, stack_context π) u ->
      Σ ;;; Γ ,,, stack_context π |- u = v ->
      welltyped Σ Γ (zipc u π).
  Proof.
    intros Γ u v π hv hu heq.
    induction π in u, v, hu, hv, heq |- *.
    - simpl in *. assumption.
    - simpl in *. eapply IHπ.
      + eassumption.
      + zip fold in hv. apply welltyped_context in hv.
        simpl in hv.
        destruct hv as [Tv hv].
        destruct hu as [Tu hu].
        apply inversion_App in hv as ihv.
        destruct ihv as [na [A' [B' [hv' [ht ?]]]]].
        (* Seems to be derivable (tediously) from some principal type lemma. *)
        admit.
      + (* Congruence *)
        admit.
  Admitted.

  Lemma conv_context_conversion :
    forall {Γ u v Γ'},
      Σ ;;; Γ |- u = v ->
      PCUICSR.conv_context Σ Γ Γ' ->
      Σ ;;; Γ' |- u = v.
  Admitted.

  (* Lemma subj_cumul : *)
  (*   forall {Γ u v A B}, *)
  (*     Σ ;;; Γ |- u <= v -> *)
  (*     Σ ;;; Γ |- u : A -> *)
  (*     Σ ;;; Γ |- v : B -> *)
  (*     Σ ;;; Γ |- u : B. *)
  (* Proof. *)
  (*   intros Γ u v A B h hu hv. *)
  (*   induction h in A, hu, B, hv |- *. *)
  (*   - admit. *)
  (*   -  *)

  (* Maybe this one is wrong *)
  (* Lemma subj_conv : *)
  (*   forall {Γ u v U V}, *)
  (*     Σ ;;; Γ |- u = v -> *)
  (*     Σ ;;; Γ |- u : U -> *)
  (*     Σ ;;; Γ |- v : V -> *)
  (*     Σ ;;; Γ |- U = V. *)
  (* Admitted. *)

  (* Lemma welltyped_zipc_change_hole : *)
  (*   forall Γ u v π, *)
  (*     welltyped Σ Γ (zipc u π) -> *)
  (*     welltyped Σ (Γ ,,, stack_context π) v -> *)
  (*     Σ ;;; Γ ,,, stack_context π |- u = v -> *)
  (*     welltyped Σ Γ (zipc v π). *)
  (* Proof. *)
  (*   intros Γ u v π h hv e. *)
  (*   induction π in u, v, h, hv, e |- *. *)
  (*   - assumption. *)
  (*   - cbn. *)
  (*     eapply IHπ. *)
  (*     + exact h. *)
  (*     + *)

  (* Lemma welltyped_zipc_change_hole : *)
  (*   forall Γ u v π A, *)
  (*     welltyped Σ Γ (zipc u π) -> *)
  (*     Σ ;;; Γ ,,, stack_context π |- u : A -> *)
  (*     Σ ;;; Γ ,,, stack_context π |- v : A -> *)
  (*     welltyped Σ Γ (zipc v π). *)
  (* Proof. *)
  (*   intros Γ u v π A h hu hv. *)
  (*   induction π in u, v, A, h, hu, hv |- *. *)
  (*   - econstructor. eassumption. *)
  (*   - cbn. *)
  (*     pose proof h as h'. cbn in h'. zip fold in h'. *)
  (*     apply welltyped_context in h'. simpl in h'. *)
  (*     destruct h' as [B h']. *)
  (*     destruct (inversion_App h') as [na [A' [B' [[hu'] [[?] [?]]]]]]. *)
  (*     simpl in hu, hv. *)
  (*     destruct (principle_typing hu hu') as [C [[? ?] ?]]. *)
  (*     eapply IHπ. *)
  (*     + exact h. *)
  (*     + eassumption. *)
  (*     + econstructor. all: try eassumption. *)
  (*       * econstructor ; try eassumption. *)

End Lemmata.