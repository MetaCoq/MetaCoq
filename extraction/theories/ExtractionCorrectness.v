(* Distributed under the terms of the MIT license.   *)

From Coq Require Import Bool String List Program BinPos Compare_dec Omega.
From Template Require Import config utils monad_utils BasicAst AstUtils.
From PCUIC Require Import PCUICAst PCUICAstUtils PCUICInduction PCUICTyping PCUICWeakening PCUICSubstitution PCUICChecker PCUICRetyping PCUICMetaTheory PCUICWcbvEval PCUICSR  PCUICClosed.
From TemplateExtraction Require Import EAst ELiftSubst ETyping EWcbvEval Extract Prelim ESubstitution EInversion EWeakening.
Require Import String.
Local Open Scope string_scope.
Set Asymmetric Patterns.
Import MonadNotation.

Require Import Lia.

Existing Instance config.default_checker_flags.
Module PA := PCUICAst.
Module P := PCUICWcbvEval.

Ltac inv H := inversion H; subst; clear H.

Lemma is_constructor_extract Σ n L :
  PCUICTyping.is_constructor n L ->
  is_constructor n (map (extract Σ []) L).
Proof.
Admitted.

(* Lemma mkApps_inj a b l1 l2  : *)
(*   mkApps a l1 = mkApps b l2 -> (~ exists a1 a2, a = tApp a1 a2) -> (~ exists b1 b2, b = tApp b1 b2) -> *)
(*   a = b /\ l1 = l2. *)
(* Proof. *)
(* (*   induction l1 in a, b, l2 |- *; cbn; intros. *) *)
(* (*   - destruct l2; eauto. cbn in H. subst. destruct H0. clear H1. *) *)
(* (*     revert b t; induction l2; cbn. *) *)
(* (*     + eauto. *) *)
(* (*     + intros. edestruct IHl2 as (? & ? & ?). eauto. *) *)
(* (*   - destruct l2; eauto. cbn in H. *) *)
(* (*     + subst. edestruct H1. *) *)
(* (*       clear. revert a a0; induction l1; cbn. *) *)
(* (*       * eauto. *) *)
(* (*       * intros. edestruct IHl1 as (? & ? & ?). eauto. *) *)
(* (*     + cbn in H. *) *)
    

(* (*     epose proof (IHl1 _ _ _ eq_refl). *) *)
(* (* Qed. *)     *)
(* Admitted. *)


(** ** Assumptions on typing of tCase *)

Lemma no_empty_case_in_empty_context Σ ind npar p c T :
  Σ;;; [] |- PCUICAst.tCase (ind, npar) p c [] : T -> False.
Proof.
Admitted.


