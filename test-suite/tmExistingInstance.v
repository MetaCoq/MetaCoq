From MetaCoq.Template Require Import utils All.

MetaCoq Run (tmLocate1 "I" >>= tmDefinition "qI").

Fail MetaCoq Run (tmExistingInstance qI).

Existing Class True.

MetaCoq Run (tmExistingInstance qI).
Print Instances True.


