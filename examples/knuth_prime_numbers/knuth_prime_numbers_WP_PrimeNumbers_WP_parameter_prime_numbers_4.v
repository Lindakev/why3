(* This file is generated by Why3's Coq 8.4 driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.
Require int.Int.
Require int.Abs.
Require int.EuclideanDivision.
Require int.ComputerDivision.
Require number.Parity.
Require number.Divisibility.
Require number.Prime.
Require map.Map.

(* Why3 assumption *)
Definition unit := unit.

Axiom qtmark : Type.
Parameter qtmark_WhyType : WhyType qtmark.
Existing Instance qtmark_WhyType.

(* Why3 assumption *)
Definition lt_nat (x:Z) (y:Z): Prop := (0%Z <= y)%Z /\ (x < y)%Z.

(* Why3 assumption *)
Inductive lex : (Z* Z)%type -> (Z* Z)%type -> Prop :=
  | Lex_1 : forall (x1:Z) (x2:Z) (y1:Z) (y2:Z), (lt_nat x1 x2) -> (lex (x1,
      y1) (x2, y2))
  | Lex_2 : forall (x:Z) (y1:Z) (y2:Z), (lt_nat y1 y2) -> (lex (x, y1) (x,
      y2)).

(* Why3 assumption *)
Inductive ref (a:Type) {a_WT:WhyType a} :=
  | mk_ref : a -> ref a.
Axiom ref_WhyType : forall (a:Type) {a_WT:WhyType a}, WhyType (ref a).
Existing Instance ref_WhyType.
Implicit Arguments mk_ref [[a] [a_WT]].

(* Why3 assumption *)
Definition contents {a:Type} {a_WT:WhyType a} (v:(@ref a a_WT)): a :=
  match v with
  | (mk_ref x) => x
  end.

(* Why3 assumption *)
Inductive array
  (a:Type) {a_WT:WhyType a} :=
  | mk_array : Z -> (@map.Map.map Z _ a a_WT) -> array a.
Axiom array_WhyType : forall (a:Type) {a_WT:WhyType a}, WhyType (array a).
Existing Instance array_WhyType.
Implicit Arguments mk_array [[a] [a_WT]].

(* Why3 assumption *)
Definition elts {a:Type} {a_WT:WhyType a} (v:(@array a a_WT)): (@map.Map.map
  Z _ a a_WT) := match v with
  | (mk_array x x1) => x1
  end.

(* Why3 assumption *)
Definition length {a:Type} {a_WT:WhyType a} (v:(@array a a_WT)): Z :=
  match v with
  | (mk_array x x1) => x
  end.

(* Why3 assumption *)
Definition get {a:Type} {a_WT:WhyType a} (a1:(@array a a_WT)) (i:Z): a :=
  (map.Map.get (elts a1) i).

(* Why3 assumption *)
Definition set {a:Type} {a_WT:WhyType a} (a1:(@array a a_WT)) (i:Z)
  (v:a): (@array a a_WT) := (mk_array (length a1) (map.Map.set (elts a1) i
  v)).

(* Why3 assumption *)
Definition make {a:Type} {a_WT:WhyType a} (n:Z) (v:a): (@array a a_WT) :=
  (mk_array n (map.Map.const v: (@map.Map.map Z _ a a_WT))).

(* Why3 assumption *)
Definition no_prime_in (l:Z) (u:Z): Prop := forall (x:Z), ((l < x)%Z /\
  (x < u)%Z) -> ~ (number.Prime.prime x).

(* Why3 assumption *)
Definition first_primes (p:(@array Z _)) (u:Z): Prop := ((get p
  0%Z) = 2%Z) /\ ((forall (i:Z) (j:Z), ((0%Z <= i)%Z /\ ((i < j)%Z /\
  (j < u)%Z)) -> ((get p i) < (get p j))%Z) /\ ((forall (i:Z),
  ((0%Z <= i)%Z /\ (i < u)%Z) -> (number.Prime.prime (get p i))) /\
  forall (i:Z), ((0%Z <= i)%Z /\ (i < (u - 1%Z)%Z)%Z) -> (no_prime_in (get p
  i) (get p (i + 1%Z)%Z)))).

Axiom exists_prime : forall (p:(@array Z _)) (u:Z), (1%Z <= u)%Z ->
  ((first_primes p u) -> forall (d:Z), ((2%Z <= d)%Z /\ (d <= (get p
  (u - 1%Z)%Z))%Z) -> ((number.Prime.prime d) -> exists i:Z, ((0%Z <= i)%Z /\
  (i < u)%Z) /\ (d = (get p i)))).

Axiom Bertrand_postulate : forall (p:Z), (number.Prime.prime p) ->
  ~ (no_prime_in p (2%Z * p)%Z).

Lemma Zle_sqrt: forall x y, (0 <= x -> 0 <= y -> x*x < y*y -> x<y)%Z.
intros x y Hx Hy H.
apply Znot_ge_lt.
intros H'.
apply (Zlt_not_le _ _ H).
apply Zge_le in H'.
now apply Zmult_le_compat.
Qed.

Import Zquot.

(* Why3 goal *)
Theorem WP_parameter_prime_numbers : forall (m:Z), (2%Z <= m)%Z ->
  ((0%Z <= m)%Z -> ((0%Z <= m)%Z -> (((0%Z <= 0%Z)%Z /\ (0%Z < m)%Z) ->
  forall (p:(@map.Map.map Z _ Z _)), ((0%Z <= m)%Z /\
  (p = (map.Map.set (map.Map.const 0%Z: (@map.Map.map Z _ Z _)) 0%Z 2%Z))) ->
  (((0%Z <= 1%Z)%Z /\ (1%Z < m)%Z) -> forall (p1:(@map.Map.map Z _ Z _)),
  ((0%Z <= m)%Z /\ (p1 = (map.Map.set p 1%Z 3%Z))) -> let o := (m - 1%Z)%Z in
  ((2%Z <= o)%Z -> forall (n:Z) (p2:(@map.Map.map Z _ Z _)), forall (j:Z),
  ((2%Z <= j)%Z /\ (j <= o)%Z) -> (((first_primes (mk_array m p2) j) /\
  ((((map.Map.get p2 (j - 1%Z)%Z) < n)%Z /\ (n < (2%Z * (map.Map.get p2
  (j - 1%Z)%Z))%Z)%Z) /\ ((number.Parity.odd n) /\ (no_prime_in
  (map.Map.get p2 (j - 1%Z)%Z) n)))) -> forall (k:Z), forall (n1:Z)
  (p3:(@map.Map.map Z _ Z _)), ((0%Z <= m)%Z /\ (((1%Z <= k)%Z /\
  (k < j)%Z) /\ ((first_primes (mk_array m p3) j) /\ ((((map.Map.get p3
  (j - 1%Z)%Z) < n1)%Z /\ (n1 < (2%Z * (map.Map.get p3 (j - 1%Z)%Z))%Z)%Z) /\
  ((number.Parity.odd n1) /\ ((no_prime_in (map.Map.get p3 (j - 1%Z)%Z)
  n1) /\ forall (i:Z), ((0%Z <= i)%Z /\ (i < k)%Z) ->
  ~ (number.Divisibility.divides (map.Map.get p3 i) n1))))))) ->
  (((0%Z <= k)%Z /\ (k < m)%Z) ->
  ((~ ((ZArith.BinInt.Z.rem n1 (map.Map.get p3 k)) = 0%Z)) ->
  (((0%Z <= k)%Z /\ (k < m)%Z) -> (((0%Z <= k)%Z /\ (k < m)%Z) ->
  ((~ ((map.Map.get p3 k) < (ZArith.BinInt.Z.quot n1 (map.Map.get p3
  k)))%Z) -> (number.Prime.prime n1)))))))))))).
(* Why3 intros m h1 h2 h3 (h4,h5) p (h6,h7) (h8,h9) p1 (h10,h11) o h12 n p2 j
        (h13,h14) (h15,((h16,h17),(h18,h19))) k n1 p3
        (h20,((h21,h22),(h23,((h24,h25),(h26,(h27,h28)))))) (h29,h30) h31
        (h32,h33) (h34,h35) h36. *)
intros m h1 h2 h3 (h4,h5) p (h6,h7) (h8,h9) p1 (h10,h11) o h12 n p2 j
        (h13,h14) (h15,((h16,h17),(h18,h19))) k n1 p3
        (h20,((h21,h22),(h23,((h24,h25),(h26,(h27,h28)))))) (h29,h30) h31
        (h32,h33) (h34,h35) h36.
intuition.
red in h23. destruct h23 as (p0, (sorted, (only_primes, all_primes))).
assert (H2: (2 < Map.get p3 k)%Z).
rewrite <- p0. apply sorted; omega.
apply Prime.small_divisors; auto.
omega.
intros.
generalize (Z_quot_rem_eq n1 (Map.get p3 k)). intro div.
assert (ne1: (0 <= n1 /\ Map.get p3 k <> 0)%Z) by omega.
assert (mod1: (0 <= Z.rem n1 (Map.get p3 k))%Z).
destruct (not_Zeq_inf _ _ (proj2 ne1)) as [Zm|Zm].
now apply Zrem_lt_pos_neg.
now apply Zrem_lt_pos_pos.
assert (mod2: (Z.rem n1 (Map.get p3 k) < Map.get p3 k)%Z).
apply Zrem_lt_pos_pos ; omega.
assert (d <= Map.get p3 k)%Z.
assert (d < Map.get p3 k+1)%Z. 2: omega.
apply Zle_sqrt; try omega.
assert (2 < Map.get p3 k)%Z. 
rewrite <- p0. apply sorted; omega.
apply Zle_lt_trans with n1; try omega.
assert (Map.get p3 k * (Z.quot n1 (Map.get p3 k)) <= Map.get p3 k * Map.get p3 k)%Z.
apply Zmult_le_compat_l; try omega.
replace ((Map.get p3 k + 1) * (Map.get p3 k + 1))%Z with (Map.get p3 k * Map.get p3 k + 2 * Map.get p3 k + 1)%Z by ring.
omega.
destruct (exists_prime (mk_array m p3) (k+1))%Z with (d := d) as (i, (hi1, hi2)); auto.
omega.
red; split; intros.
auto.
split; intros.
apply sorted; omega.
split; intros.
apply only_primes; omega.
apply all_primes; omega.
unfold get; simpl.
replace (k+1-1)%Z with k by omega.
auto.
unfold get in hi2; simpl in hi2. subst d.
assert (case: (i < k \/i = k)%Z) by omega. destruct case.
red; intro. apply h28 with i; try omega.
auto.
subst i.
intro. apply h31.
apply Divisibility.divides_mod_computer; auto; omega.
Qed.

