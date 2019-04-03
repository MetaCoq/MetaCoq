open Univ
open Names
open Pp (* this adds the ++ to the current scope *)

open Tm_util
open Quoter
open Constr_quoter
open TemplateCoqQuoter

(* todo: the recursive call is uneeded provided we call it on well formed terms *)

let print_term (u: t) : Pp.t = pr_constr u

let unquote_pair trm =
  let (h,args) = app_full trm [] in
  if Constr.equal h c_pair then
    match args with
      _ :: _ :: x :: y :: [] -> (x, y)
    | _ -> bad_term_verb trm "unquote_pair"
  else
    not_supported_verb trm "unquote_pair"

let rec unquote_list trm =
  let (h,args) = app_full trm [] in
  if Constr.equal h c_nil then
    []
  else if Constr.equal h c_cons then
    match args with
      _ :: x :: xs :: [] -> x :: unquote_list xs
    | _ -> bad_term_verb trm "unquote_list"
  else
    not_supported_verb trm "unquote_list"


let inspect_term (t:Constr.t) :  (Constr.t, quoted_int, quoted_ident, quoted_name, quoted_sort, quoted_cast_kind, quoted_kernel_name, quoted_inductive, quoted_univ_instance, quoted_proj) structure_of_term =
  let (h,args) = app_full t [] in
  if Constr.equal h tRel then
    match args with
      x :: _ -> ACoq_tRel x
    | _ -> CErrors.user_err (print_term t ++ Pp.str ("has bad structure"))
  else if Constr.equal h tVar then
    match args with
      x :: _ -> ACoq_tVar x
    | _ -> CErrors.user_err (print_term t ++ Pp.str ("has bad structure"))
  else if Constr.equal h tMeta then
    match args with
      x :: _ -> ACoq_tMeta x
    | _ -> CErrors.user_err (print_term t ++ Pp.str ("has bad structure"))
  else if Constr.equal h tSort then
    match args with
      x :: _ -> ACoq_tSort x
    | _ -> CErrors.user_err (print_term t ++ Pp.str ("has bad structure"))
  else if Constr.equal h tCast then
    match args with
      x :: y :: z :: _ -> ACoq_tCast (x, y, z)
    | _ -> CErrors.user_err (print_term t ++ Pp.str ("has bad structure"))
  else if Constr.equal h tProd then
    match args with
      n :: t :: b :: _ -> ACoq_tProd (n,t,b)
    | _ -> CErrors.user_err (print_term t ++ Pp.str ("has bad structure"))
  else if Constr.equal h tLambda then
    match args with
      n  :: t :: b :: _ -> ACoq_tLambda (n,t,b)
    | _ -> CErrors.user_err (print_term t ++ Pp.str ("has bad structure"))
  else if Constr.equal h tLetIn then
    match args with
      n :: e :: t :: b :: _ -> ACoq_tLetIn (n,e,t,b)
    | _ -> CErrors.user_err (print_term t ++ Pp.str ("has bad structure"))
  else if Constr.equal h tApp then
    match args with
      f::xs::_ -> ACoq_tApp (f, unquote_list xs)
    | _ -> CErrors.user_err (print_term t ++ Pp.str ("has bad structure"))
  else if Constr.equal h tConst then
    match args with
      s::u::_ -> ACoq_tConst (s, u)
    | _ -> CErrors.user_err (print_term t ++ Pp.str ("has bad structure"))
  else if Constr.equal h tInd then
    match args with
      i::u::_ -> ACoq_tInd (i,u)
    | _ -> CErrors.user_err (print_term t ++ Pp.str ("has bad structure"))
  else if Constr.equal h tConstructor then
    match args with
      i::idx::u::_ -> ACoq_tConstruct (i,idx,u)
    | _ -> CErrors.user_err (print_term t ++ Pp.str ("has bad structure: constructor case"))
  else if Constr.equal h tCase then
    match args with
      info::ty::d::brs::_ -> ACoq_tCase (unquote_pair info, ty, d, List.map unquote_pair (unquote_list brs))
    | _ -> CErrors.user_err (print_term t ++ Pp.str ("has bad structure"))
  else if Constr.equal h tFix then
    match args with
      bds::i::_ ->
      let unquoteFbd  b  =
        let (_,args) = app_full b [] in
        match args with
        | _(*type*) :: na :: ty :: body :: rarg :: [] ->
           { adtype = ty;
             adname = na;
             adbody = body;
             rarg
           }
        |_ -> raise (Failure " (mkdef must take exactly 5 arguments)")
      in
      let lbd = List.map unquoteFbd (unquote_list bds) in
      ACoq_tFix (lbd, i)
    | _ -> CErrors.user_err (print_term t ++ Pp.str ("has bad structure"))
  else if Constr.equal h tCoFix then
    match args with
      bds::i::_ ->
      let unquoteFbd  b  =
        let (_,args) = app_full b [] in
        match args with
        | _(*type*) :: na :: ty :: body :: rarg :: [] ->
           { adtype = ty;
             adname = na;
             adbody = body;
             rarg
           }
        |_ -> raise (Failure " (mkdef must take exactly 5 arguments)")
      in
      let lbd = List.map unquoteFbd (unquote_list bds) in
      ACoq_tCoFix (lbd, i)
    | _ -> CErrors.user_err (print_term t ++ Pp.str ("has bad structure"))
  else if Constr.equal h tProj then
    match args with
      proj::t::_ -> ACoq_tProj (proj, t)
    | _ -> CErrors.user_err (print_term t ++ Pp.str ("has bad structure"))

  else
    CErrors.user_err (str"inspect_term: cannot recognize " ++ print_term t ++ str" (maybe you forgot to reduce it?)")

