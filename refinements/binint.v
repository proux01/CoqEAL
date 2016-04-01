(** This file is part of CoqEAL, the Coq Effective Algebra Library.
(c) Copyright INRIA and University of Gothenburg, see LICENSE *)
From mathcomp Require Import ssreflect ssrfun ssrbool eqtype ssrnat div seq zmodp.
From mathcomp Require Import path choice fintype tuple finset ssralg ssrnum bigop ssrint.

From CoqEAL Require Import hrel param refinements pos.

(******************************************************************************)
(* Attempt to refine SSReflect integers (ssrint) are to a new type            *)
(* paremetrized by positive numbers (represented by a sigma type) and natural *)
(* numbers. This gives simpler proofs than in binint, but in order for this   *)
(* to be useful the parametricity part of the library must be used to change  *)
(* the representation of positive numbers and naturals to more efficient      *)
(* representations (e.g. N) which has not been done yet.                      *)
(*                                                                            *)
(******************************************************************************)

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Local Open Scope ring_scope.

Import GRing.Theory Num.Theory Refinements Op.

(******************************************************************************)
(** PART I: Defining generic datastructures and programming with them         *)
(******************************************************************************)
Section binint_op.
Variable N P : Type.

Local Open Scope computable_scope.

Inductive Z := Zpos of N | Zneg of P.

Definition Zmatch T (n : Z) f g : T :=
   match n with Zpos p => f p | Zneg n => g n end.

