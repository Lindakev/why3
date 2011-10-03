(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import ZArith.
Require Import Rbase.
(*Add Rec LoadPath "/home/guillaume/bin/why3/share/why3/theories".*)
(*Add Rec LoadPath "/home/guillaume/bin/why3/share/why3/modules".*)

Definition infix_ls: R -> R -> Prop.
(* YOU MAY EDIT THE PROOF BELOW *)
exact Rlt.
Defined.
(* DO NOT EDIT BELOW *)


Definition infix_lseq(x:R) (y:R): Prop := (infix_ls x y) \/ (x = y).

Definition infix_pl: R -> R -> R.
(* YOU MAY EDIT THE PROOF BELOW *)
exact Rplus.
Defined.
(* DO NOT EDIT BELOW *)


Definition prefix_mn: R -> R.
(* YOU MAY EDIT THE PROOF BELOW *)
exact Ropp.
Defined.
(* DO NOT EDIT BELOW *)


Definition infix_as: R -> R -> R.
(* YOU MAY EDIT THE PROOF BELOW *)
exact Rmult.
Defined.
(* DO NOT EDIT BELOW *)


(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma Unit_def : forall (x:R), ((infix_pl x 0%R) = x).
(* YOU MAY EDIT THE PROOF BELOW *)
exact Rplus_0_r.
Qed.
(* DO NOT EDIT BELOW *)

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma Assoc : forall (x:R) (y:R) (z:R), ((infix_pl (infix_pl x y)
  z) = (infix_pl x (infix_pl y z))).
(* YOU MAY EDIT THE PROOF BELOW *)
exact Rplus_assoc.
Qed.
(* DO NOT EDIT BELOW *)

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma Inv_def : forall (x:R), ((infix_pl x (prefix_mn x)) = 0%R).
(* YOU MAY EDIT THE PROOF BELOW *)
exact Rplus_opp_r.
Qed.
(* DO NOT EDIT BELOW *)

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma Comm : forall (x:R) (y:R), ((infix_pl x y) = (infix_pl y x)).
(* YOU MAY EDIT THE PROOF BELOW *)
exact Rplus_comm.
Qed.
(* DO NOT EDIT BELOW *)

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma Assoc1 : forall (x:R) (y:R) (z:R), ((infix_as (infix_as x y)
  z) = (infix_as x (infix_as y z))).
(* YOU MAY EDIT THE PROOF BELOW *)
exact Rmult_assoc.
Qed.
(* DO NOT EDIT BELOW *)

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma Mul_distr : forall (x:R) (y:R) (z:R), ((infix_as x (infix_pl y
  z)) = (infix_pl (infix_as x y) (infix_as x z))).
(* YOU MAY EDIT THE PROOF BELOW *)
exact Rmult_plus_distr_l.
Qed.
(* DO NOT EDIT BELOW *)

Definition infix_mn(x:R) (y:R): R := (infix_pl x (prefix_mn y)).

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma Comm1 : forall (x:R) (y:R), ((infix_as x y) = (infix_as y x)).
(* YOU MAY EDIT THE PROOF BELOW *)
exact Rmult_comm.
Qed.
(* DO NOT EDIT BELOW *)

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma Unitary : forall (x:R), ((infix_as 1%R x) = x).
(* YOU MAY EDIT THE PROOF BELOW *)
exact Rmult_1_l.
Qed.
(* DO NOT EDIT BELOW *)

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma NonTrivialRing : ~ (0%R = 1%R).
(* YOU MAY EDIT THE PROOF BELOW *)
apply not_eq_sym.
exact R1_neq_R0.
Qed.
(* DO NOT EDIT BELOW *)

Definition inv: R -> R.
(* YOU MAY EDIT THE PROOF BELOW *)
exact Rinv.
Defined.
(* DO NOT EDIT BELOW *)


(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma Inverse : forall (x:R), (~ (x = 0%R)) -> ((infix_as x (inv x)) = 1%R).
(* YOU MAY EDIT THE PROOF BELOW *)
exact Rinv_r.
Qed.
(* DO NOT EDIT BELOW *)

Definition infix_sl(x:R) (y:R): R := (infix_as x (inv y)).

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma assoc_mul_div : forall (x:R) (y:R) (z:R), (~ (z = 0%R)) ->
  ((infix_sl (infix_as x y) z) = (infix_as x (infix_sl y z))).
(* YOU MAY EDIT THE PROOF BELOW *)
intros x y z _.
apply Rmult_assoc.
Qed.
(* DO NOT EDIT BELOW *)

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma assoc_div_mul : forall (x:R) (y:R) (z:R), ((~ (y = 0%R)) /\
  ~ (z = 0%R)) -> ((infix_sl (infix_sl x y) z) = (infix_sl x (infix_as y
  z))).
(* YOU MAY EDIT THE PROOF BELOW *)
intros x y z (Zy, Zz).
unfold infix_sl, infix_as, inv.
rewrite Rmult_assoc.
now rewrite Rinv_mult_distr.
Qed.
(* DO NOT EDIT BELOW *)

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma assoc_div_div : forall (x:R) (y:R) (z:R), ((~ (y = 0%R)) /\
  ~ (z = 0%R)) -> ((infix_sl x (infix_sl y z)) = (infix_sl (infix_as x z)
  y)).
(* YOU MAY EDIT THE PROOF BELOW *)
intros x y z (Zy, Zz).
unfold infix_sl, infix_as, inv.
field.
now split.
Qed.
(* DO NOT EDIT BELOW *)

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma Refl : forall (x:R), (infix_lseq x x).
(* YOU MAY EDIT THE PROOF BELOW *)
exact Rle_refl.
Qed.
(* DO NOT EDIT BELOW *)

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma Trans : forall (x:R) (y:R) (z:R), (infix_lseq x y) -> ((infix_lseq y
  z) -> (infix_lseq x z)).
(* YOU MAY EDIT THE PROOF BELOW *)
exact Rle_trans.
Qed.
(* DO NOT EDIT BELOW *)

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma Antisymm : forall (x:R) (y:R), (infix_lseq x y) -> ((infix_lseq y x) ->
  (x = y)).
(* YOU MAY EDIT THE PROOF BELOW *)
exact Rle_antisym.
Qed.
(* DO NOT EDIT BELOW *)

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma Total : forall (x:R) (y:R), (infix_lseq x y) \/ (infix_lseq y x).
(* YOU MAY EDIT THE PROOF BELOW *)
intros x y.
destruct (Rle_or_lt x y) as [H|H].
now left.
right.
now apply Rlt_le.
Qed.
(* DO NOT EDIT BELOW *)

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma CompatOrderAdd : forall (x:R) (y:R) (z:R), (infix_lseq x y) ->
  (infix_lseq (infix_pl x z) (infix_pl y z)).
(* YOU MAY EDIT THE PROOF BELOW *)
intros x y z.
exact (Rplus_le_compat_r z x y).
Qed.
(* DO NOT EDIT BELOW *)

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Lemma CompatOrderMult : forall (x:R) (y:R) (z:R), (infix_lseq x y) ->
  ((infix_lseq 0%R z) -> (infix_lseq (infix_as x z) (infix_as y z))).
(* YOU MAY EDIT THE PROOF BELOW *)
intros x y z H Zz.
now apply Rmult_le_compat_r.
Qed.
(* DO NOT EDIT BELOW *)


