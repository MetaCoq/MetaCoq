(* Distributed under the terms of the MIT license. *)
From Coq Require Import Utf8 Program.
From MetaCoq.Template Require Import config utils Kernames.
From MetaCoq.PCUIC Require Import PCUICAst PCUICAstUtils
     PCUICReflect PCUICWeakeningEnv
     PCUICTyping PCUICInversion PCUICGeneration
     PCUICConfluence PCUICConversion 
     PCUICCumulativity PCUICSR PCUICSafeLemmata
     PCUICValidity PCUICPrincipality PCUICElimination PCUICSN.
     
From MetaCoq.SafeChecker Require Import PCUICSafeReduce PCUICSafeChecker PCUICSafeRetyping.
From MetaCoq.Erasure Require Import EAstUtils EArities Extract Prelim ErasureCorrectness EDeps 
    ErasureFunction ELiftSubst.

Local Open Scope string_scope.
Set Asymmetric Patterns.
Import MonadNotation.

From Equations Require Import Equations.
Set Equations Transparent.
Local Set Keyed Unification.
Require Import ssreflect ssrbool.

(** We assumes [Prop </= Type] and universes are checked correctly in the following. *)
Local Existing Instance extraction_checker_flags.

Ltac introdep := let H := fresh in intros H; depelim H.

Hint Constructors Ee.eval : core.

Import E.

