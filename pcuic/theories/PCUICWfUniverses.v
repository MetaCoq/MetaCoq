(* Distributed under the terms of the MIT license. *)
From Coq Require Import Morphisms.
From MetaCoq.Template Require Import config utils.
From MetaCoq.PCUIC Require Import PCUICAst PCUICInduction
     PCUICLiftSubst PCUICTyping PCUICWeakeningEnv PCUICWeakening PCUICInversion
     PCUICSubstitution PCUICReduction PCUICCumulativity PCUICGeneration
     PCUICUnivSubst PCUICParallelReductionConfluence PCUICWeakeningEnv
     PCUICUnivSubstitution PCUICConversion PCUICContexts.

From Equations Require Import Equations.
Require Import Equations.Prop.DepElim.
Require Import ssreflect ssrbool.

From MetaCoq.PCUIC Require Import PCUICInduction.

Lemma forallbP {A} (P : A -> Prop) (p : A -> bool) l : (forall x, reflect (P x) (p x)) -> reflect (Forall P l) (forallb p l).
Proof.
  intros Hp.
  apply: (iffP idP).
  - induction l; rewrite /= //. move/andP => [pa pl].
    constructor; auto. now apply/(Hp _).
  - induction 1; rewrite /= // IHForall // andb_true_r.
    now apply/(Hp _).
Qed.

