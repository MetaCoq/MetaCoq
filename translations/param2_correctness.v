Require Import Template.Template Template.Ast Template.monad_utils Translations.sigma.
Require Import Template.Induction Template.LiftSubst Template.Typing Template.Checker.
Require Import Arith.Compare_dec.
Require Import  Translations.translation_utils.
Import String Lists.List.ListNotations MonadNotation.
Open Scope string_scope.
Open Scope list_scope.
Open Scope sigma_scope.

Require Import Translations.tsl_param2.

Tactic Notation "myeapply" constr(lemma) "unifying" open_constr(term) :=
  let TT := type of term in
  let T := open_constr:(_:TT) in
  replace term with T;
  [eapply lemma|].


Definition tsl_ty := tsl_ty_param.


Definition option_get {A} (default : A) (x : option A) : A
  := match x with
     | Some x => x
     | None => default
     end.

Definition map_context_decl (f : term -> tsl_result term) (decl : context_decl): tsl_result context_decl

  := b' <- (match decl.(decl_body) with
           | Some b => b' <- f b ;; ret (Some b')
           | None => ret None
           end) ;;
     t' <- f decl.(decl_type) ;;
     ret {| decl_name := decl.(decl_name);
            decl_body := b'; decl_type := t' |}.



Lemma map_context_decl_success f d d' (H : map_context_decl f d = Success d')
  : (decl_name d' = decl_name d) /\ (match decl_body d with
                                    | Some t => ex (fun t' => (decl_body d') = Some t' /\ Success t' = f t)
                                    | None => decl_body d' = None
                                    end)
    /\ (Success (decl_type d') = f (decl_type d)).
  destruct d as [n t A].
  change ((b' <- (match t with
           | Some b => b' <- f b ;; ret (Some b')
           | None => ret None
           end) ;;
     t' <- f A ;;
     ret {| decl_name := n;
            decl_body := b'; decl_type := t' |}) = Success d') in H.
  destruct t.
  - remember (f t). destruct t0; [|discriminate].
    remember (f A). destruct t1; [|discriminate].
    cbn in H. inversion H. cbn.
    split. reflexivity. split; [|assumption].
    exists t0. split. reflexivity. assumption.
  - remember (f A). destruct t; [|discriminate].
    cbn in H. inversion H. cbn.
    split. reflexivity. split; [|assumption].
    reflexivity.
Qed.


  
Fixpoint tsl_ctx (fuel : nat) (Σ : global_context) (E : tsl_table) (Γ : context) : tsl_result context
  := match Γ with
     | [] => ret []
     | A :: Γ => A' <- map_context_decl (tsl_ty fuel Σ E Γ) A ;;
                Γ' <- (tsl_ctx fuel Σ E Γ) ;;
                ret (A' :: Γ')
     end.

Lemma le_irr n m (p q : n <= m) : p = q.
Admitted.

Lemma tsl_ctx_cons fuel Σ E Γ A
  : tsl_ctx fuel Σ E (A :: Γ)
    = (A' <- map_context_decl (tsl_ty fuel Σ E Γ) A ;;
       Γ' <- (tsl_ctx fuel Σ E Γ) ;;
       ret (A' :: Γ')).
  reflexivity.
Defined.

  
Lemma tsl_ctx_length fuel Σ E Γ
  : forall Γ', tsl_ctx fuel Σ E Γ = Success Γ' -> #|Γ| = #|Γ'|.
Proof.
  induction Γ; intros Γ' H.
  - destruct Γ'. reflexivity. discriminate.
  - rewrite tsl_ctx_cons in H.
(*     simpl in H. *)
(*     remember (map_context_decl (tsl_ty_param fuel Σ E Γ) a).  *)
(*     destruct t; [|discriminate]. *)
(*     remember (tsl_ctx fuel Σ E Γ).  *)
(*     destruct t; [|discriminate]. *)
(*     cbn in H. inversion H; clear H. *)
(*     cbn. apply eq_S. apply IHΓ. reflexivity. *)
(* Defined. *)
Admitted.

Fixpoint removefirst_n {A} (n : nat) (l : list A) : list A :=
  match n with
  | O => l
  | S n => match l with
          | [] => []
          | a :: l => removefirst_n n l
          end
  end.

Notation "( x ; y )" := (exist _ x y).

Lemma tsl_ctx_safe_nth fuel Σ E Γ
  : forall Γ', tsl_ctx fuel Σ E Γ = Success Γ' -> forall n p, exists p',
        map_context_decl (tsl_ty fuel Σ E (removefirst_n (S n) Γ))
                         (safe_nth Γ (n; p))
        = Success (safe_nth Γ' (n; p')).