(* Lemma prop_case_is_singleton  Σ ind npar p T i u args brs mdecl idecl : *)
(*   PCUICTyping.declared_inductive (fst Σ) mdecl ind idecl -> *)
(*   PCUICAst.ind_npars mdecl = npar -> *)
(*   is_type_or_proof Σ [] (PCUICAst.tConstruct ind i u) = true -> *)
(*   Σ;;; [] |- PCUICAst.tCase (ind, npar) p (PCUICAst.mkApps (PCUICAst.tConstruct ind i u) args) brs : T -> #|brs| = 1 /\ i = 0 /\ *)
(*                                                                                                               Forall (fun a => is_type_or_proof Σ [] a = true) (skipn (npar) args). *)
(* Proof. *)
(* Admitted. *)

Inductive extr_pre (Σ : PA.global_context) t T :=
  { extr_typed : Σ ;;; [] |- t : T;
    extr_env_axiom_free : axiom_free (fst Σ) }.

(* Lemma cumul_is_arity: *)
(*   forall (H : Fuel) (Σ : PCUICAst.global_context) (T' T'' : PCUICAst.term), *)
(*     Σ;;; [] |- T'' <= T' -> is_arity Σ [] H T'' = is_arity Σ [] H T'. *)
(* Proof. *)
(*   intros H Σ T' T''. *)
(* Admitted. *)

Lemma eval_is_type (Σ : PCUICAst.global_context) (t v : PCUICAst.term) (* T : *)
  (* wf Σ -> Σ ;;; [] |- t : T ->  *) :
  PCUICWcbvEval.eval Σ [] t v -> Extract.is_type_or_proof Σ [] t = Extract.is_type_or_proof Σ [] v.
Proof. 
  (* intros. *)
  (* unfold is_type_or_proof in *. *)
  (* simpl in *. destruct ? in H0. *)
  (* - destruct (type_of_sound _ X0 E) as []. *)
  (*   eapply subject_reduction_eval in t0; eauto. *)
  (*   destruct ?. *)
  (*   destruct (type_of_sound _ t0 E0) as []. *)
  (*   destruct ? in H0. *)
  (*   + erewrite <- cumul_is_arity in E1. rewrite E1. all:eauto. *)
  (*   + erewrite <- cumul_is_arity in E1. rewrite E1. all:eauto. *)
  (*     destruct ? in H0; inv H0. admit.  *)
  (*   + edestruct type_of_complete; eauto. congruence. *)
  (* - edestruct type_of_complete; eauto. congruence. *)
Admitted.

(** ** Concerning fixpoints *)

Fixpoint fix_subst' n l :=
  match n with
  | 0 => []
  | S n => PCUICAst.tFix l n :: fix_subst' n l
  end.

Fixpoint fix_subst'' n a l : list PCUICAst.term :=
  match n with
  | 0 => a
  | S n => fix_subst'' n (a ++ [PCUICAst.tFix l n])%list l
  end.


Lemma fix_subst_app l1 l2 : (PCUICTyping.fix_subst (l1 ++ l2) = fix_subst' (#|l1|) (l1 ++ l2) ++ fix_subst' (#|l1|) (l1 ++ l2)) % list.
Admitted.

Fixpoint fix_decls' (acc : list PCUICAst.context_decl) (ds : list (BasicAst.def PCUICAst.term)) {struct ds} :
  list PCUICAst.context_decl :=
  match ds with
  | [] => acc
  | d :: ds0 => fix_decls' (PCUICAst.vass (BasicAst.dname d) (dtype d) :: acc) ds0
  end.

Lemma fix_decls_app A mfix1 mfix2 :
  fix_decls' A (mfix1 ++ mfix2) = fix_decls' (fix_decls' A mfix1) mfix2.
Proof.
  revert A; induction mfix1; cbn; intros.
  - reflexivity.
  - eapply IHmfix1.
Qed.

Lemma subslet_fix_subst' Σ mfix1 mfix2 :
  subslet Σ [] (fix_subst' (#|mfix1|) mfix2) (fix_decls' [] mfix1).
Proof.
  revert mfix2. induction mfix1 using rev_ind; cbn; intros.
  - econstructor.
  - rewrite app_length. cbn. rewrite plus_comm. cbn.
    rewrite fix_decls_app. cbn. econstructor.
    eapply IHmfix1.
    admit (* typing *).
Admitted.

Lemma subslet_fix_subst Σ mfix1 :
  subslet Σ [] (PCUICTyping.fix_subst mfix1) (PCUICLiftSubst.fix_context mfix1).
Proof.
Admitted.

Lemma fix_subst'_subst mfix :
  fix_subst' (#|mfix|) mfix = PCUICTyping.fix_subst mfix.
Admitted.


Fixpoint efix_subst' n l :=
  match n with
  | 0 => []
  | S n => tFix l n :: efix_subst' n l
  end.
Lemma efix_subst'_subst mfix :
  efix_subst' (#|mfix|) mfix = fix_subst mfix.
Admitted.

Lemma efix_subst_app l1 l2 : (fix_subst (l1 ++ l2) = efix_subst' (#|l1|) (l1 ++ l2) ++ efix_subst' (#|l1|) (l1 ++ l2)) % list.
Admitted.

(** ** Proof inversions *)

Lemma is_type_ind:
  forall (Σ : PCUICAst.global_context) (i : inductive) (u : universe_instance) (T : PCUICAst.term),
    Σ;;; [] |- tInd i u : T -> is_type_or_proof Σ [] (tInd i u).
Proof.
  
Admitted.

Lemma is_type_App  Σ Γ a l T :
  Σ ;;; Γ |- PCUICAst.mkApps a l : T -> 
  is_type_or_proof Σ Γ a = is_type_or_proof Σ Γ (PCUICAst.mkApps a l).
Proof.
Admitted.
  
(* Lemma is_type_or_proof_lambda  Σ Γ na t b : *)
(*   Extract.is_type_or_proof Σ Γ (PCUICAst.tLambda na t b) =   *)
(*   Extract.is_type_or_proof Σ (Γ ,, PCUICAst.vass na t) b.  *)
(* Admitted. *)

(* Lemma is_type_or_proof_mkApps  Σ Γ a l : *)
(*   Extract.is_type_or_proof Σ Γ a = Checked true <-> *)
(*   Extract.is_type_or_proof Σ Γ (PCUICAst.mkApps a l) = Checked true. *)
(* Admitted. *)

Lemma is_type_subst1  (Σ : PCUICAst.global_context) (na : name) (t b a' : PCUICAst.term) :
  Extract.is_type_or_proof Σ ([],, PCUICAst.vass na t) b = 
  Extract.is_type_or_proof Σ [] (PCUICLiftSubst.subst1 a' 0 b).
Proof.
Admitted.

(** ** extract and mkApps *)

Lemma extract_Apps  Σ Γ a args :
  extract Σ Γ (PCUICAst.mkApps a args) = if is_type_or_proof Σ Γ a then tBox else mkApps (extract Σ Γ a) (map (extract Σ Γ) args).
Proof.
  revert a. induction args; cbn; intros.
  - destruct is_type_or_proof eqn:Ha.
    now eapply is_type_extract.
    reflexivity.
  - destruct is_type_or_proof eqn:Ha.
    + erewrite is_type_App with (l := [a]) in Ha.
      cbn in Ha.
      specialize (IHargs (PCUICAst.tApp a0 a)).
      rewrite Ha in IHargs.
      eauto.
      admit.
    + erewrite is_type_App with (l := [a]) in Ha.
      cbn in Ha.
      specialize (IHargs (PCUICAst.tApp a0 a)).
      rewrite Ha in IHargs.
      eauto.
      rewrite IHargs.
      cbn. now rewrite Ha.
      admit.
Admitted.

Lemma extract_tInd Σ i u :
  extract Σ [] (tInd i u) = tBox.
Proof.
  cbn. destruct is_type_or_proof eqn:E1; try destruct a; reflexivity. 
Qed.

(** ** Concerning extraction of constants *)

Fixpoint extract_global_decls' univs Σ1 Σ : E.global_declarations :=
  match Σ, Σ1 with
  | [], [] => []
  | PCUICAst.ConstantDecl kn cb :: Σ0, _ :: Σ1 =>
      let cb' := extract_constant_body (Σ1, univs) cb in
      let Σ' := extract_global_decls' univs Σ1 Σ0 in (E.ConstantDecl kn cb' :: Σ')
  | PCUICAst.InductiveDecl kn mib :: Σ0, _ :: Σ1 =>
    let mib' := extract_mutual_inductive_body (Σ1, univs) mib in
    let Σ' := extract_global_decls' univs Σ1 Σ0 in (E.InductiveDecl kn mib' :: Σ')
  | _, _ => []
   end.

Lemma extract_global_decls_eq  u Σ :
  extract_global_decls u Σ = extract_global_decls' u Σ Σ.
Proof.
  induction Σ.
  - reflexivity.
  - simpl. destruct a; congruence.
Qed.

Require Import PCUIC.PCUICWeakeningEnv.
Lemma extract_constant:
  forall (Σ : PCUICAst.global_context) (c : ident) (decl : PCUICAst.constant_body) (body : PCUICAst.term)
    (u : universe_instance) T,
    wf Σ ->
    Σ;;; [] |- PCUICAst.tConst c u : T ->
    PCUICTyping.declared_constant Σ c decl ->
    PCUICAst.cst_body decl = Some body ->
    exists decl' : constant_body, 
        declared_constant (extract_global Σ) c decl' /\
        cst_body decl' = Some (extract Σ [] (PCUICUnivSubst.subst_instance_constr u body)).
Proof.
  intros.
  (* eapply lookup_on_global_env in H as (? & ? & ?); eauto. cbn in *. *)
  (* unfold on_constant_decl in o. rewrite H0 in o. cbn in o. *)
  (* unfold on_global_env in x0. destruct x. cbn in *. *)
  destruct Σ as [Σ C]. induction Σ.
  - cbn in *. inv H.
  - cbn in *. inv H.
    destruct ? in H2.
    + inv H2.
      unfold declared_constant. cbn.
      destruct (ident_eq_spec c c); try congruence.
      eexists. split. reflexivity.
      cbn.
      rewrite H0. cbn. inv X.
      cbn in *. f_equal.
      admit.
    + edestruct IHΣ.
      * eapply wf_extends. eauto. eexists [ _ ]; cbn; eauto.
      * admit.
      * eapply H2.
      * destruct H.
        destruct a.
        -- eexists. split.
           unfold declared_constant. cbn. cbn in *. rewrite E.
           eapply H.
           rewrite H1. f_equal.
           eapply extract_extends.
           ++ eapply wf_extends. eauto. eexists [ _ ]; cbn; eauto.
           ++ econstructor.
           ++ admit.
           ++ eauto.
           ++ eexists [ _ ]; cbn; eauto.
        -- eexists. split.
           unfold declared_constant. cbn. cbn in *. rewrite E.
           eapply H.
           rewrite H1. f_equal.
           eapply extract_extends.
           ++ eapply wf_extends. eauto. eexists [ _ ]; cbn; eauto.
           ++ econstructor.
           ++ admit.
           ++ eauto.
           ++ eexists [ _ ]; cbn; eauto.
Admitted.
  
(** ** Concerning context conversion *)

Require Import PCUIC.PCUICGeneration.

Inductive red_decls Σ Γ Γ' : forall (x y : PCUICAst.context_decl), Type :=
| conv_vass na na' T T' : isWfArity_or_Type Σ Γ' T' -> red Σ Γ T T' ->
                      red_decls Σ Γ Γ' (PCUICAst.vass na T) (PCUICAst.vass na' T')

| conv_vdef_type na na' b T T' : isWfArity_or_Type Σ Γ' T' -> red Σ Γ T T' ->
                             red_decls Σ Γ Γ' (PCUICAst.vdef na b T) (PCUICAst.vdef na' b T')

| conv_vdef_body na na' b b' T : Σ ;;; Γ' |- b' : T -> red Σ Γ b b' ->
                                                  red_decls Σ Γ Γ' (PCUICAst.vdef na b T) (PCUICAst.vdef na' b' T).

Notation red_context := (context_relation red_decls).

Lemma context_conversion :
env_prop
  (fun (Σ : PCUICAst.global_context) (Γ : PCUICAst.context) (t T : PCUICAst.term) =>
     forall Γ' : PCUICAst.context, red_context Σ Γ Γ' -> Σ;;; Γ' |- t : T).
Admitted.

Lemma extract_context_conversion :
env_prop
  (fun (Σ : PCUICAst.global_context) (Γ : PCUICAst.context) (t T : PCUICAst.term) =>
     forall Γ' : PCUICAst.context, red_context Σ Γ Γ' -> forall a, extract Σ Γ a = extract Σ Γ' a).
Admitted.


(** ** Corrcectness of erasure *)
Hint Constructors PCUICWcbvEval.eval.

Theorem erasure_correct : erasure_correctness.
Proof.
  intros Σ t T pre v H. revert T pre.
  induction H using PCUICWcbvEval.eval_evals_ind; intros T pre.
  - (** beta case, done *) cbn.
    destruct Extract.is_type_or_proof eqn:Heq.
    + rewrite is_type_extract. econstructor. econstructor.
      erewrite <- eval_is_type. eauto. eauto.
    + inv pre. edestruct (type_mkApps_inv Σ [] f [a] T) as (? & U & [? ?] & ?); eauto. 
      inv t1. inv X2. pose proof (subject_reduction_eval _ [] _ _ _ extr_env_wf t0 H).
      eapply type_Lambda_inv in X2 as (? & ? & [? ?] & ?).

      cbn in IHeval1. 
      erewrite <- is_type_App with (l := [a]) in Heq; eauto.
      erewrite eval_is_type in Heq; try exact H.
      rewrite Heq in IHeval1.
      econstructor. eapply IHeval1. econstructor; eauto.
      eapply IHeval2. econstructor; eauto.

      assert (Σ ;;; [] |- a' : t). {
        eapply subject_reduction_eval; try eapply H0; eauto. 
        eapply cumul_trans in X0. 2:eauto. eapply cumul_Prod_inv in X0 as []. econstructor. eauto. eauto. eapply c1.
      }

      erewrite <- extract_subst1; eauto.
      eapply IHeval3. econstructor; eauto.

      eapply substitution0; eauto.
  - (** zeta case, done *)
    inv pre. eapply type_tLetIn_inv in extr_typed0 as (? & U & [[] ?] & ?); eauto. cbn.
    destruct Extract.is_type_or_proof eqn:Heq. 
    + rewrite is_type_extract. now econstructor.
      erewrite <- eval_is_type. eassumption.
      eauto.
    + econstructor.
      * eapply IHeval1. econstructor; eauto.
      * assert (extract Σ [PCUICAst.vdef na b0 t] b1 = extract Σ [PCUICAst.vdef na b0' t] b1) as ->. {
          eapply extract_context_conversion. 3: eassumption. all:eauto.
          econstructor. econstructor. cbn. eauto. econstructor 3. econstructor.
          econstructor. eapply subject_reduction_eval; eauto.
          eapply wcbeval_red. eauto.
        }
        assert (Σ ;;; [] |- b0' : t). {
          eapply subject_reduction_eval; eauto.
        }
        
        erewrite <- extract_subst1_vdef; eauto.
        eapply IHeval2. econstructor; eauto.
        eapply substitution_let; eauto.
        
        eapply (context_conversion _ _ _ _ _ _ t2).
        
        Hint Constructors context_relation red_decls.
        Hint Resolve wcbeval_red.
        econstructor; eauto.

        eapply (context_conversion _ _ _ _ _ _ t2).
        econstructor; eauto.
  - (** rel_def, trivial *) cbn in isdecl. inv isdecl.    
  - (** rel_undef, trivial *) cbn in isdecl. inv isdecl.    
  - (** iota case (tCase) *)
    cbn. destruct Extract.is_type_or_proof eqn:Heq.
    + rewrite is_type_extract. econstructor; eauto.
      erewrite <- eval_is_type. eassumption.
      econstructor; eauto.
    + inv pre. assert (HT := extr_typed0). eapply type_Case_inv in extr_typed0 as [ [[[[[[[[]]]]]]]] [[]]  ].
      destruct p0 as [[[[[]]]]]. 

      assert (t17 := t0).
      eapply subject_reduction_eval in t0; eauto.
      eapply type_mkApps_inv in t0 as (? & ? & [] & ?); eauto.
           
      destruct is_box eqn:Ea.
      * destruct extract eqn:He; inversion Ea; clear Ea. 
                
        destruct brs eqn:Hbrs.
        -- edestruct (no_empty_case_in_empty_context); eauto.
        -- destruct p1.
           
           (* assert (extraction_pre Σ discr (PCUICAst.mkApps (tInd ind u0) l)). *)
           (* { econstructor; eauto. } *)
           (* eapply IHeval1, eval_tBox_inv in X. *)
                      
           admit.
           (*  this is the case where the discriminee extracts to a box *)
      * rewrite extract_Apps in IHeval1. 
        cbn in IHeval1. destruct is_type_or_proof eqn:He.
        -- eapply eval_iota_sing. eapply IHeval1. econstructor; eauto.
           (* if the discriminee reduces to a constructor of a proof, there was only one branch, TODO *) admit.
           admit.
        (* -- econstructor. eapply IHeval1. econstructor; eauto. *)
        -- cbn in IHeval2.
           unfold PCUICTyping.iota_red in *. unfold iota_red.
           rewrite extract_Apps in IHeval2.
           destruct is_type_or_proof eqn: Hee in IHeval2.
           ++ econstructor. eapply IHeval1. econstructor; eauto.
              unfold iota_red.
              assert (extract Σ [] res = tBox) as ->.
              eapply eval_tBox_inv. eapply IHeval2.
              econstructor; eauto. destruct p0.
              unfold types_of_case in *.
              destruct ? in e1; try now inv e1.
              destruct ? in e1; try now inv e1.
              destruct ? in e1; try now inv e1.
              destruct ? in e1; try now inv e1.
              destruct ? in e1; try now inv e1.
              destruct ? in e1; try now inv e1. inv e1.
              admit. (* typing of the branch *)

              destruct p0.
              destruct (nth_error brs c) eqn:Hbrs. 2:{ (* impossible *) admit. }
              rewrite <- nth_default_eq.
              unfold nth_default. erewrite map_nth_error; eauto.
              destruct p0. cbn.
              
              admit.
              
           ++ destruct (nth_error brs c) eqn:Hnth.
              2:{  (* Branches can't be too few, ensured by typing *)
                admit. }
              
              Lemma nth_map {A B} (f : A -> B) n l d d2 :
                n < #|l| -> nth n (map f l) d2 = f (nth n l d).
              Proof.
                induction n in l |- *; destruct l; simpl; auto.
              Admitted.

              econstructor. eapply IHeval1. econstructor; eauto.


              unfold iota_red.
              rewrite <- nth_default_eq in *. unfold nth_default in *.
              rewrite Hnth in *.
              epose proof (map_nth_error _ _ _ Hnth).
              rewrite H1 in *. cbn.
              
              rewrite <- map_skipn.
              eapply IHeval2.
              
              econstructor; eauto.
              eapply type_mkApps.

              (* branches of case are typed *) admit. admit.
              (* eapply t1. *)
  - (** fix case *) rewrite extract_Apps.
    cbn. destruct is_type_or_proof eqn:Heq.
    + inv pre. rewrite is_type_extract.
      econstructor. eauto.
      erewrite <- eval_is_type.
      erewrite is_type_App in Heq.
      eassumption. eauto.
      econstructor; eauto.
    + inv pre.
      eapply type_mkApps_inv in extr_typed0 as (? & ? & [] & ?); eauto.

      unfold unfold_fix, PCUICTyping.unfold_fix in *.
      destruct nth_error eqn:En in H; try now inv H.
      inv H. (* unfold extract_mfix. *)
      
      econstructor.
      * unfold unfold_fix. erewrite map_nth_error.  reflexivity.
        eauto.
      * eapply Forall2_map.
        eapply All2_Forall.
        eapply All2_impl_In. eassumption.
        intros; cbn in *.  
        
        eapply typing_spine_In in t0 as []; eauto.
        eapply H4. econstructor ; eauto.
      * unfold PCUICTyping.is_constructor, is_constructor_or_box in *.
        destruct nth_error eqn:He in H1; try now inv H1.
        erewrite map_nth_error. 2:eassumption.
        unfold isConstruct_app in H1.
        destruct decompose_app eqn:Ha in H1.
        cbn in H1. destruct t2; try now inv H1.
        eapply PCUICConfluence.decompose_app_inv in Ha.
        subst.
        rewrite extract_Apps.
        destruct (is_type_or_proof _ _ (PCUICAst.tConstruct _ _ _)) eqn:Hp.
        -- eauto.
        -- cbn. rewrite Hp.
           rewrite decompose_app_mkApps. destruct ?; eauto.
           cbn. reflexivity.
      * cbn.
        eapply type_tFix_inv in t as [? [[[]]]].
        rewrite extract_Apps in IHeval.
        destruct is_type_or_proof eqn:He.
        -- (* contradictory case *)
           (* if a fixpoint is not a proof (Heq), its body won't be a proof, even after substitution of arguments *)
           admit.          
        -- erewrite (extract_subst Σ [] (PCUICLiftSubst.fix_context mfix) []) in IHeval.
           cbn in IHeval.

           rewrite app_nil_r in *. 

           enough (subst0 (map (extract Σ []) (PCUICTyping.fix_subst mfix)) (extract Σ (PCUICLiftSubst.fix_context mfix) (BasicAst.dbody d)) = subst0 (fix_subst (extract_mfix (extract Σ) [] mfix)) (extract Σ (PCUICLiftSubst.fix_context mfix) (BasicAst.dbody d))).
           rewrite <- H. unfold app_context in IHeval. rewrite app_nil_r in IHeval. eapply IHeval.
           econstructor. eapply type_mkApps.
           all:cbn; eauto.
           ++ eapply nth_error_all in En; eauto.
              destruct En.
              eapply (substitution Σ [] (PCUICLiftSubst.fix_context mfix) (PCUICTyping.fix_subst mfix) []); eauto.
              eapply subslet_fix_subst.
           ++ rewrite PCUICLiftSubst.simpl_subst_k.
              eapply typing_spine_eval; eauto.
              rewrite e in En. inv En. eauto.
              now rewrite fix_subst_length, fix_context_length.
           ++ eapply subst_free_ext. 
              intros.
              destruct (le_lt_dec (#|mfix|) n).
              ** assert (l' := l).
                 rewrite <- fix_subst_length in l.
                 eapply nth_error_None in l.
                 rewrite nth_error_map.
                 rewrite l.
                 erewrite <- map_length in l'.
                 rewrite <- fix_subst_length' in l'.
                 eapply nth_error_None in l.
                 unfold extract_mfix.
                 eapply nth_error_None in l'.
                 rewrite l'. reflexivity.
              ** enough (nth_error (map (extract Σ []) (PCUICTyping.fix_subst mfix)) n =
                         Some (extract Σ [] (PCUICAst.tFix mfix (#|mfix| - n)))) as ->.
                 enough (nth_error (fix_subst (extract_mfix (extract Σ) [] mfix)) n =
                         Some (tFix (extract_mfix (extract Σ) [] mfix) (#|mfix| - n))) as ->.
                 f_equal. cbn. destruct ?.
                 --- (* n has the same type as the fixpoint, it's thus a proof and will not be free *)
                   admit.
                 --- reflexivity.
                 --- clear - l. admit. (* easy proof by induction on mfix, using fix_subst' *)
                 --- clear - l. admit. (* easy proof by induction on mfix, using fix_subst' *)
           ++ eapply subslet_fix_subst.
           ++ eapply nth_error_all in a0. 2: exact En.
              cbn in a0. eapply a0.
        -- eauto.
  - (** delta case, done up to lemma*) cbn. destruct Extract.is_type_or_proof eqn:Heq. 
    + erewrite is_type_extract. econstructor; eauto.
      erewrite <- eval_is_type. eassumption. eauto.
    + inv pre.
      destruct (@extract_constant _ c decl body u T extr_env_wf extr_typed0 H H0) as (decl' & ? & ?); eauto.
      econstructor.
      * eauto.
      * eauto.
      * eapply IHeval. econstructor; eauto.
        eapply subject_reduction. eauto. exact extr_typed0.
        eapply PCUICReduction.red1_red. econstructor; eauto.
  - (** proj case, needs check in typing *) cbn. destruct Extract.is_type_or_proof eqn:Heq. 
    + rewrite is_type_extract. econstructor; eauto.
      erewrite <- eval_is_type. eassumption. eauto.
    + inv pre.
      eapply type_proj_inv in extr_typed0 as ( [[[[args' mdecl] idecl] [pdecl ty]] u'] & [[[]]]).
      assert (H19 := t).
      assert (H17 := H0). eapply subject_reduction_eval in t. 2-3:eauto.
      eapply type_mkApps_inv in t as (? & ? & [] & ?) ; eauto.
      eapply typing_spine_inv in t0 as []; eauto.

      rewrite extract_Apps in IHeval1 (* ok because if projection is a non-proof, constructor was no proof *).
      cbn in IHeval1. destruct ? in IHeval1.
      * admit. (* same *)
      * econstructor. eapply IHeval1. econstructor; eauto.
        eapply map_nth_error in H17.
        rewrite <- nth_default_eq. unfold nth_default.
        rewrite H17. eapply IHeval2. econstructor; eauto.
  - (** abs case, trivial *) cbn. destruct Extract.is_type_or_proof eqn:Heq. 
    + econstructor; eauto. 
    + econstructor.
  - (** prod case, trivial *) cbn. destruct Extract.is_type_or_proof eqn:Heq. 
    + econstructor; eauto. 
    + econstructor; eauto.
  - (** app_ind nil case, trivial *) cbn. destruct Extract.is_type_or_proof eqn:Heq; econstructor; eauto.
  - (* app_ind non-nil case *) inv pre. edestruct (type_mkApps_inv _ _ _ _ _ extr_env_wf extr_typed0) as (? & ? & [] & ?) ; eauto. 
    rewrite !is_type_extract.
    + econstructor; eauto.
    + erewrite <- is_type_App. eapply is_type_ind. eapply subject_reduction_eval; eauto.
      eapply subject_reduction_eval. eauto. 2:eauto.
      eapply type_mkApps; eauto.
    + admit. (* if you reduce to tInd, you are a type *)
  - (** app_constr nil case *)cbn. destruct Extract.is_type_or_proof eqn:Heq. 
    + econstructor; eauto. 
    + econstructor; eauto.
  - (** app_constr nonnil case *) inv pre. edestruct (type_mkApps_inv _ _ _ _ _ extr_env_wf extr_typed0) as (? & ? & [] & ?) ; eauto.

    rewrite !extract_Apps.
    cbn.
    destruct is_type_or_proof eqn:Heq.
    + erewrite <- eval_is_type, Heq.
      2: eauto. econstructor; eauto.
    + cbn in *. destruct (is_type_or_proof Σ [] (PCUICAst.tConstruct _ _ _)).
      * eapply eval_box_apps. eapply IHeval. econstructor; eauto.
      * econstructor. eapply IHeval. econstructor; eauto.
        eapply Forall2_map. eapply All2_Forall.
        eapply All2_impl. eassumption.
        intros. cbn in *.
        eapply typing_spine_In in H1 as []; eauto.

        eapply H3. econstructor; eauto.
Admitted.
