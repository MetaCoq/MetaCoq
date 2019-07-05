(* Distributed under the terms of the MIT license.   *)

From Coq Require Import Bool String List Program BinPos Compare_dec Arith Lia
     Classes.RelationClasses Omega.
From MetaCoq.Template Require Import config Universes monad_utils utils BasicAst
     AstUtils UnivSubst.
From MetaCoq.PCUIC Require Import PCUICAst PCUICAstUtils PCUICInduction
     PCUICReflect PCUICLiftSubst PCUICUnivSubst PCUICTyping
     PCUICCumulativity PCUICSR PCUICPosition PCUICEquality PCUICNameless
     PCUICNormal PCUICInversion PCUICCumulativity PCUICReduction.
From Equations Require Import Equations.

Require Import Equations.Prop.DepElim.

Import MonadNotation.

Set Equations With UIP.

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
  Context (hΣ : ∥ wf Σ ∥).

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
    ∥ wf (nlg Σ) ∥.
  Proof.
    destruct hΣ as [wΣ]; clear hΣ. constructor.
    destruct Σ as [Σ' φ].
    unfold nlg. unfold wf in *. unfold on_global_env in *. simpl in *.
    induction Σ'.
    - assumption.
    - simpl. inversion wΣ. subst.
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

  Lemma cored_welltyped :
    forall {Γ u v},
      welltyped Σ Γ u ->
      cored (fst Σ) Γ v u ->
      welltyped Σ Γ v.
  Proof.
    destruct hΣ as [wΣ]; clear hΣ.
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

  Lemma conv_context :
    forall Γ u v ρ,
      Σ ;;; Γ ,,, stack_context ρ |- u = v ->
      Σ ;;; Γ |- zipc u ρ = zipc v ρ.
  Proof.
    intros Γ u v ρ h.
    induction ρ in u, v, h |- *.
    - assumption.
    - simpl. eapply IHρ. eapply conv_App_l. assumption.
    - simpl. eapply IHρ. eapply conv_App_r. assumption.
    - simpl. eapply IHρ. eapply conv_App_r. assumption.
    - simpl. eapply IHρ. eapply conv_Case_c. assumption.
    - simpl. eapply IHρ. eapply conv_Proj_c. assumption.
    - simpl. eapply IHρ. eapply conv_Prod_l. assumption.
    - simpl. eapply IHρ. eapply conv_Prod_r. assumption.
    - simpl. eapply IHρ. eapply conv_Lambda_l. assumption.
    - simpl. eapply IHρ. eapply conv_Lambda_r. assumption.
    - simpl. eapply IHρ. eapply conv_App_r. assumption.
  Qed.

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
      eapply cumul_Lambda_r.
      assumption.
    - unfold zippx. simpl.
      eapply cumul_it_mkLambda_or_LetIn.
      assumption.
    - unfold zippx. simpl.
      eapply cumul_it_mkLambda_or_LetIn. cbn.
      eapply cumul_Lambda_r.
      assumption.
    - unfold zippx. simpl.
      eapply cumul_it_mkLambda_or_LetIn. assumption.
  Qed.

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

  (* TODO MOVE? *)
  Lemma isConstruct_app_eq_term_l :
    forall Re u v,
      isConstruct_app u ->
      eq_term_upto_univ Re Re u v ->
      isConstruct_app v.
  Proof.
    intros Re u v h e.
    case_eq (decompose_app u). intros t1 l1 e1.
    case_eq (decompose_app v). intros t2 l2 e2.
    unfold isConstruct_app in *.
    rewrite e1 in h. cbn in h.
    rewrite e2. cbn.
    destruct t1 ; try discriminate.
    apply PCUICParallelReductionConfluence.decompose_app_inv in e1 as ?. subst.
    apply PCUICParallelReductionConfluence.decompose_app_inv in e2 as ?. subst.
    apply eq_term_upto_univ_mkApps_inv in e as hh.
    - destruct hh as [h1 h2].
      dependent destruction h1. reflexivity.
    - reflexivity.
    - eapply decompose_app_notApp. eassumption.
  Qed.

  (* TODO MOVE? *)
  Lemma isLambda_eq_term_l :
    forall Re u v,
      isLambda u ->
      eq_term_upto_univ Re Re u v ->
      isLambda v.
  Proof.
    intros R u v h e.
    destruct u; try discriminate.
    depelim e. auto.
  Qed.

  (* TODO MOVE *)
  Lemma red1_eq_context_upto_l :
    forall Re Γ Δ u v,
      Reflexive Re ->
      red1 Σ Γ u v ->
      eq_context_upto Re Γ Δ ->
      exists v',
        ∥ red1 Σ Δ u v' *
          eq_term_upto_univ Re Re v v' ∥.
  Proof.
    intros Re Γ Δ u v he h e.
    induction h in Δ, e |- * using red1_ind_all.
    all: try solve [
      eexists ; constructor; split ; [
        solve [ econstructor ; eauto ]
      | eapply eq_term_upto_univ_refl ; eauto
      ]
    ].
    all: try solve [
      destruct (IHh _ e) as [? [[? ?]]] ;
      eexists ; constructor; split ; [
        solve [ econstructor ; eauto ]
      | constructor; eauto ;
        eapply eq_term_upto_univ_refl ; eauto
      ]
    ].
    all: try solve [
      match goal with
      | r : red1 _ (?Γ ,, ?d) _ _ |- _ =>
        assert (e' : eq_context_upto Re (Γ,, d) (Δ,, d)) ; [
          constructor ; eauto ;
          eapply eq_term_upto_univ_refl ; eauto
        |
        ]
      end ;
      destruct (IHh _ e') as [? [[? ?]]] ;
      eexists ; constructor; split ; [
        solve [ econstructor ; eauto ]
      | constructor ; eauto ;
        eapply eq_term_upto_univ_refl ; eauto
      ]
    ].
    - assert (h : exists b',
                 option_map decl_body (nth_error Δ i) = Some (Some b') /\
                 ∥ eq_term_upto_univ Re Re body b' ∥
             ).
      { induction i in Γ, Δ, H, e |- *.
        - destruct e.
          + cbn in *. discriminate.
          + simpl in *. discriminate.
          + simpl in *. inversion H. subst. clear H.
            eexists. split ; try constructor; eauto.
        - destruct e.
          + cbn in *. discriminate.
          + simpl in *. eapply IHi in H ; eauto.
          + simpl in *. eapply IHi in H ; eauto.
      }
      destruct h as [b' [e1 [e2]]].
      eexists. constructor. split.
      + constructor. eassumption.
      + eapply eq_term_upto_univ_lift ; eauto.
    - destruct (IHh _ e) as [? [[? ?]]].
      eexists. do 2 split.
      + solve [ econstructor ; eauto ].
      + destruct ind.
        econstructor ; eauto.
        * eapply eq_term_upto_univ_refl ; eauto.
        * eapply All2_same.
          intros. split ; eauto.
          eapply eq_term_upto_univ_refl ; eauto.
    - destruct (IHh _ e) as [? [[? ?]]].
      eexists. do 2 split.
      + solve [ econstructor ; eauto ].
      + destruct ind.
        econstructor ; eauto.
        * eapply eq_term_upto_univ_refl ; eauto.
        * eapply All2_same.
          intros. split ; eauto.
          eapply eq_term_upto_univ_refl ; eauto.
    - destruct ind.
      assert (h : exists brs0,
        ∥ OnOne2 (on_Trel_eq (red1 Σ Δ) snd fst) brs brs0 *
          All2 (fun x y =>
                  (fst x = fst y) *
                  eq_term_upto_univ Re Re (snd x) (snd y))%type
         brs' brs0 ∥
      ).
      { induction X.
        - destruct p0 as [[p1 p2] p3].
          eapply p2 in e as hh.
          destruct hh as [? [[? ?]]].
          eexists. do 2 split.
          + constructor.
            instantiate (1 := (_,_)).
            split ; eauto.
          + constructor.
            * split ; eauto.
            * eapply All2_same.
              intros. split ; eauto.
              eapply eq_term_upto_univ_refl ; eauto.
        - destruct IHX as [brs0 [[? ?]]].
          eexists. do 2 split.
          + eapply OnOne2_tl. eassumption.
          + constructor.
            * split ; eauto.
              eapply eq_term_upto_univ_refl ; eauto.
            * eassumption.
      }
      destruct h as [? [[? ?]]].
      eexists. do 2 split.
      + eapply case_red_brs. eassumption.
      + econstructor. all: try eapply eq_term_upto_univ_refl ; eauto.
    - assert (h : exists ll,
        ∥ OnOne2 (red1 Σ Δ) l ll *
          All2 (eq_term_upto_univ Re Re) l' ll ∥
      ).
      { induction X.
        - destruct p as [p1 p2].
          eapply p2 in e as hh. destruct hh as [? [[? ?]]].
          eexists. do 2 split.
          + constructor. eassumption.
          + constructor.
            * assumption.
            * eapply All2_same.
              intros.
              eapply eq_term_upto_univ_refl ; eauto.
        - destruct IHX as [ll [[? ?]]].
          eexists. do 2 split.
          + eapply OnOne2_tl. eassumption.
          + constructor ; eauto.
            eapply eq_term_upto_univ_refl ; eauto.
      }
      destruct h as [? [[? ?]]].
      eexists. do 2 split.
      + eapply evar_red. eassumption.
      + constructor. assumption.
    - assert (h : exists mfix',
        ∥ OnOne2 (fun d d' =>
            red1 Σ Δ d.(dtype) d'.(dtype) ×
            (d.(dname), d.(dbody), d.(rarg)) =
            (d'.(dname), d'.(dbody), d'.(rarg))
          ) mfix0 mfix'
        *
        All2 (fun x y =>
          eq_term_upto_univ Re Re (dtype x) (dtype y) *
          eq_term_upto_univ Re Re (dbody x) (dbody y) *
          (rarg x = rarg y))%type mfix1 mfix' ∥).
      { induction X.
        - destruct p as [[p1 p2] p3].
          eapply p2 in e as hh. destruct hh as [? [[? ?]]].
          eexists. do 2 split.
          + constructor.
            instantiate (1 := mkdef _ _ _ _ _).
            split ; eauto.
          + constructor.
            * simpl. repeat split ; eauto.
              eapply eq_term_upto_univ_refl ; eauto.
            * eapply All2_same.
              intros. repeat split ; eauto.
              all: eapply eq_term_upto_univ_refl ; eauto.
        - destruct IHX as [? [[? ?]]].
          eexists. do 2 split.
          + eapply OnOne2_tl. eassumption.
          + constructor ; eauto.
            repeat split ; eauto.
            all: eapply eq_term_upto_univ_refl ; eauto.
      }
      destruct h as [? [[? ?]]].
      eexists. do 2 split.
      + eapply fix_red_ty. eassumption.
      + constructor. assumption.
    - assert (h : exists mfix',
        ∥ OnOne2 (fun d d' =>
            red1 Σ (Δ ,,, fix_context mfix0) d.(dbody) d'.(dbody) ×
            (d.(dname), d.(dtype), d.(rarg)) =
            (d'.(dname), d'.(dtype), d'.(rarg))
          ) mfix0 mfix' *
        All2 (fun x y =>
          eq_term_upto_univ Re Re (dtype x) (dtype y) *
          eq_term_upto_univ Re Re (dbody x) (dbody y) *
          (rarg x = rarg y))%type mfix1 mfix' ∥).
      { induction X.
        - destruct p as [[p1 p2] p3].
          (* eapply p3 in e as hh. destruct hh as [? [[? ?]]]. *)
          (* eexists. split. *)
          (* + constructor. constructor. *)
          (*   instantiate (1 := mkdef _ _ _ _ _). *)
          (*   split ; eauto. *)
          (* + constructor. *)
          (*   * simpl. repeat split ; eauto. *)
          (*     eapply eq_term_upto_univ_refl ; eauto. *)
          (*   * eapply Forall_Forall2. eapply Forall_True. *)
          (*     intros. repeat split ; eauto. *)
          (*     all: eapply eq_term_upto_univ_refl ; eauto. *)
          (* fix_context problem *)
          admit.
        - (* destruct IHX as [? [[? ?]]]. *)
          (* eexists. split. *)
          (* + constructor. eapply OnOne2_tl. eassumption. *)
          (* + constructor ; eauto. *)
          (*   repeat split ; eauto. *)
          (*   all: eapply eq_term_upto_univ_refl ; eauto. *)
          admit.
      }
      destruct h as [? [[? ?]]].
      eexists. do 2 split.
      + eapply fix_red_body. eassumption.
      + constructor. assumption.
    - assert (h : exists mfix',
        ∥ OnOne2 (fun d d' =>
            red1 Σ Δ d.(dtype) d'.(dtype) ×
            (d.(dname), d.(dbody), d.(rarg)) =
            (d'.(dname), d'.(dbody), d'.(rarg))
          ) mfix0 mfix' *
        All2 (fun x y =>
          eq_term_upto_univ Re Re (dtype x) (dtype y) *
          eq_term_upto_univ Re Re (dbody x) (dbody y) *
          (rarg x = rarg y))%type mfix1 mfix' ∥
      ).
      { induction X.
        - destruct p as [[p1 p2] p3].
          eapply p2 in e as hh. destruct hh as [? [[? ?]]].
          eexists. do 2 split.
          + constructor.
            instantiate (1 := mkdef _ _ _ _ _).
            split ; eauto.
          + constructor.
            * simpl. repeat split ; eauto.
              eapply eq_term_upto_univ_refl ; eauto.
            * eapply All2_same.
              intros. repeat split ; eauto.
              all: eapply eq_term_upto_univ_refl ; eauto.
        - destruct IHX as [? [[? ?]]].
          eexists. do 2 split.
          + eapply OnOne2_tl. eassumption.
          + constructor ; eauto.
            repeat split ; eauto.
            all: eapply eq_term_upto_univ_refl ; eauto.
      }
      destruct h as [? [[? ?]]].
      eexists. do 2 split.
      + eapply cofix_red_ty. eassumption.
      + constructor. assumption.
  Admitted.

Lemma All2_nth :
  forall A B P l l' n (d : A) (d' : B),
    All2 P l l' ->
    P d d' ->
    P (nth n l d) (nth n l' d').
Proof.
  intros A B P l l' n d d' h hd.
  induction n in l, l', h |- *.
  - destruct h.
    + assumption.
    + assumption.
  - destruct h.
    + assumption.
    + simpl. apply IHn. assumption.
Qed.


  (* TODO MOVE *)
  Lemma red1_eq_term_upto_univ_l :
    forall Re Rle Γ u v u',
      Reflexive Re ->
      Reflexive Rle ->
      Transitive Re ->
      Transitive Rle ->
      SubstUnivPreserving Re ->
      SubstUnivPreserving Rle ->
      (forall u u' : universe, Re u u' -> Rle u u') ->
      eq_term_upto_univ Re Rle u u' ->
      red1 Σ Γ u v ->
      exists v',
        ∥ red1 Σ Γ u' v' *
        eq_term_upto_univ Re Rle v v' ∥.
  Proof.
    intros Re Rle Γ u v u' he hle tRe tRle hRe hRle hR e h.
    induction h in u', e, tRle, Rle, hle, hRle, hR |- * using red1_ind_all.
    all: try solve [
      dependent destruction e ;
      edestruct IHh as [? [[? ?]]] ; [ .. | eassumption | ] ; eauto ;
      eexists ; do 2 split ; [
        solve [ econstructor ; eauto ]
      | constructor ; eauto
      ]
    ].
    all: try solve [
      dependent destruction e ;
      edestruct IHh as [? [[? ?]]] ; [ .. | eassumption | ] ; eauto ;
      clear h ;
      lazymatch goal with
      | r : red1 _ (?Γ,, vass ?na ?A) ?u ?v,
        e : eq_term_upto_univ _ _ ?A ?B
        |- _ =>
        let hh := fresh "hh" in
        eapply red1_eq_context_upto_l in r as hh ; revgoals ; [
          eapply eq_context_vass (* with (nb := na) *) ; [
            eapply e
          | eapply eq_context_upto_refl ; eauto
          ]
        | assumption
        | destruct hh as [? [[? ?]]]
        ]
      end ;
      eexists ; do 2 split ; [
        solve [ econstructor ; eauto ]
      | constructor ; eauto ;
        eapply eq_term_upto_univ_trans ; eauto ;
        eapply eq_term_upto_univ_leq ; eauto
      ]
    ].
    - dependent destruction e. dependent destruction e1.
      eexists. do 2 split.
      + constructor.
      + eapply eq_term_upto_univ_subst ; eauto.
    - dependent destruction e.
      eexists. do 2 split.
      + constructor.
      + eapply eq_term_upto_univ_subst ; assumption.
    - dependent destruction e.
      eexists. do 2 split.
      + constructor. eassumption.
      + eapply eq_term_upto_univ_refl ; assumption.
    - dependent destruction e.
      apply eq_term_upto_univ_mkApps_l_inv in e2 as [? [? [[h1 h2] h3]]]. subst.
      dependent destruction h1.
      eexists. do 2 split.
      + constructor.
      + eapply eq_term_upto_univ_mkApps.
        * eapply All2_nth
            with (P := fun x y => eq_term_upto_univ Re Rle (snd x) (snd y)).
          -- solve_all.
             eapply eq_term_upto_univ_leq ; eauto.
          -- cbn. eapply eq_term_upto_univ_refl ; eauto.
        * eapply PCUICParallelReduction.All2_skipn. assumption.
    - apply eq_term_upto_univ_mkApps_l_inv in e as [? [? [[h1 h2] h3]]]. subst.
      dependent destruction h1.
      unfold unfold_fix in H.
      case_eq (nth_error mfix idx) ;
        try (intros e ; rewrite e in H ; discriminate H).
      intros d e. rewrite e in H. inversion H. subst. clear H.
      eapply All2_nth_error_Some in a as hh ; try eassumption.
      destruct hh as [d' [e' [[? ?] erarg]]].
      unfold is_constructor in H0.
      destruct (isLambda (dbody d)) eqn:isl; noconf H2.
      case_eq (nth_error args (rarg d)) ;
        try (intros bot ; rewrite bot in H0 ; discriminate H0).
      intros a' ea.
      rewrite ea in H0.
      eapply All2_nth_error_Some in ea as hh ; try eassumption.
      destruct hh as [a'' [ea' ?]].
      eexists. do 2 split.
      + eapply red_fix.
        * unfold unfold_fix. rewrite e'.
          erewrite isLambda_eq_term_l; eauto.
        * unfold is_constructor. rewrite <- erarg. rewrite ea'.
          eapply isConstruct_app_eq_term_l ; eassumption.
      + eapply eq_term_upto_univ_mkApps.
        * eapply eq_term_upto_univ_substs ; eauto.
          -- eapply eq_term_upto_univ_leq ; eauto.
          -- unfold fix_subst.
             apply All2_length in a as el. rewrite <- el.
             generalize #|mfix|. intro n.
             induction n.
             ++ constructor.
             ++ constructor ; eauto.
                constructor. assumption.
        * assumption.
    - dependent destruction e.
      apply eq_term_upto_univ_mkApps_l_inv in e2 as [? [? [[h1 h2] h3]]]. subst.
      dependent destruction h1.
      unfold unfold_cofix in H.
      case_eq (nth_error mfix idx) ;
        try (intros e ; rewrite e in H ; discriminate H).
      intros d e. rewrite e in H. inversion H. subst. clear H.
      eapply All2_nth_error_Some in e as hh ; try eassumption.
      destruct hh as [d' [e' [[? ?] erarg]]].
      eexists. do 2 split.
      + eapply red_cofix_case.
        unfold unfold_cofix. rewrite e'. reflexivity.
      + constructor. all: eauto.
        eapply eq_term_upto_univ_mkApps. all: eauto.
        eapply eq_term_upto_univ_substs ; eauto.
        unfold cofix_subst.
        apply All2_length in a0 as el. rewrite <- el.
        generalize #|mfix|. intro n.
        induction n.
        * constructor.
        * constructor ; eauto.
          constructor. assumption.
    - dependent destruction e.
      apply eq_term_upto_univ_mkApps_l_inv in e as [? [? [[h1 h2] h3]]]. subst.
      dependent destruction h1.
      unfold unfold_cofix in H.
      case_eq (nth_error mfix idx) ;
        try (intros e ; rewrite e in H ; discriminate H).
      intros d e. rewrite e in H. inversion H. subst. clear H.
      eapply All2_nth_error_Some in e as hh ; try eassumption.
      destruct hh as [d' [e' [[? ?] erarg]]].
      eexists. do 2 split.
      + eapply red_cofix_proj.
        unfold unfold_cofix. rewrite e'. reflexivity.
      + constructor.
        eapply eq_term_upto_univ_mkApps. all: eauto.
        eapply eq_term_upto_univ_substs ; eauto.
        unfold cofix_subst.
        apply All2_length in a as el. rewrite <- el.
        generalize #|mfix|. intro n.
        induction n.
        * constructor.
        * constructor ; eauto.
          constructor. assumption.
    - dependent destruction e.
      eexists. do 2 split.
      + econstructor. all: eauto.
      + eapply eq_term_upto_univ_subst_instance_constr ; eauto.
        eapply eq_term_upto_univ_refl ; eauto.
    - dependent destruction e.
      apply eq_term_upto_univ_mkApps_l_inv in e as [? [? [[h1 h2] h3]]]. subst.
      dependent destruction h1.
      eapply All2_nth_error_Some in h2 as hh ; try eassumption.
      destruct hh as [arg' [e' ?]].
      eexists. do 2 split.
      + constructor. eassumption.
      + eapply eq_term_upto_univ_leq ; eauto.
    - dependent destruction e.
      edestruct IHh as [? [[? ?]]] ; [ .. | eassumption | ] ; eauto.
      clear h.
      lazymatch goal with
      | r : red1 _ (?Γ,, vdef ?na ?a ?A) ?u ?v,
        e1 : eq_term_upto_univ _ _ ?A ?B,
        e2 : eq_term_upto_univ _ _ ?a ?b
        |- _ =>
        let hh := fresh "hh" in
        eapply red1_eq_context_upto_l in r as hh ; revgoals ; [
          eapply eq_context_vdef (* with (nb := na) *) ; [
            eapply e2
          | eapply e1
          | eapply eq_context_upto_refl ; eauto
          ]
        | assumption
        | destruct hh as [? [[? ?]]]
        ]
      end.
      eexists. do 2 split.
      + eapply letin_red_body ; eauto.
      + constructor ; eauto.
        eapply eq_term_upto_univ_trans ; eauto.
        eapply eq_term_upto_univ_leq ; eauto.
    - dependent destruction e.
      assert (h : exists brs0,
                 ∥ OnOne2 (on_Trel_eq (red1 Σ Γ) snd fst) brs'0 brs0 *
                 All2 (fun x y =>
                         (fst x = fst y) *
                         (eq_term_upto_univ Re Re (snd x) (snd y))
                         )%type brs' brs0 ∥
             ).
      { induction X in a, brs'0 |- *.
        - destruct p0 as [[p1 p2] p3].
          dependent destruction a. destruct p0 as [h1 h2].
          eapply p2 in h2 as hh ; eauto.
          destruct hh as [? [[? ?]]].
          eexists. do 2 split.
          + constructor.
            instantiate (1 := (_, _)). cbn. split ; eauto.
          + constructor. all: eauto.
            split ; eauto. cbn. transitivity (fst hd) ; eauto.
        - dependent destruction a.
          destruct (IHX _ a) as [? [[? ?]]].
          eexists. do 2 split.
          + eapply OnOne2_tl. eassumption.
          + constructor. all: eauto.
      }
      destruct h as [brs0 [[? ?]]].
      eexists. do 2 split.
      + eapply case_red_brs. eassumption.
      + constructor. all: eauto.
    - dependent destruction e.
      assert (h : exists args,
                 ∥ OnOne2 (red1 Σ Γ) args' args *
                   All2 (eq_term_upto_univ Re Re) l' args ∥
             ).
      { induction X in a, args' |- *.
        - destruct p as [p1 p2].
          dependent destruction a.
          eapply p2 in e as hh ; eauto.
          destruct hh as [? [[? ?]]].
          eexists. do 2 split.
          + constructor. eassumption.
          + constructor. all: eauto.
        - dependent destruction a.
          destruct (IHX _ a) as [? [[? ?]]].
          eexists. do 2 split.
          + eapply OnOne2_tl. eassumption.
          + constructor. all: eauto.
      }
      destruct h as [? [[? ?]]].
      eexists. do 2 split.
      + eapply evar_red. eassumption.
      + constructor. all: eauto.
    - dependent destruction e.
      assert (h : exists mfix,
                 ∥ OnOne2 (fun d0 d1 =>
                     red1 Σ Γ d0.(dtype) d1.(dtype) ×
                     (d0.(dname), d0.(dbody), d0.(rarg)) =
                     (d1.(dname), d1.(dbody), d1.(rarg))
                   ) mfix' mfix *
                 All2 (fun x y =>
                   eq_term_upto_univ Re Re x.(dtype) y.(dtype) *
                   eq_term_upto_univ Re Re x.(dbody) y.(dbody) *
                   (x.(rarg) = y.(rarg)))%type mfix1 mfix ∥
             ).
      { induction X in a, mfix' |- *.
        - destruct p as [[p1 p2] p3].
          dependent destruction a.
          destruct p as [[h1 h2] h3].
          eapply p2 in h1 as hh ; eauto.
          destruct hh as [? [[? ?]]].
          eexists. do 2 split.
          + constructor.
            instantiate (1 := mkdef _ _ _ _ _).
            simpl. eauto.
          + constructor. all: eauto.
            simpl. inversion p3.
            repeat split ; eauto.
        - dependent destruction a. destruct p as [[h1 h2] h3].
          destruct (IHX _ a) as [? [[? ?]]].
          eexists. do 2 split.
          + eapply OnOne2_tl. eassumption.
          + constructor. all: eauto.
      }
      destruct h as [? [[? ?]]].
      eexists. do 2 split.
      +  eapply fix_red_ty. eassumption.
      + constructor. all: eauto.
    - dependent destruction e.
      (* assert (h : exists mfix, *)
      (*            ∥ OnOne2 (fun d0 d1 => *)
      (*                red1 Σ (Γ ,,, fix_context mfix') d0.(dbody) d1.(dbody) × *)
      (*                d0.(dtype) = d1.(dtype) *)
      (*              ) mfix' mfix ∥ /\ *)
      (*            Forall2 (fun x y => *)
      (*              eq_term_upto_univ Re Re x.(dtype) y.(dtype) /\ *)
      (*              eq_term_upto_univ Re Re x.(dbody) y.(dbody) /\ *)
      (*              x.(rarg) = y.(rarg) *)
      (*            ) mfix1 mfix *)
      (*        ). *)
      (* { set (Δ := fix_context mfix0) in *. *)
      (*   assert (Δe : Δ = fix_context mfix0) by reflexivity. *)
      (*   clearbody Δ. *)
      (*   induction X in H, mfix', Δe |- *. *)
      (*   - destruct p as [[p1 p3] p2]. *)
      (*     dependent destruction H. *)
      (*     destruct H as [h1 [h2 h3]]. *)
      (*     eapply p2 in h2 as hh ; eauto. *)
      (*     destruct hh as [? [[? ?]]]. *)
      (*     eapply red1_eq_context_upto_l in X as [x' [[? ?]]] ; revgoals. *)
      (*     { instantiate (1 := Γ ,,, fix_context (y :: l')). *)
      (*       instantiate (1 := Re). *)
      (*       rewrite Δe. *)
      (*       eapply eq_context_upto_cat. *)
      (*       - eapply eq_context_upto_refl. eauto. *)
      (*       - eapply Forall2_eq_context_upto. *)
      (*         eapply Forall2_rev. *)
      (*         eapply Forall2_mapi. *)
      (*         constructor. *)
      (*         + intro i. split. *)
      (*           * cbn. constructor. *)
      (*           * cbn. eapply eq_term_upto_univ_lift. eauto. *)
      (*         + eapply Forall2_impl ; eauto. *)
      (*           intros ? ? [? [? ?]] i. *)
      (*           split. *)
      (*           * constructor. *)
      (*           * cbn. eapply eq_term_upto_univ_lift. eauto. *)
      (*     } *)
      (*     { assumption. } *)
      (*     eexists. split. *)
      (*     + constructor. constructor. *)
      (*       instantiate (1 := mkdef _ _ _ x' _). *)
      (*       simpl. split ; eauto. *)
      (*     + constructor. all: eauto. *)
      (*       simpl. repeat split ; eauto. *)
      (*       * rewrite <- p3. eauto. *)
      (*       * eapply eq_term_upto_univ_trans ; eauto. *)
      (*   - dependent destruction H. destruct H as [h1 [h2 h3]]. *)
      (*     destruct (IHX _ H0) as [? [[? ?]]]. *)
      (*     { give_up. } *)
      (*     eexists. split. *)
      (*     + constructor. eapply OnOne2_tl. *)
      (*       (* SAME PROBLEM *) *)
      (*       admit. *)
      (*     + constructor. all: eauto. *)
      (* } *)
      (* destruct h as [? [[? ?]]]. *)
      eexists. do 2 split.
      +  eapply fix_red_body. (* eassumption. *) admit.
      + constructor. all: eauto. admit.
    - dependent destruction e.
      assert (h : exists mfix,
                 ∥ OnOne2 (fun d0 d1 =>
                     red1 Σ Γ d0.(dtype) d1.(dtype) ×
                     (d0.(dname), d0.(dbody), d0.(rarg)) =
                     (d1.(dname), d1.(dbody), d1.(rarg))
                   ) mfix' mfix *
                 All2 (fun x y =>
                   eq_term_upto_univ Re Re x.(dtype) y.(dtype) *
                   eq_term_upto_univ Re Re x.(dbody) y.(dbody) *
                   (x.(rarg) = y.(rarg)))%type mfix1 mfix ∥
             ).
      { induction X in a, mfix' |- *.
        - destruct p as [[p1 p2] p3].
          dependent destruction a.
          destruct p as [[h1 h2] h3].
          eapply p2 in h1 as hh ; eauto.
          destruct hh as [? [[? ?]]].
          eexists. do 2 split.
          + constructor.
            instantiate (1 := mkdef _ _ _ _ _).
            simpl. eauto.
          + constructor. all: eauto.
            simpl. inversion p3.
            repeat split ; eauto.
        - dependent destruction a. destruct p as [[h1 h2] h3].
          destruct (IHX _ a) as [? [[? ?]]].
          eexists. do 2 split.
          + eapply OnOne2_tl. eassumption.
          + constructor. all: eauto.
      }
      destruct h as [? [[? ?]]].
      eexists. do 2 split.
      +  eapply cofix_red_ty. eassumption.
      + constructor. all: eauto.
  Admitted.

  Lemma cored_eq_term_upto_univ_r :
    forall Re Rle Γ u v u',
      Reflexive Re ->
      Reflexive Rle ->
      Transitive Re ->
      Transitive Rle ->
      SubstUnivPreserving Re ->
      SubstUnivPreserving Rle ->
      (forall u u' : universe, Re u u' -> Rle u u') ->
      eq_term_upto_univ Re Rle u u' ->
      cored Σ Γ v u ->
      exists v',
        cored Σ Γ v' u' /\
        ∥ eq_term_upto_univ Re Rle v v' ∥.
  Proof.
    intros Re Rle Γ u v u' he hle tRe tRle hRe hRle hR e h.
    induction h.
    - eapply red1_eq_term_upto_univ_l in X ; try exact e ; eauto.
      destruct X as [v' [[r e']]].
      exists v'. split ; auto.
      constructor. assumption. now constructor.
    - specialize (IHh e). destruct IHh as [v' [c [ev]]].
      eapply red1_eq_term_upto_univ_l in X ; try exact ev ; eauto.
      destruct X as [w' [[? ?]]].
      exists w'. split ; auto.
      eapply cored_trans ; eauto. now constructor.
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

  (* TODO Put more general lemma in Inversion *)
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
    intros Γ Δ t [T h].
    eexists. eapply PCUICGeneration.type_it_mkLambda_or_LetIn.
    eassumption.
  Qed.

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

  Lemma mkApps_Prod_nil' :
    forall Γ na A B l,
      wellformed Σ Γ (mkApps (tProd na A B) l) ->
      l = [].
  Admitted.

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

  Lemma red_welltyped :
    forall {Γ u v},
      welltyped Σ Γ u ->
      ∥ red (fst Σ) Γ u v ∥ ->
      welltyped Σ Γ v.
  Proof.
    destruct hΣ as [wΣ]; clear hΣ.
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
    (* pose proof (subject_reduction _ Γ _ _ _ hΣ hu r) as hu'. *)
    (* pose proof (subject_reduction _ Γ _ _ _ hΣ hv r0) as hv'. *)
    (* pose proof (type_rename _ _ _ _ hu' e) as hv''. *)
    (* pose proof (principal_typing _ hv' hv'') as [C [? [? hvC]]]. *)
    (* apply eq_term_sym in e as e'. *)
    (* pose proof (type_rename _ _ _ _ hvC e') as huC. *)
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

  Lemma wellformed_zipc_replace :
    forall Γ u v π,
      wellformed Σ Γ (zipc v π) ->
      wellformed Σ (Γ ,,, stack_context π) u ->
      Σ ;;; Γ ,,, stack_context π |- u = v ->
                                    wellformed Σ Γ (zipc u π).
  Admitted.

  Lemma conv_context_conversion :
    forall {Γ u v Γ'},
      Σ ;;; Γ |- u = v ->
      PCUICSR.conv_context Σ Γ Γ' ->
      Σ ;;; Γ' |- u = v.
  Admitted.

  Derive Signature for typing.

  Lemma Construct_Ind_ind_eq :
    forall {Γ n i args u i' args' u'},
      Σ ;;; Γ |- mkApps (tConstruct i n u) args : mkApps (tInd i' u') args' ->
      i = i'.
  Proof.
    intros Γ n i args u i' args' u' h.
    induction args.
    - simpl in h. apply inversion_Construct in h as ih.
      destruct ih as [mdecl [idecl [cdecl [? [d [? hc]]]]]].
      destruct i as [mind nind].
      destruct i' as [mind' nind'].
      unfold type_of_constructor in hc. cbn in hc.
      destruct cdecl as [[cna ct] cn]. cbn in hc.
      destruct mdecl as [mnpars mpars mbod muni]. simpl in *.
      destruct idecl as [ina ity ike ict iprj].
      apply cumul_alt in hc as [v [v' [[? ?] ?]]].
      unfold declared_constructor in d. cbn in d.
      destruct d as [[dm hin] hn]. simpl in *.
      unfold declared_minductive in dm.
      (* I have no idea how to do it. *)
      admit.
    - eapply IHargs. (* Induction on args was a wrong idea! *)
  Admitted.

  Lemma Proj_red_cond :
    forall Γ i pars narg i' c u l,
      wellformed Σ Γ (tProj (i, pars, narg) (mkApps (tConstruct i' c u) l)) ->
      nth_error l (pars + narg) <> None.
  Proof.
    intros Γ i pars narg i' c u l [[T h]|[[ctx [s [e _]]]]];
      [|discriminate].
    apply inversion_Proj in h.
    destruct h as [uni [mdecl [idecl [pdecl [args' [d [hc [? ?]]]]]]]].
    destruct d as [di [? ?]]. simpl in *. subst.
  Admitted.

  Lemma Case_Construct_ind_eq :
    forall {Γ ind ind' npar pred i u brs args},
      wellformed Σ Γ (tCase (ind, npar) pred (mkApps (tConstruct ind' i u) args) brs) ->
      ind = ind'.
  Proof.
    intros Γ ind ind' npar pred i u brs args [[A h]|[[ctx [s [e _]]]]];
      [|discriminate].
    apply inversion_Case in h as ih.
    destruct ih
      as [uni [args' [mdecl [idecl [pty [indctx [pctx [ps [btys [? [? [? [? [? [? [ht0 [? ?]]]]]]]]]]]]]]]]].
    apply Construct_Ind_ind_eq in ht0. eauto.
  Qed.

  Lemma Proj_Constuct_ind_eq :
    forall Γ i i' pars narg c u l,
      wellformed Σ Γ (tProj (i, pars, narg) (mkApps (tConstruct i' c u) l)) ->
      i = i'.
  Proof.
    intros Γ i i' pars narg c u l [[T h]|[[ctx [s [e _]]]]];
      [|discriminate].
    apply inversion_Proj in h.
    destruct h as [uni [mdecl [idecl [pdecl [args' [? [hc [? ?]]]]]]]].
    apply Construct_Ind_ind_eq in hc. eauto.
  Qed.

End Lemmata.