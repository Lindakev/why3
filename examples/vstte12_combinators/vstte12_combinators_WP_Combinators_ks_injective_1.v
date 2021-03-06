(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import ZArith.
Require Import Rbase.
Require int.Int.

(* Why3 assumption *)
Definition unit  := unit.

Parameter qtmark : Type.

Parameter at1: forall (a:Type), a -> qtmark -> a.
Implicit Arguments at1.

Parameter old: forall (a:Type), a -> a.
Implicit Arguments old.

(* Why3 assumption *)
Definition implb(x:bool) (y:bool): bool := match (x,
  y) with
  | (true, false) => false
  | (_, _) => true
  end.

(* Why3 assumption *)
Inductive term  :=
  | S : term 
  | K : term 
  | App : term -> term -> term .

(* Why3 assumption *)
Set Implicit Arguments.
Fixpoint is_value(t:term) {struct t}: Prop :=
  match t with
  | (K|S) => True
  | ((App K v)|(App S v)) => (is_value v)
  | (App (App S v1) v2) => (is_value v1) /\ (is_value v2)
  | _ => False
  end.
Unset Implicit Arguments.

(* Why3 assumption *)
Inductive context  :=
  | Hole : context 
  | Left : context -> term -> context 
  | Right : term -> context -> context .

(* Why3 assumption *)
Set Implicit Arguments.
Fixpoint is_context(c:context) {struct c}: Prop :=
  match c with
  | Hole => True
  | (Left c1 _) => (is_context c1)
  | (Right v c1) => (is_value v) /\ (is_context c1)
  end.
Unset Implicit Arguments.

(* Why3 assumption *)
Set Implicit Arguments.
Fixpoint subst(c:context) (t:term) {struct c}: term :=
  match c with
  | Hole => t
  | (Left c1 t2) => (App (subst c1 t) t2)
  | (Right v1 c2) => (App v1 (subst c2 t))
  end.
Unset Implicit Arguments.

(* Why3 assumption *)
Inductive infix_mnmngt : term -> term -> Prop :=
  | red_K : forall (c:context), (is_context c) -> forall (v1:term) (v2:term),
      (is_value v1) -> ((is_value v2) -> (infix_mnmngt (subst c (App (App K
      v1) v2)) (subst c v1)))
  | red_S : forall (c:context), (is_context c) -> forall (v1:term) (v2:term)
      (v3:term), (is_value v1) -> ((is_value v2) -> ((is_value v3) ->
      (infix_mnmngt (subst c (App (App (App S v1) v2) v3)) (subst c
      (App (App v1 v3) (App v2 v3)))))).

Axiom red_left : forall (t1:term) (t2:term) (t:term), (infix_mnmngt t1 t2) ->
  (infix_mnmngt (App t1 t) (App t2 t)).

Axiom red_right : forall (v:term) (t1:term) (t2:term), (is_value v) ->
  ((infix_mnmngt t1 t2) -> (infix_mnmngt (App v t1) (App v t2))).

(* Why3 assumption *)
Inductive relTR : term -> term -> Prop :=
  | BaseTransRefl : forall (x:term), (relTR x x)
  | StepTransRefl : forall (x:term) (y:term) (z:term), (relTR x y) ->
      ((infix_mnmngt y z) -> (relTR x z)).

Axiom relTR_transitive : forall (x:term) (y:term) (z:term), (relTR x y) ->
  ((relTR y z) -> (relTR x z)).

Axiom red_star_left : forall (t1:term) (t2:term) (t:term), (relTR t1 t2) ->
  (relTR (App t1 t) (App t2 t)).

Axiom red_star_right : forall (v:term) (t1:term) (t2:term), (is_value v) ->
  ((relTR t1 t2) -> (relTR (App v t1) (App v t2))).

Axiom reducible_or_value : forall (t:term), (exists tqt:term, (infix_mnmngt t
  tqt)) \/ (is_value t).

(* Why3 assumption *)
Definition irreducible(t:term): Prop := forall (tqt:term), ~ (infix_mnmngt t
  tqt).

Axiom irreducible_is_value : forall (t:term), (irreducible t) <->
  (is_value t).

(* Why3 assumption *)
Inductive only_K : term -> Prop :=
  | only_K_K : (only_K K)
  | only_K_App : forall (t1:term) (t2:term), (only_K t1) -> ((only_K t2) ->
      (only_K (App t1 t2))).

Axiom only_K_reduces : forall (t:term), (only_K t) -> exists v:term, (relTR t
  v) /\ ((is_value v) /\ (only_K v)).

(* Why3 assumption *)
Set Implicit Arguments.
Fixpoint size(t:term) {struct t}: Z :=
  match t with
  | (K|S) => 0%Z
  | (App t1 t2) => ((1%Z + (size t1))%Z + (size t2))%Z
  end.
Unset Implicit Arguments.

Axiom size_nonneg : forall (t:term), (0%Z <= (size t))%Z.

Parameter ks: Z -> term.

Axiom ksO : ((ks 0%Z) = K).

Axiom ksS : forall (n:Z), (0%Z <= n)%Z -> ((ks (n + 1%Z)%Z) = (App (ks n)
  K)).

Axiom ks1 : ((ks 1%Z) = (App K K)).

Axiom only_K_ks : forall (n:Z), (0%Z <= n)%Z -> (only_K (ks n)).

Axiom ks_inversion : forall (n:Z), (0%Z <= n)%Z -> ((n = 0%Z) \/
  ((0%Z <  n)%Z /\ ((ks n) = (App (ks (n - 1%Z)%Z) K)))).

Require Import Why3. Ltac ae := why3 "alt-ergo".

(* Why3 goal *)
Theorem ks_injective : forall (n1:Z) (n2:Z), (0%Z <= n1)%Z ->
  ((0%Z <= n2)%Z -> (((ks n1) = (ks n2)) -> (n1 = n2))).
intros n1 n2 h1 h2.
cut (n1 + n2 <= n1 + n2)%Z. 2:omega.
cut (0 <= n1 + n2)%Z. 2: omega.
generalize (n1+n2)%Z at 1 3.
intros z hz.
generalize n1 n2 h1 h2. clear n1 n2 h1 h2.
pattern z; apply Z_lt_induction.
2: auto.
intros n IH.
intros n1 n2 h1 h2 h12.
destruct (ks_inversion n1); intuition.
subst n1.
destruct (ks_inversion n2); intuition.
ae.
destruct (ks_inversion n2); intuition.
ae.
assert (n1 - 1 = n2 - 1)%Z.
apply (IH (n1-1+n2-1)%Z); clear IH; try omega.
ae.
omega.
Qed.


