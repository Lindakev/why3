(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import ZArith.
Require Import Rbase.
Require int.Int.

(* Why3 assumption *)
Inductive list (a:Type) :=
  | Nil : list a
  | Cons : a -> (list a) -> list a.
Set Contextual Implicit.
Implicit Arguments Nil.
Unset Contextual Implicit.
Implicit Arguments Cons.

(* Why3 assumption *)
Set Implicit Arguments.
Fixpoint length (a:Type)(l:(list a)) {struct l}: Z :=
  match l with
  | Nil => 0%Z
  | (Cons _ r) => (1%Z + (length r))%Z
  end.
Unset Implicit Arguments.

Axiom Length_nonnegative : forall (a:Type), forall (l:(list a)),
  (0%Z <= (length l))%Z.

Axiom Length_nil : forall (a:Type), forall (l:(list a)),
  ((length l) = 0%Z) <-> (l = (Nil :(list a))).

Parameter set : forall (a:Type), Type.

Parameter mem: forall (a:Type), a -> (set a) -> Prop.
Implicit Arguments mem.

(* Why3 assumption *)
Definition infix_eqeq (a:Type)(s1:(set a)) (s2:(set a)): Prop :=
  forall (x:a), (mem x s1) <-> (mem x s2).
Implicit Arguments infix_eqeq.

Axiom extensionality : forall (a:Type), forall (s1:(set a)) (s2:(set a)),
  (infix_eqeq s1 s2) -> (s1 = s2).

(* Why3 assumption *)
Definition subset (a:Type)(s1:(set a)) (s2:(set a)): Prop := forall (x:a),
  (mem x s1) -> (mem x s2).
Implicit Arguments subset.

Axiom subset_trans : forall (a:Type), forall (s1:(set a)) (s2:(set a))
  (s3:(set a)), (subset s1 s2) -> ((subset s2 s3) -> (subset s1 s3)).

Parameter empty: forall (a:Type), (set a).
Set Contextual Implicit.
Implicit Arguments empty.
Unset Contextual Implicit.

(* Why3 assumption *)
Definition is_empty (a:Type)(s:(set a)): Prop := forall (x:a), ~ (mem x s).
Implicit Arguments is_empty.

Axiom empty_def1 : forall (a:Type), (is_empty (empty :(set a))).

Parameter add: forall (a:Type), a -> (set a) -> (set a).
Implicit Arguments add.

Axiom add_def1 : forall (a:Type), forall (x:a) (y:a), forall (s:(set a)),
  (mem x (add y s)) <-> ((x = y) \/ (mem x s)).

Parameter remove: forall (a:Type), a -> (set a) -> (set a).
Implicit Arguments remove.

Axiom remove_def1 : forall (a:Type), forall (x:a) (y:a) (s:(set a)), (mem x
  (remove y s)) <-> ((~ (x = y)) /\ (mem x s)).

Axiom subset_remove : forall (a:Type), forall (x:a) (s:(set a)),
  (subset (remove x s) s).

Parameter union: forall (a:Type), (set a) -> (set a) -> (set a).
Implicit Arguments union.

Axiom union_def1 : forall (a:Type), forall (s1:(set a)) (s2:(set a)) (x:a),
  (mem x (union s1 s2)) <-> ((mem x s1) \/ (mem x s2)).

Parameter inter: forall (a:Type), (set a) -> (set a) -> (set a).
Implicit Arguments inter.

Axiom inter_def1 : forall (a:Type), forall (s1:(set a)) (s2:(set a)) (x:a),
  (mem x (inter s1 s2)) <-> ((mem x s1) /\ (mem x s2)).

Parameter diff: forall (a:Type), (set a) -> (set a) -> (set a).
Implicit Arguments diff.

Axiom diff_def1 : forall (a:Type), forall (s1:(set a)) (s2:(set a)) (x:a),
  (mem x (diff s1 s2)) <-> ((mem x s1) /\ ~ (mem x s2)).

Axiom subset_diff : forall (a:Type), forall (s1:(set a)) (s2:(set a)),
  (subset (diff s1 s2) s1).

Parameter choose: forall (a:Type), (set a) -> a.
Implicit Arguments choose.

Axiom choose_def : forall (a:Type), forall (s:(set a)), (~ (is_empty s)) ->
  (mem (choose s) s).

Parameter all: forall (a:Type), (set a).
Set Contextual Implicit.
Implicit Arguments all.
Unset Contextual Implicit.

Axiom all_def : forall (a:Type), forall (x:a), (mem x (all :(set a))).

Parameter cardinal: forall (a:Type), (set a) -> Z.
Implicit Arguments cardinal.

Axiom cardinal_nonneg : forall (a:Type), forall (s:(set a)),
  (0%Z <= (cardinal s))%Z.

Axiom cardinal_empty : forall (a:Type), forall (s:(set a)),
  ((cardinal s) = 0%Z) <-> (is_empty s).

Axiom cardinal_add : forall (a:Type), forall (x:a), forall (s:(set a)),
  (~ (mem x s)) -> ((cardinal (add x s)) = (1%Z + (cardinal s))%Z).

Axiom cardinal_remove : forall (a:Type), forall (x:a), forall (s:(set a)),
  (mem x s) -> ((cardinal s) = (1%Z + (cardinal (remove x s)))%Z).

Axiom cardinal_subset : forall (a:Type), forall (s1:(set a)) (s2:(set a)),
  (subset s1 s2) -> ((cardinal s1) <= (cardinal s2))%Z.

Axiom cardinal1 : forall (a:Type), forall (s:(set a)),
  ((cardinal s) = 1%Z) -> forall (x:a), (mem x s) -> (x = (choose s)).

Parameter nth: forall (a:Type), Z -> (set a) -> a.
Implicit Arguments nth.

Axiom nth_injective : forall (a:Type), forall (s:(set a)) (i:Z) (j:Z),
  ((0%Z <= i)%Z /\ (i < (cardinal s))%Z) -> (((0%Z <= j)%Z /\
  (j < (cardinal s))%Z) -> (((nth i s) = (nth j s)) -> (i = j))).

Axiom nth_surjective : forall (a:Type), forall (s:(set a)) (x:a), (mem x
  s) -> exists i:Z, ((0%Z <= i)%Z /\ (i < (cardinal s))%Z) -> (x = (nth i
  s)).

Parameter vertex : Type.

Parameter vertices: (set vertex).

Parameter edges: (set (vertex* vertex)%type).

(* Why3 assumption *)
Definition edge(x:vertex) (y:vertex): Prop := (mem (x, y) edges).

Axiom edges_def : forall (x:vertex) (y:vertex), (mem (x, y) edges) -> ((mem x
  vertices) /\ (mem y vertices)).

Parameter s: vertex.

Axiom s_in_graph : (mem s vertices).

Axiom vertices_cardinal_pos : (0%Z < (cardinal vertices))%Z.

(* Why3 assumption *)
Set Implicit Arguments.
Fixpoint infix_plpl (a:Type)(l1:(list a)) (l2:(list a)) {struct l1}: (list
  a) :=
  match l1 with
  | Nil => l2
  | (Cons x1 r1) => (Cons x1 (infix_plpl r1 l2))
  end.
Unset Implicit Arguments.

Axiom Append_assoc : forall (a:Type), forall (l1:(list a)) (l2:(list a))
  (l3:(list a)), ((infix_plpl l1 (infix_plpl l2
  l3)) = (infix_plpl (infix_plpl l1 l2) l3)).

Axiom Append_l_nil : forall (a:Type), forall (l:(list a)), ((infix_plpl l
  (Nil :(list a))) = l).

Axiom Append_length : forall (a:Type), forall (l1:(list a)) (l2:(list a)),
  ((length (infix_plpl l1 l2)) = ((length l1) + (length l2))%Z).

(* Why3 assumption *)
Set Implicit Arguments.
Fixpoint mem1 (a:Type)(x:a) (l:(list a)) {struct l}: Prop :=
  match l with
  | Nil => False
  | (Cons y r) => (x = y) \/ (mem1 x r)
  end.
Unset Implicit Arguments.

Axiom mem_append : forall (a:Type), forall (x:a) (l1:(list a)) (l2:(list a)),
  (mem1 x (infix_plpl l1 l2)) <-> ((mem1 x l1) \/ (mem1 x l2)).

Axiom mem_decomp : forall (a:Type), forall (x:a) (l:(list a)), (mem1 x l) ->
  exists l1:(list a), exists l2:(list a), (l = (infix_plpl l1 (Cons x l2))).

(* Why3 assumption *)
Inductive path : vertex -> (list vertex) -> vertex -> Prop :=
  | Path_empty : forall (x:vertex), (path x (Nil :(list vertex)) x)
  | Path_cons : forall (x:vertex) (y:vertex) (z:vertex) (l:(list vertex)),
      (edge x y) -> ((path y l z) -> (path x (Cons x l) z)).

Axiom path_right_extension : forall (x:vertex) (y:vertex) (z:vertex) (l:(list
  vertex)), (path x l y) -> ((edge y z) -> (path x (infix_plpl l (Cons y
  (Nil :(list vertex)))) z)).

Axiom path_right_inversion : forall (x:vertex) (z:vertex) (l:(list vertex)),
  (path x l z) -> (((x = z) /\ (l = (Nil :(list vertex)))) \/
  exists y:vertex, exists lqt:(list vertex), (path x lqt y) /\ ((edge y z) /\
  (l = (infix_plpl lqt (Cons y (Nil :(list vertex))))))).

Axiom path_trans : forall (x:vertex) (y:vertex) (z:vertex) (l1:(list vertex))
  (l2:(list vertex)), (path x l1 y) -> ((path y l2 z) -> (path x
  (infix_plpl l1 l2) z)).

Axiom empty_path : forall (x:vertex) (y:vertex), (path x (Nil :(list vertex))
  y) -> (x = y).

Axiom path_decomposition : forall (x:vertex) (y:vertex) (z:vertex) (l1:(list
  vertex)) (l2:(list vertex)), (path x (infix_plpl l1 (Cons y l2)) z) ->
  ((path x l1 y) /\ (path y (Cons y l2) z)).

Parameter weight: vertex -> vertex -> Z.

(* Why3 assumption *)
Set Implicit Arguments.
Fixpoint path_weight(l:(list vertex)) (dst:vertex) {struct l}: Z :=
  match l with
  | Nil => 0%Z
  | (Cons x Nil) => (weight x dst)
  | (Cons x ((Cons y _) as r)) => ((weight x y) + (path_weight r dst))%Z
  end.
Unset Implicit Arguments.

Axiom path_weight_right_extension : forall (x:vertex) (y:vertex) (l:(list
  vertex)), ((path_weight (infix_plpl l (Cons x (Nil :(list vertex))))
  y) = ((path_weight l x) + (weight x y))%Z).

Axiom path_weight_decomposition : forall (y:vertex) (z:vertex) (l1:(list
  vertex)) (l2:(list vertex)), ((path_weight (infix_plpl l1 (Cons y l2))
  z) = ((path_weight l1 y) + (path_weight (Cons y l2) z))%Z).

Axiom path_in_vertices : forall (v1:vertex) (v2:vertex) (l:(list vertex)),
  (mem v1 vertices) -> ((path v1 l v2) -> (mem v2 vertices)).

Axiom pigeonhole : forall (s1:(set vertex)) (l:(list vertex)),
  (forall (e:vertex), (mem1 e l) -> (mem e s1)) ->
  (((cardinal s1) < (length l))%Z -> exists e:vertex, exists l1:(list
  vertex), exists l2:(list vertex), exists l3:(list vertex),
  (l = (infix_plpl l1 (Cons e (infix_plpl l2 (Cons e l3)))))).

(* Why3 goal *)
Theorem long_path_decomposition_pigeon1 : forall (l:(list vertex))
  (v:vertex), (path s l v) -> ((~ (l = (Nil :(list vertex)))) ->
  forall (v1:vertex), (mem1 v1 (Cons v l)) -> (mem v1 vertices)).

Require Why3.
Ltac ae := why3 "alt-ergo".
Ltac cvc := why3 "cvc3-2.4".

intros l v H0.
induction H0.
tauto.

apply edges_def in H.
ae.

Qed.


