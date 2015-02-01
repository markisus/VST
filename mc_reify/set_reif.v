Require Import floyd.proofauto.
Require Import mc_reify.funcs.
Require Import mc_reify.types.
Require Import mc_reify.bool_funcs.
Require Import MirrorCore.Lambda.ExprCore.
Require Import mc_reify.get_set_reif.
Require Import mc_reify.func_defs.

Definition as_option e :
option ((typ * expr typ func)  + typ):=
match e with 
| (App (Inj (inr (Other (fsome t)))) e) => Some (inl (t, e))
| (Inj (inr (Other (fnone t)))) => Some (inr t)
| _ => None
end.


Inductive val_e :=
    Vundef : val_e
  | Vint : int -> val_e
  | Vlong : int64 -> val_e
  | Vfloat : float -> val_e
  | Vsingle : float32 -> val_e
  | Vexpr : expr typ func -> val_e
  | Vunop : Cop.unary_operation -> type ->  val_e -> val_e
  | Vbinop : Cop.binary_operation -> type -> type -> val_e -> val_e -> val_e
  | Veval_cast : type -> type -> val_e -> val_e
  | Vforce_ptr : val_e -> val_e
  | Veval_field : type -> ident -> val_e -> val_e
  | Vfail : val_e.

Definition Vderef_noload (t: type) (e: val_e) : val_e :=
  match access_mode t with
  | By_reference => e
  | _ => Vundef
  end.