(* Unquote Coq nat to OCaml int *)
let rec unquote_nat trm =
  let (h,args) = app_full trm [] in
  if Constr.equal h tO then
    0
  else if Constr.equal h tS then
    match args with
      n :: [] -> 1 + unquote_nat n
    | _ -> bad_term_verb trm "unquote_nat"
  else
    not_supported_verb trm "unquote_nat"

let unquote_bool trm =
  if Constr.equal trm ttrue then
    true
  else if Constr.equal trm tfalse then
    false
  else not_supported_verb trm "from_bool"

let unquote_char trm =
  let (h,args) = app_full trm [] in
  if Constr.equal h tAscii then
    match args with
      a :: b :: c :: d :: e :: f :: g :: h :: [] ->
      let bits = List.rev [a;b;c;d;e;f;g;h] in
      let v = List.fold_left (fun a n -> (a lsl 1) lor if unquote_bool n then 1 else 0) 0 bits in
      char_of_int v
    | _ -> bad_term_verb trm "unquote_char"
  else
    not_supported trm

let unquote_string trm =
  let rec go n trm =
    let (h,args) = app_full trm [] in
    if Constr.equal h tEmptyString then
      Bytes.create n
    else if Constr.equal h tString then
      match args with
        c :: s :: [] ->
        let res = go (n + 1) s in
        let _ = Bytes.set res n (unquote_char c) in
        res
      | _ -> bad_term_verb trm "unquote_string"
    else
      not_supported_verb trm "unquote_string"
  in
  Bytes.to_string (go 0 trm)

let unquote_ident trm =
  Id.of_string (unquote_string trm)

let unquote_cast_kind trm =
  if Constr.equal trm kVmCast then
    Constr.VMcast
  else if Constr.equal trm kCast then
    Constr.DEFAULTcast
  else if Constr.equal trm kRevertCast then
    Constr.REVERTcast
  else if Constr.equal trm kNative then
    Constr.VMcast
  else
    not_supported_verb trm "unquote_cast_kind"


let unquote_name trm =
  let (h,args) = app_full trm [] in
  if Constr.equal h nAnon then
    Names.Anonymous
  else if Constr.equal h nNamed then
    match args with
      n :: [] -> Names.Name (unquote_ident n)
    | _ -> bad_term_verb trm "unquote_name"
  else
    not_supported_verb trm "unquote_name"


(* If strict unquote universe mode is on then fail when unquoting a non *)
(* declared universe / an empty list of level expressions. *)
(* Otherwise, add it / a fresh level the global environnment. *)

let strict_unquote_universe_mode = ref true

let _ =
  let open Goptions in
  declare_bool_option
    { optdepr  = false;
      optname  = "strict unquote universe mode";
      optkey   = ["Strict"; "Unquote"; "Universe"; "Mode"];
      optread  = (fun () -> !strict_unquote_universe_mode);
      optwrite = (fun b -> strict_unquote_universe_mode := b) }

let map_evm (f : 'a -> 'b -> 'a * 'c) (evm : 'a) (l : 'b list) : 'a * ('c list) =
  let evm, res = List.fold_left (fun (evm, l) b -> let evm, c = f evm b in evm, c :: l) (evm, []) l in
  evm, List.rev res



let get_level evm s =
  if CString.string_contains ~where:s ~what:"." then
    match List.rev (CString.split '.' s) with
    | [] -> CErrors.anomaly (str"Invalid universe name " ++ str s ++ str".")
    | n :: dp ->
       let num = int_of_string n in
       let dp = DirPath.make (List.map Id.of_string dp) in
       let l = Univ.Level.make dp num in
       try
         let evm = Evd.add_global_univ evm l in
         if !strict_unquote_universe_mode then
           CErrors.user_err ~hdr:"unquote_level" (str ("Level "^s^" is not a declared level and you are in Strict Unquote Universe Mode."))
         else (Feedback.msg_info (str"Fresh universe " ++ Level.pr l ++ str" was added to the context.");
               evm, l)
       with
       | UGraph.AlreadyDeclared -> evm, l
  else
    try
      evm, Evd.universe_of_name evm (Id.of_string s)
    with Not_found ->
         try
           let univ, k = Nametab.locate_universe (Libnames.qualid_of_string s) in
           evm, Univ.Level.make univ k
         with Not_found ->
           CErrors.user_err ~hdr:"unquote_level" (str ("Level "^s^" is not a declared level."))





