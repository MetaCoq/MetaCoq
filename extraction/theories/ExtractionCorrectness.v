(* Distributed under the terms of the MIT license.   *)

From Coq Require Import Bool String List Program BinPos Compare_dec Omega.
From Template Require Import config utils monad_utils BasicAst AstUtils.
From PCUIC Require Import PCUICAst PCUICAstUtils PCUICInduction PCUICTyping PCUICWeakening PCUICSubstitution PCUICChecker PCUICRetyping PCUICMetaTheory PCUICWcbvEval PCUICSR.
From TemplateExtraction Require Import EAst ELiftSubst ETyping EWcbvEval Extract.
Require Import String.
Local Open Scope string_scope.
Set Asymmetric Patterns.
Import MonadNotation.

Require Import Lia.
Lemma Forall2_length {A B} {P : A -> B -> Prop} l l' : Forall2 P l l' -> #|l| = #|l'|.
Proof. induction 1; simpl; auto. Qed.


Existing Instance config.default_checker_flags.
Module PA := PCUICAst.
Module P := PCUICWcbvEval.


Ltac inv H := inversion H; subst; clear H.

Theorem type_of_sound `{Fuel} Σ {Γ t A B} :
      Σ ;;; Γ |- t : A ->
      type_of Σ Γ t = Checked B ->
      (Σ ;;; Γ |- t : B) * (Σ ;;; Γ |- B <= A).
Admitted.

Theorem type_of_complete `{Fuel} Σ {Γ t A} :
      Σ ;;; Γ |- t : A ->
                    {B & type_of Σ Γ t = Checked B}.
Admitted.

(** ** All2 *)

Lemma is_constructor_extract `{Fuel} Σ n L L' :
  PCUICTyping.is_constructor n L -> Forall2 (fun (a : PCUICAst.term) (e : E.term) => extract Σ [] a = Checked e) L L' -> is_constructor n L'.
Proof.
Admitted.


Lemma nth_error_app_inv X (x : X) n l1 l2 :
  nth_error (l1 ++ l2) n = Some x -> (n < #|l1| /\ nth_error l1 n = Some x) \/ (n >= #|l1| /\ nth_error l2 (n - List.length l1) = Some x).
Admitted.

Lemma mkApps_inj a b l1 l2  :
  mkApps a l1 = mkApps b l2 -> (~ exists a1 a2, a = tApp a1 a2) -> a = b /\ l1 = l2.
Admitted.


Lemma emkApps_snoc a l b :
  mkApps a (l ++ [b]) = tApp (mkApps a l) b.
Proof.
  revert a; induction l; cbn; congruence.
Qed.

Lemma All2_app_inv : forall (A B : Type) (R : A -> B -> Type),
    forall l l1 l2, All2 R (l1 ++ l2) l -> { '(l1',l2') : _ & (l = l1' ++ l2')%list * (All2 R l1 l1') * (All2 R l2 l2')}%type.
Proof.
  intros. revert l2 l X. induction l1; intros; cbn in *.
  - exists ([], l). eauto.
  - inversion X. subst.
    eapply IHl1 in X1 as ( [] & ? & ?). destruct p.  subst.
    eexists (y :: l, l0). repeat split; eauto.
Qed.

Lemma All2_ind_rev : forall (A B : Type) (R : A -> B -> Type) (P : forall (l : list A) (l0 : list B), Prop),
    P [] [] ->
    (forall (x : A) (y : B) (l : list A) (l' : list B) (r : R x y) (a : All2 R l l'),
        P l l' -> P (l ++ [x])%list (l' ++ [y]))%list ->
    forall (l : list A) (l0 : list B) (a : All2 R l l0), P l l0.
Proof.
  intros. revert l0 a. induction l using rev_ind; cbn; intros.
  - inv a. eauto.
  - eapply All2_app_inv in a as ([] & [[]]). subst.
    inv a0. inv X0. eauto.
Qed.

Lemma last_inv A (l1 l2 : list A) x y :
  (l1 ++ [x] = l2 ++ [y] -> l1 = l2 /\ x = y)%list.
Proof.
  revert l2. induction l1; cbn; intros.
  - destruct l2; cbn in H; inv H. eauto. destruct l2; inv H2.
  - destruct l2; inv H. destruct l1; inv H2.
    eapply IHl1 in H2 as []. split; congruence.
Qed.

Lemma All2_app : forall (A B : Type) (R : A -> B -> Type),
    forall l1 l2 l1' l2', All2 R l1 l1' -> All2 R l2 l2' -> All2 R (l1 ++ l2) (l1' ++ l2').
Proof.
  induction 1; cbn; eauto.
Qed.

Lemma Forall2_skipn A B (P : A -> B -> Prop) l l' n:
  Forall2 P l l' -> Forall2 P (skipn n l) (skipn n l').
Proof.
  revert l l'; induction n; intros.
  - unfold skipn. eauto.
  - cbv [skipn]. fold (@skipn A n). fold (@skipn B n).
    inversion H; subst. econstructor.
    eauto.
Qed.

Lemma All2_Forall A B (P : A -> B -> Prop) l l' :
  All2 P l l' -> Forall2 P l l'.
Proof.
  induction 1; eauto.
Qed.

Lemma Forall2_nth_error_Some {A B} {P : A -> B -> Prop} {l l'} n t :
  Forall2 P l l' ->
  nth_error l n = Some t ->
  exists t' : B, (nth_error l' n = Some t') /\ P t t'.
Proof.
  intros Hall. revert n.
  induction Hall; destruct n; simpl; try congruence. intros [= ->]. exists y. intuition auto.
  eauto.
Qed.


Lemma no_empty_case_in_empty_context Σ ind npar p c T :
  Σ;;; [] |- PCUICAst.tCase (ind, npar) p c [] : T -> False.
Proof.
Admitted.


Lemma prop_case_is_singleton `{Fuel} Σ ind npar p T i u args brs mdecl idecl :
  PCUICTyping.declared_inductive (fst Σ) mdecl ind idecl ->
  PCUICAst.ind_npars mdecl = npar ->
  is_type_or_proof Σ [] (PCUICAst.tConstruct ind i u) = Checked true ->
  Σ;;; [] |- PCUICAst.tCase (ind, npar) p (PCUICAst.mkApps (PCUICAst.tConstruct ind i u) args) brs : T -> #|brs| = 1 /\ i = 0 /\
                                                                                                              Forall (fun a => is_type_or_proof Σ [] a = Checked true) (skipn (npar) args).
Proof.
Admitted.

Inductive extr_pre (Σ : PA.global_context) t T :=
  { extr_typed : Σ ;;; [] |- t : T;
    extr_env_axiom_free : axiom_free (fst Σ) }.