Context `{zero_of N, one_of N, sub_of N, add_of N, mul_of N, leq_of N(*, lt N*), eq_of N}.
Context `{one_of P, sub_of P, add_of P, mul_of P, eq_of P, leq_of P(*, lt P*)}.
Context `{cast_of N P, cast_of P N}.
Context `{spec_of N nat, spec_of P pos}.
Context `{implem_of nat N, implem_of pos P}.

Global Instance zeroZ : zero_of Z := Zpos 0.
Global Instance oneZ : one_of Z := Zpos 1.

Global Instance addZ : add_of Z := fun x y : Z => match x, y with
  | Zpos x, Zpos y => Zpos (x + y)
  | Zneg x, Zneg y => Zneg (x + y)
  | Zpos x, Zneg y => if (cast y <= x) then Zpos (x - cast y)
                                       else Zneg (cast (cast y - x))
  | Zneg x, Zpos y => if (cast x <= y) then Zpos (y - cast x)
                                       else Zneg (cast (cast x - y))
  end.

Global Instance oppZ : opp_of Z := fun x : Z => match x with
  | Zpos x => if (x == 0)%C then 0%C else Zneg (cast x)
  | Zneg x => Zpos (cast x)
  end.

Global Instance subZ : sub_of Z := fun x y : Z => match x, y with
  | Zpos x, Zneg y => Zpos (x + cast y)
  | Zneg x, Zpos y => if (y == 0)%C then Zneg x else Zneg (x + cast y)
  | Zpos x, Zpos y => if (y <= x) then Zpos (x - y)
                                  else Zneg (cast (y - x))
  | Zneg x, Zneg y => if ((cast x : N) <= (cast y : N)) then Zpos (cast y - cast x)
                                            else Zneg (cast ((cast x : N) - cast y))
  end.

Global Instance eqZ : eq_of Z := fun x y : Z => match x, y with
  | Zpos x, Zpos y => (x == y)
  | Zneg x, Zneg y => (x == y)
  | _, _ => false
  end.

Global Instance mulZ : mul_of Z := fun x y : Z => match x, y with
  | Zpos x, Zpos y => Zpos (x * y)
  | Zneg x, Zpos y => if (y == 0)%C then 0%C else Zneg (x * cast y)
  | Zpos x, Zneg y => if (x == 0)%C then 0%C else Zneg (cast x * y)
  | Zneg x, Zneg y => Zpos (cast x * cast y)
  end.

Global Instance leqZ : leq_of Z := fun x y : Z => match x, y with
  | Zpos x, Zpos y => (x <= y)
  | Zneg x, Zneg y => (y <= x)
  | Zneg _, Zpos _ => true
  | Zpos _, Zneg _ => false
  end.

(*Global Instance ltZ : lt Z := fun x y : Z => match x, y with
  | Zpos x, Zpos y => (x < y)
  | Zneg x, Zneg y => (y < x)
  | Zneg _, Zpos _ => true
  | Zpos _, Zneg _ => false
  end.*)

Global Instance cast_NZ : cast_of N Z := fun n : N => Zpos n.

Global Instance cast_PZ : cast_of P Z := fun n : P => Zpos (cast n).

Global Instance cast_ZN : cast_of Z N := fun z =>
  if z is Zpos n then n else 0.

Global Instance cast_ZP : cast_of Z P := fun z => cast (cast_ZN z).

Global Instance specZ : spec_of Z int :=
  fun x => (match x with
             | Zpos p => (spec p : nat)%:Z
             | Zneg n => - (spec (cast n : N): nat)%:Z
           end)%R.

Global Instance implemZ : implem_of int Z :=
  fun x => (match x with
            | Posz n => Zpos (implem n)
            | Negz n => Zneg (implem (posS n))
           end).

End binint_op.

Parametricity Z.
Parametricity Zmatch.
Parametricity zeroZ.
Parametricity oneZ.
Parametricity addZ.
Parametricity oppZ.
Parametricity subZ.
Parametricity eqZ.
Parametricity mulZ.
Parametricity leqZ.
Parametricity cast_NZ.
Parametricity cast_PZ.
Parametricity cast_ZN.
Parametricity cast_ZP.
(* Parametricity int. *)
(* Parametricity sum. *)
(* Definition specZ_simpl := Eval cbv in specZ. *)
(* Parametricity specZ_simpl. *)
(* Realizer specZ as specZ_R := specZ_simpl_R. *)

(******************************************************************************)
(** PART II: Proving correctness properties of the previously defined objects *)
(******************************************************************************)
Section binint_theory.

Notation Znp := (Z nat pos).

Definition Z_of_int (m : int) : Znp := match m with
  | Posz m => Zpos _ m
  | Negz m => Zneg _ (posS m)
  end.

Definition int_of_Z (m : Znp) : int := match m with
  | Zpos p => p%:Z
  | Zneg p => -(val p)%:Z
  end.

Lemma Z_of_intK : pcancel Z_of_int (some \o int_of_Z).
Proof. by rewrite /Z_of_int /int_of_Z => [[[]|]]. Qed.

Local Open Scope rel_scope.

Definition Rint : int -> Znp -> Type := fun_hrel int_of_Z.

Local Instance zero_nat : zero_of nat := 0%N.
Local Instance one_nat  : one_of nat  := 1%N.
Local Instance add_nat  : add_of nat  := addn.
Local Instance sub_nat  : sub_of nat  := subn.
Local Instance mul_nat  : mul_of nat  := muln.
Local Instance leq_nat  : leq_of nat  := ssrnat.leq.
(*Local Instance lt_nat   : lt nat  := ssrnat.ltn.*)
Local Instance eq_nat   : eq_of nat   := eqtype.eq_op.

Local Instance spec_nat : spec_of nat nat := spec_id.
Local Instance spec_ps : spec_of pos pos := spec_id.

Local Instance implem_nat : implem_of nat nat := implem_id.
Local Instance implem_ps : implem_of pos pos := implem_id.

Lemma RintE n x : refines Rint n x -> n = int_of_Z x.
Proof. by rewrite refinesE. Qed.

Local Instance Rint_0 : refines Rint 0 0%C.
Proof. by rewrite refinesE. Qed.

Local Instance Rint_1 : refines Rint 1 1%C.
Proof. by rewrite refinesE. Qed.

Local Instance Rint_Posz : refines (Logic.eq ==> Rint) Posz cast.
Proof. by rewrite refinesE=> n n' <-. Qed.

Local Instance Rint_pos_to_int : refines (Logic.eq ==> Rint) pos_to_int cast.
Proof. by rewrite refinesE=> n n' <-; rewrite /pos_to_int natz. Qed.

Local Instance Rint_int_to_nat : refines (Rint ==> Logic.eq) int_to_nat cast.
Proof.
  rewrite refinesE=> a b rab; rewrite [a]RintE {a rab}.
  case: b => [n|[n n_gt0]] //=; rewrite /cast /cast_ZP /cast_ZN /int_to_nat.
    by rewrite ltz_nat; have [->|] // := posnP n.
  by rewrite ler_gtF // oppr_le0 ltrW.
Qed.

Local Instance Rint_int_to_pos : refines (Rint ==> Logic.eq) int_to_pos cast.
Proof.
  rewrite refinesE => a b rab; rewrite /int_to_pos.
  by rewrite [int_to_nat a]refines_eq {a rab}.
Qed.

Lemma eqSub (n m : nat) :
  int_of_Z (if (m <= n)%C then Zpos pos (n - m)%N
            else Zneg nat (cast (m - n)%N)) = (Posz n) - (Posz m).
Proof.
  have [mn|nm] /= := leqP m n.
    have := mn.
    rewrite -[((_<=_)%N)]/(_<=_)%C => ->.
    by rewrite /= -subzn.
  rewrite [((_<=_)%C)]/(_<=_)%N ifN_eq=> /=.
    by rewrite insubdK -?topredE /= ?subn_gt0 // -?subzn 1?ltnW // opprB.
  by have := nm; rewrite lt0n_neq0 // subn_gt0.
Qed.

Local Instance Rint_add : refines (Rint ==> Rint ==> Rint) +%R +%C.
Proof.
  rewrite refinesE /Rint /fun_hrel /add_op /= => _ x <- _ y <-.
  case: x y => [x|x] [y|y] //=; rewrite ?(add0r, addr0) //=; simpC.
      by rewrite (eqSub x (cast y)).
    by rewrite (eqSub y (cast x)) addrC.
  by rewrite insubdK -?topredE /= ?addn_gt0 ?valP // -opprB opprK addrC.
Qed.

Local Instance Rint_opp : refines (Rint ==> Rint) -%R -%C.
Proof.
rewrite refinesE  /Rint /fun_hrel => _ x <-.
by case: x => [[]|] //= n; rewrite ?insubdK ?opprK.
Qed.

Local Instance Rint_sub :
  refines (Rint ==> Rint ==> Rint) (fun x y => x - y) sub_op.
Proof.
  rewrite refinesE /Rint /fun_hrel /sub_op => _ x <- _ y <-.
  case: x y=> [x|x] [y|y]; rewrite ?opprK //=; simpC.
      by rewrite (eqSub x y).
    have [->|y_neq0 /=] := (altP eqP); first by rewrite subr0.
    by rewrite !insubdK -?opprD -?topredE //= ?addn_gt0 ?valP ?lt0n.
  by rewrite (eqSub (cast y) (cast x)) addrC.
Qed.

Implicit Type n : nat.
Implicit Type p : pos.

Local Instance Rint_eq : refines (Rint ==> Rint ==> bool_R) eqtype.eq_op eq_op.
Proof.
  have nat_nneg n p : bool_R (n == - (Posz (val p)) :> int) false.
    by rewrite gtr_eqF // ltNz_nat -lt0n [(_ < _)%N]valP.
  rewrite refinesE=> _ x <- _ y <-; rewrite /eq_op /eqZ.
  case: x; case: y=> * /=; simpC; rewrite ?eqr_opp ?[- _ == _]eq_sym //;
  exact: bool_Rxx.
Qed.

Local Instance Rint_leq : refines (Rint ==> Rint ==> bool_R) Num.le leq_op.
Proof.
  have nat_nleqneg n p : bool_R (n <= - (Posz (val p)) :> int) false.
    rewrite lerNgt (@ltr_le_trans _ 0) ?oppr_lt0 //=.
    apply: valP.
  have neg_leqnat n p : bool_R (- (Posz (val p)) <= n :> int) true.
    by rewrite ler_oppl (@ler_trans _ 0) // oppr_le0 le0z_nat.
  rewrite refinesE=> _ x <- _ y <-; rewrite /leq_op /leqZ.
  case: x y => [x|x] [y|y] /=; rewrite -?[((_<=_)%C)]/(_<=_)%N ?ler_opp2 //;
  exact: bool_Rxx.
Qed.

(*Local Instance Rint_lt : refines (Rint ==> Rint ==> Logic.eq) Num.lt lt_op.
Proof.
rewrite refinesE /Rint /fun_hrel /eq_op => _ x <- _ y <-.
case: x y => [x|x] [y|y] //=.
- by rewrite ltrNge (@ler_trans _ 0) // oppr_le0.
- by rewrite (@ltr_le_trans _ 0) // oppr_lt0; apply: valP.
by rewrite ltr_opp2.
Qed.*)

Local Instance Rint_mul : refines (Rint ==> Rint ==> Rint) *%R *%C.
Proof.
rewrite refinesE /Rint /fun_hrel /mul_op => _ x <- _ y <-.
case: x y => [x|x] [y|y] //=; simpC; last by rewrite mulrNN.
  have [->|y_neq0 /=] := (altP eqP); first by rewrite mul0r.
  by rewrite mulrN !insubdK -?topredE /= ?muln_gt0 ?valP ?andbT ?lt0n.
have [->|y_neq0 /=] := (altP eqP); first by rewrite mulr0.
by rewrite mulNr !insubdK -?topredE /= ?muln_gt0 ?valP ?andbT ?lt0n.
Qed.

Local Instance Rint_specZ_r x : refines Rint (spec x) x.
Proof. by rewrite !refinesE; case: x. Qed.

Local Instance Rint_specZ_l :
  refines (Rint ==> Logic.eq) spec_id spec.
Proof. by rewrite refinesE => a a' ra; rewrite [spec _]RintE. Qed.

Local Instance Rint_implem x : refines Rint x (implem x) | 999.
Proof.
  by rewrite refinesE; case: x.
Qed.

(*************************************************************************)
(* PART III: Parametricity part                                          *)
(*************************************************************************)
Section binint_parametricity.

Section binint_nat_pos.

Variables N P : Type.
Variables (Rnat : nat -> N -> Type) (Rpos : pos -> P -> Type).

Definition RZNP := (Rint \o Z_R Rnat Rpos)%rel.

Context `{zero_of N, one_of N, sub_of N, add_of N, mul_of N, leq_of N, eq_of N(*, lt N*)}.
Context `{one_of P, sub_of P, add_of P, mul_of P, eq_of P, leq_of P(*, lt P*)}.
Context `{cast_of N P, cast_of P N}.
Context `{spec_of N nat, spec_of P pos}.
Context `{implem_of nat N, implem_of pos P}.