Section optimize.
  Context (Σ : global_context).

  Fixpoint optimize (t : term) : term :=
    match t with
    | tRel i => tRel i
    | tEvar ev args => tEvar ev (List.map optimize args)
    | tLambda na M => tLambda na (optimize M)
    | tApp u v => tApp (optimize u) (optimize v)
    | tLetIn na b b' => tLetIn na (optimize b) (optimize b')
    | tCase ind c brs =>
      let brs' := List.map (on_snd optimize) brs in
      match ETyping.is_propositional_ind Σ (fst ind) with
      | Some true =>
        match brs' with
        | [(a, b)] => E.mkApps b (repeat E.tBox a)
        | _ => E.tCase ind (optimize c) brs'
        end
      | _ => E.tCase ind (optimize c) brs'
      end
    | tProj p c =>
      match ETyping.is_propositional_ind Σ p.1.1 with 
      | Some true => tBox
      | _ => tProj p (optimize c)
      end
    | tFix mfix idx =>
      let mfix' := List.map (map_def optimize) mfix in
      tFix mfix' idx
    | tCoFix mfix idx =>
      let mfix' := List.map (map_def optimize) mfix in
      tCoFix mfix' idx
    | tBox => t
    | tVar _ => t
    | tConst _ => t
    | tConstruct _ _ => t
    end.

  Lemma optimize_mkApps f l : optimize (mkApps f l) = mkApps (optimize f) (map optimize l).
  Proof.
    induction l using rev_ind; simpl; auto.
    now rewrite -mkApps_nested /= IHl map_app /= -mkApps_nested /=.
  Qed.
  
  Lemma optimize_iota_red pars n args brs :
    optimize (ETyping.iota_red pars n args brs) = ETyping.iota_red pars n (map optimize args) (map (on_snd optimize) brs).
  Proof.
    unfold ETyping.iota_red.
    rewrite !nth_nth_error nth_error_map.
    destruct nth_error eqn:hnth => /=;
    now rewrite optimize_mkApps map_skipn.
  Qed.
  
  Lemma map_repeat {A B} (f : A -> B) x n : map f (repeat x n) = repeat (f x) n.
  Proof.
    now induction n; simpl; auto; rewrite IHn.
  Qed.
  
  Lemma map_optimize_repeat_box n : map optimize (repeat tBox n) = repeat tBox n.
  Proof. by rewrite map_repeat. Qed.

  Import ECSubst.

  Lemma csubst_mkApps {a k f l} : csubst a k (mkApps f l) = mkApps (csubst a k f) (map (csubst a k) l).
  Proof.
    induction l using rev_ind; simpl; auto.
    rewrite - mkApps_nested /= IHl.
    now rewrite [EAst.tApp _ _](mkApps_nested _ _ [_]) map_app.
  Qed.

  Lemma optimize_csubst a k b : 
    optimize (ECSubst.csubst a k b) = ECSubst.csubst (optimize a) k (optimize b).
  Proof.
    induction b in k |- * using EInduction.term_forall_list_ind; simpl; auto; 
      try solve [f_equal; eauto; ELiftSubst.solve_all].
    
    - destruct (k ?= n); auto.
    - f_equal; eauto. rewrite !map_map_compose; eauto.
      solve_all.
    - destruct ETyping.is_propositional_ind as [[|]|] => /= //.
      destruct l as [|[br n] [|l']] eqn:eql; simpl.
      * f_equal; auto.
      * depelim X. simpl in *.
        rewrite e. rewrite csubst_mkApps.
        now rewrite map_repeat /=.
      * depelim X.
        f_equal; eauto.
        f_equal; eauto. now rewrite e.
        f_equal; eauto.
        f_equal. depelim X.
        now rewrite e0. depelim X. rewrite !map_map_compose.
        solve_all.
      * f_equal; eauto.
        rewrite !map_map_compose; solve_all.
      * f_equal; eauto.
        rewrite !map_map_compose; solve_all.
    - destruct ETyping.is_propositional_ind as [[|]|]=> //;
      now rewrite IHb.
    - rewrite !map_map_compose; f_equal; solve_all.
      destruct x; unfold EAst.map_def; simpl in *. 
      autorewrite with len. f_equal; eauto.
    - rewrite !map_map_compose; f_equal; solve_all.
      destruct x; unfold EAst.map_def; simpl in *. 
      autorewrite with len. f_equal; eauto.
  Qed.

  Lemma optimize_substl s t : optimize (Ee.substl s t) = Ee.substl (map optimize s) (optimize t).
  Proof.
    induction s in t |- *; simpl; auto.
    rewrite IHs. f_equal.
    now rewrite optimize_csubst.
  Qed.

  Lemma optimize_fix_subst mfix : ETyping.fix_subst (map (map_def optimize) mfix) = map optimize (ETyping.fix_subst mfix).
  Proof.
    unfold ETyping.fix_subst.
    rewrite map_length.
    generalize #|mfix|.
    induction n; simpl; auto.
    f_equal; auto.
  Qed.

  Lemma optimize_cofix_subst mfix : ETyping.cofix_subst (map (map_def optimize) mfix) = map optimize (ETyping.cofix_subst mfix).
  Proof.
    unfold ETyping.cofix_subst.
    rewrite map_length.
    generalize #|mfix|.
    induction n; simpl; auto.
    f_equal; auto.
  Qed.

  Lemma optimize_cunfold_fix mfix idx n f : 
    Ee.cunfold_fix mfix idx = Some (n, f) ->
    Ee.cunfold_fix (map (map_def optimize) mfix) idx = Some (n, optimize f).
  Proof.
    unfold Ee.cunfold_fix.
    rewrite nth_error_map.
    destruct nth_error.
    intros [= <- <-] => /=. f_equal.
    now rewrite optimize_substl optimize_fix_subst.
    discriminate.
  Qed.

  Lemma optimize_cunfold_cofix mfix idx n f : 
    Ee.cunfold_cofix mfix idx = Some (n, f) ->
    Ee.cunfold_cofix (map (map_def optimize) mfix) idx = Some (n, optimize f).
  Proof.
    unfold Ee.cunfold_cofix.
    rewrite nth_error_map.
    destruct nth_error.
    intros [= <- <-] => /=. f_equal.
    now rewrite optimize_substl optimize_cofix_subst.
    discriminate.
  Qed.

  Lemma optimize_nth {n l d} : 
    optimize (nth n l d) = nth n (map optimize l) (optimize d).
  Proof.
    induction l in n |- *; destruct n; simpl; auto.
  Qed.

End optimize.


Lemma is_box_inv b : is_box b -> ∑ args, b = mkApps tBox args.
Proof.
  unfold is_box, EAstUtils.head.
  destruct decompose_app eqn:da.
  simpl. destruct t => //.
  eapply decompose_app_inv in da. subst.
  eexists; eauto.
Qed.

Lemma eval_is_box {wfl:Ee.WcbvFlags} Σ t u : Σ ⊢ t ▷ u -> is_box t -> u = EAst.tBox.
Proof.
  intros ev; induction ev => //.
  - rewrite is_box_tApp.
    intros isb. intuition congruence.
  - rewrite is_box_tApp. move/IHev1 => ?; solve_discr.
  - rewrite is_box_tApp. move/IHev1 => ?; solve_discr.
  - rewrite is_box_tApp. move/IHev1 => ?. subst => //.
  - destruct t => //.
Qed. 

Lemma isType_tSort {cf:checker_flags} {Σ : global_env_ext} {Γ l A} {wfΣ : wf Σ} : Σ ;;; Γ |- tSort (Universe.make l) : A -> isType Σ Γ (tSort (Universe.make l)).
Proof.
  intros HT.
  eapply inversion_Sort in HT as [l' [wfΓ Hs]]; auto.
  eexists; econstructor; eauto.
Qed.

Lemma isType_it_mkProd {cf:checker_flags} {Σ : global_env_ext} {Γ na dom codom A} {wfΣ : wf Σ} :   
  Σ ;;; Γ |- tProd na dom codom : A -> 
  isType Σ Γ (tProd na dom codom).
Proof.
  intros HT.
  eapply inversion_Prod in HT as (? & ? & ? & ? & ?); auto.
  eexists; econstructor; eauto.
Qed.

Lemma erasable_tBox_value (wfl := Ee.default_wcbv_flags) (Σ : global_env_ext) (wfΣ : wf_ext Σ) t T v :
  axiom_free Σ.1 ->
  forall wt : Σ ;;; [] |- t : T,
  Σ |-p t ▷ v -> erases Σ [] v tBox -> ∥ isErasable Σ [] t ∥.
Proof.
  intros.
  depind H0.
  eapply Is_type_eval_inv; eauto. eexists; eauto.
Qed.

Lemma erase_eval_to_box (wfl := Ee.default_wcbv_flags) {Σ : global_env_ext}  {wfΣ : wf_ext Σ} {t v Σ' t' deps} :
  axiom_free Σ.1 ->
  forall wt : welltyped Σ [] t,
  erase Σ (sq wfΣ) [] t wt = t' ->
  KernameSet.subset (term_global_deps t') deps ->
  erase_global deps Σ (sq wfΣ.1) = Σ' ->
  PCUICWcbvEval.eval Σ t v ->
  @Ee.eval Ee.default_wcbv_flags Σ' t' tBox -> ∥ isErasable Σ [] t ∥.
Proof.
  intros axiomfree [T wt].
  intros.
  destruct (erase_correct Σ wfΣ _ _ _ _ _ axiomfree _ H H0 H1 X) as [ev [eg [eg']]].
  pose proof (Ee.eval_deterministic H2 eg'). subst.
  eapply erasable_tBox_value; eauto.
Qed.

Definition optimize_constant_decl Σ cb := 
  {| cst_body := option_map (optimize Σ) cb.(cst_body) |}.
  
Definition optimize_decl Σ d :=
  match d with
  | ConstantDecl cb => ConstantDecl (optimize_constant_decl Σ cb)
  | InductiveDecl idecl => d
  end.

Definition optimize_env (Σ : EAst.global_declarations) := 
  map (on_snd (optimize_decl Σ)) Σ.

Import ETyping.

(* Lemma optimize_extends Σ Σ' : extends Σ Σ' ->
  optimize Σ t = optimize Σ' t. *)

Lemma lookup_env_optimize Σ kn : 
  lookup_env (optimize_env Σ) kn = 
  option_map (optimize_decl Σ) (lookup_env Σ kn).
Proof.
  unfold optimize_env.
  induction Σ at 2 4; simpl; auto.
  destruct kername_eq_dec => //.
Qed.

Lemma is_propositional_optimize Σ ind : 
  is_propositional_ind Σ ind = is_propositional_ind (optimize_env Σ) ind.
Proof.
  rewrite /is_propositional_ind.
  rewrite lookup_env_optimize.
  destruct lookup_env; simpl; auto.
  destruct g; simpl; auto.
Qed.

Lemma isLambda_mkApps f l : ~~ isLambda f -> ~~ EAst.isLambda (mkApps f l).
Proof.
  induction l using rev_ind; simpl; auto => //.
  intros isf; specialize (IHl isf).
  now rewrite -mkApps_nested.
Qed.
 
Lemma isFixApp_mkApps f l : ~~ Ee.isFixApp f -> ~~ Ee.isFixApp (mkApps f l).
Proof.
  unfold Ee.isFixApp.
  erewrite <- (fst_decompose_app_rec _ l).
  now rewrite /decompose_app decompose_app_rec_mkApps app_nil_r.
Qed.

Lemma isBox_mkApps f l : ~~ isBox f -> ~~ isBox (mkApps f l).
Proof.
  induction l using rev_ind; simpl; auto => //.
  intros isf; specialize (IHl isf).
  now rewrite -mkApps_nested.
Qed.

Definition extends (Σ Σ' : global_declarations) := ∑ Σ'', Σ' = Σ'' ++ Σ.

Definition fresh_global kn (Σ : global_declarations) :=
  Forall (fun x => x.1 <> kn) Σ.

Inductive wf_glob : global_declarations -> Type :=
| wf_glob_nil : wf_glob []
| wf_glob_cons kn d Σ : 
  wf_glob Σ ->
  fresh_global kn Σ ->
  wf_glob ((kn, d) :: Σ).
Derive Signature for wf_glob.

Lemma lookup_env_Some_fresh {Σ c decl} :
  lookup_env Σ c = Some decl -> ~ (fresh_global c Σ).
Proof.
  induction Σ; cbn. 1: congruence.
  unfold eq_kername; destruct kername_eq_dec; subst.
  - intros [= <-] H2. inv H2.
    contradiction.
  - intros H1 H2. apply IHΣ; tas.
    now inv H2.
Qed.

Lemma extends_lookup {Σ Σ' c decl} :
  wf_glob Σ' ->
  extends Σ Σ' ->
  lookup_env Σ c = Some decl ->
  lookup_env Σ' c = Some decl.
Proof.
  intros wfΣ' [Σ'' ->]. simpl.
  induction Σ'' in wfΣ', c, decl |- *.
  - simpl. auto.
  - specialize (IHΣ'' c decl). forward IHΣ''.
    + now inv wfΣ'.
    + intros HΣ. specialize (IHΣ'' HΣ).
      inv wfΣ'. simpl in *.
      unfold eq_kername; destruct kername_eq_dec; subst; auto.
      apply lookup_env_Some_fresh in IHΣ''; contradiction.
Qed.

Lemma extends_is_propositional {Σ Σ'} : 
  wf_glob Σ' -> extends Σ Σ' ->
  forall ind b, is_propositional_ind Σ ind = Some b -> is_propositional_ind Σ' ind = Some b.
Proof.
  intros wf ex ind b.
  rewrite /is_propositional_ind.
  destruct lookup_env eqn:lookup => //.
  now rewrite (extends_lookup wf ex lookup).
Qed.

Lemma weakening_eval_env (wfl : Ee.WcbvFlags) {Σ Σ'} : 
  wf_glob Σ' -> extends Σ Σ' ->
  ∀ v t, Ee.eval Σ v t -> Ee.eval Σ' v t.
Proof.
  intros wf ex t v ev.
  induction ev; try solve [econstructor; eauto using (extends_is_propositional wf ex)].
  econstructor; eauto.
  red in isdecl |- *. eauto using extends_lookup.
Qed.

Lemma optimize_correct Σ t v :
  @Ee.eval Ee.default_wcbv_flags Σ t v ->
  @Ee.eval Ee.opt_wcbv_flags (optimize_env Σ) (optimize Σ t) (optimize Σ v).
Proof.
  intros ev.
  induction ev; simpl in *; try solve [econstructor; eauto].

  - econstructor; eauto.
    now rewrite optimize_csubst in IHev3.

  - rewrite optimize_csubst in IHev2.
    econstructor; eauto.

  - rewrite optimize_mkApps in IHev1.
    rewrite optimize_iota_red in IHev2.
    destruct ETyping.is_propositional_ind as [[]|]eqn:isp => //.
    eapply Ee.eval_iota; eauto.
    now rewrite -is_propositional_optimize.
  
  - rewrite e e0 /=.
    now rewrite optimize_mkApps map_optimize_repeat_box in IHev2.

  - rewrite optimize_mkApps in IHev1.
    simpl in *. eapply Ee.eval_fix; eauto.
    rewrite map_length. now eapply optimize_cunfold_fix. 
    now rewrite optimize_mkApps in IHev3.

  - rewrite optimize_mkApps in IHev1 |- *.
    simpl in *. eapply Ee.eval_fix_value. auto. auto.
    eapply optimize_cunfold_fix; eauto. now rewrite map_length. 

  - destruct ETyping.is_propositional_ind as [[]|] eqn:isp => //.
    destruct brs as [|[a b] []]; simpl in *; auto.
    rewrite -> optimize_mkApps in IHev |- *. simpl.
    econstructor; eauto.
    now apply optimize_cunfold_cofix.
    rewrite -> optimize_mkApps in IHev |- *. simpl.
    econstructor; eauto.
    now apply optimize_cunfold_cofix.
    rewrite -> optimize_mkApps in IHev |- *. simpl.
    econstructor; eauto.
    now apply optimize_cunfold_cofix.
    rewrite -> optimize_mkApps in IHev |- *. simpl.
    econstructor; eauto.
    now apply optimize_cunfold_cofix.

  - destruct ETyping.is_propositional_ind as [[]|] eqn:isp; auto.
    rewrite -> optimize_mkApps in IHev |- *. simpl.
    econstructor; eauto.
    now apply optimize_cunfold_cofix.
    rewrite -> optimize_mkApps in IHev |- *. simpl.
    econstructor; eauto.
    now apply optimize_cunfold_cofix.
  
  - econstructor. red in isdecl |- *.
    rewrite lookup_env_optimize isdecl //.
    now rewrite /optimize_constant_decl e.
    apply IHev.
  
  - destruct ETyping.is_propositional_ind as [[]|] eqn:isp => //.
    rewrite optimize_mkApps in IHev1.
    rewrite optimize_nth in IHev2.
    econstructor; eauto. now rewrite -is_propositional_optimize.
  
  - now rewrite e.

  - eapply Ee.eval_app_cong; eauto.
    eapply Ee.eval_to_value in ev1.
    destruct ev1; simpl in *; eauto.
    * destruct t => //; rewrite optimize_mkApps /=.
    * destruct t => /= //; rewrite optimize_mkApps /=;
      rewrite (negbTE (isLambda_mkApps _ _ _)) // (negbTE (isBox_mkApps _ _ _)) 
        // (negbTE (isFixApp_mkApps _ _ _)) //.
    * destruct f0 => //.
      rewrite optimize_mkApps /=.
      unfold Ee.isFixApp in i.
      rewrite decompose_app_mkApps /= in i => //.
      rewrite orb_true_r /= // in i.
  - destruct t => //.
    all:constructor; eauto.
Qed.

Lemma erase_opt_correct (wfl := Ee.default_wcbv_flags) (Σ : global_env_ext) (wfΣ : wf_ext Σ) t v Σ' t' :
  axiom_free Σ.1 ->
  forall wt : welltyped Σ [] t,
  erase Σ (sq wfΣ) [] t wt = t' ->
  erase_global (term_global_deps t') Σ (sq wfΣ.1) = Σ' ->
  PCUICWcbvEval.eval Σ t v ->
  ∃ v' : term, Σ;;; [] |- v ⇝ℇ v' ∧ 
  ∥ @Ee.eval Ee.opt_wcbv_flags (optimize_env Σ') (optimize Σ' t') (optimize Σ' v') ∥.
Proof.
  intros axiomfree wt.
  generalize (sq wfΣ.1) as swfΣ.
  intros swfΣ HΣ' Ht' ev.
  assert (extraction_pre Σ) by now constructor.
  pose proof (erases_erase (wfΣ := sq wfΣ) wt); eauto.
  rewrite HΣ' in H.
  destruct wt as [T wt].
  unshelve epose proof (erase_global_erases_deps wfΣ wt H _); cycle 2.
  eapply erases_correct in ev; eauto.
  destruct ev as [v' [ev evv]].
  exists v'. split.
  2:{ sq. now apply optimize_correct. }
  auto. 
  rewrite <- Ht'.
  eapply erase_global_includes.
  intros.
  eapply term_global_deps_spec in H; eauto.
  eapply KernameSet.subset_spec.
  intros x hin; auto.
Qed.

Print Assumptions erase_opt_correct.