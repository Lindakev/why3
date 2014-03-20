
(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.
Require int.Int.
Require map.Map.
Require map.MapPermut.

(* Why3 assumption *)
Definition unit  := unit.

(* Why3 assumption *)
Definition injective(a:(map.Map.map Z Z)) (n:Z): Prop := forall (i:Z) (j:Z),
  ((0%Z <= i)%Z /\ (i < n)%Z) -> (((0%Z <= j)%Z /\ (j < n)%Z) ->
  ((~ (i = j)) -> ~ ((map.Map.get a i) = (map.Map.get a j)))).

(* Why3 assumption *)
Definition surjective(a:(map.Map.map Z Z)) (n:Z): Prop := forall (i:Z),
  ((0%Z <= i)%Z /\ (i < n)%Z) -> exists j:Z, ((0%Z <= j)%Z /\ (j < n)%Z) /\
  ((map.Map.get a j) = i).

(* Why3 assumption *)
Definition range(a:(map.Map.map Z Z)) (n:Z): Prop := forall (i:Z),
  ((0%Z <= i)%Z /\ (i < n)%Z) -> ((0%Z <= (map.Map.get a i))%Z /\
  ((map.Map.get a i) < n)%Z).

Axiom injective_surjective : forall (a:(map.Map.map Z Z)) (n:Z), (injective a
  n) -> ((range a n) -> (surjective a n)).

(* Why3 assumption *)
Definition map_permutation(m:(map.Map.map Z Z)) (u:Z): Prop := (range m u) /\
  (injective m u).

(* Why3 goal *)
Theorem map_permut_permutation : forall (m1:(map.Map.map Z Z))
  (m2:(map.Map.map Z Z)) (u:Z), (map.MapPermut.permut_sub m1 m2 0%Z u) ->
  ((map_permutation m1 u) -> (map_permutation m2 u)).
intros m1 m2 u h1 h2.
unfold permutation in *.
simpl in *.
subst l2.
Print permut_sub.
inversion h2.
elim h2; auto.
admit.
unfold range, injective.
intuition.
destruct H1 as (h1 & h2 & h3).
intros.
assert (i0=i \/ i0 = j \/ (i0 <> i /\ i0 <> j)) by omega.
destruct H1.
subst i0.
rewrite h2.

Qed.