Context `{!refines Rnat 0%N 0%C, !refines Rnat 1%N 1%C}.
Context `{!refines Rpos pos1 1%C}.
Context `{!refines (Rnat ==> Rnat ==> Rnat) addn +%C}.
Context `{!refines (Rpos ==> Rpos ==> Rpos) add_pos +%C}.
Context `{!refines (Rnat ==> Rnat ==> Rnat) subn sub_op}.
Context `{!refines (Rpos ==> Rpos ==> Rpos) sub_pos sub_op}.
Context `{!refines (Rnat ==> Rnat ==> Rnat) muln *%C}.
Context `{!refines (Rpos ==> Rpos ==> Rpos) mul_pos *%C}.
Context `{!refines (Rnat ==> Rnat ==> bool_R) ssrnat.leq leq_op}.
(*Context `{!refines (Rnat ==> Rnat ==> Logic.eq) ssrnat.ltn lt_op}.*)
Context `{!refines (Rpos ==> Rpos ==> bool_R) leq_pos leq_op}.
(*Context `{!refines (Rpos ==> Rpos ==> Logic.eq) lt_pos lt_op}.*)
Context `{!refines (Rnat ==> Rpos) (insubd pos1) cast}.
Context `{!refines (Rpos ==> Rnat) val cast}.
Context `{!refines (Rnat ==> Rnat ==> bool_R) eqtype.eq_op eq_op}.
Context `{!refines (Rpos ==> Rpos ==> bool_R) eqtype.eq_op eq_op}.
Context `{forall x, refines Rnat (spec x) x,
          forall x, refines Rpos (spec x) x}.
(* Context `{!refines (Rnat ==> nat_R) spec_id spec, *)
(*           !refines (Rpos ==> pos_R) spec_id spec}. *)
Context `{!refines (Rnat ==> Logic.eq) spec_id spec,
          !refines (Rpos ==> Logic.eq) spec_id spec}.

Local Notation Z := (Z N P).

Global Instance RZNP_zeroZ  : refines RZNP 0 0%C.
Proof. param_comp zeroZ_R. Qed.

Global Instance RZNP_oneZ  : refines RZNP 1 1%C.
Proof. param_comp oneZ_R. Qed.

Global Instance RZNP_castNZ : refines (Rnat ==> RZNP) Posz cast.
Proof. param_comp cast_NZ_R. Qed.

Global Instance RZNP_castPZ : refines (Rpos ==> RZNP) pos_to_int cast.
Proof. param_comp cast_PZ_R. Qed.

Global Instance RZNP_castZN: refines (RZNP ==> Rnat) int_to_nat cast.
Proof. rewrite /cast; param_comp cast_ZN_R. Qed.

Global Instance RZNP_castZP: refines (RZNP ==> Rpos) int_to_pos cast.
Proof. rewrite /cast; param_comp cast_ZP_R. Qed.

Global Instance RZNP_addZ : refines (RZNP ==> RZNP ==> RZNP) +%R +%C.
Proof. param_comp addZ_R. Qed.

Global Instance RZNP_mulZ : refines (RZNP ==> RZNP ==> RZNP) *%R *%C.
Proof. param_comp mulZ_R. Qed.

Global Instance RZNP_oppZ : refines (RZNP ==> RZNP) -%R -%C.
Proof. param_comp oppZ_R. Qed.

Global Instance RZNP_subZ :
  refines (RZNP ==> RZNP ==> RZNP) (fun x y => x - y) sub_op.
Proof. param_comp subZ_R. Qed.

Global Instance RZNP_eqZ :
  refines (RZNP ==> RZNP ==> bool_R) eqtype.eq_op (@Op.eq_op Z _).
Proof. param_comp eqZ_R. Qed.

Global Instance RZNP_leqZ :
  refines (RZNP ==> RZNP ==> bool_R) Num.le (@Op.leq_op Z _).
Proof. param_comp leqZ_R. Qed.

(* Global Instance RZNP_ltZ : *)
(*   refines (RZNP ==> RZNP ==> Logic.eq) Num.lt (@Op.lt_op Z _). *)
(* Proof. exact: refines_trans. Qed. *)

(* Global Instance RZNP_specZ_l : refines (RZNP ==> int_R) spec_id spec. *)
(* Proof. param_comp specZ_R. Qed. *)

Global Instance RZNP_specZ : refines (RZNP ==> Logic.eq) spec_id spec.
Proof.
  eapply refines_trans; tc.
  rewrite refinesE=> x y rxy.
  case: rxy=> [n m rnm|p q rpq]; rewrite /spec /=; apply: congr1.
    exact: refinesP.
  apply: congr1; exact: refinesP.
Qed.

End binint_nat_pos.
End binint_parametricity.
End binint_theory.

Section testint.

From CoqEAL Require Import binnat.

Goal (0 == 0 :> int).
rewrite [_ == _]refines_eq.
by compute.
Abort.

Goal (1 == 1 :> int).
rewrite [_ == _]refines_eq.
by compute.
Abort.

Goal (- 1%:Z == - 1%:Z).
rewrite [_ == _]refines_eq.
by compute.
Abort.

Goal (10%:Z - 5%:Z == 1 + 4%:Z).
rewrite -[X in (X == _)]/(spec_id _) [spec_id _]refines_eq /=.
rewrite [_ == _]refines_eq.
by compute.
Abort.

Goal (-(1 + 2%:Z * 4%:Z) == -(1 + 2%:Z * 4%:Z)).
rewrite -[X in (X == _)]/(spec_id _).
rewrite [spec_id _]refines_eq /=.
rewrite [_ == _]refines_eq.
by compute.
Abort.

Goal (1000%:Z == 998%:Z + 2%:Z).
rewrite [_ == _]refines_eq.
by compute.
Abort.

Goal (1000%:Z == 2%:Z * 500%:Z).
rewrite [_ == _]refines_eq.
by compute.
Abort.

End testint.