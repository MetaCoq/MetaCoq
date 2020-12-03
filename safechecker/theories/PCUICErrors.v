
(* Distributed under the terms of the MIT license. *)
From MetaCoq.Template Require Import config utils uGraph.
From MetaCoq.PCUIC Require Import PCUICAst PCUICAstUtils PCUICPretty.
From Equations Require Import Equations.
Require Import ssreflect ssrbool.

Local Set Keyed Unification.
Set Equations Transparent.

Inductive ConversionError :=
| NotFoundConstants (c1 c2 : kername)

| NotFoundConstant (c : kername)

| LambdaNotConvertibleTypes
    (Γ1 : context) (na : aname) (A1 t1 : term)
    (Γ2 : context) (na' : aname) (A2 t2 : term)
    (e : ConversionError)

| LambdaNotConvertibleAnn
    (Γ1 : context) (na : aname) (A1 t1 : term)
    (Γ2 : context) (na' : aname) (A2 t2 : term)

| ProdNotConvertibleDomains
    (Γ1 : context) (na : aname) (A1 B1 : term)
    (Γ2 : context) (na' : aname) (A2 B2 : term)
    (e : ConversionError)

| ProdNotConvertibleAnn
    (Γ1 : context) (na : aname) (A1 B1 : term)
    (Γ2 : context) (na' : aname) (A2 B2 : term)

| CaseOnDifferentInd
    (Γ1 : context)
    (ind : inductive) (par : nat) (p c : term) (brs : list (nat × term))
    (Γ2 : context)
    (ind' : inductive) (par' : nat) (p' c' : term) (brs' : list (nat × term))

| CaseBranchNumMismatch
    (ind : inductive) (par : nat)
    (Γ : context) (p c : term) (brs1 : list (nat × term))
    (m : nat) (br : term) (brs2 : list (nat × term))
    (Γ' : context) (p' c' : term) (brs1' : list (nat × term))
    (m' : nat) (br' : term) (brs2' : list (nat × term))

| DistinctStuckProj
    (Γ : context) (p : projection) (c : term)
    (Γ' : context) (p' : projection) (c' : term)

| CannotUnfoldFix
    (Γ : context) (mfix : mfixpoint term) (idx : nat)
    (Γ' : context) (mfix' : mfixpoint term) (idx' : nat)

| FixRargMismatch (idx : nat)
    (Γ : context) (u : def term) (mfix1 mfix2 : mfixpoint term)
    (Γ' : context) (v : def term) (mfix1' mfix2' : mfixpoint term)

| FixMfixMismatch (idx : nat)
    (Γ : context) (mfix : mfixpoint term)
    (Γ' : context) (mfix' : mfixpoint term)

| DistinctCoFix
    (Γ : context) (mfix : mfixpoint term) (idx : nat)
    (Γ' : context) (mfix' : mfixpoint term) (idx' : nat)

| CoFixRargMismatch (idx : nat)
    (Γ : context) (u : def term) (mfix1 mfix2 : mfixpoint term)
    (Γ' : context) (v : def term) (mfix1' mfix2' : mfixpoint term)

| CoFixMfixMismatch (idx : nat)
    (Γ : context) (mfix : mfixpoint term)
    (Γ' : context) (mfix' : mfixpoint term)

| StackHeadError
    (leq : conv_pb)
    (Γ1 : context)
    (t1 : term) (args1 : list term) (u1 : term) (l1 : list term)
    (Γ2 : context)
    (t2 : term) (u2 : term) (l2 : list term)
    (e : ConversionError)

| StackTailError (leq : conv_pb)
    (Γ1 : context)
    (t1 : term) (args1 : list term) (u1 : term) (l1 : list term)
    (Γ2 : context)
    (t2 : term) (u2 : term) (l2 : list term)
    (e : ConversionError)

| StackMismatch
    (Γ1 : context) (t1 : term) (args1 l1 : list term)
    (Γ2 : context) (t2 : term) (l2 : list term)

| HeadMismatch
    (leq : conv_pb)
    (Γ1 : context) (t1 : term)
    (Γ2 : context) (t2 : term).

Inductive type_error :=
| UnboundRel (n : nat)
| UnboundVar (id : string)
| UnboundEvar (ev : nat)
| UndeclaredConstant (c : kername)
| UndeclaredInductive (c : inductive)
| UndeclaredConstructor (c : inductive) (i : nat)
| NotCumulSmaller (G : universes_graph) (Γ : context) (t u t' u' : term) (e : ConversionError)
| NotConvertible (G : universes_graph) (Γ : context) (t u : term)
| NotASort (t : term)
| NotAProduct (t t' : term)
| NotAnInductive (t : term)
| NotAnArity (t : term)
| IllFormedFix (m : mfixpoint term) (i : nat)
| UnsatisfiedConstraints (c : ConstraintSet.t)
| Msg (s : string).
Derive NoConfusion for type_error.

Definition print_level := string_of_level.

Definition string_of_Z z :=
  if (z <=? 0)%Z then "-" ^ string_of_nat (Z.to_nat (- z)) else string_of_nat (Z.to_nat z).

Definition print_edge '(l1, n, l2)
  := "(" ^ print_level l1 ^ ", " ^ string_of_Z n ^ ", "
         ^ print_level l2 ^ ")".

Definition print_universes_graph (G : universes_graph) :=
  let levels := LevelSet.elements G.1.1 in
  let edges := wGraph.EdgeSet.elements G.1.2 in
  string_of_list print_level levels
  ^ "\n" ^ string_of_list print_edge edges.

Definition string_of_conv_pb (c : conv_pb) : string :=
  match c with
  | Conv => "conversion"
  | Cumul => "cumulativity"
  end.

Definition print_term Σ Γ t :=
  print_term Σ Γ true false t.

Fixpoint string_of_conv_error Σ (e : ConversionError) : string :=
  match e with
  | NotFoundConstants c1 c2 =>
      "Both constants " ^ string_of_kername c1 ^ " and " ^ string_of_kername c2 ^
      " are not found in the environment."
  | NotFoundConstant c =>
      "Constant " ^ string_of_kername c ^
      " common in both terms is not found in the environment."
  | LambdaNotConvertibleAnn Γ1 na A1 t1 Γ2 na' A2 t2 =>
      "When comparing\n" ^ print_term Σ Γ1 (tLambda na A1 t1) ^
      "\nand\n" ^ print_term Σ Γ2 (tLambda na' A2 t2) ^
      "\nbinding annotations are not convertible\n"
  | LambdaNotConvertibleTypes Γ1 na A1 t1 Γ2 na' A2 t2 e =>
      "When comparing\n" ^ print_term Σ Γ1 (tLambda na A1 t1) ^
      "\nand\n" ^ print_term Σ Γ2 (tLambda na' A2 t2) ^
      "\ntypes are not convertible:\n" ^
      string_of_conv_error Σ e
  | ProdNotConvertibleAnn Γ1 na A1 B1 Γ2 na' A2 B2 =>
      "When comparing\n" ^ print_term Σ Γ1 (tProd na A1 B1) ^
      "\nand\n" ^ print_term Σ Γ2 (tProd na' A2 B2) ^
      "\nbinding annotations are not convertible:\n"
  | ProdNotConvertibleDomains Γ1 na A1 B1 Γ2 na' A2 B2 e =>
      "When comparing\n" ^ print_term Σ Γ1 (tProd na A1 B1) ^
      "\nand\n" ^ print_term Σ Γ2 (tProd na' A2 B2) ^
      "\ndomains are not convertible:\n" ^
      string_of_conv_error Σ e
  | CaseOnDifferentInd Γ ind par p c brs Γ' ind' par' p' c' brs' =>
      "The two stuck pattern-matching\n" ^
      print_term Σ Γ (tCase (ind, par) p c brs) ^
      "\nand\n" ^ print_term Σ Γ' (tCase (ind', par') p' c' brs') ^
      "\nare done on distinct inductive types."
  | CaseBranchNumMismatch
      ind par Γ p c brs1 m br brs2 Γ' p' c' brs1' m' br' brs2' =>
      "The two stuck pattern-matching\n" ^
      print_term Σ Γ (tCase (ind, par) p c (brs1 ++ (m,br) :: brs2)) ^
      "\nand\n" ^
      print_term Σ Γ' (tCase (ind, par) p' c' (brs1' ++ (m',br') :: brs2')) ^
      "\nhave a mistmatch in the branch number " ^ string_of_nat #|brs1| ^
      "\nthe number of parameters do not coincide\n" ^
      print_term Σ Γ br ^
      "\nhas " ^ string_of_nat m ^ " parameters while\n" ^
      print_term Σ Γ br' ^
      "\nhas " ^ string_of_nat m' ^ "."
  | DistinctStuckProj Γ p c Γ' p' c' =>
      "The two stuck projections\n" ^
      print_term Σ Γ (tProj p c) ^
      "\nand\n" ^
      print_term Σ Γ' (tProj p' c') ^
      "\nare syntactically different."
  | CannotUnfoldFix Γ mfix idx Γ' mfix' idx' =>
      "The two fixed-points\n" ^
      print_term Σ Γ (tFix mfix idx) ^
      "\nand\n" ^ print_term Σ Γ' (tFix mfix' idx') ^
      "\ncorrespond to syntactically distinct terms that can't be unfolded."
  | FixRargMismatch idx Γ u mfix1 mfix2 Γ' v mfix1' mfix2' =>
      "The two fixed-points\n" ^
      print_term Σ Γ (tFix (mfix1 ++ u :: mfix2) idx) ^
      "\nand\n" ^ print_term Σ Γ' (tFix (mfix1' ++ v :: mfix2') idx) ^
      "\nhave a mismatch in the function number " ^ string_of_nat #|mfix1| ^
      ": arguments " ^ string_of_nat u.(rarg) ^
      " and " ^ string_of_nat v.(rarg) ^ "are different."
  | FixMfixMismatch idx Γ mfix Γ' mfix' =>
      "The two fixed-points\n" ^
      print_term Σ Γ (tFix mfix idx) ^
      "\nand\n" ^
      print_term Σ Γ' (tFix mfix' idx) ^
      "\nhave a different number of mutually defined functions."
  | DistinctCoFix Γ mfix idx Γ' mfix' idx' =>
      "The two cofixed-points\n" ^
      print_term Σ Γ (tCoFix mfix idx) ^
      "\nand\n" ^ print_term Σ Γ' (tCoFix mfix' idx') ^
      "\ncorrespond to syntactically distinct terms."
  | CoFixRargMismatch idx Γ u mfix1 mfix2 Γ' v mfix1' mfix2' =>
      "The two co-fixed-points\n" ^
      print_term Σ Γ (tCoFix (mfix1 ++ u :: mfix2) idx) ^
      "\nand\n" ^ print_term Σ Γ' (tCoFix (mfix1' ++ v :: mfix2') idx) ^
      "\nhave a mismatch in the function number " ^ string_of_nat #|mfix1| ^
      ": arguments " ^ string_of_nat u.(rarg) ^
      " and " ^ string_of_nat v.(rarg) ^ "are different."
  | CoFixMfixMismatch idx Γ mfix Γ' mfix' =>
      "The two co-fixed-points\n" ^
      print_term Σ Γ (tCoFix mfix idx) ^
      "\nand\n" ^
      print_term Σ Γ' (tCoFix mfix' idx) ^
      "\nhave a different number of mutually defined functions."
  | StackHeadError leq Γ1 t1 args1 u1 l1 Γ2 t2 u2 l2 e =>
      "TODO stackheaderror\n" ^
      string_of_conv_error Σ e
  | StackTailError leq Γ1 t1 args1 u1 l1 Γ2 t2 u2 l2 e =>
      "TODO stacktailerror\n" ^
      string_of_conv_error Σ e
  | StackMismatch Γ1 t1 args1 l1 Γ2 t2 l2 =>
      "Convertible terms\n" ^
      print_term Σ Γ1 t1 ^
      "\nand\n" ^ print_term Σ Γ2 t2 ^
      "are convertible/convertible (TODO) but applied to a different number" ^
      " of arguments."
  | HeadMismatch leq Γ1 t1 Γ2 t2 =>
      "Terms\n" ^
      print_term Σ Γ1 t1 ^
      "\nand\n" ^ print_term Σ Γ2 t2 ^
      "\ndo not have the same head when comparing for " ^
      string_of_conv_pb leq
  end.

Definition string_of_type_error Σ (e : type_error) : string :=
  match e with
  | UnboundRel n => "Unbound rel " ^ string_of_nat n
  | UnboundVar id => "Unbound var " ^ id
  | UnboundEvar ev => "Unbound evar " ^ string_of_nat ev
  | UndeclaredConstant c => "Undeclared constant " ^ string_of_kername c
  | UndeclaredInductive c => "Undeclared inductive " ^ string_of_kername (inductive_mind c)
  | UndeclaredConstructor c i => "Undeclared inductive " ^ string_of_kername (inductive_mind c)
  | NotCumulSmaller G Γ t u t' u' e => "Terms are not <= for cumulativity:\n" ^
      print_term Σ Γ t ^ "\nand:\n" ^ print_term Σ Γ u ^
      "\nafter reduction:\n" ^
      print_term Σ Γ t' ^ "\nand:\n" ^ print_term Σ Γ u' ^
      "\nerror:\n" ^ string_of_conv_error Σ e ^
      "\nin universe graph:\n" ^ print_universes_graph G
  | NotConvertible G Γ t u => "Terms are not convertible:\n" ^
      print_term Σ Γ t ^ "\nand:\n" ^ print_term Σ Γ u ^
      "\nin universe graph:\n" ^ print_universes_graph G
  | NotASort t => "Not a sort"
  | NotAProduct t t' => "Not a product"
  | NotAnArity t => print_term Σ [] t ^ " is not an arity"
  | NotAnInductive t => "Not an inductive"
  | IllFormedFix m i => "Ill-formed recursive definition"
  | UnsatisfiedConstraints c => "Unsatisfied constraints"
  | Msg s => "Msg: " ^ s
  end.

Inductive typing_result (A : Type) :=
| Checked (a : A)
| TypeError (t : type_error).
Global Arguments Checked {A} a.
Global Arguments TypeError {A} t.

Instance typing_monad : Monad typing_result :=
  {| ret A a := Checked a ;
     bind A B m f :=
       match m with
       | Checked a => f a
       | TypeError t => TypeError t
       end
  |}.

Instance monad_exc : MonadExc type_error typing_result :=
  { raise A e := TypeError e;
    catch A m f :=
      match m with
      | Checked a => m
      | TypeError t => f t
      end
  }.

Inductive env_error :=
| IllFormedDecl (e : string) (e : type_error)
| AlreadyDeclared (id : string).

Inductive EnvCheck (A : Type) :=
| CorrectDecl (a : A)
| EnvError (Σ : global_env_ext) (e : env_error).
Global Arguments EnvError {A} Σ e.
Global Arguments CorrectDecl {A} a.

Global Instance envcheck_monad : Monad EnvCheck :=
  {| ret A a := CorrectDecl a ;
      bind A B m f :=
        match m with
        | CorrectDecl a => f a
        | EnvError g e => EnvError g e
        end
  |}.

Global Instance envcheck_monad_exc
  : MonadExc (global_env_ext * env_error) EnvCheck :=
  { raise A '(g, e) := EnvError g e;
    catch A m f :=
      match m with
      | CorrectDecl a => m
      | EnvError g t => f (g, t)
      end
  }.

Definition wrap_error {A} Σ (id : string) (check : typing_result A) : EnvCheck A :=
  match check with
  | Checked a => CorrectDecl a
  | TypeError e => EnvError Σ (IllFormedDecl id e)
  end.