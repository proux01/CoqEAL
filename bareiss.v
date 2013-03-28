Require Import ssreflect ssrfun ssrbool eqtype ssrnat div seq path ssralg.
Require Import fintype perm choice matrix bigop zmodp poly polydiv mxpoly.

Require Import refinements minor.

Import GRing.Theory Pdiv.Ring Pdiv.CommonRing Pdiv.RingMonic Refinements.Op.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensives.

Open Scope ring_scope.

(* A first try on a generic Bareiss: *)
(* Section generic_bareiss. *)

(* Variable A polyA mxA mxpA : Type. *)

(* Context `{zero A, one polyA, opp mxA, sub mxpA, scale polyA mxpA}. *)
(* Variable mulmxpA : mxpA -> mxpA -> mxpA. *)
(* Variables ursubmxpA dlsubmxpA drsubmxpA : mxpA -> mxpA. *)
(* Variable top_left : mxpA -> polyA. *)
(* Variable map_mxpA : (polyA -> polyA) -> mxpA -> mxpA. *)
(* Variable rdivpA : polyA -> polyA -> polyA. *)
(* Variable char_poly_mxpA : mxA -> mxpA. *)
(* Variable head : A -> polyA -> A. *)

(* Fixpoint bareiss_rec m a (M : mxpA) : polyA := match m with *)
(*     | S p => let d   := top_left M in *)
(*              let l   := ursubmxpA M in *)
(*              let c   := dlsubmxpA M in *)
(*              let N   := drsubmxpA M in *)
(*              let M'  := (d *: N - mulmxpA c l)%C in *)
(*              let M'' := map_mxpA (fun x => rdivpA x a) M' in *)
(*                bareiss_rec p d M'' *)
(*     | _ => top_left M *)
(*   end. *)

(* Definition bareiss n M := bareiss_rec n 1%C M. *)

(* Definition bareiss_char_poly n M := bareiss (1 + n) (char_poly_mxpA M). *)

(* (* The actual determinant function based on Bareiss *) *)
(* Definition bdet n M := head 0%C (bareiss_char_poly (1 + n) (- M)%C). *)

(* End generic_bareiss. *)

Section bareiss_def.

Variable R : comRingType.

Fixpoint bareiss_rec m a : 'M[{poly R}]_(1 + m) -> {poly R} :=
  match m return 'M[_]_(1 + m) -> {poly R} with
    | S p => fun (M: 'M[_]_(1 + _)) =>
      let d   := M 0 0 in
      let l   := ursubmx M in
      let c   := dlsubmx M in
      let N   := drsubmx M in
      let M'  := d *: N - c *m l in
      let M'' := map_mx (fun x => rdivp x a) M' in
        bareiss_rec d M''
    | _ => fun M => M 0 0
  end.

Definition bareiss n (M : 'M[{poly R}]_(1 + n)) := bareiss_rec 1 M.

Definition bareiss_char_poly n (M : 'M[R]_(1 + n)) := bareiss (char_poly_mx M).

(* The actual determinant function based on Bareiss *)
Definition bdet n (M : 'M[R]_(1 + n)) := (bareiss_char_poly (-M))`_0.

End bareiss_def.

Section bareiss_correctness.

(* First some lemmas for an arbitrary comRingType *)
Section bareiss_comRingType.

Variable R : comRingType.

Lemma key_lemma m d l (c : 'cV[R]_m) M :
  d ^+ m * \det (block_mx d%:M l c M) = d * \det (d *: M - c *m l).
Proof.
rewrite -[d ^+ m]mul1r -det_scalar -(det1 _ 1) -(det_ublock _ 0) -det_mulmx.
rewrite mulmx_block ?(mul0mx,addr0,add0r,mul1mx,mul_scalar_mx) -2![LHS]mul1r.
rewrite -{1}(@det1 _ 1) -{2}(@det1 _ m) mulrA -(@det_lblock _ _ _ _ (- c)).
rewrite -det_mulmx mulmx_block ?(mul1mx,mul0mx,addr0) addrC mul_mx_scalar.
by rewrite scalerN subrr det_ublock det_scalar1 addrC mulNmx.
Qed.

(* The key lemma of our proof: after simplification, all the k-minors (involving *)
(* 1st line/column) can be divided by (M 0 0)^k-1 *)
Lemma key_lemma_sub m n k (M : 'M[R]_(1 + m,1 + n))
  (f : 'I_k -> 'I_m) (g : 'I_k -> 'I_n) :
  M 0 0 * (minor f g (M 0 0 *: drsubmx M - dlsubmx M *m ursubmx M)) =
  M 0 0 ^+ k * (minor (lift_pred f) (lift_pred g) M).
Proof.
rewrite /minor -{7}[M]submxK submatrix_add submatrix_scale submatrix_opp.
have -> : ulsubmx M = (M 0 0)%:M by apply/rowP=> i; rewrite ord1 !mxE !lshift0.
by rewrite submatrix_lift_block key_lemma submatrix_mul.
Qed.

End bareiss_comRingType.

(* Switch to polynomials over a commutative ring *)
Section bareiss_poly.

Variable R : comRingType.

(* Why is this not in the libraries? *)
Lemma monic_lreg (p : {poly R}) : p \is monic -> GRing.lreg p.
Proof. by rewrite monicE=> /eqP h; apply/lreg_lead; rewrite h; apply/lreg1. Qed.

Lemma bareiss_recE : forall m a (M : 'M[{poly R}]_(1 + m)),
  a \is monic ->
 (forall p (h h' : p < 1 + m), pminor h h' M \is monic) ->
 (forall k (f g : 'I_k.+1 -> 'I_m.+1), rdvdp (a ^+ k) (minor f g M)) ->
  a ^+ m * (bareiss_rec a M) = \det M.
Proof.
elim=> [a M _ _ _|m ih a M am hpm hdvd] /=.
  by rewrite expr0 mul1r {2}[M]mx11_scalar det_scalar1.
have ak_monic k : a ^+ k \in monic by apply/monic_exp.
set d := M 0 0; set M' := _ - _; set M'' := map_mx _ _; simpl in M'.
have d_monic : d \in monic.
  have -> // : d = pminor (ltn0Sn _) (ltn0Sn _) M.
  have h : widen_ord (ltn0Sn m.+1) =1 (fun _ => 0) 
    by move=> x; apply/ord_inj; rewrite [x]ord1.
  by rewrite /pminor (minor_eq h h) minor1.
have dk_monic : forall k, d ^+ k \in monic by move=> k; apply/monic_exp.
have hM' : M' = a *: M''.
  pose f := fun m (i : 'I_m) (x : 'I_2) => if x == 0 then 0 else (lift 0 i).
  apply/matrixP => i j.
  rewrite !mxE big_ord1 !rshift1 [a * _]mulrC rdivpK ?(eqP am,expr1n,mulr1) //.
  move: (hdvd 1%nat (f _ i) (f _ j)).
  by rewrite !minor2 /f /= expr1 !mxE !lshift0 !rshift1.
rewrite -[M]submxK; apply/(@lregX _ d m.+1 (monic_lreg d_monic)).
have -> : ulsubmx M = d%:M by apply/rowP=> i; rewrite !mxE ord1 lshift0.
rewrite key_lemma -/M' hM' detZ mulrCA [_ * (a ^+ _ * _)]mulrCA !exprS -!mulrA.
rewrite ih // => [p h h'|k f g].
  rewrite -(@monicMl _ (a ^+ p.+1)) // -detZ -submatrix_scale -hM'.
  rewrite -(monicMl _ d_monic) key_lemma_sub monicMr //.
  by rewrite (minor_eq (lift_pred_widen_ord h) (lift_pred_widen_ord h')) hpm.
case/rdvdpP: (hdvd _ (lift_pred f) (lift_pred g)) => // x hx.
apply/rdvdpP => //; exists x.
apply/(@lregX _ _ k.+1 (monic_lreg am))/(monic_lreg d_monic).
rewrite -detZ -submatrix_scale -hM' key_lemma_sub mulrA [x * _]mulrC mulrACA.
by rewrite -exprS [_ * x]mulrC -hx.
Qed.

Lemma bareissE n (M : 'M[{poly R}]_(1 + n)) 
  (H : forall p (h h' : p < 1 + n), pminor h h' M \is monic) :
  bareiss M = \det M.
Proof.
rewrite /bareiss -(@bareiss_recE n 1 M) ?monic1 ?expr1n ?mul1r //.
by move=> k f g; rewrite expr1n rdvd1p.
Qed.

Lemma bareiss_char_polyE n (M : 'M[R]_(1 + n)) : 
  bareiss_char_poly M = char_poly M.
Proof.
rewrite /bareiss_char_poly bareissE // => p h h'.
exact: pminor_char_poly_mx_monic.
Qed.

Lemma bdetE n (M : 'M[R]_(1 + n)) : bdet M = \det M.
Proof.
rewrite /bdet bareiss_char_polyE char_poly_det -scaleN1r detZ mulrA -expr2.
by rewrite sqrr_sign mul1r.
Qed.

End bareiss_poly.
End bareiss_correctness.

(* (* Test computations *) *)

(* (* *)
(*    WARNING never use compute, but vm_compute, *)
(*    otherwise it's painfully slow *)
(* *) *)
(* Require Import ZArith Zinfra. *)
(* Section test. *)

(* Definition excp n (M: Matrix [cringType Z of Z]) := ex_char_poly_mx n M. *)

(* Definition idZ n := @ident _ [cringType Z of Z] n. *)

(* Definition cpmxid2 := (excp 2 (idZ 2)). *)
(* Definition cpid2 := (exBareiss_rec 2 [:: 1%Z] cpmxid2). *)

(* Eval vm_compute in cpid2. *)

(* Definition detid2 := horner_seq cpid2 0%Z. *)

(* Eval vm_compute in detid2. *)

(* Definition M2 := cM 19%Z [:: 3%Z] [:: (-2)%Z] (cM 26%Z [::] [::] (@eM _ _)). *)

(* Definition cpmxM2 := excp 2 M2. *)
(* Definition cpM2 := exBareiss 2 cpmxM2. *)

(* Eval vm_compute in cpM2. *)
(* Eval vm_compute in ex_bdet 2 M2. *)

(* (* Random 3x3 matrix *) *)
(* Definition M3 := *)
(*   cM 10%Z [:: (-42%Z); 13%Z] [:: (-34)%Z; 77%Z] *)
(*      (cM 15%Z [:: 76%Z] [:: 98%Z] *)
(*          (cM 49%Z [::] [::] (@eM _ _))). *)

(* Time Eval vm_compute in ex_bdet 3 M3. *)

(* (* Random 10x10 matrix *) *)
(* Definition M10 := cM (-7)%Z [:: (-12)%Z ; (-15)%Z ; (-1)%Z ; (-8)%Z ; (-8)%Z ; 19%Z ; (-3)%Z ; (-8)%Z ; 20%Z] [:: 5%Z ; (-14)%Z ; (-12)%Z ; 19%Z ; 20%Z ; (-5)%Z ; (-3)%Z ; 8%Z ; 16%Z] (cM 1%Z [:: 16%Z ; (-18)%Z ; 8%Z ; (-13)%Z ; 18%Z ; (-6)%Z ; 10%Z ; 6%Z] [:: 5%Z ; 4%Z ; 0%Z ; 4%Z ; (-18)%Z ; (-19)%Z ; (-2)%Z ; 3%Z] (cM (-8)%Z [:: 1%Z ; (-10)%Z ; 12%Z ; 0%Z ; (-14)%Z ; 18%Z ; (-5)%Z] [:: (-14)%Z ; (-10)%Z ; 15%Z ; 0%Z ; 13%Z ; (-12)%Z ; (-16)%Z] (cM (-13)%Z [:: (-2)%Z ; (-14)%Z ; (-11)%Z ; 15%Z ; (-1)%Z ; 8%Z] [:: 6%Z ; 9%Z ; (-19)%Z ; (-19)%Z ; (-16)%Z ; (-10)%Z] (cM (-12)%Z [:: 1%Z ; (-5)%Z ; 16%Z ; 5%Z ; 6%Z] [:: 16%Z ; (-20)%Z ; 19%Z ; 16%Z ; 5%Z] (cM 2%Z [:: (-10)%Z ; (-3)%Z ; (-17)%Z ; 18%Z] [:: 4%Z ; (-4)%Z ; 20%Z ; (-7)%Z] (cM 4%Z [:: (-8)%Z ; 2%Z ; 9%Z] [:: 17%Z ; 10%Z ; 10%Z] (cM (-15)%Z [:: 16%Z ; 3%Z] [:: 5%Z ; (-1)%Z] (cM 3%Z [:: 4%Z] [:: (-12)%Z] ((@eM _ _)))))))))). *)

(* Time Eval vm_compute in ex_bdet 10 M10. *)

(* (* *)
(* (* Random 20x20 matrix *) *)
(* Definition M20 := cM (-17)%Z [:: 4%Z ; 9%Z ; 4%Z ; (-7)%Z ; (-4)%Z ; 16%Z ; (-13)%Z ; (-6)%Z ; (-4)%Z ; (-9)%Z ; 18%Z ; 7%Z ; 3%Z ; (-14)%Z ; 8%Z ; (-17)%Z ; 17%Z ; (-2)%Z ; 8%Z] [:: 0%Z ; 10%Z ; 17%Z ; (-7)%Z ; 3%Z ; 18%Z ; (-3)%Z ; 6%Z ; 2%Z ; (-7)%Z ; (-3)%Z ; 16%Z ; 7%Z ; (-9)%Z ; 15%Z ; (-17)%Z ; (-9)%Z ; (-18)%Z ; 9%Z] (cM 13%Z [:: (-3)%Z ; 9%Z ; 7%Z ; 4%Z ; 18%Z ; 2%Z ; 7%Z ; 9%Z ; (-10)%Z ; 18%Z ; 4%Z ; 13%Z ; (-16)%Z ; (-5)%Z ; 6%Z ; (-14)%Z ; 3%Z ; 12%Z] [:: 14%Z ; (-15)%Z ; 14%Z ; (-7)%Z ; 11%Z ; 10%Z ; (-10)%Z ; 9%Z ; (-4)%Z ; (-7)%Z ; (-4)%Z ; 7%Z ; (-10)%Z ; 15%Z ; (-4)%Z ; 12%Z ; (-18)%Z ; 4%Z] (cM 16%Z [:: (-5)%Z ; 8%Z ; 4%Z ; 8%Z ; 4%Z ; (-18)%Z ; 10%Z ; 3%Z ; (-12)%Z ; 12%Z ; 8%Z ; 11%Z ; (-12)%Z ; (-1)%Z ; 12%Z ; (-5)%Z ; (-10)%Z] [:: 1%Z ; (-15)%Z ; (-3)%Z ; (-3)%Z ; 6%Z ; (-3)%Z ; 18%Z ; 6%Z ; (-6)%Z ; (-10)%Z ; 15%Z ; 11%Z ; 6%Z ; (-4)%Z ; (-4)%Z ; 9%Z ; (-3)%Z] (cM (-12)%Z [:: 1%Z ; 6%Z ; 7%Z ; 5%Z ; 0%Z ; (-2)%Z ; 2%Z ; 14%Z ; 15%Z ; (-10)%Z ; (-14)%Z ; (-6)%Z ; 3%Z ; 17%Z ; (-11)%Z ; (-8)%Z] [:: (-15)%Z ; (-8)%Z ; 5%Z ; 18%Z ; 15%Z ; (-14)%Z ; 13%Z ; 17%Z ; 12%Z ; 16%Z ; (-18)%Z ; 13%Z ; 14%Z ; 17%Z ; (-8)%Z ; (-9)%Z] (cM (-17)%Z [:: (-12)%Z ; (-14)%Z ; (-7)%Z ; (-1)%Z ; 14%Z ; (-14)%Z ; (-13)%Z ; (-4)%Z ; 18%Z ; 13%Z ; (-9)%Z ; 15%Z ; (-10)%Z ; 18%Z ; 14%Z] [:: 8%Z ; (-14)%Z ; 9%Z ; 16%Z ; (-3)%Z ; (-8)%Z ; 9%Z ; (-9)%Z ; (-13)%Z ; 4%Z ; 15%Z ; 15%Z ; 6%Z ; (-14)%Z ; (-6)%Z] (cM 9%Z [:: 4%Z ; (-6)%Z ; 5%Z ; (-3)%Z ; (-6)%Z ; 18%Z ; 2%Z ; 10%Z ; 9%Z ; 17%Z ; (-12)%Z ; (-9)%Z ; 1%Z ; (-2)%Z] [:: (-10)%Z ; (-2)%Z ; 17%Z ; 14%Z ; 1%Z ; (-16)%Z ; 17%Z ; 18%Z ; (-3)%Z ; 4%Z ; (-14)%Z ; 17%Z ; 10%Z ; 7%Z] (cM 16%Z [:: (-15)%Z ; (-15)%Z ; (-18)%Z ; (-12)%Z ; 15%Z ; 7%Z ; (-11)%Z ; (-7)%Z ; (-8)%Z ; (-3)%Z ; (-17)%Z ; (-17)%Z ; (-12)%Z] [:: (-8)%Z ; 4%Z ; 12%Z ; (-7)%Z ; (-11)%Z ; 13%Z ; (-16)%Z ; 7%Z ; 16%Z ; (-1)%Z ; 16%Z ; 3%Z ; (-9)%Z] (cM (-15)%Z [:: 0%Z ; (-12)%Z ; 0%Z ; 16%Z ; 13%Z ; (-5)%Z ; 4%Z ; 1%Z ; 13%Z ; 11%Z ; 0%Z ; 16%Z] [:: 0%Z ; (-17)%Z ; (-10)%Z ; (-6)%Z ; 7%Z ; (-1)%Z ; 17%Z ; 8%Z ; 8%Z ; (-15)%Z ; (-16)%Z ; (-18)%Z] (cM 5%Z [:: 8%Z ; (-17)%Z ; (-15)%Z ; 0%Z ; 8%Z ; 1%Z ; (-2)%Z ; 14%Z ; 14%Z ; (-1)%Z ; (-7)%Z] [:: 14%Z ; (-11)%Z ; (-4)%Z ; (-18)%Z ; (-10)%Z ; (-11)%Z ; (-10)%Z ; (-6)%Z ; (-14)%Z ; (-13)%Z ; 5%Z] (cM (-7)%Z [:: 1%Z ; (-3)%Z ; (-7)%Z ; (-1)%Z ; 2%Z ; 14%Z ; 13%Z ; 7%Z ; 17%Z ; 7%Z] [:: 0%Z ; 1%Z ; (-7)%Z ; 12%Z ; (-1)%Z ; (-5)%Z ; (-12)%Z ; (-7)%Z ; 8%Z ; (-4)%Z] (cM 15%Z [:: (-18)%Z ; (-17)%Z ; 6%Z ; 1%Z ; (-13)%Z ; (-12)%Z ; 4%Z ; 13%Z ; 11%Z] [:: 12%Z ; 2%Z ; (-7)%Z ; (-18)%Z ; 0%Z ; 13%Z ; (-15)%Z ; (-16)%Z ; (-2)%Z] (cM 5%Z [:: (-9)%Z ; (-11)%Z ; 14%Z ; (-6)%Z ; (-11)%Z ; (-15)%Z ; (-12)%Z ; (-4)%Z] [:: (-12)%Z ; 8%Z ; (-8)%Z ; (-14)%Z ; 9%Z ; 3%Z ; 14%Z ; 3%Z] (cM (-18)%Z [:: 16%Z ; (-1)%Z ; 3%Z ; 11%Z ; 9%Z ; (-9)%Z ; 14%Z] [:: (-2)%Z ; (-7)%Z ; (-1)%Z ; 6%Z ; (-16)%Z ; 1%Z ; 6%Z] (cM 3%Z [:: (-8)%Z ; (-1)%Z ; (-1)%Z ; 15%Z ; 10%Z ; 6%Z] [:: 3%Z ; 7%Z ; 15%Z ; 12%Z ; 8%Z ; 5%Z] (cM (-14)%Z [:: (-2)%Z ; (-5)%Z ; 8%Z ; (-9)%Z ; 10%Z] [:: 12%Z ; 0%Z ; (-3)%Z ; 11%Z ; (-2)%Z] (cM 6%Z [:: (-8)%Z ; (-4)%Z ; (-9)%Z ; (-1)%Z] [:: 2%Z ; 5%Z ; (-8)%Z ; 0%Z] (cM (-14)%Z [:: (-8)%Z ; (-2)%Z ; 16%Z] [:: 11%Z ; 2%Z ; (-2)%Z] (cM 16%Z [:: (-14)%Z ; 9%Z] [:: (-17)%Z ; 8%Z] (cM (-18)%Z [:: (-11)%Z] [:: (-14)%Z] ((@eM _ _)))))))))))))))))))). *)

(* Time Eval vm_compute in ex_bdet 20 M20. *)

(*      = 75728050107481969127694371861%Z *)
(*      : CZmodule.Pack (Phant Z_comRingType) (CRing.class Z_cringType) *)
(*          Z_cringType *)
(* Finished transaction in 63. secs (62.825904u,0.016666s) *)
(* *) *)

(* End test. *)

(* (* Extraction Language Haskell. *) *)
(* (*  Extraction "Bareiss" ex_bdet. *) *)