Lemma typing_spine_inv_app Σ x0 l x x1 :
  PCUICGeneration.typing_spine Σ [] x0 (l ++ [x]) x1 -> { '(x2, x3) : _ & (PCUICGeneration.typing_spine Σ [] x0 l x2) * (Σ ;;; [] |- x : x3)}%type.
Proof.
  intros. depind X. destruct l; inv x. 
  destruct l; inv x.
  + eexists (_, _). split. econstructor. eauto.
  + specialize (IHX _ _ eq_refl) as ([] & []).
    eexists (_, _). split.  econstructor; eauto. eauto.
Qed.

Lemma typing_spine_inv:
  forall (Σ : PCUICAst.global_context) (i : inductive) (pars arg : nat) (args : list PCUICAst.term) 
    (a T : PCUICAst.term) (args' : list PCUICAst.term) (u' : universe_instance)
    (H17 : nth_error args (pars + arg) = Some a) (x2 x3 : PCUICAst.term),
    PCUICGeneration.typing_spine Σ [] x2 args x3 ->
    Σ;;; [] |- x3 <= PCUICAst.mkApps (tInd (fst (fst (i, pars, arg))) u') args' -> {T & Σ;;; [] |- a : T}.
Proof.
  intros Σ i pars arg args a T args' u' H17 x2 x3 t0 c0.
Admitted.

Lemma typing_spine_skipn:
  forall (Σ : PCUICAst.global_context) (args : list PCUICAst.term) (n0 : nat) (t5 x x0 : PCUICAst.term) 
    (n : nat) (t3 : PCUICGeneration.typing_spine Σ [] x args x0),
    {T & PCUICGeneration.typing_spine Σ [] (snd (n0, t5)) (skipn n args) T}.
Proof.
  intros Σ args n0 t5 x x0.
Admitted.


Tactic Notation "destruct" "?" :=
  let E := fresh "E" in
  match goal with
    [ |- context[match ?X with _ => _ end]] => destruct X eqn:E
  | [ H : context[match ?X with _ => _ end] |- _] => destruct X eqn:E
  end.

Tactic Notation "destruct" "?" "in" hyp(H) :=
  let e := fresh "E" in
  match type of H with context [match ?x with _ => _ end] => destruct x eqn:e
  end.

Theorem subject_reduction_eval : forall (Σ : PCUICAst.global_context) Γ t u T,
  wf Σ -> Σ ;;; Γ |- t : T -> PCUICWcbvEval.eval Σ Γ t u -> Σ ;;; Γ |- u : T.
Proof.
  intros * wfΣ Hty Hred % wcbeval_red. eapply subject_reduction; eauto.
Qed.

Lemma cumul_is_arity:
  forall (H : Fuel) (Σ : PCUICAst.global_context) (T' T'' : PCUICAst.term),
    Σ;;; [] |- T'' <= T' -> forall a : bool, is_arity Σ [] H T' = Checked a <-> is_arity Σ [] H T'' = Checked a.
Proof.
  intros H Σ T' T''.
  

Admitted.

Lemma eval_is_type `{Fuel} (Σ : PCUICAst.global_context) (t v : PCUICAst.term) (* T : *)
  (* wf Σ -> Σ ;;; [] |- t : T -> *) :
  PCUICWcbvEval.eval Σ [] t v -> Extract.is_type_or_proof Σ [] t = Checked true -> Extract.is_type_or_proof Σ [] v = Checked true.
Proof. 
  (* intros. *)
  (* destruct (type_of_sound _ X0) as (T' & [] & ?). *)
  (* eapply subject_reduction_eval in t0; eauto. *)
  (* destruct (type_of_sound _ t0) as (T'' & [] & ?). *)
  (* unfold is_type_or_proof in *. rewrite e, e0 in *. *)
  (* simpl in *.  *)

  (* destruct (is_arity _ _ _ T') eqn:E1. *)
  (* eapply (cumul_is_arity H Σ T' T'' c0) in E1 as ->. reflexivity. *)
  (* destruct ?; eauto.  *)
Admitted.

Lemma eval_is_type_backwards `{Fuel} (Σ : PCUICAst.global_context) (t v : PCUICAst.term) (* T : *)
  (* wf Σ -> Σ ;;; [] |- t : T -> *) :
  PCUICWcbvEval.eval Σ [] t v -> Extract.is_type_or_proof Σ [] v = Checked true -> Extract.is_type_or_proof Σ [] t = Checked true.
Proof.
  intros.
  (* destruct (type_of_sound _ X0) as (T' & [] & ?). *)
  (* eapply subject_reduction_eval in t0; eauto. *)
  (* destruct (type_of_sound _ t0) as (T'' & [] & ?). *)
  (* unfold is_type_or_proof in *. rewrite e, e0 in *. *)
  (* simpl in *. *)

  (* destruct (is_arity _ _ _ T') eqn:E1. reflexivity. *)
    
Admitted.
  
Lemma is_type_extract `{Fuel} (Σ : PCUICAst.global_context) Γ (t : PCUICAst.term) (* T : *)
  (* Σ ;;; Γ |- t : T -> *) :
  Extract.is_type_or_proof Σ Γ t = Checked true <-> extract Σ Γ t = Checked E.tBox.
Proof.
  split.
  - intros H1.
    destruct t; simpl; try rewrite H1; try reflexivity.
    all: try inversion H1.
  (* - intros. induction X. *)
  (*   all: simpl in H0; try destruct ?; try destruct a0. all: try congruence. *)
  (*   cbn in E. destruct is_arity eqn:EE. inv E. *)
  (*   all: try now destruct ?; congruence. *)
  (*   cbn in E. destruct H. cbn in E. inv E. *)

    
Admitted.

(** ** Substitution *)
Require Import PCUIC.PCUICValidity.
  
Lemma is_arity_subst `{Fuel} Σ Γ Γ' Δ a s :
  wf Σ -> subslet Σ Γ s Γ' ->
  (* Σ ;;; Γ ,,, Γ' ,,, Δ |- a : T -> *)
  wf_local Σ (Γ ,,, subst_context s 0 Δ) ->
  is_arity Σ (Γ ,,, Γ' ,,, Δ) _ a = is_arity Σ (Γ ,,, subst_context s 0 Δ) _ (PCUICLiftSubst.subst s #|Δ| a). 
Proof.
Admitted.

(* this is probably too strict, a might also be an algebraic universe *)
Lemma type_of_subst `{Fuel} Σ Γ Γ' Δ a T s T' :
  wf Σ -> subslet Σ Γ s Γ' ->
  Σ ;;; Γ ,,, Γ' ,,, Δ |- a : T ->
  wf_local Σ (Γ ,,, subst_context s 0 Δ) ->
  type_of Σ (Γ ,,, Γ' ,,, Δ) a = Checked T' ->
  type_of Σ (Γ ,,, subst_context s 0 Δ) (PCUICLiftSubst.subst s #|Δ| a) = Checked (PCUICLiftSubst.subst s #|Δ| T').
Proof.
Admitted.

Lemma reduce_to_sort_subst:
  forall (H : Fuel) (Σ : PCUICAst.global_context) (Γ Γ' Δ : PCUICAst.context)
    (s : list PCUICAst.term),
    wf Σ ->
    subslet Σ Γ s Γ' ->
    wf_local Σ (Γ ,,, subst_context s 0 Δ) ->
    forall a0 : PCUICAst.term,
      reduce_to_sort (fst Σ) (Γ ,,, subst_context s 0 Δ) (PCUICLiftSubst.subst s #|Δ| a0) =
      reduce_to_sort (fst Σ) (Γ ,,, Γ' ,,, Δ) a0.
Proof.
  intros H Σ Γ Γ' Δ s X X0 X2 a0.
Admitted.

Lemma type_of_as_sort_subst `{Fuel} Σ Γ Γ' Δ a s T :
  wf Σ -> subslet Σ Γ s Γ' ->
  Σ ;;; Γ ,,, Γ' ,,, Δ |- a : T ->
  wf_local Σ (Γ ,,, subst_context s 0 Δ) ->
  type_of_as_sort Σ (type_of Σ) (Γ ,,, subst_context s 0 Δ)
      (PCUICLiftSubst.subst s #|Δ| a) = type_of_as_sort Σ (type_of Σ) (Γ ,,, Γ' ,,, Δ) a.
Proof.
  intros. unfold type_of_as_sort.
  destruct type_of eqn:E at 2.
  eapply type_of_subst in E; eauto.
  - rewrite E. simpl. eapply reduce_to_sort_subst; eauto.
  - edestruct type_of_complete; eauto. congruence.
Qed.

Lemma is_type_subst `{Fuel} Σ Γ Γ' Δ a T s :
  wf Σ -> subslet Σ Γ s Γ' ->
  Σ ;;; Γ ,,, Γ' ,,, Δ |- a : T ->
  wf_local Σ (Γ ,,, subst_context s 0 Δ) ->
  is_type_or_proof Σ (Γ ,,, subst_context s 0 Δ) (PCUICLiftSubst.subst s #|Δ| a) = is_type_or_proof Σ (Γ ,,, Γ' ,,, Δ) a.
Proof.
  intros.
  unfold is_type_or_proof.
  destruct type_of eqn:E at 2.
  - assert (E' := E).
    eapply type_of_sound in E' as []; eauto.
    eapply type_of_subst in E; eauto. rewrite E. simpl.
    destruct is_arity eqn:Ea at 2.
    + erewrite is_arity_subst in Ea; eauto. rewrite Ea. reflexivity.
    + erewrite is_arity_subst in Ea; eauto. rewrite Ea.
      erewrite type_of_as_sort_subst with (Γ'0 := Γ'); eauto. admit. 
  - edestruct type_of_complete; eauto. congruence.
Admitted.

Lemma extract_weakening `{Fuel} (Σ : PCUICAst.global_context) (Γ Γ' : PCUICAst.context) (t T : PCUICAst.term) t' :
    wf Σ ->
    wf_local Σ (Γ ,,, Γ') ->
    Σ;;; Γ |- t : T ->
    extract Σ Γ t = Checked t' -> extract Σ (Γ ,,, Γ') (PCUICLiftSubst.lift #|Γ'| 0 t) = Checked (lift #|Γ'| 0 t').
Admitted.

Lemma extract_subst `{Fuel} Σ Γ Γ' Δ a a' s s' T :
  wf Σ ->
  subslet Σ Γ s Γ' ->
  wf_local Σ (Γ ,,, subst_context s 0 Δ) ->
  Σ ;;; Γ ,,, Γ'  ,,, Δ |- a : T ->
  extract Σ (Γ,,,Γ',,,Δ) a = Checked a' ->
  Forall2 (fun a b => extract Σ Γ a = Checked b) s s' ->            
  extract Σ (Γ ,,, subst_context s 0 Δ) (PCUICLiftSubst.subst s #|Δ| a) = Checked (subst s' #|Δ| a').
Proof.
  intros HΣ HΔ Hs Ha.
  pose proof (typing_wf_local Ha).
  generalize_eqs Ha. intros eqw. rewrite <- eqw in X.
  revert Γ Γ' Δ s Hs HΔ eqw.
  revert Σ HΣ Γ0 X a T Ha.
  eapply (typing_ind_env (fun Σ Γ0 a T =>
                            forall (Γ Γ' : PCUICAst.context) Δ (s : list PCUICAst.term),
                              wf_local Σ (Γ ,,, subst_context s 0 Δ) ->
                              subslet Σ Γ s Γ' ->
                              Γ0 = Γ ,,, Γ' ,,, Δ ->
                              extract Σ (Γ ,,, Γ' ,,, Δ) a = Checked a' ->
                              Forall2 (fun (a0 : PCUICAst.term) (b : E.term) => extract Σ Γ a0 = Checked b) s s' ->
                              extract Σ (Γ ,,, subst_context s 0 Δ) (PCUICLiftSubst.subst s #|Δ| a) = Checked (subst s' #|Δ| a')));
  intros Σ wfΣ Γ0 wfΓ0; intros; simpl in * |-; subst Γ0.
  - destruct ? in H2; try congruence.
    destruct a.
    + inv H2. eapply is_type_extract.
      erewrite is_type_subst; eauto.
      econstructor; eauto.
    + inv H2. simpl.
      elim (leb_spec_Set); intros Hn.
      elim nth_error_spec.
      * intros x Heq Hlt.
        pose proof (substlet_length X1). rewrite H1 in *.
        rewrite -> nth_error_app_context_ge in H0 by lia.
        rewrite -> nth_error_app_context_lt in H0 by lia.
        eapply Forall2_nth_error_Some in H3 as (? & ? & ?); eauto.
        rewrite H2.
        eapply subslet_nth_error in Heq; eauto.
         destruct decl, decl_body;
           cbn -[skipn] in Heq.
        -- destruct Heq as [-> ].
           eapply (extract_weakening _ _ (subst_context s 0 Δ)) in H3; eauto.
           rewrite subst_context_length in H3; eauto.
        -- eapply (extract_weakening _ _ (subst_context s 0 Δ)) in H3; eauto.
           rewrite subst_context_length in H3; eauto.
      * intros Hs.
        pose proof (substlet_length X1).
        eapply Forall2_length in H3. rewrite H3 in *.
        assert (Hs' := Hs).
        eapply nth_error_None in Hs. rewrite Hs.
        simpl.
        erewrite <- is_type_subst in E; eauto.
        cbn - [is_type_or_proof] in E.
        revert E. elim (leb_spec_Set); intros; try lia.
        2: econstructor; eauto.
        rewrite <- H3 in Hs'.
        eapply nth_error_None in Hs'.
        rewrite Hs' in E.
        rewrite H3 in *.
        now rewrite E.
      * assert (sub := X1).
        eapply subslet_nth_error_lt in X1; eauto.
        rewrite H0 in X1. simpl in X1.
        simpl.
        erewrite <- is_type_subst in E; eauto.
        cbn - [is_type_or_proof] in E.
        revert E. elim (leb_spec_Set); intros; try lia.
        2: econstructor; eauto.
        now rewrite E.
  - 
Admitted.

Lemma extract_subst_alt `{Fuel} Σ Γ Γ' Δ a a' s s' T :
  wf Σ ->
  subslet Σ Γ s Γ' ->
  Σ ;;; Γ ,,, Γ'  ,,, Δ |- a : T ->
  extract Σ (Γ,,,Γ',,,Δ) a = Checked a' ->
  Forall2 (fun a b => extract Σ Γ a = Checked b) s s' ->            
  extract Σ (Γ ,,, subst_context s 0 Δ) (PCUICLiftSubst.subst s #|Δ| a) = Checked (subst s' #|Δ| a').
Proof.
  intros.
  eapply extract_subst; eauto. clear H0 H1 a' H s'.
  eapply All_local_env_app_inv.
  apply typing_wf_local in X1; eauto.
  apply All_local_env_app in X1 as [X1 X2].
  apply All_local_env_app in X1. intuition.
  induction X2; simpl; rewrite ?subst_context_snoc0; econstructor; eauto.
  destruct t0 as [u tu].
  eapply substitution in tu; simpl in *; eauto.
  eapply All_local_env_app_inv; intuition.
  eapply substitution in t0; simpl in *; eauto.
  eapply All_local_env_app_inv; intuition.
Qed.

(* Lemma substitution0  Σ Γ n u U (t : term) T : *)
(*   wf Σ -> *)
(*   Σ ;;; Γ ,, vass n U |- t : T -> Σ ;;; Γ |- u : U -> *)
(*   Σ ;;; Γ |- t {0 := u} : T {0 := u}. *)
(* Proof. *)
(*   intros HΣ Ht Hu. *)
(*   assert (wfΓ : wf_local Σ Γ). *)
(*   apply typing_wf_local in Hu; eauto. *)
(*   pose proof (substitution_alt Σ Γ [vass n U] [u] [] t T HΣ) as thm. *)
(*   forward thm. constructor. constructor. rewrite subst_empty; auto. *)
(*   now apply (thm Ht). *)
(* Qed. *)

Lemma extract_subst1 
      (Σ : PCUICAst.global_context) (na : name) (t b a' : PCUICAst.term) (fuel : Fuel) (a0 : E.term) T :
  wf Σ -> Σ ;;; [] ,, PCUICAst.vass na t |- b : T -> Σ ;;; [] |- a' : t ->
    extract Σ [PCUICAst.vass na t] b = Checked a0 ->
    forall vea : E.term,
      extract Σ [] a' = Checked vea -> extract Σ [] (PCUICLiftSubst.subst1 a' 0 b) = Checked (a0 {0 := vea}).
Proof.
  intros HΣ Ht Hu.
  assert (wfΓ : wf_local Σ []).
  apply typing_wf_local in Hu; eauto. intros.
  pose proof (extract_subst_alt Σ [] [PCUICAst.vass na t] [] b a0 [a'] [vea] T) as thm.
  forward thm. eauto.
  forward thm. econstructor. econstructor. rewrite PCUICLiftSubst.subst_empty; auto.
  now apply (thm Ht).
Qed.

Require Import Equations.Equations.

Lemma extract_subst1_vdef
      (Σ : PCUICAst.global_context) (na : name) (t b a' : PCUICAst.term) (fuel : Fuel) (a0 : E.term) T :
  (* PCUICWcbvEval.eval Σ [] a'' a' -> *)
  wf Σ -> Σ ;;; [] ,, PCUICAst.vdef na a' t |- b : T -> (* Σ ;;; [] |- a' : t -> *)
    extract Σ [PCUICAst.vdef na a' t] b = Checked a0 ->
    forall vea : E.term,
      extract Σ [] a' = Checked vea -> extract Σ [] (PCUICLiftSubst.subst1 a' 0 b) = Checked (a0 {0 := vea}).
Proof.
  intros HΣ Ht.
  assert ((wf_local Σ []) * (Σ ;;; [] |- a' : t)%type) as [wfΓ tyu].
  apply typing_wf_local in Ht; eauto with wf. 
  now depelim Ht; simpl in *; unfold PCUICAst.vdef, PCUICAst.vass in H; noconf H. 
  intros.
  epose proof (extract_subst_alt Σ [] [PCUICAst.vdef na a' t] [] b a0 _ [vea] T HΣ) as thm.
  forward thm. econstructor. econstructor. rewrite !PCUICLiftSubst.subst_empty in *; auto.
  rewrite !PCUICLiftSubst.subst_empty in *.
  cbn in *. 
  eapply thm; eauto.
Qed.

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

Lemma subslet_fix_subst Σ mfix1 mfix2 :
  subslet Σ [] (PCUICTyping.fix_subst mfix2) (fix_decls mfix1).
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

(** ** monad_map *)

Lemma monad_map_All2 (X Y : Type) (f : X -> typing_result Y) (l1 : list X) (a1 : list Y) :
  monad_map f l1 = Checked a1 -> All2 (fun a b => f a = Checked b) l1 a1.
Proof.
Admitted.
Lemma monad_map_Forall2 (X Y : Type) (f : X -> typing_result Y) (l1 : list X) (a1 : list Y) :
  monad_map f l1 = Checked a1 -> Forall2 (fun a b => f a = Checked b) l1 a1.
Proof.
Admitted.
Lemma monad_map_length X Y (f : X -> typing_result Y) (l1  : list X) a :
  monad_map f l1 = Checked a -> #|l1| = #|a|.
Proof.
  revert a; induction l1; cbn; intros.
  - inv H. cbn. congruence.
  - destruct (f a). destruct ? in H. inv H. cbn. f_equal. eauto. inv H. inv H.
Qed.


Lemma monad_map_app X Y (f : X -> typing_result Y) (l1 l2 : list X) a1 a2 :
  monad_map f l1 = Checked a1 -> monad_map f l2 = Checked a2 -> monad_map f (l1 ++ l2) = Checked (a1 ++ a2)%list.
Proof.
  revert a1. induction l1; intros.
  - cbn in *. inv H. eauto.
  - cbn in *. destruct ?. destruct ? in H; try congruence.
    inv H. rewrite (IHl1 _ eq_refl); eauto. inv H.
Qed.

Lemma monad_map_app_inv X Y (f : X -> typing_result Y) (l1 l2 : list X) a :
  monad_map f (l1 ++ l2) = Checked a -> exists a1 a2, monad_map f l1 = Checked a1 /\ monad_map f l2 = Checked a2 /\ (a = a1 ++ a2)%list.
Proof.
  intros. revert a H. induction l1; intros.
  - cbn in *. eauto.
  - cbn in *. destruct ?. destruct ? in H; try congruence.
    inv H. destruct (IHl1 _ eq_refl) as (? & ? & ? & ? & ->).
    do 2 eexists. rewrite H. eauto. inv H.
Qed.

Lemma Forall2_impl {A B} {P Q : A -> B -> Prop} {l l'} :
    Forall2 P l l' ->
    (forall x y, P x y -> Q x y) ->
    Forall2 Q l l'.
Proof.
  induction 1; constructor; auto.
Qed.

(* Lemma map_fix_subst_extract: *)
(*   forall (Σ : PCUICAst.global_context) (fuel : Fuel)  *)
(*     (mfix : BasicAst.mfixpoint PCUICAst.term) (x : list (E.def E.term)), *)
(*     extract_mfix (extract Σ) [] mfix = Checked x -> *)
(*     Forall2 (fun (a : PCUICAst.term) (b : E.term) => extract Σ [] a = Checked b) (PCUICTyping.fix_subst mfix) (fix_subst x). *)
(* Proof. *)
(*   intros. *)
(*   pose proof (monad_map_length _ _ _ _ _ H) as HL. *)
(*   (* pose proof (monad_map_Forall2 _ _ (fun d : BasicAst.def PCUICAst.term => *) *)
(*   (*        dbody' <- extract Σ (fix_decls mfix ++ [])%list (BasicAst.dbody d);; *) *)
(*   (*               ret {| E.dname := BasicAst.dname d; E.dbody := dbody'; E.rarg := BasicAst.rarg d |})). *) *)
(*   (* eapply H0 in H. clear H0. *) *)
(*   rewrite <- fix_subst'_subst, <- efix_subst'_subst. *)
(*   rewrite HL.  *)
(*   assert (#|x| <= #|x|) by omega. revert H0. generalize (#|x|) at 1 3 4. induction n; cbn; intros. *)
(*   - econstructor. *)
(*   - econstructor. simpl. destruct ?. destruct a. admit. rewrite H. reflexivity. admit. *)
(*     eapply IHn. omega. *)
(* Admitted. *)

(** ** Proof inversions *)

Lemma is_type_ind:
  forall (Σ : PCUICAst.global_context) (i : inductive) (u : universe_instance) (T : PCUICAst.term) (fuel : Fuel),
    Σ;;; [] |- tInd i u : T -> is_type_or_proof Σ [] (tInd i u) = Checked true.
Proof.
  
Admitted.

Lemma is_type_App `{Fuel} Σ a l T :
  Σ ;;; [] |- PCUICAst.mkApps a l : T -> 
  is_type_or_proof Σ [] a = Checked true ->
  is_type_or_proof Σ [] (PCUICAst.mkApps a l) = Checked true.
Proof.
Admitted.
  
Lemma is_type_or_proof_lambda `{Fuel} Σ Γ na t b :
  Extract.is_type_or_proof Σ Γ (PCUICAst.tLambda na t b) = Checked true ->
  Extract.is_type_or_proof Σ (Γ ,, PCUICAst.vass na t) b = Checked true.
Admitted.

Lemma is_type_or_proof_mkApps `{Fuel} Σ Γ a l :
  Extract.is_type_or_proof Σ Γ a = Checked true <->
  Extract.is_type_or_proof Σ Γ (PCUICAst.mkApps a l) = Checked true.
Admitted.

Lemma is_type_subst1 `{Fuel} (Σ : PCUICAst.global_context) (na : name) (t b a' : PCUICAst.term) :
  Extract.is_type_or_proof Σ ([],, PCUICAst.vass na t) b = Checked true ->
  Extract.is_type_or_proof Σ [] (PCUICLiftSubst.subst1 a' 0 b) = Checked true.
Proof.
Admitted.

Lemma mkApps_snoc a l b :
  PCUICAst.mkApps a (l ++ [b]) = PCUICAst.tApp (PCUICAst.mkApps a l) b.
Proof.
  revert a; induction l; cbn; congruence.
Qed.

Lemma mkAppBox_repeat n a :
  mkAppBox a n = mkApps a (repeat tBox n).
Proof.
  revert a; induction n; cbn; firstorder congruence.
Qed.


(** ** extract and mkApps *)

Lemma extract_Apps `{Fuel} Σ Γ a args x :
  extract Σ Γ (PCUICAst.mkApps a args) = Checked x ->
  {e : _ & (extract Σ Γ a = Checked e) *
           { l : list E.term & (All2 (fun a e => extract Σ Γ a = Checked e) args l) *
                               (* (x = mkApps e l) *)
                               match e with tBox => x = tBox | _ => (x = mkApps e l) end }}%type.
Proof.
  revert a x. induction args using rev_ind; intros.
  - cbn in H0. repeat eexists; eauto. destruct x; eauto.
  - rewrite mkApps_snoc in H0. assert (H17 := H0). simpl in H0.
    destruct ?. destruct a0. all:try congruence.
    + inv H0. exists tBox. split. eapply is_type_extract. admit. 
      eapply is_type_or_proof_mkApps with (l := [x]) in E. 
      eapply is_type_extract in E. eapply IHargs in E as (? & ?  & ? & ? &?).
      Lemma mkApps_tbox:
        forall x0 (x1 : list E.term), E.tBox = mkApps x0 x1 -> x0 = tBox.
      Proof.
        intros.
        induction x1 using rev_ind; rewrite ?emkApps_snoc in *. cbn in H. inv H. eauto.
        inv H.
      Qed.
      destruct x0; try eapply mkApps_tbox in y; inv y.
      destruct (extract Σ Γ x) eqn:EE.
      * repeat eexists; eauto. eapply All2_app. eauto. 
        repeat econstructor. eauto.
      * admit.
    + destruct ?. destruct ?. all:try congruence. inv H0.
      eapply IHargs in E0 as (? & ? & ? & ? & ?).
      exists x0. split. eauto. exists (x1 ++ [a1])%list.
      split. eapply All2_app. eauto. repeat econstructor. eauto.
      rewrite emkApps_snoc. destruct x0; subst; eauto.
      admit.      
Admitted.

Lemma extract_Apps2 `{Fuel} Σ Γ a args e l :
  extract Σ Γ a = Checked e -> Forall2 (fun a e => extract Σ Γ a = Checked e) args l ->                                                                                  extract Σ Γ (PCUICAst.mkApps a args) = Checked (mkApps e l).
Proof.
Admitted.

Lemma extract_tInd `{Fuel} Σ i u t :
  extract Σ [] (tInd i u) = Checked t -> t = tBox.
Proof.
  intros ?. simpl in *. destruct is_type_or_proof eqn:E1; try destruct a; now inv H0.
Qed.

Lemma eval_box_apps:
  forall (Σ' : list E.global_decl) (e : E.term) (x : list E.term), eval Σ' e tBox -> eval Σ' (mkApps e x) tBox.
Proof.
  intros Σ' e x H2.
Admitted.

Lemma extract_constant:
  forall (Σ : PCUICAst.global_context) (c : ident) (decl : PCUICAst.constant_body) (body : PCUICAst.term)
    (u : universe_instance) (fuel : Fuel) (Σ' : list E.global_decl),
    wf Σ ->
    PCUICTyping.declared_constant Σ c decl ->
    extract_global Σ = Checked Σ' ->
    PCUICAst.cst_body decl = Some body ->
    exists decl' : constant_body, exists ebody,
        declared_constant Σ' c decl' /\
        extract Σ [] (PCUICUnivSubst.subst_instance_constr u body) = Checked ebody /\ cst_body decl' = Some ebody.
Proof.
  intros (decls, Σ) c decl body u fuel Σ'. intros. 
  induction decls using rev_ind.
  - inv H0. inv H.
  - simpl in H0. rewrite rev_app_distr in *. simpl in H0. destruct x.
    + unfold PCUICTyping.declared_constant in H.
      
Admitted.

Lemma eval_tBox_inv Σ' x2 :
  eval Σ' E.tBox x2 -> x2 = tBox.
Proof.
  intros. dependent induction H.
  - induction args using rev_ind. inv x. rewrite emkApps_snoc in x. inv x.
  - induction l using rev_ind. cbn in x. inv x. inv H0. eapply IHeval. eauto.
    rewrite emkApps_snoc in x. inv x.
  - reflexivity.
Qed.

Lemma type_Case_inv Σ Γ ind npar p c brs T :
  Σ;;; Γ |- PCUICAst.tCase (ind, npar) p c brs : T ->
  { '(u, args, mdecl, idecl, pty, indctx, pctx, ps, btys) : _ &                                                 
         (PCUICTyping.declared_inductive (fst Σ) mdecl ind idecl) *
         (PCUICAst.ind_npars mdecl = npar) *
         let pars := firstn npar args in
         (Σ;;; Γ |- p : pty) *
         (types_of_case ind mdecl idecl pars u p pty = Some (indctx, pctx, ps, btys)) *
         (check_correct_arity (snd Σ) idecl ind u indctx pars pctx = true) *
         (Exists (fun sf : sort_family => universe_family ps = sf) (PCUICAst.ind_kelim idecl)) *
         (Σ;;; Γ |- c : PCUICAst.mkApps (tInd ind u) args) *
         (All2 (fun x y : nat * PCUICAst.term => ((fst x = fst y) * (Σ;;; Γ |- snd x : snd y))) brs btys) *
         (Σ ;;; Γ |- PCUICAst.mkApps p (skipn npar args ++ [c])  <= T)}%type.
Proof.
  intros. dependent induction X.
  - unshelve eexists.
    + repeat refine (_,_). all:shelve.
    + cbn. intuition eauto.
  - edestruct (IHX _ _ _ _ _ eq_refl) as [ [[[[[[[[]]]]]]]] ].
    repeat match goal with [ H : _ * _ |- _ ] => destruct H end.
    unshelve eexists.
    + repeat refine (_, _). all:shelve.
    + cbn. intuition eauto.
      all: eapply cumul_trans; eauto.
Qed.

Lemma type_Construct_inv Σ Γ ind i u T :
  Σ;;; Γ |- PCUICAst.tConstruct ind i u : T ->
  { '(mdecl, idecl, cdecl) : _ & 
        (wf_local Σ Γ) *
        (PCUICTyping.declared_constructor (fst Σ) mdecl idecl (ind, i) cdecl) *
        (consistent_universe_context_instance Σ (ind_universes mdecl) u) *
        (Σ ;;; Γ |- type_of_constructor mdecl cdecl (ind, i) u <= T)}%type.
Proof.
  intros. dependent induction X.
  - eexists (_, _, _). cbn. intuition eauto.
  - edestruct IHX. reflexivity. destruct x as []. destruct p.
    exists (m, o, p0). intuition eauto.
    all: eapply cumul_trans; eauto.
Qed.

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

Lemma extract_context_conversion `{Fuel} :
env_prop
  (fun (Σ : PCUICAst.global_context) (Γ : PCUICAst.context) (t T : PCUICAst.term) =>
     forall Γ' : PCUICAst.context, conv_context Σ Γ Γ' -> forall a ea, extract Σ Γ a = Checked ea -> extract Σ Γ' a = Checked ea).
Admitted.


Theorem erasure_correct : erasure_correctness.
Proof.
  intros Σ t T pre v H. revert T pre.
  induction H using PCUICWcbvEval.eval_evals_ind; intros T pre fuel Σ' t' Ht' HΣ'.
  - simpl in Ht'.
    destruct Extract.is_type_or_proof eqn:Heq. inv pre.
    destruct a0.
    + inv Ht'.
      exists tBox. split. 2:repeat econstructor.
      eapply is_type_extract. eapply eval_is_type. econstructor. 3:eauto. all: eauto. 
    + destruct (extract Σ [] f) as [ ef | ] eqn:Ef ; try congruence.
      destruct (extract Σ [] a) as [ ea | ] eqn:Ea; try congruence.
      inv Ht'. 
      edestruct (type_mkApps_inv Σ [] f [a] T) as (? & U & [? ?] & ?); eauto. 
      inv t1. inv X2. pose proof (subject_reduction_eval _ [] _ _ _ extr_env_wf t0 H).
      eapply type_Lambda_inv in X2 as (? & ? & [? ?] & ?).
      
      eapply IHeval1 in Ef as (vef & ? & ?) ; eauto.
      eapply IHeval2 in Ea as (vea & ? & ?) ; eauto.
      
      simpl in H2. destruct ?; try now cbn in *; congruence.
      destruct a0.
      * inv H2. eapply is_type_or_proof_lambda in E.
        edestruct (IHeval3) as (? & ? & ?).
        -- econstructor; eauto. eapply substitution0. eauto. eauto. eapply subject_reduction_eval; try eapply H0; eauto. 
           eapply cumul_trans in X0. 2:eauto. eapply cumul_Prod_inv in X0 as []. econstructor. eauto. eauto. eapply c1.
        -- eapply extract_subst1; eauto. 2:{ eapply is_type_extract. eauto. }
           eapply subject_reduction_eval; eauto.
           edestruct cumul_Prod_inv.
           eapply cumul_trans; eauto.
           econstructor; eauto. eapply c1.
        -- eauto.
        -- exists tBox. cbn in H6. split. 2: eapply eval_box; eauto.
           now eapply eval_tBox_inv in H6 as ->.
      * destruct ?; try congruence.
        inv H2. edestruct IHeval3 as (? & ? & ?).
        -- econstructor; eauto.
           eapply substitution0. eauto. eauto. eapply subject_reduction_eval; try eapply H0; eauto. 
           eapply cumul_trans in X0. 2:eauto. eapply cumul_Prod_inv in X0 as []. 
           econstructor. eauto. eauto. eapply c1. 
        -- shelve.
        -- eauto.
        -- exists x2. split. eauto. econstructor. eauto. exact H5. eauto.
           Unshelve. shelve. shelve. eapply extract_subst1; eauto.
           eapply subject_reduction_eval; eauto.
           edestruct cumul_Prod_inv.
           eapply cumul_trans; eauto.
           econstructor; eauto. eapply c1.
      * econstructor; eauto.
      * econstructor; eauto.
    + congruence.
  - simpl in Ht'. inv pre. eapply type_tLetIn_inv in extr_typed0 as (? & U & [[] ?] & ?); eauto.
    destruct Extract.is_type_or_proof eqn:Heq. destruct a; try congruence.
    + inv Ht'.  exists tBox. split. 2: repeat econstructor.
      eapply is_type_extract. eapply eval_is_type. 2:eauto.
      econstructor; eauto.
    + destruct (extract _ _ b0) as [ eb0 | ] eqn:Eb0; try congruence.
      destruct (extract _ _ b1) as [ eb1 | ] eqn:Eb1; try congruence.
      inv Ht'. 

      eapply IHeval1 in Eb0 as (veb0 & ? & ?). 3:eauto.
      edestruct IHeval2 as (veb1 & ? & ?).
      4:{ exists veb1. split. eauto. econstructor. 2:eauto. eauto. }
      -- econstructor; eauto. eapply substitution_let; eauto.
         eapply context_conversion. 3: eassumption. all:eauto.
         econstructor. econstructor. econstructor 3. eapply subject_reduction_eval; eauto.
         eapply wcbeval_red. eauto.
      -- eapply extract_subst1_vdef; eauto.
         eapply context_conversion. eauto. 2:eauto.
         econstructor. eauto. eauto.
         econstructor. econstructor. econstructor. eapply subject_reduction_eval; eauto.
         eapply wcbeval_red. eauto.
         eapply extract_context_conversion. eauto.
         3:{ econstructor. econstructor. econstructor 3.
             eapply subject_reduction_eval; eauto.
             eapply wcbeval_red. eauto. }
         all: eauto. econstructor. eauto. econstructor; eauto.
      -- eauto.
      -- econstructor; eauto. 
    + congruence.
  - cbn in isdecl. inv isdecl.    
  - cbn in isdecl. inv isdecl.    
  - simpl in Ht'. destruct Extract.is_type_or_proof eqn:Heq.
    destruct a.
    + inv Ht'. exists tBox. split. 2: repeat econstructor.
      eapply is_type_extract. eapply eval_is_type. 2:eauto.
      econstructor; eauto.
    + destruct extract eqn:He; try congruence.
      inv pre. assert (HT := extr_typed0). eapply type_Case_inv in extr_typed0 as [ [[[[[[[[]]]]]]]] [[]]  ].
      destruct p0 as [[[[[]]]]]. 

      assert (t17 := t0).
      eapply subject_reduction_eval in t0; eauto.
      eapply type_mkApps_inv in t0 as (? & ? & [] & ?); eauto.
           
      destruct is_box eqn:Ea.
      * destruct a; inversion Ea; clear Ea. 

        destruct brs eqn:Hbrs.
        -- edestruct (no_empty_case_in_empty_context); eauto.
           
           
          (*  econstructor; eauto. *)

          (* inv Ht'. *)
           
          (*  eapply type_Construct_inv in t0 as [ [[]] ]. destruct y as [[[]]]. *)
          (*  destruct d. cbn in H2. subst. destruct p0. *)
          (*  unfold types_of_case in e. destruct ? in e; inv e. *)
          (*  destruct p0. destruct ? in H5; inv H5. destruct p0. destruct ? in H6; inv H6. *)

          (*  Lemma map_optinons_out_length A (L : list (option A)) L' : *)
          (*    map_option_out L = Some L' -> #|L| = #|L'|. *)
          (*  Proof. *)
          (*    revert L'; induction L; inversion 1; subst; cbn. *)
          (*    - reflexivity. *)
          (*    - destruct a; inv H1. destruct ? in H2; inv H2. cbn. f_equal. *)
          (*      eauto. *)
          (*  Qed. *)
          (*  eapply map_optinons_out_length in E1. inv a0. *)
          (*  unfold build_branches_type in E1. rewrite mapi_length in E1. *)
          (*  destruct o. cbn in E1. destruct ind_ctors; inv E1. *)
          (*  cbn in *. clear Heq. *)
          (*  destruct l1 ; inv e0. *)
        -- eapply is_type_extract in He.
           edestruct prop_case_is_singleton as (? & ? & ?). eauto. eauto. 
           unfold PCUICTyping.declared_inductive.
           eapply is_type_or_proof_mkApps.
           eapply eval_is_type. eauto. eauto.
           eapply subject_reduction. eauto. eapply HT.
           eapply PCUICReduction.red_case. eapply refl_red.
           eapply wcbeval_red. eauto.
           eapply All_All2. 2:{ intros []. unfold on_Trel. cbn. intros. eapply refl_red. } instantiate (1 := fun _ => True).
           econstructor; eauto. clear. induction l3; econstructor; eauto. 
           
           inv a0. destruct l3; inv H1. inv X0. 
           destruct p0. destruct p1. destruct ? in Ht'; inv Ht'.
           unfold PCUICTyping.iota_red in IHeval2. simpl in IHeval2.
           destruct X. destruct y. cbn in e; subst.
           eapply typing_spine_skipn in t1 as [].  
           
           edestruct IHeval2 as (? & ? & ?).
           ++ econstructor; eauto. eapply PCUICGeneration.type_mkApps; eauto.
           ++ eapply extract_Apps2. eauto.
              instantiate (1 := repeat tBox n0). cbn in e2. subst.
              (* unfold types_of_case in *. destruct ? in e; inv e. *)
             (*  destruct p0. destruct ? in H4; inv H4. destruct p0. *)
             (*  destruct ? in H5; inv H5. *)
             (*  unfold build_branches_type in E2. destruct o. destruct ind_ctors. cbn in *. congruence. *)
             (*  destruct ind_ctors; cbn in E2. 2:{  destruct p0. destruct p0. destruct ? in E2. destruct p1. destruct p1. *)
             (*                                      destruct ? in E3. destruct ? in E3. destruct ? in E3. inv E3. *)
             (*                                      destruct ? in E2. inv E2. destruct ? in E3. destruct ? in E2. destruct ? in E2. *)
             (*                                      destruct ? in E2. inv E2. destruct ? in E3. inv E3. inv E3. *)
             (*                                      all: try congruence. } *)
             (*  destruct p0. destruct p0. destruct (instantiate_params (ind_params m) (firstn (PCUICAst.ind_npars m) l) *)
             (* (PCUICLiftSubst.subst (inds (inductive_mind ind) u0 (PCUICAst.ind_bodies m)) 0 *)
             (*                       (PCUICUnivSubst.subst_instance_constr u0 t6))); inv E2. *)
             (*  destruct ? in H4; inv H4. destruct ? in E2. destruct ? in E2. inv E2. *)
           (*  cbn in *. destruct l1; inv e0.  *)
              (* should follow from H3 *) admit.
           ++ eauto.
           ++ exists x2. split; eauto. cbn in e2. subst.
              now rewrite mkAppBox_repeat.
      * destruct monad_map eqn:Em; try congruence.
        inv Ht'. assert (He' := He). eapply IHeval1 in He as (? & ? & ?); eauto.
        2:{ econstructor; eauto. }
        eapply extract_Apps in H1 as (? & ? & ? & ? & ?).
        simpl in e. destruct ? in e; [ | admit (* goes away with fuel *) ]. destruct a3; inv e.
        { subst. exfalso. enough (is_box a = true) by congruence.
          enough (extract Σ [] discr = Checked tBox). rewrite H1 in He'; now inv He'.
          eapply is_type_extract.
          eapply eval_is_type_backwards. eauto. rewrite <- is_type_or_proof_mkApps.
          eauto. }

        eapply type_Construct_inv in t0 as [ [[]] ]. destruct y0 as [[[]]].
        destruct d. cbn in H3. subst. destruct p0.
        unfold types_of_case in e. destruct ? in e; inv e.
        destruct p0. destruct ? in H5; inv H5. destruct p0. destruct ? in H6; inv H6.
        
        destruct (nth_error brs c) eqn:E3.
        2:{  (* if looking up c in (ind.ctors o0) works, looking up c in brs must work *)
          (* eapply nth_error_None in E3. *)
          (* Lemma All2_length X Y (P : X -> Y -> Type) x y : *)
          (*   All2 P x y -> #|x| = #|y|. *)
          (* Proof. *)
          (*   induction 1; cbn; congruence. *)
          (* Qed. *)
          (* eapply All2_length in a0. rewrite a0 in *. clear a0. *)
          (* pose proof (nth_error_Some (PCUICAst.ind_ctors o0) c). rewrite H4 in H5. *)
          (* assert (c < #|PCUICAst.ind_ctors o0|) by (eapply H5; intuition congruence). *)
          (* enough (#|l2| = #|PCUICAst.ind_ctors o0|) by omega. *)
          admit.
        }
        pose proof (monad_map_All2 _ _ _ _ _ Em) as [[] [] ] % (All2_nth_error_Some c p0); eauto.
        destruct ?; inv e2.
        edestruct (All2_nth_error_Some _ _ a0 E3) as ([] & ? & ? & ?).
        eapply typing_spine_skipn in t1 as (? & ?).
        subst. cbn in e3. subst. edestruct IHeval2 as (? & ? & ?).
        -- econstructor; eauto. unfold PCUICTyping.iota_red.
           eapply PCUICGeneration.type_mkApps.
           rewrite <- nth_default_eq. unfold nth_default. rewrite E3.
           eauto. eauto.
        -- unfold PCUICTyping.iota_red. eapply extract_Apps2.
           rewrite <- nth_default_eq. unfold nth_default. rewrite E3.
           eauto. 
           eapply Forall2_skipn. now eapply All2_Forall.
        -- eauto.
        -- exists x2. split. eauto. econstructor.
           eassumption.
           unfold iota_red. rewrite <- nth_default_eq.
           unfold nth_default. rewrite e. cbn. eauto.
    + congruence.
  - pose (Ht'' := Ht'). eapply extract_Apps in Ht'' as (e & He & l & Hl & ?).
    inv pre.
    simpl in He. destruct is_type_or_proof eqn:Heq. destruct a. inv He. subst.
    + exists tBox. split. 2:econstructor; eauto.
      eapply is_type_extract. eapply is_type_App in Heq. eapply eval_is_type.
      2:exact Heq. econstructor; eauto. eauto.      
    + destruct extract_mfix eqn:E. inv He. 2:congruence. subst.
      enough (exists l', Forall2 (eval Σ') l l' /\ Forall2 (fun a e => extract Σ [] a = Checked e) args' l' /\ (PCUICTyping.is_constructor narg args' -> is_constructor narg l')) as (l' & ? & ? & ?).

      assert (E' := E).
      pose proof (monad_map_All2 _ _ (fun d : BasicAst.def PCUICAst.term =>
         dbody' <- extract Σ (fix_decls mfix ++ [])%list (BasicAst.dbody d);;
                ret {| E.dname := BasicAst.dname d; E.dbody := dbody'; E.rarg := BasicAst.rarg d |})).
      eapply H6 in E. clear H6.

      assert (H'' := H).
      unfold PCUICTyping.unfold_fix in H. destruct ? in H; try congruence.
      eapply All2_nth_error_Some in E as (? & ? & ?); eauto.
      inv e0. destruct ? in H7; inv H7. inv H.
      assert (exists s', monad_map (extract Σ []) (PCUICTyping.fix_subst mfix) = Checked s') as [s' ?] by admit. (* this goes away without fuel *)

      edestruct IHeval as (? & ? & ?).
      
      2:{ eapply extract_Apps2; eauto. eapply (extract_subst Σ [] _ []).
          - eauto.
          - eapply subslet_fix_subst.
          - rewrite app_context_nil_l. rewrite app_nil_r in E. eauto.
          - admit.
          - eauto.
          - eapply monad_map_Forall2. eauto. }

      econstructor. eapply subject_reduction.
      eauto. exact extr_typed0. all:eauto.
      etransitivity. eapply PCUICReduction.red_mkApps.
      eapply refl_red. eapply All2_impl. exact X. intros. now eapply wcbeval_red.

      eapply PCUICReduction.red_step. econstructor; eauto. eapply refl_red.

      exists x. split. eauto. econstructor. 

      unfold unfold_fix. rewrite e. simpl. f_equal. eauto. eauto.

      assert (subst0 (fix_subst a) a0 = subst0 s' a0) by admit. (* substituting with extracted fix_subst is the same as substituing with fix_subst on results of extraction (like a0), since variables where they differ (extracted fix_subst is box where fix_subst is fix ... := box) are replaced by box in a0 already *)
      rewrite H8. eauto.

      1:{ clear H1. revert H0  X Hl narg  H extr_typed0 extr_env_axiom_free0 extr_env_wf HΣ'. clear.
          intros H0. intros. revert l Hl T extr_typed0. dependent induction H0 using All2_ind_rev; intros.
          - inv Hl. exists []. repeat split; eauto. unfold PCUICTyping.is_constructor, is_constructor.
            destruct narg; cbn; eauto.
          - eapply All2_app_inv in X as ( []  & [[]]). inv a0. inv X0.
            eapply All2_app_inv in Hl as ( []  & [[]]). inv a1. inv H5.
            eapply last_inv in e as (-> & ->).
            eapply type_mkApps_inv in extr_typed0 as (? & ? & [] & ?) ; eauto.
            eapply typing_spine_inv_app in t0 as [[] []].
            eapply IHAll2 in a as (? & ? & ? & ?).  
            
            eapply r in H3 as (? & ? & ?); eauto. 
            eexists (x2 ++ [x3])%list. repeat split.
            eapply Forall2_app; eauto.
            eapply Forall2_app; eauto.

            Hint Resolve Forall2_app.
            intros.
            eapply is_constructor_extract. eauto. eauto.
              
            econstructor; eauto. all:eauto.
            eapply PCUICGeneration.type_mkApps; eauto. }
    + congruence.
  - simpl in Ht'. destruct Extract.is_type_or_proof eqn:Heq. destruct a.
    + inv Ht'. exists tBox. split. 2: repeat econstructor.
      eapply is_type_extract. eapply eval_is_type. 2:eapply Heq.
      econstructor; eauto.
    + inv Ht'. inv pre.
      edestruct (extract_constant _ c decl body u _ _  extr_env_wf H HΣ' H0) as (decl' & ebody & ? & ? & ?); eauto.
      edestruct IHeval as (? & ? & ?).
      * econstructor; eauto.
        eapply subject_reduction. eauto. exact extr_typed0.
        eapply PCUICReduction.red1_red. econstructor; eauto.
      * eauto.
      * eauto.
      * exists x. split. eauto. econstructor. eauto. eauto. eauto. 
    + congruence.
  - simpl in Ht'. destruct Extract.is_type_or_proof eqn:Heq. destruct a0.
    + inv Ht'. exists tBox. split. 2:repeat econstructor.
      eapply is_type_extract. eapply eval_is_type. 2:eapply Heq.
      econstructor; eauto.
    + destruct ?; try congruence. inv Ht'. inv pre.
      eapply type_proj_inv in extr_typed0 as ( [[[[args' mdecl] idecl] [pdecl ty]] u'] & [[[]]]).
      assert (H19 := t).
      assert (H17 := H0). eapply subject_reduction_eval in t. 2-3:eauto.
      eapply type_mkApps_inv in t as (? & ? & [] & ?) ; eauto.
      eapply typing_spine_inv in t0 as []; eauto.
      
      eapply IHeval1 in E as (? & ? & ?); eauto. clear IHeval1.
      eapply extract_Apps in H3 as (e' & l & ? & ? & ?).
      eapply (All2_nth_error_Some _ _ a1) in H0 as (? & ? & ?). 
      eapply IHeval2 in e1 as (? & ? & ?); eauto.
      simpl in l. destruct (Extract.is_type_or_proof _ _ (PCUICAst.tConstruct i k u)) eqn:Hc; inv l.
      destruct a2; inv H6; subst.
      * exfalso. assert (forall t, Extract.is_type_or_proof Σ [] (PCUICAst.tProj (i, pars, arg) discr) = Checked t -> Extract.is_type_or_proof Σ [] discr = Checked t).
        cbn. clear. intros ?. destruct type_of; try eauto.
        destruct reduce_to_ind eqn:E.  eauto. inversion 1.
        eapply H5 in Heq. clear H5. eapply eval_is_type_backwards in H.
        2: rewrite <- is_type_or_proof_mkApps; eauto. congruence.
      * exists x5. split. eauto. eapply eval_proj. eauto. rewrite <- nth_default_eq.
        unfold nth_default. rewrite e0. eauto.
      * econstructor; eauto.
      * econstructor; eauto.
    + congruence.
  - simpl in Ht'. destruct Extract.is_type_or_proof eqn:Heq. destruct a.
    + inv Ht'. exists tBox. split. 2: repeat econstructor. 
      simpl. rewrite Heq. reflexivity.
    + destruct ?; try congruence.
      inv Ht'. eexists. split. 2:econstructor.
      simpl. now rewrite Heq, E.
    + congruence.
  - simpl in Ht'. destruct Extract.is_type_or_proof eqn:Heq. destruct a.
    + inv Ht'. exists tBox. split. 2: repeat econstructor.
      simpl. rewrite Heq. reflexivity.
    + inv Ht'. exists tBox. split. 2: repeat econstructor.
      simpl. now rewrite Heq. 
    + congruence. 
  - simpl in Ht'. destruct Extract.is_type_or_proof eqn:Heq. destruct a.
    + inv Ht'. exists tBox. split. 2: repeat econstructor.
      simpl. rewrite Heq. reflexivity.
    + inv Ht'.  exists tBox. split. 2: repeat econstructor.
      simpl. rewrite Heq. reflexivity.
    + congruence.
  - eapply extract_Apps in Ht' as (e & ? & ? & []). subst.
    inv pre. edestruct (type_mkApps_inv _ _ _ _ _ extr_env_wf extr_typed0) as (? & ? & [] & ?) ; eauto. 

    eapply IHeval in e0 as (? & ? & ?); eauto.
    eapply extract_tInd in H1. subst.
    exists tBox. split. eapply is_type_extract. eapply is_type_App. eauto. eapply subject_reduction.
    eauto. 2:{ eapply PCUICReduction.red_mkApps. eapply wcbeval_red. eauto.
               eapply All2_impl. exact X. intros. eapply wcbeval_red. eauto. }
    eauto. eapply is_type_ind. eapply subject_reduction_eval; eauto.
    destruct e; subst; eauto; eapply eval_box_apps; eauto.
    econstructor; eauto.
  - simpl in Ht'. destruct Extract.is_type_or_proof eqn:Heq. destruct a.
    + inv Ht'. exists tBox. split. 2: repeat econstructor.
      simpl. rewrite Heq. reflexivity.
    + inv Ht'. eexists. split.
      simpl. rewrite Heq. reflexivity. econstructor. eauto.
    + congruence.
  - assert (H10 := Ht'). eapply extract_Apps in Ht' as (e & ? & ? & []). subst.
    inv pre. edestruct (type_mkApps_inv _ _ _ _ _ extr_env_wf extr_typed0) as (? & ? & [] & ?) ; eauto. 

    eapply IHeval in e0 as (? & ? & ?); eauto.
    simpl in H1. destruct is_type_or_proof eqn:Heq. destruct a0.
    + inv H1. exists tBox.
      split. eapply is_type_extract. eapply is_type_App. eapply subject_reduction.
      eauto. 2:{ eapply PCUICReduction.red_mkApps. eapply wcbeval_red. eauto.
               eapply All2_impl. exact X. intros. eapply wcbeval_red. eauto. }

      eauto. eauto.
      destruct e; subst; eauto; eapply eval_box_apps; eauto.
    + inv H1. assert (t' = mkApps e x). destruct e; eauto. eapply eval_tBox_inv in H2. inv H2. subst. clear y.
      enough (exists x', Forall2 (eval Σ') x x' /\ Forall2 (fun a e => extract Σ [] a = Checked e) l' x') as (x' & H1 & H12).
      eexists (mkApps (tConstruct i k) x'). split.
      * eapply extract_Apps2. simpl. now rewrite Heq. eauto.
      * econstructor; eauto.
      * clear IHeval. clear H10. revert x a X HΣ' extr_env_axiom_free0 extr_typed0 extr_env_wf.
        clear - H0. intros.
        
        dependent induction H0 using All2_ind_rev.
        -- depelim a. exists []. repeat econstructor.
        -- specialize (All2_app_inv _ _ _ _ _ _  a) as ([] & ([->] & ?)).
           specialize (All2_app_inv _ _ _ _ _ _  X) as ([] & ([] & ?)).
           inv a1. inv H4. 
           inv a3. inv X1.
           eapply last_inv in e as [-> ->].

           rewrite mkApps_snoc in extr_typed0.
           edestruct (type_mkApps_inv _ _ _ [x] _ extr_env_wf extr_typed0) as (? & ? & [] & ?) ; eauto. 
           inv t0.
           
           eapply IHAll2 in a0 as (? & ? & ?).
           all:auto. 2:eauto.
           eapply r in H2 as (? & ? & ?).
           
           exists (x2 ++ [x3])%list. 
           2:econstructor; eauto. 3:eauto. split.
           ++ eapply Forall2_app; eauto.
           ++ eapply Forall2_app; eauto.
           ++ eauto.
    + congruence.
    + econstructor; eauto.
Admitted.
