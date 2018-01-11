(*! Common syntax to ITT and ETT *)

Require Import Ast.

Inductive sterm : Set :=
| sRel       : nat -> sterm
| sSort      : sort -> sterm
| sProd      : name -> sterm (** the type **) -> sterm -> sterm
| sLambda    : name -> sterm (** type **) -> sterm (** type **) -> sterm -> sterm
| sApp       : sterm -> name -> sterm (** type **) -> sterm (** type **) -> sterm -> sterm
(* For now we use our own syntax for equality and Σ-types *)
| sEq        : sort -> sterm -> sterm -> sterm -> sterm
| sRefl      : sterm -> sterm -> sterm
| sJ         : sterm -> sterm -> sterm -> sterm -> sterm -> sterm -> sterm
| sUip       : sterm -> sterm -> sterm -> sterm -> sterm -> sterm
| sFunext    : sterm -> sterm -> sterm -> sterm -> sterm -> sterm

| sSig       : name -> sterm -> sterm -> sterm
| sPair      : sterm -> sterm -> sterm -> sterm -> sterm
| sSigLet    : sterm -> sterm -> sterm -> sterm -> sterm -> sterm
.