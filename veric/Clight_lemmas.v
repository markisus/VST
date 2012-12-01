Load loadpath.
Require Import veric.base.
Require Import Clight.

Definition val_to_bool (v: val) : option bool :=
  match v with 
    | Vint n => Some (negb (Int.eq n Int.zero))
    | Vptr _ _ => Some true
    | _ => None
  end.

Definition bool_of_valf (v: val): option bool := 
match v with
  | Vint i => Some (negb (Int.eq i Int.zero))
  | Vfloat _ => None
  | Vptr _ _ => Some true
  | Vundef => None
end.

Definition var_name (V: Type) (bdec: ident * globvar V) : ident := 
   fst bdec.

Definition no_dups (F V: Type) (fdecs: list (ident * F)) (bdecs: list (ident * globvar V)) : Prop :=
  list_norepet (map (@fst ident F) fdecs ++ map (@var_name V) bdecs).
Implicit Arguments no_dups.

Lemma no_dups_inv:
  forall  (A V: Type) id f fdecs bdecs,
    no_dups ((id,f)::fdecs) bdecs ->
    no_dups fdecs bdecs /\
     ~ In id (map (@fst ident A) fdecs) /\
     ~ In id (map (@var_name V) bdecs).
Proof.
intros.
inversion H; clear H. subst.
repeat split.
apply H3.
intro; contradiction H2; apply in_or_app; auto.
intro; contradiction H2; apply in_or_app; auto.
Qed.
Implicit Arguments no_dups_inv.
 

Lemma of_bool_Int_eq_e:
  forall i j, Val.of_bool (Int.eq i j) = Vtrue -> i = j.
Proof.
unfold Val.of_bool.
do 2 intro.
assert (if Int.eq i j then i=j else i<>j).
apply Int.eq_spec.
caseEq (Int.eq i j); intros.
rewrite H0 in H ; trivial.
inversion H1.
Qed.

Lemma eq_block_lem: 
    forall (A: Set) a (b: A) c, (if eq_block a a then b else c) = b. 
Proof.
intros.
unfold eq_block.
rewrite zeq_true.
auto.
Qed.

Lemma nat_ind2_Type:
forall P : nat -> Type,
((forall n, (forall j:nat, (j<n )%nat -> P j) ->  P n):Type) ->
(forall n, P n).
Proof.
intros.
assert (forall j , (j <= n)%nat -> P j).
induction n.
intros.
replace j with 0%nat ; try omega.
apply X; intros.
elimtype False; omega.
intros.  apply X. intros.
apply IHn.
omega.
apply X0.
omega.
Qed.

Lemma nat_ind2:
forall P : nat -> Prop,
(forall n, (forall j:nat, (j<n )%nat -> P j) ->  P n) ->
(forall n, P n).
Proof.
intros; apply Wf_nat.lt_wf_ind. auto.
Qed.

Lemma signed_zero: Int.signed Int.zero = 0.
Proof. apply Int.signed_zero. Qed.

Lemma equiv_e1 : forall A B: Prop, A=B -> A -> B.
Proof.
intros.
rewrite <- H; auto.
Qed.
Implicit Arguments equiv_e1.

Lemma equiv_e2 : forall A B: Prop, A=B -> B -> A.
Proof.
intros.
rewrite H; auto.
Qed.
Implicit Arguments equiv_e2.