Section CheckerFlags.
  Context {cf:checker_flags}.

  Lemma wf_universe_type1 Σ : wf_universe Σ Universe.type1.
  Proof.
    simpl.
    intros l hin%UnivExprSet.singleton_spec.
    subst l. simpl.
    apply LS.union_spec. right; apply global_levels_Set.
  Qed.

  Lemma wf_universe_super {Σ u} : wf_universe Σ u -> wf_universe Σ (Universe.super u).
  Proof.
    destruct u; cbn.
    1-2:intros _ l hin%UnivExprSet.singleton_spec; subst l; apply wf_universe_type1;
     now apply UnivExprSet.singleton_spec.
    intros Hl.
    intros l hin. 
    eapply Universes.spec_map_succ in hin as [x' [int ->]].
    simpl. now specialize (Hl _ int).
  Qed.

  Lemma wf_universe_sup {Σ u u'} : wf_universe Σ u -> wf_universe Σ u' ->
    wf_universe Σ (Universe.sup u u').
  Proof.
    destruct u, u'; cbn; auto.
    intros Hu Hu' l [Hl|Hl]%UnivExprSet.union_spec.
    now apply (Hu _ Hl).
    now apply (Hu' _ Hl).
  Qed.
  
  Lemma wf_universe_product {Σ u u'} : wf_universe Σ u -> wf_universe Σ u' ->
    wf_universe Σ (Universe.sort_of_product u u').
  Proof.
    intros Hu Hu'. unfold Universe.sort_of_product.
    destruct (Universe.is_prop u' || Universe.is_sprop u'); auto.
    now apply wf_universe_sup.
  Qed.

  Hint Resolve @wf_universe_type1 @wf_universe_super @wf_universe_sup @wf_universe_product : pcuic.


  Definition wf_universeb_level Σ l := 
    LevelSet.mem l (global_ext_levels Σ).

  Definition wf_universe_level Σ l := 
    LevelSet.In l (global_ext_levels Σ).
    
  Definition wf_universe_instance Σ u :=
    Forall (wf_universe_level Σ) u.

  Definition wf_universeb_instance Σ u :=
    forallb (wf_universeb_level Σ) u.


  Lemma wf_universe_levelP {Σ l} : reflect (wf_universe_level Σ l) (wf_universeb_level Σ l).
  Proof.
    unfold wf_universe_level, wf_universeb_level.
    destruct LevelSet.mem eqn:ls; constructor.
    now apply LevelSet.mem_spec in ls.
    intros hin.
    now apply LevelSet.mem_spec in hin.
  Qed.

  Lemma wf_universe_instanceP {Σ u} : reflect (wf_universe_instance Σ u) (wf_universeb_instance Σ u).
  Proof.
    unfold wf_universe_instance, wf_universeb_instance.
    apply forallbP. intros x; apply wf_universe_levelP.
  Qed.
  
  Lemma wf_universe_subst_instance (Σ : global_env_ext) univs u l :
    wf Σ ->
    wf_universe Σ l ->
    wf_universe_instance (Σ.1, univs) u ->
    sub_context_set (monomorphic_udecl Σ.2) (global_ext_context_set (Σ.1, univs)) ->
    wf_universe (Σ.1, univs) (subst_instance u l). 
  Proof.
    destruct l; simpl; auto.
    intros wfΣ Hl Hu sub e [[l n] [inl ->]]%In_subst_instance.
    destruct l; simpl; auto.
    - unfold global_ext_levels.
      apply LS.union_spec. right.
      apply global_levels_Set.
    - specialize (Hl (Level.Level s, n) inl).
      simpl in Hl.
      destruct sub. unfold levels_of_udecl in H.
      unfold global_ext_levels in Hl.
      destruct Σ.2.
      * eapply LS.union_spec in Hl.
        destruct Hl as [Hl|Hl].
        + now specialize (H _ Hl).
        + eapply LS.union_spec. now right.
      * eapply LS.union_spec in Hl as [Hl|Hl].
        + simpl in Hl.
          now apply monomorphic_level_notin_AUContext in Hl.
        + apply LS.union_spec; now right.
    - specialize (Hl (Level.Var n0, n) inl).
      eapply LS.union_spec in Hl as [Hl|Hl].
      + red in Hu.
        unfold levels_of_udecl in Hl.
        destruct Σ.2.
        * simpl in Hu. simpl in *.
          unfold subst_instance; simpl.
          destruct nth_error eqn:hnth; simpl.
          eapply nth_error_forall in Hu; eauto.
          eapply LS.union_spec; right. eapply global_levels_Set.
        * simpl in sub.
          unfold subst_instance. simpl.
          destruct (nth_error u n0) eqn:hnth.
          2:{ simpl. rewrite hnth. eapply LS.union_spec; right; apply global_levels_Set. }
          eapply nth_error_forall in Hu. 2:eauto. change (nth_error u n0) with (nth_error u n0) in *.
          rewrite -> hnth. simpl. apply Hu.
      + now apply not_var_global_levels in Hl.
  Qed.

  Lemma wf_universe_instantiate Σ univs s u φ :
    wf Σ ->
    wf_universe (Σ, univs) s ->
    wf_universe_instance (Σ, φ) u ->
    sub_context_set (monomorphic_udecl univs) (global_ext_context_set (Σ, φ)) ->
    wf_universe (Σ, φ) (subst_instance_univ u s).
  Proof.
    intros wfΣ Hs cu.
    apply (wf_universe_subst_instance (Σ, univs) φ); auto.
  Qed.

  Lemma subst_instance_instance_empty u : 
    forallb (fun x => ~~ Level.is_var x) u ->
    subst_instance_instance [] u = u.
  Proof.
    induction u; simpl; intros Hu; auto.
    depelim Hu.
    rewrite IHu //.
    now destruct a => /= //; auto.
    now destruct a => /= //; auto.
  Qed.

  Lemma wf_universe_level_mono Σ ctx u : 
    wf Σ ->
    on_udecl_prop Σ (Monomorphic_ctx ctx) ->
    Forall (wf_universe_level (Σ, Monomorphic_ctx ctx)) u ->
    forallb (fun x => ~~ Level.is_var x) u.
  Proof.
    intros wf uprop.
    induction 1 => /= //.
    destruct x eqn:isv => /= //.
    apply LS.union_spec in H as [H|H]; simpl in H.
    epose proof (@udecl_prop_in_var_poly _ (Σ, _) _ uprop H) as [ctx' eq].
    discriminate.
    now pose proof (not_var_global_levels _ wf _ H).
  Qed.

  Lemma wf_universe_level_sub Σ ctx univs u :
    wf_universe_level (Σ, Monomorphic_ctx ctx) u ->
    sub_context_set ctx (global_ext_context_set (Σ, univs)) ->
    wf_universe_level (Σ, univs) u.
  Proof.
    intros wfx [sub _].
    red in wfx |- *.
    eapply LevelSet.union_spec in wfx; simpl in *.
    destruct wfx as [wfx|wfx].
    now specialize (sub _ wfx).
    eapply LevelSet.union_spec. now right.
  Qed.

  Lemma wf_universe_instance_sub Σ ctx univs u :
    wf_universe_instance (Σ, Monomorphic_ctx ctx) u ->
    sub_context_set ctx (global_ext_context_set (Σ, univs)) ->
    wf_universe_instance (Σ, univs) u.
  Proof.
    intros wfu [sub ?].
    red in wfu |- *.
    eapply Forall_impl; eauto.
    intros; eapply wf_universe_level_sub; eauto.
    red. split; auto.
  Qed.

  Lemma In_Level_global_ext_poly s Σ cst : 
    LS.In (Level.Level s) (global_ext_levels (Σ, Polymorphic_ctx cst)) ->
    LS.In (Level.Level s) (global_levels Σ).
  Proof.
    intros [hin|hin]%LS.union_spec.
    simpl in hin.
    now apply monomorphic_level_notin_AUContext in hin.
    apply hin.
  Qed.

  Lemma Forall_In (A : Type) (P : A -> Prop) (l : list A) :
    Forall P l -> (forall x : A, In x l -> P x).
  Proof.
    induction 1; simpl; auto.
    intros x' [->|inx]; auto.
  Qed.

  Lemma wf_universe_instance_In {Σ u} : wf_universe_instance Σ u <-> 
    (forall l, In l u -> LS.In l (global_ext_levels Σ)).
  Proof.
    unfold wf_universe_instance.
    split; intros. eapply Forall_In in H; eauto.
    apply In_Forall. auto.
  Qed.

  Lemma in_subst_instance_instance l u u' : 
    In l (subst_instance_instance u u') ->
    In l u \/ In l u' \/ l = Level.lSet.
  Proof.
    induction u'; simpl; auto.
    intros [].
    destruct a; simpl in *; subst; auto.
    destruct (nth_in_or_default n u Level.lSet); auto.
    specialize (IHu' H). intuition auto.
  Qed.

  Lemma wf_universe_subst_instance_instance Σ univs u u' φ : 
    wf Σ ->
    on_udecl_prop Σ univs ->
    wf_universe_instance (Σ, univs) u' ->
    wf_universe_instance (Σ, φ) u ->
    sub_context_set (monomorphic_udecl univs) (global_ext_context_set (Σ, φ)) ->
    wf_universe_instance (Σ, φ) (subst_instance_instance u u').
  Proof.
    intros wfΣ onup Hs cu subc.
    destruct univs.
    - red in Hs |- *.
      unshelve epose proof (wf_universe_level_mono _ _ _ _ _ Hs); eauto.
      eapply forallb_Forall in H. apply Forall_map.
      solve_all. destruct x; simpl => //.
      eapply LS.union_spec. right. eapply global_levels_Set.
      eapply wf_universe_level_sub; eauto.
    - simpl in subc.
      clear subc onup.
      red in Hs |- *.
      eapply Forall_map, Forall_impl; eauto.
      intros x wfx.
      red in wfx. destruct x => /= //.
      red.
      eapply LS.union_spec; right.
      eapply global_levels_Set.
      eapply In_Level_global_ext_poly in wfx.
      apply LS.union_spec; now right.
      eapply in_var_global_ext in wfx; simpl in wfx; auto.
      unfold AUContext.levels, AUContext.repr in wfx.
      destruct cst as [? cst].
      rewrite mapi_unfold in wfx.
      eapply (proj1 (LevelSetProp.of_list_1 _ _)) in wfx.
      apply SetoidList.InA_alt in wfx as [? [<- wfx]]. simpl in wfx.
      eapply In_unfold in wfx.
      destruct (nth_in_or_default n u (Level.lSet)).
      red in cu. eapply Forall_In in cu; eauto. rewrite e.
      red. eapply LS.union_spec. right. eapply global_levels_Set.
  Qed.

  Section WfUniverses.
    Context (Σ : global_env_ext).

    Definition wf_universeb (s : Universe.t) : bool :=
      match s with
      | Universe.lType l => UnivExprSet.for_all (fun l => LevelSet.mem (UnivExpr.get_level l) (global_ext_levels Σ)) l
      | _ => true
      end.

    Lemma wf_universe_reflect (u : Universe.t) : 
      reflect (wf_universe Σ u) (wf_universeb u).
    Proof.
      destruct u; simpl; try now constructor.
      eapply iff_reflect.
      rewrite UnivExprSet.for_all_spec.
      split; intros.
      - intros l Hl; specialize (H l Hl).
        now eapply LS.mem_spec.
      - specialize (H l H0). simpl in H.
        now eapply LS.mem_spec in H.
    Qed.

    Lemma reflect_bP {P b} (r : reflect P b) : b -> P.
    Proof. destruct r; auto. discriminate. Qed.

    Lemma reflect_Pb {P b} (r : reflect P b) : P -> b.
    Proof. destruct r; auto. Qed.

    Fixpoint wf_universes t := 
      match t with
      | tSort s => wf_universeb s
      | tApp t u
      | tProd _ t u
      | tLambda _ t u => wf_universes t && wf_universes u
      | tCase _ t p brs => wf_universes t && wf_universes p && 
        forallb (test_snd wf_universes) brs
      | tLetIn _ t t' u =>
        wf_universes t && wf_universes t' && wf_universes u
      | tProj _ t => wf_universes t
      | tFix mfix _ | tCoFix mfix _ =>
        forallb (fun d => wf_universes d.(dtype) && wf_universes d.(dbody)) mfix
      | tConst _ u | tInd _ u | tConstruct _ _ u => wf_universeb_instance Σ u
      | _ => true
      end.

    Lemma All_forallb {A} (P : A -> Type) l (H : All P l) p p' : (forall x, P x -> p x = p' x) -> forallb p l = forallb p' l.
    Proof.
      intros; induction H; simpl; auto.
      now rewrite IHAll H0.
    Qed.

    Lemma wf_universes_lift n k t : wf_universes (lift n k t) = wf_universes t.
    Proof.
      induction t in n, k |- * using term_forall_list_ind; simpl; auto; try
        rewrite ?IHt1 ?IHt2 ?IHt3; auto.
        ssrbool.bool_congr. red in X.
        rewrite forallb_map.
        eapply All_forallb; eauto. simpl; intros [].
        simpl. intros. cbn. now rewrite H.
        rewrite forallb_map.
        eapply All_forallb; eauto. simpl; intros [].
        simpl. intros. cbn. now rewrite H.
        rewrite forallb_map.
        eapply All_forallb; eauto. simpl; intros [].
        simpl. intros. cbn. now rewrite H.
    Qed.

    Lemma wf_universes_subst s k t :
      All wf_universes s ->
      wf_universes (subst s k t) = wf_universes t.
    Proof.
      intros Hs.
      induction t in k |- * using term_forall_list_ind; simpl; auto; try
        rewrite ?IHt1 ?IHt2 ?IHt3; auto.
      - destruct (Nat.leb_spec k n); auto.
        destruct nth_error eqn:nth; simpl; auto.
        eapply nth_error_all in nth; eauto.
        simpl in nth. intros. now rewrite wf_universes_lift.
      - ssrbool.bool_congr. red in X.
        rewrite forallb_map.
        eapply All_forallb; eauto. simpl; intros [].
        simpl. intros. cbn. now apply H.
      - rewrite forallb_map.
        eapply All_forallb; eauto. simpl; intros [].
        simpl. intros. cbn. now rewrite H.
      - rewrite forallb_map.
        eapply All_forallb; eauto. simpl; intros [].
        simpl. intros. cbn. now rewrite H.
    Qed.

  End WfUniverses.

  Ltac to_prop := 
    repeat match goal with 
    | [ H: is_true (?x && ?y) |- _ ] =>
     let x := fresh in let y := fresh in move/andP: H; move=> [x y]; rewrite ?x ?y; simpl
    end. 

  Ltac to_wfu := 
    repeat match goal with 
    | [ H: is_true (wf_universeb _ ?x) |- _ ] => apply (reflect_bP (wf_universe_reflect _ x)) in H
    | [ |- is_true (wf_universeb _ ?x) ] => apply (reflect_Pb (wf_universe_reflect _ x))
    end. 
 
  Lemma wf_universes_inst {Σ : global_env_ext} univs t u : 
    wf Σ ->
    on_udecl_prop Σ.1 univs ->
    sub_context_set (monomorphic_udecl univs) (global_ext_context_set Σ) ->
    wf_universe_instance Σ u  ->
    wf_universes (Σ.1, univs) t ->
    wf_universes Σ (subst_instance u t).
  Proof.
    intros wfΣ onudecl sub cu wft.
    induction t using term_forall_list_ind; simpl in *; auto; try to_prop; 
      try apply /andP; to_wfu; intuition eauto 4.

    - to_wfu. destruct Σ as [Σ univs']. simpl in *.
      eapply (wf_universe_subst_instance (Σ, univs)); auto.

    - apply /andP; to_wfu; intuition eauto 4.
    - apply/wf_universe_instanceP.
      eapply wf_universe_subst_instance_instance; eauto.
      destruct Σ; simpl in *.
      now move/wf_universe_instanceP: wft.
    - apply/wf_universe_instanceP.
      eapply wf_universe_subst_instance_instance; eauto.
      destruct Σ; simpl in *.
      now move/wf_universe_instanceP: wft.
    - apply/wf_universe_instanceP.
      eapply wf_universe_subst_instance_instance; eauto.
      destruct Σ; simpl in *.
      now move/wf_universe_instanceP: wft.
    
    - apply /andP; to_wfu; intuition eauto 4.
    - rewrite forallb_map.
      red in X. solve_all.
    - rewrite forallb_map. red in X.
      solve_all. to_prop.
      apply /andP; split; to_wfu; auto 4.
    - rewrite forallb_map. red in X.
      solve_all. to_prop.
      apply /andP; split; to_wfu; auto 4.
  Qed.
  
  Lemma weaken_wf_universe Σ Σ' t : wf Σ' -> extends Σ.1 Σ' ->
    wf_universe Σ t ->
    wf_universe (Σ', Σ.2) t.
  Proof.
    intros wfΣ ext.
    destruct t; simpl; auto.
    intros Hl l inl; specialize (Hl l inl).
    apply LS.union_spec. apply LS.union_spec in Hl as [Hl|Hl]; simpl.
    left; auto.
    right. destruct ext as [? ->]. simpl.
    rewrite global_levels_ext.
    eapply LS.union_spec. right; auto.
  Qed.

  Lemma weaken_wf_universe_level Σ Σ' t : wf Σ' -> extends Σ.1 Σ' ->
    wf_universe_level Σ t ->
    wf_universe_level (Σ', Σ.2) t.
  Proof.
    intros wfΣ ext.
    unfold wf_universe_level.
    destruct t; simpl; auto;
    intros; apply LS.union_spec.
    - right. eapply global_levels_Set.
    - eapply LS.union_spec in H as [H|H].
      left; auto.
      right; auto. simpl.
      destruct ext. subst Σ'.
      rewrite global_levels_ext.
      eapply LS.union_spec. right; auto.
    - eapply in_var_global_ext in H; eauto.
      now eapply wf_extends.
  Qed.

  Lemma weaken_wf_universe_instance Σ Σ' t : wf Σ' -> extends Σ.1 Σ' ->
    wf_universe_instance Σ t ->
    wf_universe_instance (Σ', Σ.2) t.
  Proof.
    intros wfΣ ext.
    unfold wf_universe_instance.
    intros H; eapply Forall_impl; eauto.
    intros. now eapply weaken_wf_universe_level.
  Qed.

  Lemma weaken_wf_universes Σ Σ' t : wf Σ' -> extends Σ.1 Σ' ->
    wf_universes Σ t ->
    wf_universes (Σ', Σ.2) t.
  Proof.
    intros wfΣ ext.
    induction t using term_forall_list_ind; simpl in *; auto; intros; to_prop;
    try apply /andP; to_wfu; intuition eauto 4.

  - now eapply weaken_wf_universe.
  - apply /andP; to_wfu; intuition eauto 4.
  - apply /wf_universe_instanceP; apply weaken_wf_universe_instance; eauto.
    now apply /wf_universe_instanceP.
  - apply /wf_universe_instanceP; apply weaken_wf_universe_instance; eauto.
    now apply /wf_universe_instanceP.
  - apply /wf_universe_instanceP; apply weaken_wf_universe_instance; eauto.
    now apply /wf_universe_instanceP.
  - apply /andP; to_wfu; intuition eauto 4.
  - red in X; solve_all.
  - red in X. solve_all. to_prop.
    apply /andP; split; to_wfu; auto 4.
  - red in X. solve_all. to_prop.
    apply /andP; split; to_wfu; auto 4.
  Qed.

  Lemma wf_universes_weaken_full : weaken_env_prop_full (fun Σ Γ t T => 
      wf_universes Σ t && wf_universes Σ T).
  Proof.
    red. intros.     
    to_prop; apply /andP; split; now apply weaken_wf_universes.
  Qed.

  Lemma wf_universes_weaken :
    weaken_env_prop
      (lift_typing (fun Σ Γ (t T : term) =>
        wf_universes Σ t && wf_universes Σ T)).
  Proof.
    red. intros.
    unfold lift_typing in *. destruct T. now eapply (wf_universes_weaken_full (_, _)).
    destruct X1 as [s Hs]; exists s. now eapply (wf_universes_weaken_full (_, _)).
  Qed.

  Lemma wf_universes_inds Σ mind u bodies : 
    wf_universe_instance Σ u ->
    All (fun t : term => wf_universes Σ t) (inds mind u bodies).
  Proof.
    intros wfu.
    unfold inds.
    generalize #|bodies|.
    induction n; simpl; auto.
    constructor; auto.
    simpl. now apply /wf_universe_instanceP.
  Qed.

  Lemma wf_universes_mkApps Σ f args : 
    wf_universes Σ (mkApps f args) = wf_universes Σ f && forallb (wf_universes Σ) args.
  Proof.
    induction args using rev_ind; simpl; auto. now rewrite andb_true_r.
    rewrite -PCUICAstUtils.mkApps_nested /= IHargs forallb_app /=.
    now rewrite andb_true_r andb_assoc.
  Qed.
    
  Lemma type_local_ctx_wf Σ Γ Δ s : type_local_ctx
    (lift_typing
     (fun (Σ : PCUICEnvironment.global_env_ext)
        (_ : PCUICEnvironment.context) (t T : term) =>
      wf_universes Σ t && wf_universes Σ T)) Σ Γ Δ s ->
      All (fun d => option_default (wf_universes Σ) (decl_body d) true && wf_universes Σ (decl_type d)) Δ.
  Proof.
    induction Δ as [|[na [b|] ty] ?]; simpl; constructor; auto.
    simpl.
    destruct X as [? [? ?]]. now to_prop.
    apply IHΔ. apply X.
    simpl.
    destruct X as [? ?]. now to_prop.
    apply IHΔ. apply X.
  Qed.

  Lemma consistent_instance_ext_wf Σ univs u : consistent_instance_ext Σ univs u ->
    wf_universe_instance Σ u.
  Proof.
    destruct univs; simpl.
    - destruct u => // /=.
      intros _. constructor.
    - intros [H%forallb_Forall [H' H'']].
      eapply Forall_impl; eauto.
      simpl; intros. now eapply LS.mem_spec in H0.
  Qed.

  Ltac specIH :=
    repeat match goal with
    | [ H : on_udecl _ _, H' : on_udecl _ _ -> _ |- _ ] => specialize (H' H)
    end.

  Local Lemma wf_type_local_ctx_smash (Σ : global_env_ext) mdecl args sort :
    type_local_ctx
    (lift_typing
       (fun (Σ : PCUICEnvironment.global_env_ext)
          (_ : PCUICEnvironment.context) (t T : term) =>
        wf_universes Σ t && wf_universes Σ T)) (Σ.1, ind_universes mdecl)
    (arities_context (ind_bodies mdecl),,, ind_params mdecl)
    args sort ->
    type_local_ctx
    (lift_typing
       (fun (Σ : PCUICEnvironment.global_env_ext)
          (_ : PCUICEnvironment.context) (t T : term) =>
        wf_universes Σ t && wf_universes Σ T)) (Σ.1, ind_universes mdecl)
    (arities_context (ind_bodies mdecl),,, ind_params mdecl)
    (smash_context [] args) sort.
  Proof.
    induction args as [|[na [b|] ty] args]; simpl; auto.
    intros [].
    rewrite subst_context_nil. auto.
    intros [].
    rewrite smash_context_acc /=. split. auto.
    rewrite wf_universes_subst.
    clear -t. generalize 0.
    induction args as [|[na [b|] ty] args]; simpl in *; auto.
    destruct t as [? [[s wf] [? ?]%MCProd.andP]].
    constructor; auto.
    rewrite wf_universes_subst. apply IHargs; auto.
    now rewrite wf_universes_lift.
    constructor => //. now apply IHargs.
    now rewrite wf_universes_lift.
  Qed.

  Lemma wf_type_local_ctx_nth_error Σ P Γ Δ s n d : 
    type_local_ctx P Σ Γ Δ s -> 
    nth_error Δ n = Some d ->
    ∑ Γ' t, P Σ Γ' (decl_type d) t.
  Proof.
    induction Δ as [|[na [b|] ty] Δ] in n |- *; simpl; auto.
    - now rewrite nth_error_nil.
    - intros [h [h' h'']].
      destruct n. simpl. move=> [= <-] /=. do 2 eexists; eauto.
      now simpl; apply IHΔ.
    - intros [h h'].
      destruct n. simpl. move=> [= <-] /=. eexists; eauto.
      now simpl; apply IHΔ.
  Qed.

  Lemma In_unfold_var x n : In x (unfold n Level.Var) <-> exists k, k < n /\ (x = Level.Var k).
  Proof.
    split.
    - induction n => /= //.
      intros [hin|hin]%in_app_or.
      destruct (IHn hin) as [k [lt eq]].
      exists k; auto.
      destruct hin => //. subst x.
      eexists; eauto.
    - intros [k [lt ->]].
      induction n in k, lt |- *. lia.
      simpl. apply in_or_app.
      destruct (lt_dec k n). left; auto.
      right. left. f_equal. lia.      
  Qed.

  Lemma wf_abstract_instance Σ decl :
    wf_universe_instance (Σ, decl) (PCUICLookup.abstract_instance decl).
  Proof.
    destruct decl as [|[u cst]]=> /= //.
    red. constructor.
    rewrite /UContext.instance /AUContext.repr /=.
    rewrite mapi_unfold.
    red. eapply In_Forall.
    intros x hin. eapply In_unfold_var in hin as [k [lt eq]].
    subst x. red.
    eapply LS.union_spec; left. simpl.
    rewrite /AUContext.levels /= mapi_unfold.
    eapply (proj2 (LevelSetProp.of_list_1 _ _)).
    apply SetoidList.InA_alt. eexists; split; eauto.
    eapply In_unfold_var. exists k; split; eauto.
  Qed.

  Definition wf_decl_universes Σ d :=
    option_default (wf_universes Σ) d.(decl_body) true &&
    wf_universes Σ d.(decl_type).
  
  Definition wf_ctx_universes Σ Γ :=
    forallb (wf_decl_universes Σ) Γ.
  
  Lemma wf_universes_it_mkProd_or_LetIn {Σ Γ T} : 
    wf_universes Σ (it_mkProd_or_LetIn Γ T) = wf_ctx_universes Σ Γ && wf_universes Σ T.
  Proof.
    induction Γ as [ |[na [b|] ty] Γ] using rev_ind; simpl; auto;
      now rewrite it_mkProd_or_LetIn_app /= IHΓ /wf_ctx_universes forallb_app /=
      {3}/wf_decl_universes; cbn; bool_congr.
  Qed.
  
  Lemma wf_projs Σ ind npars p :
    All (fun t : term => wf_universes Σ t) (projs ind npars p).
  Proof.
    induction p; simpl; auto.
  Qed.

  Lemma wf_extended_subst Σ Γ n :
    wf_ctx_universes Σ Γ ->
    All (fun t : term => wf_universes Σ t) (extended_subst Γ n).
  Proof.
    induction Γ as [|[na [b|] ty] Γ] in n |- *; simpl; auto.
    move=> /andP []; rewrite /wf_decl_universes /= => /andP [] wfb wfty wfΓ.
    constructor; eauto. rewrite wf_universes_subst //. now apply IHΓ.
    now rewrite wf_universes_lift. eauto.
    move=> /andP []; rewrite /wf_decl_universes /= => wfty wfΓ.
    constructor; eauto.
  Qed.

  Theorem wf_types :
    env_prop (fun Σ Γ t T => 
      wf_universes Σ t && wf_universes Σ T)
      (fun Σ Γ wfΓ =>
      All_local_env_over typing
      (fun (Σ : global_env_ext) (Γ : context) (_ : wf_local Σ Γ) 
         (t T : term) (_ : Σ;;; Γ |- t : T) => wf_universes Σ t && wf_universes Σ T) Σ Γ
      wfΓ).
  Proof.
    apply typing_ind_env; intros; rename_all_hyps; simpl; specIH; to_prop; simpl; auto.

    - rewrite wf_universes_lift.
      destruct (nth_error_All_local_env_over heq_nth_error X) as [HΓ' Hd].
      destruct decl as [na [b|] ty]; cbn -[skipn] in *.
      + destruct Hd as [Hd _]; now to_prop.
      + destruct lookup_wf_local_decl; cbn -[skipn] in *.
        destruct o. now simpl in Hd; to_prop.

    - apply/andP; split; to_wfu; eauto with pcuic.
       
    - simpl in *; to_wfu; eauto with pcuic.
    - rewrite wf_universes_subst. constructor. to_wfu; auto. constructor.
      now move/andP: H3 => [].

    - apply/andP; split.
      { apply/wf_universe_instanceP.
        eapply consistent_instance_ext_wf; eauto. }
      pose proof (declared_constant_inv _ _ _ _ wf_universes_weaken wf X H).
      red in X1; cbn in X1.
      destruct (cst_body decl).
      * to_prop.
        epose proof (weaken_lookup_on_global_env'' Σ.1 _ _ wf H).
        epose proof (weaken_lookup_on_global_env' Σ.1 _ _ wf H).
        eapply wf_universes_inst. 2:eauto. all:eauto.
        simpl in H3.
        eapply sub_context_set_trans; eauto.
        eapply global_context_set_sub_ext.
        now eapply consistent_instance_ext_wf.
      * move: X1 => [s /andP[Hc _]].
        to_prop.
        eapply wf_universes_inst; eauto.
        exact (weaken_lookup_on_global_env' Σ.1 _ _ wf H).
        epose proof (weaken_lookup_on_global_env'' Σ.1 _ _ wf H).
        eapply sub_context_set_trans; eauto.
        eapply global_context_set_sub_ext.
        now eapply consistent_instance_ext_wf.

    - apply/andP; split.
      { apply/wf_universe_instanceP.
        eapply consistent_instance_ext_wf; eauto. }
      pose proof (declared_inductive_inv wf_universes_weaken wf X isdecl).
      cbn in X1. eapply onArity in X1. cbn in X1.
      move: X1 => [s /andP[Hind ?]].
      eapply wf_universes_inst; eauto.
      exact (weaken_lookup_on_global_env' Σ.1 _ _ wf (proj1 isdecl)).
      generalize (weaken_lookup_on_global_env'' Σ.1 _ _ wf (proj1 isdecl)).
      simpl. intros H'.
      eapply sub_context_set_trans; eauto.
      eapply global_context_set_sub_ext.
      now eapply consistent_instance_ext_wf.

    - apply/andP; split.
      { apply/wf_universe_instanceP.
        eapply consistent_instance_ext_wf; eauto. }
      pose proof (declared_constructor_inv wf_universes_weaken wf X isdecl) as [sc [nthe onc]].
      unfold type_of_constructor.
      rewrite wf_universes_subst.
      { apply wf_universes_inds.
        now eapply consistent_instance_ext_wf. }
      eapply on_ctype in onc. cbn in onc.
      move: onc=> [_ /andP[onc _]].
      eapply wf_universes_inst; eauto.
      exact (weaken_lookup_on_global_env' Σ.1 _ _ wf (proj1 (proj1 isdecl))).
      generalize (weaken_lookup_on_global_env'' Σ.1 _ _ wf (proj1 (proj1 isdecl))).
      simpl. intros H'.
      eapply sub_context_set_trans; eauto.
      eapply global_context_set_sub_ext.
      now eapply consistent_instance_ext_wf.
    
    - apply /andP. split.
      solve_all. cbn in *. now to_prop.
      rewrite wf_universes_mkApps; apply/andP; split; auto.
      rewrite forallb_app /= H /= andb_true_r.
      rewrite forallb_skipn //.
      rewrite wf_universes_mkApps in H0.
      now to_prop.

    - rewrite /subst1. rewrite wf_universes_subst.
      constructor => //. eapply All_rev.
      rewrite wf_universes_mkApps in H1.
      move/andP: H1 => [].
      now intros _ hargs%forallb_All.
      pose proof (declared_projection_inv wf_universes_weaken wf X isdecl).
      destruct (declared_inductive_inv); simpl in *.
      destruct ind_cshapes as [|cs []] => //.
      destruct X1. red in o. subst ty.
      destruct nth_error eqn:heq => //.
      destruct o as [_ ->].
      rewrite wf_universes_mkApps in H1.
      move/andP: H1 => [/wf_universe_instanceP wfu wfargs].

      eapply (wf_universes_inst (ind_universes mdecl)); eauto.
      exact (weaken_lookup_on_global_env' Σ.1 _ _ wf (proj1 (proj1 isdecl))).
      generalize (weaken_lookup_on_global_env'' Σ.1 _ _ wf (proj1 (proj1 isdecl))).
      simpl. intros H'.
      eapply sub_context_set_trans; eauto.
      eapply global_context_set_sub_ext.
      rewrite wf_universes_subst.
      eapply wf_universes_inds; eauto.
      eapply wf_abstract_instance.
      rewrite wf_universes_subst. apply wf_projs.
      rewrite wf_universes_lift.
      destruct p0 as [[? ?] ?].
      rewrite smash_context_app smash_context_acc in heq.
      autorewrite with len in heq. rewrite nth_error_app_lt in heq.
      autorewrite with len. lia.
      rewrite nth_error_subst_context in heq.
      autorewrite with len in heq. simpl in heq.
      epose proof (nth_error_lift_context_eq _ (smash_context [] (ind_params mdecl)) _ _).
      autorewrite with len in H. simpl in H. rewrite -> H in heq. clear H.
      autorewrite with len in heq.
      simpl in heq.
      destruct nth_error eqn:hnth; simpl in * => //.
      noconf heq. simpl.
      rewrite wf_universes_subst.
      apply wf_extended_subst.
      rewrite ind_arity_eq in onArity. destruct onArity as [s Hs].
      rewrite wf_universes_it_mkProd_or_LetIn in Hs.
      now move/andP: Hs => /andP /andP [] /andP [].
      rewrite wf_universes_lift.
      eapply wf_type_local_ctx_smash in t.
      eapply wf_type_local_ctx_nth_error in t as [? [? H]]; eauto.
      red in H. destruct x0. now move/andP: H => [].
      now destruct H as [s [Hs _]%MCProd.andP].
    
    - apply/andP; split; auto.
      solve_all. move:a => [s [Hty /andP[wfty wfs]]].
      to_prop. now rewrite wfty.
      eapply nth_error_all in X0; eauto.
      simpl in X0. now move: X0 => [s [Hty /andP[wfty _]]].

    - apply/andP; split; auto.
      solve_all. move:a => [s [Hty /andP[wfty wfs]]].
      to_prop. now rewrite wfty.
      eapply nth_error_all in X0; eauto.
      simpl in X0. now move: X0 => [s [Hty /andP[wfty _]]].
  Qed.

  Lemma typing_wf_universes {Σ : global_env_ext} {Γ t T} : 
    wf Σ ->
    Σ ;;; Γ |- t : T -> wf_universes Σ t && wf_universes Σ T.
  Proof.
    intros wfΣ Hty.
    exact (env_prop_typing _ _ wf_types _ wfΣ _ _ _ Hty).
  Qed.

  Lemma typing_wf_universe {Σ : global_env_ext} {Γ t s} : 
    wf Σ ->
    Σ ;;; Γ |- t : tSort s -> wf_universe Σ s.
  Proof.
    intros wfΣ Hty.
    apply typing_wf_universes in Hty as [_ wfs]%MCProd.andP; auto.
    simpl in wfs. now to_wfu.
  Qed.

  Lemma isType_wf_universes {Σ Γ T} : wf Σ.1 -> isType Σ Γ T -> wf_universes Σ T.
  Proof.
    intros wfΣ [s Hs]. now eapply typing_wf_universes in Hs as [HT _]%MCProd.andP.
  Qed.
  
End CheckerFlags.

Hint Resolve @wf_universe_type1 @wf_universe_super @wf_universe_sup @wf_universe_product : pcuic.

Hint Extern 4 (wf_universe _ ?u) => 
  match goal with
  [ H : typing _ _ _ (tSort u) |- _ ] => apply (typing_wf_universe _ H)
  end : pcuic.
