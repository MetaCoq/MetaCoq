# Small stuffs

- `assumption_context` should be a boolean function.

- remove duplication of eq_context / eq_context_upto  and eq_decl / eq_decl_upto

- Rename `mkApps_nested` into `mkApps_app` (et inverser la direction de la
  règle)

- Make `wf Σ` `wf_ext Σ` some typeclasses (as at the begining of PCUICCanonicity)
  et changer les : wf Σ -> en {wfΣ : wf Σ} partout, ce qui éviterait bien des
  conditions de bord triviales

- Make complilation of Checker plugin working again

- Remove PCUIC plugin target? And Extraction file?

- Remove remaining warnings.
  May needs `Set Warnings "-notation-overridden".`

- Replace all `eauto with pcuic` by `pcuic` or somehing like this and make
  this tactic available everywhere.

- Recompile the dpd-graph.

- Remove funext axiom from PCUICConfluence.

- Remove ProofIrrelevance axiom everywhere.

- Clean `Derive`s: always derive `Siganture`, `NoConf`, ... directly after the
  definition of the inductive. (To avoid doing it several times.)
  (Mostly done)
  
- Finish the PCUICSigmaCalculus proofs.

# Big projects

- Refine the longest-simple-path algorithm on universes with the 
  Bender & al algorithm used in Coq, extended with edges of negative weight.
  Alternatively prove the spec for that algorithm. Refinement might be easier:
  it amounts to show that the new algorithm calculates the longest simple
  path between two universes. 

- Verify parsing and printing of terms / votour

- Primivite projections: we could be more relaxed on the elimination sort of the 
  inductive. If it is e.g. InProp, then all projections to types in Prop should
  be definable. Probably not very useful though because if the elimination is 
  restricted then it means some Type is in the constructor and won't be projectable.
  

## Website

Put a demo using JS-coq on the webiste


## Eta



## Template <-> PCUIC

- Finish the started proofs

- Prove that:
   Γ |- t : A   iff   [Γ] |- [t] : [A]

This is not obvious because we don't have that [ [t] ]⁻¹ = t. The casts are changed
into β-redexes, hence it is only β-convertible and not a syntactical equality.

- Deduce that we have weakening and substitution lemmas in Template from those of
  PCUIC.