Lemma deref_loc_fun: forall {ty m b z v v'},
   Clight.deref_loc ty m b z v -> Clight.deref_loc ty m b z v' -> v=v'.
 Proof. intros.  inv H; inv H0; try congruence.
Qed.

Lemma eval_expr_lvalue_fun:
  forall ge e le m,
    (forall a v v', Clight.eval_expr ge e le m a v -> Clight.eval_expr ge e le m a v' -> v=v') /\
    (forall a b b' i i', Clight.eval_lvalue ge e le m a b i -> Clight.eval_lvalue ge e le m a b' i' ->
                               (b,i)=(b',i')).
Proof.
 intros.
 destruct (Clight.eval_expr_lvalue_ind ge e le m
   (fun a v =>  forall v', Clight.eval_expr ge e le m a v' -> v=v')
   (fun a b i => forall b' i', Clight.eval_lvalue ge e le m a b' i' -> (b,i)=(b',i'))); intros.
  inv H; auto. inv H0; auto. inv H; auto. inv H0; auto. inv H0; auto.
  congruence. inv H1; auto. inv H1; auto. apply H0 in H5. inv H5; auto.
  inv H2; auto. inv H2; auto. apply H0 in H7.  subst; congruence.
  inv H3. inv H4. apply H0 in H10. apply H2 in H11. subst; congruence.
  inv H6. inv H5. inv H5. inv H5. inv H2.
  apply H0 in H5. subst v1. congruence.

  inv H3.
  inv H; inv H2; try solve [  apply H0 in H; inv H;  eapply deref_loc_fun; eauto].
  inv H0; congruence.
  inv H2; congruence.
  inv H1. apply H0 in H6. congruence.
  inv H3. apply H0 in H7; congruence.
  apply H0 in H9; congruence.
  inv H2.
  apply H0 in H6; congruence.
  apply H0 in H8; congruence.

 split; intros; [apply (H _ _ H1 _ H2) | apply (H0 _ _ _ H1 _ _ H2)].
Qed.

Lemma eval_expr_fun:   forall {ge e le m a v v'},
    Clight.eval_expr ge e le m a v -> Clight.eval_expr ge e le m a v' -> v=v'.
Proof.
  intros. destruct (eval_expr_lvalue_fun ge e le m).
  eauto.
Qed.

Lemma eval_exprlist_fun:   forall {ge e le m a ty v v'},
    Clight.eval_exprlist ge e le m a ty v -> Clight.eval_exprlist ge e le m a ty v' -> v=v'.
Proof.
  induction a; intros; inv H; inv H0; f_equal.
  apply (eval_expr_fun H3) in H6. subst. congruence.
  eauto.
Qed.


Lemma eval_lvalue_fun:   forall {ge e le m a b b' z z'},
    Clight.eval_lvalue ge e le m a b z -> Clight.eval_lvalue ge e le m a b' z' -> (b,z)=(b',z').
Proof.
  intros. destruct (eval_expr_lvalue_fun ge e le m).
  eauto.
Qed.


Lemma inv_find_symbol_fun:
  forall {F V ge id id' b},
    @Genv.find_symbol F V ge id = Some b ->
    @Genv.find_symbol F V ge id' = Some b -> 
    id=id'.
Proof.
 intros.
 destruct (ident_eq id id'); auto.
  contradiction (Genv.global_addresses_distinct ge n H H0); auto.
Qed.

Lemma assign_loc_fun: 
  forall {ty m b ofs v m1 m2},
   assign_loc ty m b ofs v m1 ->
   assign_loc ty m b ofs v m2 ->
   m1=m2.
Proof.
 intros. inv H; inv H0; try congruence.
Qed.


Lemma alloc_variables_fun: 
  forall {e m vl e1 m1 e2 m2},
     Clight.alloc_variables e m vl e1 m1 ->
     Clight.alloc_variables e m vl e2 m2 ->
     (e1,m1)=(e2,m2).
Proof.
 intros until vl; revert e m;
 induction vl; intros; inv H; inv H0; auto.
 inversion2 H5 H9.
 eauto. 
Qed.

Lemma bind_parameters_fun:
  forall {e m p v m1 m2}, 
    Clight.bind_parameters e m p v m1 ->
    Clight.bind_parameters e m p v m2 ->
    m1=m2.
Proof.
intros until p. revert e m; induction p; intros; inv H; inv H0; auto.
 inversion2 H3 H10.
 apply (assign_loc_fun H5) in H11. inv H11. eauto.
Qed.

Lemma eventval_list_match_fun:
  forall {F V ge a a' t v}, 
    @Events.eventval_list_match F V ge a t v ->
    @Events.eventval_list_match F V ge a' t v ->
    a=a'.
Proof.
 intros.
 revert a' H0; induction H; intros.
 inv H0; eauto.
 inv H1.
 f_equal. clear - H6 H.
 inv H; inv H6; auto.
 apply (inv_find_symbol_fun H0) in H3; subst; auto.
 eauto.
Qed.

Ltac fun_tac :=
  match goal with
  | H: ?A = Some _, H': ?A = Some _ |- _ => inversion2 H H' 
  | H: Clight.eval_expr ?ge ?e ?le ?m ?A _,
    H': Clight.eval_expr ?ge ?e ?le ?m ?A _ |- _ =>
        apply (eval_expr_fun H) in H'; subst
  | H: Clight.eval_exprlist ?ge ?e ?le ?m ?A ?ty _,
    H': Clight.eval_exprlist ?ge ?e ?le ?m ?A ?ty _ |- _ =>
        apply (eval_exprlist_fun H) in H'; subst
  | H: Clight.eval_lvalue ?ge ?e ?le ?m ?A _ _,
    H': Clight.eval_lvalue ?ge ?e ?le ?m ?A _ _ |- _ =>
        apply (eval_lvalue_fun H) in H'; inv H'
  | H: Clight.assign_loc ?ge ?ty ?m ?b ?ofs ?v _ _,
    H': Clight.assign_loc ?ge ?ty ?m ?b ?ofs ?v _ _ |- _ =>
        apply (assign_loc_fun H) in H'; inv H'
  | H: Clight.deref_loc ?ge ?ty ?m ?b ?ofs ?t _,
    H': Clight.deref_loc ?ge ?ty ?m ?b ?ofs ?t _ |- _ =>
        apply (deref_loc_fun H) in H'; inv H'
  | H: Clight.alloc_variables ?e ?m ?vl _ _,
    H': Clight.alloc_variables ?e ?m ?vl _ _ |- _ =>
        apply (alloc_variables_fun H) in H'; inv H'
  | H: Clight.bind_parameters ?ge ?e ?m ?p ?vl _,
    H': Clight.bind_parameters ?ge ?e ?m ?p ?vl _ |- _ =>
        apply (bind_parameters_fun H) in H'; inv H'
  | H: Genv.find_symbol ?ge _ = Some ?b,
    H': Genv.find_symbol ?ge _ = Some ?b |- _ => 
       apply (inv_find_symbol_fun H) in H'; inv H'
  | H: Events.eventval_list_match ?ge _ ?t ?v,
    H': Events.eventval_list_match ?ge _ ?t ?v |- _ =>
       apply (eventval_list_match_fun H) in H'; inv H'
 end. 