(*   intros Γ' H n p. cbn beta in *. *)
(*   revert Γ Γ' H p. *)
(*   induction n; intros Γ Γ' H p; *)
(*     (destruct Γ as [|A Γ]; [inversion p|]). *)
(*   - cbn -[map_context_decl]. *)
(*     rewrite tsl_ctx_cons in H. *)
(*     remember (map_context_decl (tsl_term fuel Σ E Γ) A).  *)
(*     destruct t; [|discriminate]. *)
(*     remember (tsl_ctx fuel Σ E Γ).  *)
(*     destruct t; [|discriminate]. *)
(*     cbn in H. inversion H; clear H. *)
(*     clear p H1. *)
(*     unshelve econstructor. apply le_n_S, le_0_n. *)
(*     reflexivity. *)
(*   - cbn -[map_context_decl]. *)
(*     rewrite tsl_ctx_cons in H. *)
(*     remember (map_context_decl (tsl_term fuel Σ E Γ) A).  *)
(*     destruct t; [|discriminate]. *)
(*     remember (tsl_ctx fuel Σ E Γ).  *)
(*     destruct t; [|discriminate]. *)
(*     cbn in H. inversion H; clear H. *)
(*     symmetry in Heqt0. *)
(*     set (Typing.safe_nth_obligation_2 context_decl (A :: Γ) (S n; p) A Γ eq_refl n eq_refl). *)
(*     specialize (IHn Γ c0 Heqt0 l). *)
(*     destruct IHn. *)
    
(*     unshelve econstructor. *)
(*     cbn. rewrite <- (tsl_ctx_length fuel Σ E Γ _ Heqt0). exact p. *)
(*     etransitivity. exact π2. cbn. *)
(*     apply f_equal, f_equal, f_equal. *)
(*     apply le_irr. *)
(* Defined. *)
Admitted.

(* (* todo inductives *) *)
(* Definition global_ctx_correct (Σ : global_context) (E : tsl_context) *)
(*   := forall id T, lookup_constant_type Σ id = Checked T *)
(*                 -> exists fuel t' T', lookup_tsl_ctx E (ConstRef id) = Some t' /\ *)
(*                            tsl_term fuel Σ E [] T = Success _ T' /\ *)
(*                            squash (Σ ;;; [] |-- t' : T'). *)


Definition tsl_table_correct Σ E
  := forall id t' T,
    lookup_tsl_table E (ConstRef id) = Some t' ->
    lookup_constant_type Σ id = Checked T ->
    exists fuel T', ((tsl_ty fuel Σ E [] T = Success T')
      * (Σ ;;; [] |--  t' : T'))%type.

Lemma tsl_lift fuel Σ E Γ n (p : n <= #|Γ|) t
  : tsl_term fuel Σ E Γ (lift0 n t) =
    (t' <- tsl_term fuel Σ E (removefirst_n n Γ) t ;; ret (lift0 n t')).
Admitted.

Lemma tsl_ty_lift fuel Σ E Γ n (p : n <= #|Γ|) t
  : tsl_ty fuel Σ E Γ (lift0 n t) =
    (t' <- tsl_ty fuel Σ E (removefirst_n n Γ) t ;; ret (lift0 n t')).
Admitted.

Lemma tsl_S_fuel {fuel Σ E Γ t t'}
  : tsl_term fuel Σ E Γ t = Success t' -> tsl_term (S fuel) Σ E Γ t = Success t'.
Admitted.

Run TemplateProgram (sd <- tmQuoteInductive "Translations.sigma.sigma" ;;
                     tmDefinition "sigma_decl" sd).

Definition declare_sigma Σ := declared_minductive Σ "Translations.sigma.sigma" sigma_decl.

Require Import ssreflect ssrfun.

Record hidden T := Hidden {show : T}.
Arguments show : simpl never.
Notation "'hidden" := (show _ (Hidden _ _)).
Lemma hide T (t : T) : t = show T (Hidden T t).
Proof. by []. Qed.

Lemma typing_pair (Σ : global_context) (HΣ : declare_sigma Σ)
      Γ a1 a2 t1 t2 :
      Σ ;;; Γ |-- t1 : a1 ->
      Σ ;;; Γ |-- t2 : tApp a2 [t1] ->
      Σ ;;; Γ |-- pair a1 a2 t1 t2 : pack a1 a2.
Proof.
  intros H H0. unfold pair, pack, tPair, tSigma.
  eapply type_App.
    unshelve eapply type_Construct; first shelve.
    eexists; split.
      by exists sigma_decl.
    reflexivity.
  - simpl. unfold declare_sigma, declared_minductive in HΣ.
    rewrite HΣ.
    
    symmetry in HΣ |-.
    

    set spine := (X in typing_spine _ _ X).



    
Lemma tsl_correct Σ Γ t T (H : Σ ;;; Γ |-- t : T)
  : forall E, tsl_table_correct Σ E ->
    forall fuel Γ' t' T',
    tsl_term fuel Σ E Γ t = Success t' ->
    tsl_ty fuel Σ E Γ T = Success T' ->
    tsl_ctx fuel Σ E Γ = Success Γ' -> Σ ;;; Γ' |-- t' : T'.
  induction H; intros;
    (destruct fuel; [discriminate|]).
  - inversion H0.
    destruct (tsl_ctx_safe_nth _ Σ E Γ _ H2 n isdecl) as [p H3].
    unshelve myeapply type_Rel unifying T'. assumption.
    apply map_context_decl_success in H3.
    destruct H3 as [_ [_ H3]].
    assert (Success (lift0 (S n) (decl_type (safe_nth Γ' (n; p))))
            = Success T'). {
      etransitivity; [|eassumption].
      clear -H3. rewrite -> tsl_ty_lift. now rewrite <- H3. assumption.
    }
    now inversion H5.
  - simpl in H0.
    case t_def : tsl_rec2 => [t|//] in H0.
    case t2_def : tsl_rec2 => [t2|//] in H0.
    injection H0; clear H0; intro H0.
    injection H1; clear H1; intro H1.
    destruct H0, H1.


    
    cbn in H1.
    inversion H1; clear H1.
    clear H3 H4.
    econstructor.
  - cbn in H2.
    remember (tsl_term fuel Σ E Γ c).
    destruct t0; [|discriminate].
    remember (tsl_term fuel Σ E Γ t).
    destruct t1; [|discriminate].
    inversion H2; clear H2. clear t' H6.
    myeapply type_Cast unifying T'.
    + eapply IHtyping1 ; try eassumption.
      2: reflexivity. now apply tsl_S_fuel.
    + eapply IHtyping2; try eassumption;
        now apply tsl_S_fuel.
    + symmetry in Heqt1. apply tsl_S_fuel in Heqt1.
      rewrite Heqt1 in H3. now inversion H3.
  - cbn in H3. cbn in H2.
    inversion H3. clear H3 H6.
    remember (tsl_term fuel Σ E Γ t).
    destruct t0; [|discriminate].
    remember (tsl_term fuel Σ E (Γ,, vass n t) b).
    destruct t1; [|discriminate].
    inversion H2. clear H2 H5.
    unfold timesBool.
    symmetry in Heqt0, Heqt1.
    specialize (IHtyping1 E H1 (S fuel) Γ' t0 (tSort s1) (tsl_S_fuel Heqt0) eq_refl H4).
    specialize (IHtyping2 E H1 (S fuel) (Γ' ,,vass n t0) t1 (tSort s2) (tsl_S_fuel Heqt1) eq_refl).
    simple refine (let IH2 := IHtyping2 _ in _);
      [|clearbody IH2; clear IHtyping2].
    { unfold snoc. rewrite tsl_ctx_cons.
      rewrite H4. cbn -[tsl_term].
      rewrite (tsl_S_fuel Heqt0). reflexivity. }
    pose proof (type_Prod  _ _ _ _ _ _ _ IHtyping1 IH2).
    clear -H2.
    eapply type_App. unfold tSigma.
eapply type_Ind. econstructor.