Definition val_e_binarith op ty1 ty2 e1 e2 :=
  match op, ty1, ty2, e1, e2 with
  | Oand, Tint _ _ _, Tint _ _ _,
    App (Inj (inr (Value fVint))) e1',
    App (Inj (inr (Value fVint))) e2' =>
      match e1', e2' with
      | App (Inj (inr (Intop fint_repr))) e1'',
        App (Inj (inr (Intop fint_repr))) e2'' =>
                appR (Value fVint) (appR (Intop fint_repr) (App (appR (Zop fZ_land) e1'') e2''))
      | _, _ => appR (Value fVint) (App (appR (Intop fint_and) e1') e2')
      end
  | Oadd, Tint _ _ _, Tint _ _ _,
    App (Inj (inr (Value fVint))) e1',
    App (Inj (inr (Value fVint))) e2' =>
      match e1', e2' with
      | App (Inj (inr (Intop fint_repr))) e1'',
        App (Inj (inr (Intop fint_repr))) e2'' =>
                appR (Value fVint) (appR (Intop fint_repr) (App (appR (Zop fZ_add) e1'') e2''))
      | _, _ => appR (Value fVint) (App (appR (Intop fint_add) e1') e2')
      end
  | _, _, _, _, _ => App (appR (Eval_f (feval_binop op 
                                         ty1 ty2)) e1) e2
  end.

Fixpoint val_e_to_expr (v : val_e) : option (expr typ func) :=
match v with
  | Vundef => Some  (injR (Value fVundef))
  | Vlong l => Some (appR (Value fVlong) (injR (Const (fint64 l))))
  | Vint i => Some (appR (Value fVint) (injR (Const (fint i))))
  | Vfloat f => Some (appR (Value fVfloat) (injR (Const (ffloat f))))
  | Vsingle f => Some (appR (Value fVsingle) (injR (Const (ffloat32 f))))
  | Vexpr e => Some e
  | Vunop op ty e => 
    option_map (appR (Eval_f (feval_unop op ty))) (val_e_to_expr e)
  | Vbinop op ty1 ty2 e1 e2 => 
    match (val_e_to_expr e1), (val_e_to_expr e2) with
      | Some e1', Some e2' => Some (val_e_binarith op ty1 ty2 e1' e2')
      | _, _ => None
    end
  | Veval_cast ty1 ty2 v =>
    option_map (appR (Eval_f (feval_cast ty1 ty2))) (val_e_to_expr v)
  | Vforce_ptr v => 
    option_map (appR (Other (fforce_ptr))) (val_e_to_expr v)
  | Veval_field t id v => 
    option_map (appR (Eval_f (feval_field t id))) (val_e_to_expr v)
  | Vfail => None
end.

Definition msubst_var id T2 ty :=
match as_option (get_reif id T2 (typrod tyc_type tyval)) with
  | Some (inl (t, (App (App (Inj (inr (Data (fpair t1 t2))))
                  (Inj (inr (Const (fCtype ty')))))
             v))) =>
    if eqb_type ty ty'
    then Some (Vexpr v)
    else None
  | Some (inr _) => None
  | _ => Some (Vfail)
end.

Fixpoint msubst_eval_expr_reif (T1: ExprCore.expr typ func) (T2: ExprCore.expr typ func) (e: Clight.expr) : option (val_e) :=
  match e with
  | Econst_int i ty => Some (Vint i)
  | Econst_long i ty => Some (Vlong i)
  | Econst_float f ty => Some (Vfloat f)
  | Econst_single f ty => Some (Vsingle f)
  | Etempvar id ty => match as_option (get_reif id T1 tyval) with
                        | Some (inl (t, v)) => Some (Vexpr v)
                        | Some (inr t) => None
                        | None => Some (Vfail)
                      end
  | Eaddrof a ty => msubst_eval_lvalue_reif T1 T2 a  
  | Eunop op a ty =>  option_map (Vunop op (typeof a)) (msubst_eval_expr_reif T1 T2 a ) 
  | Ebinop op a1 a2 ty => match (msubst_eval_expr_reif T1 T2 a1 ), (msubst_eval_expr_reif T1 T2 a2 ) with
                            | Some v1, Some v2 => Some (Vbinop op (typeof a1) (typeof a2) v1 v2) 
                            | _, _ => None
                          end
  | Ecast a ty => option_map (Veval_cast (typeof a) ty) (msubst_eval_expr_reif T1 T2 a )
  | Evar id ty => option_map (Vderef_noload ty) (msubst_var id T2 ty )
  | Ederef a ty => option_map (Vderef_noload ty) (option_map Vforce_ptr (msubst_eval_expr_reif T1 T2 a ))
  | Efield a i ty => option_map (Vderef_noload ty) (option_map (Veval_field (typeof a) i) (msubst_eval_lvalue_reif T1 T2 a ))
  end
with
msubst_eval_lvalue_reif (T1: ExprCore.expr typ func) (T2: ExprCore.expr typ func) (e: Clight.expr)  : option val_e := 
  match e with 
  | Evar id ty => (msubst_var id T2 ty )
  | Ederef a ty => option_map Vforce_ptr (msubst_eval_expr_reif T1 T2 a )
  | Efield a i ty => option_map (Veval_field (typeof a) i) (msubst_eval_lvalue_reif T1 T2 a )
  | _  => Some Vundef
  end.
  
Definition rmsubst_eval_expr (T1: (ExprCore.expr typ func)) (T2: ExprCore.expr typ func) (e: Clight.expr) := 
match msubst_eval_expr_reif T1 T2 e with
| Some e => some_reif (val_e_to_expr e) tyval
| None => none_reif tyval
end.

Definition rmsubst_eval_lvalue (T1: (ExprCore.expr typ func)) (T2: ExprCore.expr typ func) (e: Clight.expr) := 
match msubst_eval_lvalue_reif T1 T2 e with
| Some e => some_reif (val_e_to_expr e) tyval
| None => none_reif tyval
end.

Definition rmsubst_eval_LR (T1: (ExprCore.expr typ func)) (T2: ExprCore.expr typ func) (e: Clight.expr) (lr : LLRR) := 
match lr with
| LLLL => rmsubst_eval_lvalue T1 T2 e
| RRRR => rmsubst_eval_expr T1 T2 e
end.

Fixpoint msubst_efield_denote_reif (T1: ExprCore.expr typ func) (T2: ExprCore.expr typ func) (efs : list efield) :=
  match efs with
  | nil => Some (injR (Data (fnil tygfield)))
  | cons (eStructField i) efs0 => option_map (App
                                (appR (Data (fcons tygfield))
                                      (appR (Smx fstruct_field) (injR (Const (fident i))))))
                                 (msubst_efield_denote_reif T1 T2 efs0)
  | cons (eUnionField i) efs0 => option_map (App
                                (appR (Data (fcons tygfield))
                                      (appR (Smx funion_field) (injR (Const (fident i))))))
                                 (msubst_efield_denote_reif T1 T2 efs0)
  | cons (eArraySubsc ei) efs0 =>
      match typeof ei, rmsubst_eval_expr T1 T2 ei with
      | Tint _ _ _,
        App (Inj (inr (Other (fsome _))))
         (App (Inj (inr (Value fVint))) i) =>
                             option_map (App
                                (appR (Data (fcons tygfield))
                                      (appR (Smx farray_subsc) (appR (Intop fint_unsigned) i))))
                                 (msubst_efield_denote_reif T1 T2 efs0)
      | _, _ => None
      end
  end.

Definition rmsubst_efield_denote (T1: ExprCore.expr typ func) (T2: ExprCore.expr typ func) (efs : list efield) :=
match msubst_efield_denote_reif T1 T2 efs with
| Some e => some_reif e (tylist tygfield)
| None => none_reif (tylist tygfield)
end.

Fixpoint rnth_error (ty: typ) (xs: expr typ func) (n: nat) : expr typ func :=
  match xs with
  | Inj (inr (Data (fnil _))) => none_reif ty
  | App (App (Inj (inr (Data (fcons _)))) hd) tl => 
    match n with
    | O => some_reif hd ty
    | S n0 => rnth_error ty tl n0
    end
  | _ => none_reif ty
  end.

Lemma Forall_reverse :
forall A P (l: list A),
Forall P l <->
Forall P (rev l). 
Proof.
intros.
split; intros.
 + rewrite Forall_forall in *.
   intros. destruct l.
      - apply H. auto.
      - simpl in *. apply in_app in H0.
        destruct H0. apply H; auto.
        right. apply in_rev; auto.
        apply H.  left. simpl in H0. intuition.
 + rewrite Forall_forall in *; intros.
   destruct l.
   inversion H0.
   destruct H0.
   subst.
   simpl in *. apply H. apply in_app. right. constructor. auto.
   apply H. simpl. apply in_app. left. apply in_rev in H0. auto.
Qed.

Lemma in_fst :
forall T T2 (p : T) (v: T2) l, 
In (p, v) l -> In p (map fst l).
Proof.
intros.
  + induction l. auto.
      - simpl in *. intuition.
        destruct a. left. simpl. congruence.
Qed.


Lemma elt_eq : forall T l p (v:T) v0 ls, 
(p, v0) :: l = rev (PTree.elements (PTree.set p v ls)) ->
v = v0.
Proof.
intros.
assert (In (p, v) (rev (PTree.elements (PTree.set p v ls)))).
  { rewrite <- in_rev. apply PTree.elements_correct. rewrite PTree.gss. auto. }
assert (X := PTree.elements_keys_norepet (PTree.set p v ls)).
assert (In (p, v0) (rev (PTree.elements (PTree.set p v ls)))).
  { rewrite <- list_norepet_rev in X. rewrite <- map_rev in X. unfold PTree.elt in *. 
    rewrite <- H in *. simpl in *. intuition. }
rewrite <- in_rev in H1. 
  rewrite <- list_norepet_rev in X. rewrite <- map_rev in X. unfold PTree.elt in *.
  rewrite in_rev in H1.  
    rewrite <- H in *. simpl in *. clear - X H0 H1. intuition; try congruence.
    inversion X; subst. intuition. apply in_fst in H. intuition.
    inversion X. subst. intuition. apply in_fst in H. intuition.
Qed.

Definition tempD' := (fun Q i v => `(eq v) (eval_id i) :: Q).
Definition localD' := (fun Q i tv => `(eq (snd tv)) (eval_var i (fst tv)) :: Q).
Definition LocalD_app (T1: PTree.t val) (T2: PTree.t (type * val)) (Q: list (environ -> Prop)) :=
  (PTree.fold tempD' T1 nil) ++ 
 (PTree.fold localD' T2 nil) ++ Q.


Lemma localD_app_eq : forall t2 q, PTree.fold localD' t2 q = PTree.fold localD' t2 nil ++ q.
Proof.
intros.
repeat rewrite PTree.fold_spec.
simpl in *. repeat rewrite <- fold_left_rev_right.
induction (rev (PTree.elements t2)).
  + reflexivity.
  + simpl. rewrite IHl. auto.
Qed.

Lemma tempD_app_eq : forall t2 q, PTree.fold tempD' t2 q = PTree.fold tempD' t2 nil ++ q.
intros.
repeat rewrite PTree.fold_spec.
simpl in *. repeat rewrite <- fold_left_rev_right.
induction (rev (PTree.elements t2)).
  + reflexivity.
  + simpl. rewrite IHl. auto.
Qed.

Lemma LocalD_app_eq : 
forall t1 t2 q,
LocalD t1 t2 q = LocalD_app t1 t2 q.
Proof.
intros.
unfold LocalD, LocalD_app.
simpl in *.
rewrite localD_app_eq.
rewrite tempD_app_eq. auto.
Qed.

Lemma fold_right_conj : 
forall a b rho, 
(fold_right (fun (x0 x1 : environ -> Prop) (x2 : environ) => x0 x2 /\ x1 x2) 
     (`True) (a ++ b) rho) <-> ((fold_right (fun (x0 x1 : environ -> Prop) (x2 : environ) => x0 x2 /\ x1 x2) 
     (`True) a rho /\ fold_right (fun (x0 x1 : environ -> Prop) (x2 : environ) => x0 x2 /\ x1 x2) 
     (`True) b rho)).
Proof.
intros. 
split; intros; induction a; simpl in *; intuition.
Qed.

Lemma LocalD_to_localD : forall P R t l,
PROPx (P) (LOCALx (LocalD t l []) (SEPx (R))) =
PROPx (P) (LOCALx (localD t l) (SEPx (R))).
Proof.
intros. apply pred_ext.
 entailer.
entailer.
Qed.

