(* Distributed under the terms of the MIT license.   *)

From Coq Require Import Bool String List Program BinPos Compare_dec Arith Lia
     Classes.RelationClasses Omega.
From MetaCoq.Template Require Import config utils Universes BasicAst AstUtils
     UnivSubst.
From MetaCoq.PCUIC Require Import PCUICAst PCUICAstUtils PCUICInduction
     PCUICReflect PCUICLiftSubst PCUICUnivSubst PCUICTyping PCUICNameless
     PCUICCumulativity PCUICPosition.

Fixpoint eqb_term_upto_univ (equ lequ : universe -> universe -> bool) (u v : term) : bool :=
  match u, v with
  | tRel n, tRel m =>
    eqb n m

  | tEvar e args, tEvar e' args' =>
    eqb e e' &&
    forallb2 (eqb_term_upto_univ equ equ) args args'

  | tVar id, tVar id' =>
    eqb id id'

  | tSort u, tSort u' =>
    lequ u u'

  | tApp u v, tApp u' v' =>
    eqb_term_upto_univ equ lequ u u' &&
    eqb_term_upto_univ equ equ v v'

  | tConst c u, tConst c' u' =>
    eqb c c' &&
    forallb2 lequ (map Universe.make u) (map Universe.make u')

  | tInd i u, tInd i' u' =>
    eqb i i' &&
    forallb2 lequ (map Universe.make u) (map Universe.make u')

  | tConstruct i k u, tConstruct i' k' u' =>
    eqb i i' &&
    eqb k k' &&
    forallb2 lequ (map Universe.make u) (map Universe.make u')

  | tLambda na A t, tLambda na' A' t' =>
    eqb_term_upto_univ equ equ A A' &&
    eqb_term_upto_univ equ equ t t'

  | tProd na A B, tProd na' A' B' =>
    eqb_term_upto_univ equ equ A A' &&
    eqb_term_upto_univ equ lequ B B'

  | tLetIn na B b u, tLetIn na' B' b' u' =>
    eqb_term_upto_univ equ equ B B' &&
    eqb_term_upto_univ equ equ b b' &&
    eqb_term_upto_univ equ lequ u u'

  | tCase indp p c brs, tCase indp' p' c' brs' =>
    eqb indp indp' &&
    eqb_term_upto_univ equ equ p p' &&
    eqb_term_upto_univ equ equ c c' &&
    forallb2 (fun x y =>
      eqb (fst x) (fst y) &&
      eqb_term_upto_univ equ equ (snd x) (snd y)
    ) brs brs'

  | tProj p c, tProj p' c' =>
    eqb p p' &&
    eqb_term_upto_univ equ equ c c'

  | tFix mfix idx, tFix mfix' idx' =>
    eqb idx idx' &&
    forallb2 (fun x y =>
      eqb_term_upto_univ equ equ x.(dtype) y.(dtype) &&
      eqb_term_upto_univ equ equ x.(dbody) y.(dbody) &&
      eqb x.(rarg) y.(rarg)
    ) mfix mfix'

  | tCoFix mfix idx, tCoFix mfix' idx' =>
    eqb idx idx' &&
    forallb2 (fun x y =>
      eqb_term_upto_univ equ equ x.(dtype) y.(dtype) &&
      eqb_term_upto_univ equ equ x.(dbody) y.(dbody) &&
      eqb x.(rarg) y.(rarg)
    ) mfix mfix'

  | _, _ => false
  end.

(* Definition eqb_term `{checker_flags} (u v : term) : bool := *)
(*   eqb_term_upto_univ () *)

(* Definition leqb_term `{checker_flags} (u v : term) : bool := *)
(*   eqb_term_upto_univ () *)

Ltac eqspec :=
  lazymatch goal with
  | |- context [ eqb ?u ?v ] =>
    destruct (eqb_spec u v) ; nodec ; subst
  end.

Ltac eqspecs :=
  repeat eqspec.

Local Ltac equspec equ h :=
  repeat lazymatch goal with
  | |- context [ equ ?x ?y ] =>
    destruct (h x y) ; nodec ; subst
  end.

Local Ltac ih :=
  repeat lazymatch goal with
  | ih : forall lequ Rle hle t', reflect (eq_term_upto_univ _ _ ?t _) _,
    hle : forall u u', reflect (?Rle u u') (?lequ u u')
    |- context [ eqb_term_upto_univ _ ?lequ ?t ?t' ] =>
    destruct (ih lequ Rle hle t') ; nodec ; subst
  end.

Lemma reflect_eq_term_upto_univ :
  forall equ lequ Re Rle,
    (forall u u', reflect (Re u u') (equ u u')) ->
    (forall u u', reflect (Rle u u') (lequ u u')) ->
    forall t t',
      reflect (eq_term_upto_univ Re Rle t t')
              (eqb_term_upto_univ equ lequ t t').
Proof.
  intros equ lequ Re Rle he hle t t'.
  induction t in t', lequ, Rle, hle |- * using term_forall_list_ind.
  all: destruct t' ; nodec.
  (* all: try solve [ *)
  (*   cbn - [eqb] ; eqspecs ; equspec equ h ; ih ; *)
  (*   constructor ; constructor ; assumption *)
  (* ]. *)
  - cbn - [eqb]. eqspecs. equspec equ he. equspec lequ hle. ih.
    constructor. constructor ; assumption.
  - cbn - [eqb]. eqspecs. equspec equ he. equspec lequ hle. ih.
    constructor. constructor ; assumption.
  - cbn - [eqb]. eqspecs. equspec equ he. equspec lequ hle. ih.
    cbn.
    induction X in l0 |- *.
    + destruct l0.
      * constructor. constructor. constructor.
      * constructor. intro bot. inversion bot. subst.
        inversion H0.
    + destruct l0.
      * constructor. intro bot. inversion bot. subst.
        inversion H0.
      * cbn. destruct (p _ _ he t).
        -- destruct (IHX l0).
           ++ constructor. constructor. constructor ; try assumption.
              inversion e0. subst. assumption.
           ++ constructor. intro bot. inversion bot. subst.
              inversion H0. subst.
              apply n. constructor. assumption.
        -- constructor. intro bot. apply n.
           inversion bot. subst. inversion H0. subst. assumption.
  - cbn - [eqb]. eqspecs. equspec equ he. equspec lequ hle. ih.
    constructor. constructor. assumption.
  - cbn - [eqb]. eqspecs. equspec equ he. equspec lequ hle. ih.
    constructor. constructor ; assumption.
  - cbn - [eqb]. eqspecs. equspec equ he. equspec lequ hle. ih.
    constructor. constructor ; assumption.
  - cbn - [eqb]. eqspecs. equspec equ he. equspec lequ hle. ih.
    constructor. constructor ; assumption.
  - cbn - [eqb]. eqspecs. equspec equ he. equspec lequ hle. ih.
    constructor. constructor ; assumption.
  - cbn - [eqb].
    pose proof (eqb_spec s k) as H.
    match goal with
    | |- context G[ eqb ?x ?y ] =>
      set (toto := eqb x y) in * ;
      let G' := context G[toto] in
      change G'
    end.
    destruct H ; nodec. subst.
    equspec equ he. equspec lequ hle. ih.
    cbn. induction u in ui |- *.
    + destruct ui.
      * constructor. constructor. constructor.
      * constructor. intro bot. inversion bot. subst. inversion H0.
    + destruct ui.
      * constructor. intro bot. inversion bot. subst. inversion H0.
      * cbn. equspec equ he. equspec lequ hle.
        -- cbn. destruct (IHu ui).
           ++ constructor. constructor.
              inversion e. subst.
              constructor ; assumption.
           ++ constructor. intro bot. apply n.
              inversion bot. subst. constructor. inversion H0.
              subst. assumption.
        -- constructor. intro bot. apply n.
           inversion bot. subst. inversion H0. subst.
           assumption.
  - cbn - [eqb]. eqspecs. equspec equ he. equspec lequ hle. ih.
    simpl. induction u in ui |- *.
    + destruct ui.
      * constructor. constructor. constructor.
      * constructor. intro bot. inversion bot. subst. inversion H0.
    + destruct ui.
      * constructor. intro bot. inversion bot. subst. inversion H0.
      * cbn. equspec equ he. equspec lequ hle.
        -- cbn. destruct (IHu ui).
           ++ constructor. constructor.
              inversion e. subst.
              constructor ; assumption.
           ++ constructor. intro bot. apply n.
              inversion bot. subst. constructor. inversion H0.
              subst. assumption.
        -- constructor. intro bot. apply n.
           inversion bot. subst. inversion H0. subst.
           assumption.
  - cbn - [eqb]. eqspecs. equspec equ he. equspec lequ hle. ih.
    simpl. induction u in ui |- *.
    + destruct ui.
      * constructor. constructor. constructor.
      * constructor. intro bot. inversion bot. subst. inversion H0.
    + destruct ui.
      * constructor. intro bot. inversion bot. subst. inversion H0.
      * cbn. equspec equ he. equspec lequ hle.
        -- cbn. destruct (IHu ui).
           ++ constructor. constructor.
              inversion e. subst.
              constructor ; assumption.
           ++ constructor. intro bot. apply n.
              inversion bot. subst. constructor. inversion H0.
              subst. assumption.
        -- constructor. intro bot. apply n.
           inversion bot. subst. inversion H0. subst.
           assumption.
  - cbn - [eqb]. eqspecs. equspec equ he. equspec lequ hle. ih.
    cbn - [eqb].
    destruct indn as [i n].
    induction l in brs, X |- *.
    + destruct brs.
      * constructor. constructor ; try assumption.
        constructor.
      * constructor. intro bot. inversion bot. subst. inversion H9.
    + destruct brs.
      * constructor. intro bot. inversion bot. subst. inversion H9.
      * cbn - [eqb]. inversion X. subst.
        destruct a, p. cbn - [eqb]. eqspecs.
        -- cbn - [eqb]. pose proof (X0 equ Re he t0) as hh. cbn in hh.
           destruct hh.
           ++ cbn - [eqb].
              destruct (IHl X1 brs).
              ** constructor. constructor ; try assumption.
                 constructor ; try easy.
                 inversion e2. subst. assumption.
              ** constructor. intro bot. apply n0. inversion bot. subst.
                 constructor ; try assumption.
                 inversion H9. subst. assumption.
           ++ constructor. intro bot. apply n0. inversion bot. subst.
              inversion H9. subst. destruct H3. assumption.
        -- constructor. intro bot. inversion bot. subst.
           inversion H9. subst. destruct H3. cbn in H. subst.
           apply n2. reflexivity.
  - cbn - [eqb]. eqspecs. equspec equ he. equspec lequ hle. ih.
    constructor. constructor ; assumption.
  - cbn - [eqb]. eqspecs. equspec equ he. equspec lequ hle. ih.
    cbn - [eqb]. induction m in X, mfix |- *.
    + destruct mfix.
      * constructor. constructor. constructor.
      * constructor. intro bot. inversion bot. subst. inversion H0.
    + destruct mfix.
      * constructor. intro bot. inversion bot. subst. inversion H0.
      * cbn - [eqb]. inversion X. subst.
        destruct X0 as [h1 h2].
        destruct (h1 equ Re he (dtype d)).
        -- destruct (h2 equ Re he (dbody d)).
           ++ cbn - [eqb]. eqspecs.
              ** cbn - [eqb]. destruct (IHm X1 mfix).
                 --- constructor. constructor. constructor ; try easy.
                     inversion e2. assumption.
                 --- constructor. intro bot. apply n.
                     inversion bot. subst. constructor.
                     inversion H0. subst. assumption.
              ** constructor. intro bot. inversion bot. subst.
                 apply n. inversion H0. subst. destruct H3 as [? [? ?]].
                 assumption.
           ++ constructor. intro bot. apply n.
              inversion bot. subst. inversion H0. subst.
              apply H3.
        -- constructor. intro bot. apply n.
           inversion bot. subst. inversion H0. subst. apply H3.
  - cbn - [eqb]. eqspecs. equspec equ he. equspec lequ hle. ih.
    cbn - [eqb]. induction m in X, mfix |- *.
    + destruct mfix.
      * constructor. constructor. constructor.
      * constructor. intro bot. inversion bot. subst. inversion H0.
    + destruct mfix.
      * constructor. intro bot. inversion bot. subst. inversion H0.
      * cbn - [eqb]. inversion X. subst.
        destruct X0 as [h1 h2].
        destruct (h1 equ Re he (dtype d)).
        -- destruct (h2 equ Re he (dbody d)).
           ++ cbn - [eqb]. eqspecs.
              ** cbn - [eqb]. destruct (IHm X1 mfix).
                 --- constructor. constructor. constructor ; try easy.
                     inversion e2. assumption.
                 --- constructor. intro bot. apply n.
                     inversion bot. subst. constructor.
                     inversion H0. subst. assumption.
              ** constructor. intro bot. inversion bot. subst.
                 apply n. inversion H0. subst. destruct H3 as [? [? ?]].
                 assumption.
           ++ constructor. intro bot. apply n.
              inversion bot. subst. inversion H0. subst.
              apply H3.
        -- constructor. intro bot. apply n.
           inversion bot. subst. inversion H0. subst. apply H3.
Qed.

(* Syntactical equality *)
Definition nleq_term t t' :=
  eqb_term_upto_univ eqb eqb t t'.

Corollary reflect_eq_term_upto_univ_eqb :
  forall t t',
    reflect (eq_term_upto_univ eq eq t t') (nleq_term t t').
Proof.
  intros t t'. eapply reflect_eq_term_upto_univ.
  all: eapply eqb_spec.
Qed.

Corollary reflect_nleq_term :
  forall `{checker_flags} t t',
    reflect (nl t = nl t') (nleq_term t t').
Proof.
  intros flags t t'.
  destruct (reflect_eq_term_upto_univ_eqb t t').
  - constructor. eapply eq_term_nl_eq. assumption.
  - constructor. intro bot. apply n.
    apply eq_term_upto_univ_nl_inv ; auto.
    rewrite bot.
    apply eq_term_upto_univ_refl ; auto.
Qed.

Local Ltac ih2 :=
  lazymatch goal with
  | ih : forall Rle v, _ -> _ -> eq_term_upto_univ _ _ ?u _
    |- eq_term_upto_univ _ _ ?u _ =>
    eapply ih
  end.

Lemma eq_term_upto_univ_eq_eq_term_upto_univ :
  forall Re Rle u v,
    Reflexive Re ->
    Reflexive Rle ->
    eq_term_upto_univ eq eq u v ->
    eq_term_upto_univ Re Rle u v.
Proof.
  intros Re Rle u v he hle h.
  induction u using term_forall_list_ind in v, h, Rle, hle |- *.
  all: dependent destruction h.
  all: try solve [ constructor ; try ih2 ; try assumption ; try reflexivity ].
  - constructor. eapply Forall2_impl' ; try eassumption.
    eapply All_Forall. eapply All_impl ; eauto.
  - constructor. eapply Forall2_impl ; try eassumption.
    intros x y []. reflexivity.
  - constructor. eapply Forall2_impl ; try eassumption.
    intros x y []. reflexivity.
  - constructor. eapply Forall2_impl ; try eassumption.
    intros x y []. reflexivity.
  - constructor ; try ih2 ; try assumption.
    eapply Forall2_impl' ; try eassumption.
    apply All_Forall. eapply All_impl ; try eassumption.
    intros [? ?] ? [? ?] [? ?]. split ; auto.
  - constructor. eapply Forall2_impl' ; try eassumption.
    eapply All_Forall. eapply All_impl ; try eassumption.
    intros x [? ?] y [? [? ?]]. repeat split ; auto.
  - constructor. eapply Forall2_impl' ; try eassumption.
    eapply All_Forall. eapply All_impl ; try eassumption.
    intros x [? ?] y [? [? ?]]. repeat split ; auto.
Qed.

Lemma eq_term_upto_univ_eq_eq_term :
  forall φ u v,
    eq_term_upto_univ eq eq u v ->
    eq_term φ u v.
Proof.
  intros φ u v h.
  eapply eq_term_upto_univ_eq_eq_term_upto_univ ; auto.
  all: intro x ; eapply eq_universe_refl.
Qed.

Local Ltac lih :=
  lazymatch goal with
  | ih : forall Rle v n k, eq_term_upto_univ _ _ ?u _ -> _
    |- eq_term_upto_univ _ _ (lift _ _ ?u) _ =>
    eapply ih
  end.

Lemma eq_term_upto_univ_lift :
  forall Re Rle u v n k,
    eq_term_upto_univ Re Rle u v ->
    eq_term_upto_univ Re Rle (lift n k u) (lift n k v).
Proof.
  intros Re Rle u v n k e.
  induction u in v, n, k, e, Rle |- * using term_forall_list_ind.
  all: dependent destruction e.
  all: try (cbn ; constructor ; try lih ; assumption).
  - cbn. destruct (Nat.leb_spec0 k n0).
    + constructor.
    + constructor.
  - cbn. constructor.
    eapply Forall2_map.
    eapply Forall2_impl'.
    + eassumption.
    + eapply All_Forall.
      eapply All_impl ; [ eassumption |].
      intros x H1 y H2. cbn in H1.
      eapply H1. assumption.
  - cbn. constructor ; try lih ; try assumption.
    eapply Forall2_map. eapply Forall2_impl' ; [ eassumption |].
    eapply All_Forall. eapply All_impl ; [ eassumption |].
    intros x H0 y [? ?]. cbn in H0. repeat split ; auto.
    eapply H0. assumption.
  - cbn. constructor.
    eapply Forall2_map. eapply Forall2_impl' ; [ eassumption |].
    eapply All_Forall. eapply All_impl ; [ eassumption |].
    intros x [h1 h2] y [? [? ?]].
    repeat split ; auto.
    + eapply h1. assumption.
    + apply Forall2_length in H. rewrite H.
      eapply h2. assumption.
  - cbn. constructor.
    eapply Forall2_map. eapply Forall2_impl' ; [ eassumption |].
    eapply All_Forall. eapply All_impl ; [ eassumption |].
    intros x [h1 h2] y [? [? ?]].
    repeat split ; auto.
    + eapply h1. assumption.
    + apply Forall2_length in H. rewrite H.
      eapply h2. assumption.
Qed.

Local Ltac sih :=
  lazymatch goal with
  | ih : forall Rle v n x y, _ -> eq_term_upto_univ _ _ ?u _ -> _ -> _
    |- eq_term_upto_univ _ _ (subst _ _ ?u) _ => eapply ih
  end.

Lemma eq_term_upto_univ_subst :
  forall (Re Rle : universe -> universe -> Prop) u v n x y,
    (forall u u' : universe, Re u u' -> Rle u u') ->
    eq_term_upto_univ Re Rle u v ->
    eq_term_upto_univ Re Re x y ->
    eq_term_upto_univ Re Rle (u{n := x}) (v{n := y}).
Proof.
  intros Re Rle u v n x y hR e1 e2.
  induction u in v, n, x, y, e1, e2, Rle, hR |- * using term_forall_list_ind.
  all: dependent destruction e1.
  all: try solve [ cbn ; constructor ; try sih ; eauto ].
  - cbn. destruct (Nat.leb_spec0 n n0).
    + destruct (eqb_spec n0 n).
      * subst. replace (n - n) with 0 by omega. cbn.
        eapply eq_term_upto_univ_lift.
        eapply eq_term_upto_univ_leq ; eauto.
      * replace (n0 - n) with (S (n0 - (S n))) by omega. cbn.
        rewrite nth_error_nil. constructor.
    + constructor.
  - cbn. constructor.
    eapply Forall2_map. eapply Forall2_impl' ; [ eassumption |].
    eapply All_Forall.
    eapply All_impl ; [ eassumption |].
    intros x0 H1 y0 H2. cbn in H1.
    eapply H1. all: eauto.
  - cbn. constructor ; try sih ; eauto.
    eapply Forall2_map. eapply Forall2_impl' ; [ eassumption |].
    eapply All_Forall. eapply All_impl ; [ eassumption |].
    intros ? H0 ? [? ?]. cbn in H0. repeat split ; auto.
    eapply H0. all: eauto.
  - cbn. constructor.
    eapply Forall2_map. eapply Forall2_impl' ; [ eassumption |].
    eapply All_Forall. eapply All_impl ; [ eassumption |].
    intros ? [h1 h2] ? [? [? ?]].
    repeat split ; auto.
    + eapply h1. all: eauto.
    + apply Forall2_length in H. rewrite H.
      eapply h2. all: eauto.
  - cbn. constructor.
    eapply Forall2_map. eapply Forall2_impl' ; [ eassumption |].
    eapply All_Forall. eapply All_impl ; [ eassumption |].
    intros ? [h1 h2] ? [? [? ?]].
    repeat split ; auto.
    + eapply h1. all: eauto.
    + apply Forall2_length in H. rewrite H.
      eapply h2. all: eauto.
Qed.

Lemma eq_term_upto_univ_mkApps_l_inv :
  forall Re u l t,
    eq_term_upto_univ Re Re (mkApps u l) t ->
    exists u' l',
      eq_term_upto_univ Re Re u u' /\
      Forall2 (eq_term_upto_univ Re Re) l l' /\
      t = mkApps u' l'.
Proof.
  intros Re u l t h.
  induction l in u, t, h |- *.
  - cbn in h. exists t, []. split ; auto.
  - cbn in h. apply IHl in h as [u' [l' [h1 [h2 h3]]]].
    dependent destruction h1. subst.
    eexists. eexists. split ; [ | split ].
    + eassumption.
    + constructor.
      * eassumption.
      * eassumption.
    + cbn. reflexivity.
Qed.

Lemma eq_term_upto_univ_mkApps :
  forall Re u1 l1 u2 l2,
    eq_term_upto_univ Re Re u1 u2 ->
    Forall2 (eq_term_upto_univ Re Re) l1 l2 ->
    eq_term_upto_univ Re Re (mkApps u1 l1) (mkApps u2 l2).
Proof.
  intros Re u1 l1 u2 l2 hu hl.
  induction l1 in u1, u2, l2, hu, hl |- *.
  - inversion hl. subst. assumption.
  - inversion hl. subst. simpl.
    eapply IHl1.
    + constructor. all: assumption.
    + assumption.
Qed.

Lemma nleq_term_it_mkLambda_or_LetIn :
  forall Γ u v,
    nleq_term u v ->
    nleq_term (it_mkLambda_or_LetIn Γ u) (it_mkLambda_or_LetIn Γ v).
Proof.
  intros Γ u v h.
  induction Γ as [| [na [b|] A] Γ ih ] in u, v, h |- *.
  - assumption.
  - simpl. cbn. apply ih.
    eapply ssrbool.introT.
    + eapply reflect_nleq_term.
    + cbn. f_equal.
      eapply ssrbool.elimT.
      * eapply reflect_nleq_term.
      * assumption.
  - simpl. cbn. apply ih.
    eapply ssrbool.introT.
    + eapply reflect_nleq_term.
    + cbn. f_equal.
      eapply ssrbool.elimT.
      * eapply reflect_nleq_term.
      * assumption.
Qed.

Lemma eq_term_it_mkLambda_or_LetIn_inv :
  forall (Σ : global_context) Γ u v,
    eq_term (snd Σ) (it_mkLambda_or_LetIn Γ u) (it_mkLambda_or_LetIn Γ v) ->
    eq_term (snd Σ) u v.
Proof.
  intros Σ Γ.
  induction Γ as [| [na [b|] A] Γ ih ] ; intros u v h.
  - assumption.
  - simpl in h. cbn in h. apply ih in h. inversion h. subst.
    assumption.
  - simpl in h. cbn in h. apply ih in h. inversion h. subst.
    assumption.
Qed.

Lemma eq_term_zipc_inv :
  forall (Σ : global_context) u v π,
    eq_term (snd Σ) (zipc u π) (zipc v π) ->
    eq_term (snd Σ) u v.
Proof.
  intros Σ u v π h.
  revert u v h. induction π ; intros u v h.
  all: solve [
           simpl in h ; try apply IHπ in h ;
           cbn in h ; inversion h ; subst ; assumption
         ].
Qed.

Lemma eq_term_zipx_inv :
  forall (Σ : global_context) Γ u v π,
    eq_term (snd Σ) (zipx Γ u π) (zipx Γ v π) ->
    eq_term (snd Σ) u v.
Proof.
  intros Σ Γ u v π h.
  eapply eq_term_zipc_inv.
  eapply eq_term_it_mkLambda_or_LetIn_inv.
  eassumption.
Qed.

Lemma eq_term_it_mkLambda_or_LetIn :
  forall (Σ : global_context) Γ u v,
    eq_term (snd Σ) u v ->
    eq_term (snd Σ) (it_mkLambda_or_LetIn Γ u) (it_mkLambda_or_LetIn Γ v).
Proof.
  intros Σ Γ.
  induction Γ as [| [na [b|] A] Γ ih ] ; intros u v h.
  - assumption.
  - simpl. cbn. apply ih. constructor ; try apply eq_term_refl. assumption.
  - simpl. cbn. apply ih. constructor ; try apply eq_term_refl. assumption.
Qed.

Lemma eq_term_zipc :
  forall (Σ : global_context) u v π,
    eq_term (snd Σ) u v ->
    eq_term (snd Σ) (zipc u π) (zipc v π).
Proof.
  intros Σ u v π h.
  revert u v h. induction π ; intros u v h.
  all: try solve [
             simpl ; try apply IHπ ;
             cbn ; constructor ; try apply eq_term_refl ; assumption
           ].
  - assumption.
  - simpl. apply IHπ. destruct indn as [i n].
    constructor.
    + apply eq_term_refl.
    + assumption.
    + eapply Forall_Forall2. eapply Forall_True.
      intros. split ; auto. apply eq_term_refl.
Qed.

Lemma eq_term_zipx :
  forall (Σ : global_context) Γ u v π,
    eq_term (snd Σ) u v ->
    eq_term (snd Σ) (zipx Γ u π) (zipx Γ v π).
Proof.
  intros Σ Γ u v π h.
  eapply eq_term_it_mkLambda_or_LetIn.
  eapply eq_term_zipc.
  eassumption.
Qed.