let unquote_level evm trm (* of type level *) : Evd.evar_map * Univ.Level.t =
  let (h,args) = app_full trm [] in
  if Constr.equal h lProp then
    match args with
    | [] -> evm, Univ.Level.prop
    | _ -> bad_term_verb trm "unquote_level"
  else if Constr.equal h lSet then
    match args with
    | [] -> evm, Univ.Level.set
    | _ -> bad_term_verb trm "unquote_level"
  else if Constr.equal h tLevel then
    match args with
    | s :: [] -> debug (fun () -> str "Unquoting level " ++ pr_constr trm);
                 get_level evm (unquote_string s)
    | _ -> bad_term_verb trm "unquote_level"
  else if Constr.equal h tLevelVar then
    match args with
    | l :: [] -> evm, Univ.Level.var (unquote_nat l)
    | _ -> bad_term_verb trm "unquote_level"
  else
    not_supported_verb trm "unquote_level"

let unquote_level_expr evm trm (* of type level *) b (* of type bool *) : Evd.evar_map * Univ.Universe.t =
  let evm, l = unquote_level evm trm in
  let u = Univ.Universe.make l in
  evm, if unquote_bool b then Univ.Universe.super u else u


let unquote_universe evm trm (* of type universe *) =
  let levels = List.map unquote_pair (unquote_list trm) in
  match levels with
  | [] -> if !strict_unquote_universe_mode then
            CErrors.user_err ~hdr:"unquote_universe" (str "It is not possible to unquote an empty universe in Strict Unquote Universe Mode.")
          else
            let evm, u = Evd.new_univ_variable (Evd.UnivFlexible false) evm in
            Feedback.msg_info (str"Fresh universe " ++ Universe.pr u ++ str" was added to the context.");
            evm, u
  | (l,b)::q -> List.fold_left (fun (evm,u) (l,b) -> let evm, u' = unquote_level_expr evm l b
                                                     in evm, Univ.Universe.sup u u')
                               (unquote_level_expr evm l b) q

let unquote_universe_instance evm trm (* of type universe_instance *) =
  let l = unquote_list trm in
  let evm, l = map_evm unquote_level evm l in
  evm, Univ.Instance.of_array (Array.of_list l)



let unquote_kn (k : quoted_kernel_name) : Libnames.qualid =
  Libnames.qualid_of_string (clean_name (unquote_string k))

let unquote_proj (qp : quoted_proj) : (quoted_inductive * quoted_int * quoted_int) =
  let (h,args) = app_full qp [] in
  match args with
  | tyin::tynat::indpars::idx::[] ->
     let (h',args') = app_full indpars [] in
     (match args' with
      | tyind :: tynat :: ind :: n :: [] -> (ind, n, idx)
      | _ -> bad_term_verb qp "unquote_proj")
  | _ -> bad_term_verb qp "unquote_proj"

let unquote_inductive trm =
  let (h,args) = app_full trm [] in
  if Constr.equal h tmkInd then
    match args with
      nm :: num :: _ ->
      let s = (unquote_string nm) in
      let (dp, nm) = split_name s in
      (try
         match Nametab.locate (Libnames.make_qualid dp nm) with
         | Globnames.ConstRef c ->  CErrors.user_err (str "this not an inductive constant. use tConst instead of tInd : " ++ str s)
         | Globnames.IndRef i -> (fst i, unquote_nat  num)
         | Globnames.VarRef _ -> CErrors.user_err (str "the constant is a variable. use tVar : " ++ str s)
         | Globnames.ConstructRef _ -> CErrors.user_err (str "the constant is a consructor. use tConstructor : " ++ str s)
       with
         Not_found ->   CErrors.user_err (str "Constant not found : " ++ str s))
    | _ -> assert false
  else
    bad_term_verb trm "non-constructor"



(* TODO: replace app_full by this abstract version?*)
let rec app_full_abs (trm: Constr.t) (acc: Constr.t list) =
  match inspect_term trm with
    ACoq_tApp (f, xs) -> app_full_abs f (xs @ acc)
  | _ -> (trm, acc)


let denote_term evm (trm: Constr.t) : Evd.evar_map * Constr.t =
  let rec aux evm (trm: Constr.t) : _ * Constr.t =
    debug (fun () -> Pp.(str "denote_term" ++ spc () ++ pr_constr trm)) ;
    match inspect_term trm with
    | ACoq_tRel x -> evm, Constr.mkRel (unquote_nat x + 1)
    | ACoq_tVar x -> evm, Constr.mkVar (unquote_ident x)
    | ACoq_tSort x -> let evm, u = unquote_universe evm x in evm, Constr.mkType u
    | ACoq_tCast (t,c,ty) -> let evm, t = aux evm t in
                             let evm, ty = aux evm ty in
                             evm, Constr.mkCast (t, unquote_cast_kind c, ty)
    | ACoq_tProd (n,t,b) -> let evm, t = aux evm t in
                            let evm, b = aux evm b in
                            evm, Constr.mkProd (unquote_name n, t, b)
    | ACoq_tLambda (n,t,b) -> let evm, t = aux evm t in
                              let evm, b = aux evm b in
                              evm, Constr.mkLambda (unquote_name n, t, b)
    | ACoq_tLetIn (n,e,t,b) -> let evm, e = aux evm e in
                               let evm, t = aux evm t in
                               let evm, b = aux evm b in
                               evm, Constr.mkLetIn (unquote_name n, e, t, b)
    | ACoq_tApp (f,xs) -> let evm, f = aux evm f in
                          let evm, xs = map_evm aux evm xs in
                          evm, Constr.mkApp (f, Array.of_list xs)
    | ACoq_tConst (s,u) ->
       let s = unquote_kn s in
       let evm, u = unquote_universe_instance evm u in
       (try
          match Nametab.locate s with
          | Globnames.ConstRef c -> evm, Constr.mkConstU (c, u)
          | Globnames.IndRef _ -> CErrors.user_err (str"The constant " ++ Libnames.pr_qualid s ++ str" is an inductive, use tInd.")
          | Globnames.VarRef _ -> CErrors.user_err (str"The constant " ++ Libnames.pr_qualid s ++ str" is a variable, use tVar.")
          | Globnames.ConstructRef _ -> CErrors.user_err (str"The constant " ++ Libnames.pr_qualid s ++ str" is a constructor, use tConstructor.")
        with
          Not_found -> CErrors.user_err (str"Constant not found: " ++ Libnames.pr_qualid s))
    | ACoq_tConstruct (i,idx,u) ->
       let ind = unquote_inductive i in
       let evm, u = unquote_universe_instance evm u in
       evm, Constr.mkConstructU ((ind, unquote_nat idx + 1), u)
    | ACoq_tInd (i, u) ->
       let i = unquote_inductive i in
       let evm, u = unquote_universe_instance evm u in
       evm, Constr.mkIndU (i, u)
    | ACoq_tCase ((i, _), ty, d, brs) ->
       let ind = unquote_inductive i in
       let evm, ty = aux evm ty in
       let evm, d = aux evm d in
       let evm, brs = map_evm aux evm (List.map snd brs) in
       (* todo: reify better case_info *)
       let ci = Inductiveops.make_case_info (Global.env ()) ind Constr.RegularStyle in
       evm, Constr.mkCase (ci, ty, d, Array.of_list brs)
    | ACoq_tFix (lbd, i) ->
       let (names,types,bodies,rargs) = (List.map (fun p->p.adname) lbd,  List.map (fun p->p.adtype) lbd, List.map (fun p->p.adbody) lbd,
                                         List.map (fun p->p.rarg) lbd) in
       let evm, types = map_evm aux evm types in
       let evm, bodies = map_evm aux evm bodies in
       let (names,rargs) = (List.map unquote_name names, List.map unquote_nat rargs) in
       let la = Array.of_list in
       evm, Constr.mkFix ((la rargs,unquote_nat i), (la names, la types, la bodies))
    | ACoq_tCoFix (lbd, i) ->
       let (names,types,bodies,rargs) = (List.map (fun p->p.adname) lbd,  List.map (fun p->p.adtype) lbd, List.map (fun p->p.adbody) lbd,
                                         List.map (fun p->p.rarg) lbd) in
       let evm, types = map_evm aux evm types in
       let evm, bodies = map_evm aux evm bodies in
       let (names,rargs) = (List.map unquote_name names, List.map unquote_nat rargs) in
       let la = Array.of_list in
       evm, Constr.mkCoFix (unquote_nat i, (la names, la types, la bodies))
    | ACoq_tProj (proj,t) ->
       let (ind, _, narg) = unquote_proj proj in (* todo: is narg the correct projection? *)
       let ind' = unquote_inductive ind in
       let projs = Recordops.lookup_projections ind' in
       let evm, t = aux evm t in
       (match List.nth projs (unquote_nat narg) with
        | Some p -> evm, Constr.mkProj (Names.Projection.make p false, t)
        | None -> bad_term trm)
    | _ ->  not_supported_verb trm "big_case"
  in aux evm trm
