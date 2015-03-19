Require Import floyd.proofauto.
Require Import sha.sha.
Require Import sha.SHA256.
Require Import sha.spec_sha.
Require Import sha.sha_lemmas.
Require Import sha.verif_sha_update2.
Require Import sha.verif_sha_update3.
Local Open Scope nat.
Local Open Scope logic.


Lemma Hblocks_lem:
 forall {blocks: list int} {frag: list Z} {data},
 intlist_to_Zlist blocks = frag ++ firstn (length blocks * 4 - length frag) data ->
 length frag <= length blocks * 4.
Proof.
intros.
assert (length (intlist_to_Zlist blocks) = 
               length ( frag ++
     firstn (length blocks * 4 - length frag) data)) by congruence.
 rewrite length_intlist_to_Zlist, app_length in H0.
 rewrite mult_comm; omega.
Qed.

Lemma intro_update_inv:
 forall (len: nat) (blocks : list int) (frag data: list Z) (P' Q: Prop),
  (forall (Hblocks_len: len >= length blocks * 4 - length frag)
            (Hdiv: (LBLOCKz | Zlength blocks))
            (Hblocks: intlist_to_Zlist blocks = frag ++ firstn (length blocks * 4 - length frag) data)
            (DONE: P')
            (Hblocks': length blocks * 4 >= length frag),
            Q) ->
    (len >= length blocks*4 - length frag /\
    (LBLOCKz | Zlength blocks) /\ 
    intlist_to_Zlist blocks = frag ++ firstn (length blocks * 4 - length frag) data /\
              P' -> Q). 
Proof.
intros.
 destruct H0 as  [Hblocks_len [Hdiv [Hblocks DONE]]].
 apply H; clear H; auto.
 apply Hblocks_lem in Hblocks; auto.
Qed.

Definition sha_update_loop_body :=
  (Ssequence
     (Scall None
        (Evar _sha256_block_data_order
           (Tfunction
              (Tcons (tptr t_struct_SHA256state_st) (Tcons (tptr tvoid) Tnil))
              tvoid cc_default))
        [Etempvar _c (tptr t_struct_SHA256state_st);
        Etempvar _data (tptr tuchar)])
     (Ssequence
        (Sset _data
           (Ebinop Oadd (Etempvar _data (tptr tuchar))
              (Ebinop Omul (Econst_int (Int.repr 16) tint)
                 (Econst_int (Int.repr 4) tint) tint) (tptr tuchar)))
        (Sset _len
           (Ebinop Osub (Etempvar _len tuint)
              (Ebinop Omul (Econst_int (Int.repr 16) tint)
                 (Econst_int (Int.repr 4) tint) tint) tuint)))).

Lemma update_loop_body_proof:
 forall (Espec : OracleKind) (sh: share) (hashed : list int) (frag data : list Z) (c d : val)
  (len : nat) kv (r_h : list int)
   (Delta : tycontext) (blocks bl : list int)
 (HDelta: Delta = initialized _p (initialized _n (initialized _data
                     (func_tycontext f_SHA256_Update Vprog Gtot))))
 (H: len <= length data)
 (Hdiv: (LBLOCKz | Zlength blocks))
 (H0: r_h = hash_blocks init_registers hashed)
 (H4: (LBLOCKz | Zlength hashed))
 (Hblocks: intlist_to_Zlist blocks =  frag ++ firstn (length blocks * 4 - length frag) data)
 (H3 : (Zlength frag < CBLOCKz)%Z)
 (Hlen: (Z.of_nat len <= Int.max_unsigned)%Z)
 (Hlen_ge: len - (length blocks * 4 - length frag) >= CBLOCK)
 (H6: firstn CBLOCK (skipn (length blocks * 4 - length frag) data) =
     intlist_to_Zlist bl)
 (H7: Zlength bl = LBLOCKz)
 (LEN64: (bitlength hashed frag  + Z.of_nat len * 8 < two_p 64)%Z),
 semax Delta
  (PROP  ()
   LOCAL 
   (`(typed_true tint)
      (eval_expr
         (Ebinop Oge (Etempvar _len tuint)
            (Ebinop Omul (Econst_int (Int.repr 16) tint)
               (Econst_int (Int.repr 4) tint) tint) tint));
    temp _p (field_address t_struct_SHA256state_st [StructField _data] c);
    temp _c c;
    temp _data (offset_val (Int.repr (Z.of_nat (length blocks * 4 - length frag))) d);
    temp _len (Vint
          (Int.repr (Z.of_nat (len - (length blocks * 4 - length frag)))));
    gvar _K256 kv)
   SEP 
   (`(K_vector kv);
    `(data_at Tsh t_struct_SHA256state_st
                 (map Vint (hash_blocks init_registers (hashed++blocks)),
                  (Vint (lo_part (bitlength hashed frag + (Z.of_nat len)*8)),
                   (Vint (hi_part (bitlength hashed frag + (Z.of_nat len)*8)),
                    (nil, Vundef))))
               c);
   `(data_block sh data d)))
   sha_update_loop_body
  (loop1_ret_assert
     (sha_update_inv sh hashed len c d frag data kv false)
     (normal_ret_assert
        (sha_update_inv sh hashed len c d frag data kv true))).
Proof.
intros.
name c' _c.
name data_ _data_.
name len' _len.
name data' _data.
name p _p.
name n _n.
unfold sha_update_loop_body.
subst Delta; abbreviate_semax.
 rewrite (split3_data_block (length blocks * 4 - length frag) CBLOCK sh data)
 by (clear - H Hlen_ge; change CBLOCK with 64 in *; omega).
normalize.
 rewrite Zlength_correct in H3; change CBLOCKz with (Z.of_nat CBLOCK) in H3;
  apply Nat2Z.inj_lt in H3.
 rewrite H6.
rename H2 into H98; rename H4 into H99.
assert_PROP (
  (Z.of_nat (len - (length blocks * 4 - length frag))) >= 16*4)%Z. {
 entailer!.
 normalize in H4.
 rewrite negb_true_iff in H4.
 apply ltu_repr_false in H4; try repable_signed.
 split; try repable_signed.
 clear - Hlen.
 assert (Z.of_nat (len - (length blocks * 4 - length frag)) <= Z.of_nat len)%Z; [ | omega].
 rewrite <- Nat2Z.inj_le; omega.
} drop_LOCAL 0.

forward_call' (* sha256_block_data_order (c,data); *)
 (hashed++ blocks,  bl, c, 
  offset_val (Int.repr (Z.of_nat (length blocks * 4 - length frag))) d,
  sh, kv).
 unfold_data_at 1.
entailer!.
split; auto.
apply divide_length_app; auto.
 simpl map.

 forward data_old. (* data += SHA_CBLOCK; *)
 forward len_old. (* len  -= SHA_CBLOCK; *)
 unfold loop1_ret_assert.
 unfold sha_update_inv.
 apply exp_right with (blocks++ bl).
 entailer.
 clear TC1 TC.
 assert (Hblocks' := Hblocks_lem Hblocks).
 unfold_data_at 1.
 apply andp_right; [ apply prop_right; repeat split | cancel].
*
 rewrite app_length.
 rewrite  mult_plus_distr_r. 
 rewrite plus_comm.
 rewrite <- NPeano.Nat.add_sub_assoc by (clear - Hblocks'; omega).
 apply Zlength_length in H7; auto. rewrite H7.
 clear - H2.
 rewrite Nat2Z.inj_sub_max in H2.
 rewrite Zmax_spec in H2. if_tac in H2; try omega.
 clear H.
 apply Nat2Z.inj_ge.
 rewrite Nat2Z.inj_add.
 change (Z.of_nat (Z.to_nat LBLOCKz *4)) with 64%Z. omega.
* apply divide_length_app; auto. rewrite H7. exists 1%Z; reflexivity.
*
 rewrite intlist_to_Zlist_app.
 rewrite Hblocks; rewrite <- H6.
 rewrite app_ass.
 f_equal. rewrite app_length. apply Zlength_length in H7; auto.
  rewrite H7.
  rewrite  mult_plus_distr_r. change (LBLOCK*4)%nat with CBLOCK.
 rewrite NPeano.Nat.add_sub_swap by auto.
 apply firstn_app.
*
 destruct d; inv Pd; simpl. f_equal.
  f_equal.
 rewrite app_length.
 apply Zlength_length in H7; auto.
 rewrite H7.
 f_equal.
 rewrite  mult_plus_distr_r.
 change (LBLOCK*4)%nat with CBLOCK.
rewrite NPeano.Nat.add_sub_swap by auto.
 rewrite Nat2Z.inj_add.
 reflexivity.
*
 f_equal.
 rewrite app_length. rewrite mult_plus_distr_r. 
 apply Zlength_length in H7; auto. rewrite H7.
 clear - Hblocks' H2 Hlen_ge Hlen . rename H2 into H0.
 change (Z.to_nat LBLOCKz * 4)%nat with (Z.to_nat 64).
 assert (length blocks * 4 - length frag + 64 <= len).
  { 
   change (16*4)%Z with (Z.of_nat 64) in H0.
   apply Nat2Z.inj_ge in H0. clear - H0; omega.
 }
 change (Z.to_nat 64) with 64.
 rewrite <- (Nat2Z.inj_sub _ 64) by omega.
 rewrite Nat2Z.inj_sub by omega. 
 rewrite <- NPeano.Nat.sub_add_distr by auto.
 rewrite (Nat2Z.inj_sub len) by omega.
 rewrite NPeano.Nat.add_sub_swap by auto.
 reflexivity.
*
 rewrite app_ass.
 rewrite (split3_data_block (length blocks * 4 - length frag) CBLOCK sh data)
  by omega.
 rewrite H6.
 normalize.
 cancel.
Qed.

Definition update_outer_if :=
     Sifthenelse
        (Ebinop One (Etempvar _n tuint) (Econst_int (Int.repr 0) tint) tint)
        (Ssequence
           (Sset _fragment
              (Ebinop Osub
                 (Ebinop Omul (Econst_int (Int.repr 16) tint)
                    (Econst_int (Int.repr 4) tint) tint) (Etempvar _n tuint)
                 tuint)) update_inner_if)
        Sskip.

Lemma update_outer_if_proof:
 forall  (Espec : OracleKind) (hashed : list int) 
           (dd data : list Z) (c d : val) (sh : share) (len : nat) kv
   (H : len <= length data)
   (HBOUND : (bitlength hashed dd + Z.of_nat len * 8 < two_p 64)%Z)
   (c' : name _c)
   (data_ : name _data_)
   (len' : name _len)
   (data' : name _data)
   (p : name _p)
   (n : name _n)
   (fragment : name _fragment)
   (H3 : (Zlength dd < CBLOCKz)%Z)
   (H3' : Forall isbyteZ dd) 
   (H4 : (LBLOCKz | Zlength hashed))
   (Hlen : (Z.of_nat len <= Int.max_unsigned)%Z),
semax
  (initialized _p
     (initialized _n
        (initialized _data (func_tycontext f_SHA256_Update Vprog Gtot))))
  (PROP  ()
   LOCAL 
   (temp _p (deref_noload (tarray tuchar 64)
           (field_address t_struct_SHA256state_st [StructField _data]  (force_ptr c)));
    temp _n (Vint (Int.repr (Zlength dd)));
    temp _data d; temp _c c; temp _data_ d;
    temp _len (Vint (Int.repr (Z.of_nat len)));
    gvar _K256 kv)
   SEP  (`(data_at Tsh t_struct_SHA256state_st
                 (map Vint (hash_blocks init_registers hashed),
                  (Vint (lo_part (bitlength hashed dd + (Z.of_nat len)*8)),
                   (Vint (hi_part (bitlength hashed dd + (Z.of_nat len)*8)),
                    (map Vint (map Int.repr dd), 
                     Vint (Int.repr (Zlength dd))))))
               c);
   `(K_vector kv);
   `(data_block sh data d))) update_outer_if
  (overridePost (sha_update_inv sh hashed len c d dd data kv false)
     (function_body_ret_assert tvoid
        (EX  a' : s256abs,
         PROP  (update_abs (firstn len data) (S256abs hashed dd) a')
         LOCAL ()
         SEP  (`(K_vector kv);
                `(sha256state_ a' c); `(data_block sh data d))))).
Proof.
intros.
unfold update_outer_if.
simplify_Delta; abbreviate_semax.
unfold POSTCONDITION, abbreviate; clear POSTCONDITION.
forward_if (sha_update_inv sh hashed len c d dd data kv false).
* (* then clause *)
forward.  (* fragment = SHA_CBLOCK-n; *)
rewrite semax_seq_skip.

apply semax_pre with (inv_at_inner_if sh hashed len c d dd data kv).
unfold inv_at_inner_if; entailer!.
apply semax_seq with (sha_update_inv sh hashed len c d dd data kv false).
replace Delta with Delta_update_inner_if
 by (unfold Delta_update_inner_if; simplify_Delta; reflexivity).
unfold POSTCONDITION, abbreviate; clear POSTCONDITION Delta.
autorewrite with norm.
simple apply (update_inner_if_proof Espec hashed dd data c d sh len kv);
  try assumption.
forward. 
apply andp_left2; auto.
* (* else clause *)
forward.  (* skip; *)
apply exp_right with nil. rewrite <- app_nil_end.
entailer.
assert (Int.unsigned (Int.repr (Zlength dd)) = Int.unsigned (Int.repr 0)) by (f_equal; auto).
rewrite (Int.unsigned_repr 0) in H6 by repable_signed.
rewrite Int.unsigned_repr in H6
 by (clear - H3; change CBLOCKz with 64%Z in H3;
  rewrite Zlength_correct in *; repable_signed).
 rewrite Zlength_correct in H6;  destruct dd; inv H6; auto.
 entailer!.
 exists 0%Z; auto.
 rewrite NPeano.Nat.sub_0_r; auto.
 rewrite <- app_nil_end.
 unfold_data_at 1.
 unfold_data_at 1.
 cancel.
Qed.

Lemma update_while_proof:
 forall (Espec : OracleKind) (hashed : list int) (dd data: list Z) kv
    (c d : val) (sh : share) (len : nat) 
  (H : len <= length data)
  (HBOUND : (bitlength hashed dd + Z.of_nat len * 8 < two_p 64)%Z)
  (c' : name _c) (data_ : name _data_) (len' : name _len)  
  (data' : name _data) (p : name _p) (n : name _n)  (fragment : name _fragment)
  (H3 : (Zlength dd < CBLOCKz)%Z)
  (H3' : Forall isbyteZ dd) 
  (H4 : (LBLOCKz | Zlength hashed)) 
  (Hlen : (Z.of_nat len <= Int.max_unsigned)%Z),
 semax
  (update_tycon
     (initialized _p
        (initialized _n
           (initialized _data (func_tycontext f_SHA256_Update Vprog Gtot))))
     update_outer_if) (sha_update_inv sh hashed len c d dd data kv false)
  (Swhile
     (Ebinop Oge (Etempvar _len tuint)
        (Ebinop Omul (Econst_int (Int.repr 16) tint)
           (Econst_int (Int.repr 4) tint) tint) tint) sha_update_loop_body)
  (normal_ret_assert (sha_update_inv sh hashed len c d dd data kv true)).
Proof.
intros.
simplify_Delta; abbreviate_semax.
unfold POSTCONDITION, abbreviate; clear POSTCONDITION.
apply semax_while.
+ reflexivity.
+ entailer!.
+ rewrite normal_ret_assert_elim.
  unfold sha_update_inv.
  normalize.
  rewrite andp_assoc; do 2 rewrite insert_local.
  apply exp_right with blocks.
  entailer.

  rename H5 into Hblocks;  assert (Hblocks' := Hblocks_lem Hblocks).
  apply prop_right.
  change (Int.mul (Int.repr 16) (Int.repr 4)) with (Int.repr 64) in H6;
  rewrite negb_false_iff in H6;
  apply Int.ltu_inv in H6.  
  rewrite Int.unsigned_repr in H6.
  destruct H6 as [_ H6].
  apply Nat2Z.inj_lt;  apply H6.
  split; [ clear; omega | ].
  rewrite Nat2Z.inj_sub by auto.
 omega.
+ unfold LOOP_BODY, abbreviate; clear LOOP_BODY.
  unfold sha_update_inv at 1.
  normalize.
  apply extract_exists_pre; intro blocks.
  rewrite insert_local.
  apply semax_extract_PROP; apply intro_update_inv; intros.
 apply (assert_PROP (Forall isbyteZ data /\ len - (length blocks*4 - length dd) >= CBLOCK));
  [ | intros [BYTESdata Hlen_ge]]. {
  rewrite (data_block_isbyteZ sh data d).
  entailer!. rename H2 into H2'.
  rewrite negb_true_iff in H1;
   unfold Int.ltu in H1;
  if_tac in H1; inv H1.
  rewrite Int.unsigned_repr in H2;
  change (Int.unsigned (Int.mul (Int.repr 16) (Int.repr 4)))
    with (Z.of_nat CBLOCK) in H2.
  apply Nat2Z.inj_ge.
 apply H2.
  split; [clear; omega | ].
  rewrite Nat2Z.inj_sub by auto.
  omega.
}
pose (bl := Zlist_to_intlist (firstn CBLOCK (skipn (length blocks * 4 - length dd) data) )).
assert (H97: CBLOCK <= length (skipn (length blocks * 4 - length dd) data)). {
rewrite skipn_length.
change (4*LBLOCK)%nat with CBLOCK.
clear - Hlen_ge Hblocks' H Hblocks_len; omega.
}
assert (H1: length bl = LBLOCK). {
unfold bl.
apply length_Zlist_to_intlist.
assert (H98: length data >= length blocks * 4 - length dd)
 by (clear - H Hblocks' Hblocks_len; omega).
rewrite firstn_length.
apply min_l; auto.
}
assert (H0:  firstn CBLOCK (skipn (length blocks * 4 - length dd) data) =
      intlist_to_Zlist bl). {
unfold bl; rewrite Zlist_to_intlist_to_Zlist; auto.
rewrite firstn_length.
rewrite min_l by auto.
exists LBLOCK; reflexivity.
apply Forall_firstn.
apply Forall_skipn; auto.
}
clearbody bl; clear H97.
 simple apply (update_loop_body_proof Espec sh hashed dd data c d len kv (hash_blocks init_registers hashed) Delta blocks bl); 
   try assumption.
simplify_Delta; reflexivity.
reflexivity.
apply Zlength_length; auto.
Qed.
