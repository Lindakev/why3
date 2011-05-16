(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import ZArith.
Require Import Rbase.
Definition unit  := unit.

Parameter ignore: forall (a:Type), a  -> unit.

Implicit Arguments ignore.

Parameter label_ : Type.

Parameter at1: forall (a:Type), a -> label_  -> a.

Implicit Arguments at1.

Parameter old: forall (a:Type), a  -> a.

Implicit Arguments old.

Definition ref (a:Type) := a.

Parameter map : forall (a:Type) (b:Type), Type.

Parameter get: forall (a:Type) (b:Type), (map a b) -> a  -> b.

Implicit Arguments get.

Parameter set: forall (a:Type) (b:Type), (map a b) -> a -> b  -> (map a b).

Implicit Arguments set.

Axiom Select_eq : forall (a:Type) (b:Type), forall (m:(map a b)),
  forall (a1:a) (a2:a), forall (b1:b), (a1 = a2) -> ((get (set m a1 b1)
  a2) = b1).

Axiom Select_neq : forall (a:Type) (b:Type), forall (m:(map a b)),
  forall (a1:a) (a2:a), forall (b1:b), (~ (a1 = a2)) -> ((get (set m a1 b1)
  a2) = (get m a2)).

Parameter create_const: forall (b:Type) (a:Type), b  -> (map a b).

Set Contextual Implicit.
Implicit Arguments create_const.
Unset Contextual Implicit.

Axiom Const : forall (b:Type) (a:Type), forall (b1:b) (a1:a),
  ((get (create_const(b1):(map a b)) a1) = b1).

Inductive array (a:Type) :=
  | mk_array : Z -> (map Z a) -> array a.
Implicit Arguments mk_array.

Definition elts (a:Type)(u:(array a)): (map Z a) :=
  match u with
  | mk_array _ elts1 => elts1
  end.
Implicit Arguments elts.

Definition length (a:Type)(u:(array a)): Z :=
  match u with
  | mk_array length1 _ => length1
  end.
Implicit Arguments length.

Definition mixfix_lbrb (a:Type)(a1:(array a)) (i:Z): a := (get (elts a1) i).
Implicit Arguments mixfix_lbrb.

Definition decrease1(a:(array Z)): Prop := forall (i:Z), ((0%Z <= i)%Z /\
  (i <  ((length a) - 1%Z)%Z)%Z) -> (((mixfix_lbrb a
  i) - 1%Z)%Z <= (mixfix_lbrb a (i + 1%Z)%Z))%Z.

Theorem decrease1_induction : forall (a:(array Z)), (decrease1 a) ->
  forall (i:Z) (j:Z), (((0%Z <= i)%Z /\ (i <= j)%Z) /\
  (j <  (length a))%Z) -> ((((mixfix_lbrb a
  i) + i)%Z - j)%Z <= (mixfix_lbrb a j))%Z.
(* YOU MAY EDIT THE PROOF BELOW *)
unfold decrease1.
intros a Ha i j Hij.
generalize Hij; pattern j.
apply (Zlt_lower_bound_ind _ i).
2: omega.
intuition.
assert (x = i \/ i < x)%Z by omega.
destruct H4.
subst x.
ring_simplify.
omega.
apply Zle_trans with (mixfix_lbrb a (x-1) - 1)%Z.
assert (i <= x-1 < x)%Z by omega.
assert (0 <= i <= x-1 /\ x-1 < length a)%Z by omega.
generalize (H (x-1)%Z H8 H9); clear H; intuition.
apply Zle_trans with (mixfix_lbrb a (x-1+1))%Z.
apply (Ha (x-1)%Z); omega.
ring_simplify (x-1+1)%Z.
omega.
Qed.
(* DO NOT EDIT BELOW *)


