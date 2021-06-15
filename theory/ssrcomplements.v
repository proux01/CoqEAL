(** This file is part of CoqEAL, the Coq Effective Algebra Library.
(c) Copyright INRIA and University of Gothenburg, see LICENSE *)
From mathcomp Require Import ssreflect ssrfun ssrbool eqtype ssrnat div seq path.
From mathcomp Require Import ssralg fintype finfun perm matrix bigop zmodp mxalgebra.
From mathcomp Require Import choice poly polydiv mxpoly binomial.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

(** This file contains definitions and lemmas that are generic enough that
we could try to integrate them in Math Components' library.
Definitions and theories are gathered according to the file of the
library which they could be moved to. *)

(** ** Informative version of [iff] *)

(** As CoqEAL now puts all relations in [Type], we define a compliant
version of [iff], named [ifft], along with view declarations *)
Inductive ifft (A B : Type) : Type := Ifft of (A -> B) & (B -> A).
Infix "<=>" := ifft (at level 95) : type_scope.

Section ApplyIfft.

Variables P Q : Type.
Hypothesis eqPQ : P <=> Q.

Lemma ifft1 : P -> Q. Proof. by case: eqPQ. Qed.
Lemma ifft2 : Q -> P. Proof. by case: eqPQ. Qed.

End ApplyIfft.

Hint View for move/ ifft1|2 ifft2|2.
Hint View for apply/ ifft1|2 ifft2|2.

Lemma ifftW (P Q : Prop) : P <=> Q -> (P <-> Q).
Proof. by case. Qed.

(********************* seq.v *********************)
Section Seqeqtype.

Variable T : eqType.
Variable leT : rel T.

Hypothesis leT_tr : transitive leT.

(* TODO: replace with drop_sorted *)
Lemma sorted_drop (s : seq T) m : sorted leT s -> sorted leT (drop m s).
Proof.
by elim: s m => //= a l ih [|n h] //; apply/ih/(path_sorted h).
Qed.

(* TODO: replace with take_sorted *)
Lemma sorted_take (s : seq T) m : sorted leT s -> sorted leT (take m s).
Proof.
move=> H; exact: (subseq_sorted leT_tr (take_subseq _ _) H).
Qed.

End Seqeqtype.

(* TODO: PR MathComp ? *)
(** ** map2 - Section taken from coq-interval *)
Section Map2.
Variables (A : Type) (B : Type) (C : Type).
Variable f : A -> B -> C.

Fixpoint map2 (s1 : seq A) (s2 : seq B) : seq C :=
  match s1, s2 with
    | a :: s3, b :: s4 => f a b :: map2 s3 s4
    | _, _ => [::]
  end.

Lemma size_map2 (s1 : seq A) (s2 : seq B) :
  size (map2 s1 s2) = minn (size s1) (size s2).
Proof.
elim: s1 s2 => [|x1 s1 IH1] [|x2 s2] //=.
by rewrite IH1 -addn1 addn_minl 2!addn1.
Qed.

Lemma nth_map2 s1 s2 (k : nat) da db dc :
  dc = f da db -> size s2 = size s1 ->
  nth dc (map2 s1 s2) k = f (nth da s1 k) (nth db s2 k).
Proof.
elim: s1 s2 k => [|x1 s1 IH1] s2 k Habc Hsize.
  by rewrite (size0nil Hsize) !nth_nil.
case: s2 IH1 Hsize =>[//|x2 s2] IH1 [Hsize].
case: k IH1 =>[//|k]; exact.
Qed.

End Map2.

(********************* matrix.v *********************)
Section Matrix.

Local Open Scope ring_scope.
Import GRing.Theory.

Section matrix_raw_type.

Variable T : Type.

(* TODO: PR MathComp ? *)
Lemma row_thin_mx  p q (M : 'M_(p,0)) (N : 'M[T]_(p,q)) :
  row_mx M N = N.
Proof.
apply/matrixP=> i j; rewrite mxE; case: splitP=> [|k H]; first by case.
by congr fun_of_matrix; exact: val_inj.
Qed.

(* TODO: PR MathComp ? *)
Lemma col_flat_mx p q (M : 'M[T]_(0, q)) (N : 'M_(p,q)) :
  col_mx M N = N.
Proof.
apply/matrixP=> i j; rewrite mxE; case: splitP => [|k H]; first by case.
by congr fun_of_matrix; exact: val_inj.
Qed.

End matrix_raw_type.

Section matrix_ringType.

Variable R : ringType.

(* TODO: PR MathComp ? *)
Lemma mulmx_rsub m n p k (A : 'M[R]_(m, n)) (B : 'M[R]_(n, p + k)) :
  A *m rsubmx B = (rsubmx (A *m B)).
Proof.
by apply/matrixP=> i j; rewrite !mxE; apply: eq_bigr => l //= _; rewrite mxE.
Qed.

(* TODO: PR MathComp ? *)
Lemma mulmx_lsub m n p k (A : 'M[R]_(m, n)) (B : 'M[R]_(n, p + k)) :
  A *m lsubmx B = (lsubmx (A *m B)).
Proof.
by apply/matrixP=> i j; rewrite !mxE; apply: eq_bigr => l //= _; rewrite mxE.
Qed.

(* TODO: PR MathComp ? *)
Lemma col_id_mulmx m n (M : 'M[R]_(m,n)) i :
  M *m col i 1%:M = col i M.
Proof.
apply/matrixP=> k l; rewrite !mxE.
rewrite (bigD1 i) // big1 /= ?addr0 ?mxE ?eqxx ?mulr1 // => j /negbTE neqji.
by rewrite !mxE neqji mulr0.
Qed.

(* TODO: PR MathComp ? *)
Lemma row_id_mulmx m n (M : 'M[R]_(m,n)) i :
   row i 1%:M *m M = row i M.
Proof.
apply/matrixP=> k l; rewrite !mxE.
rewrite (bigD1 i) // big1 /= ?addr0 ?mxE ?eqxx ?mul1r // => j /negbTE Hj.
by rewrite !mxE eq_sym Hj mul0r.
Qed.

(* TODO: PR MathComp ? *)
Lemma row'_col'_char_poly_mx m i (M : 'M[R]_m) :
  row' i (col' i (char_poly_mx M)) = char_poly_mx (row' i (col' i M)).
Proof.
apply/matrixP=> k l; rewrite !mxE.
suff ->: (lift i k == lift i l) = (k == l) => //.
by apply/inj_eq/lift_inj.
Qed.

(* TODO: PR MathComp ? *)
Lemma exp_block_mx m n (A: 'M[R]_m.+1) (B : 'M_n.+1) k :
  (block_mx A 0 0 B) ^+ k = block_mx (A ^+ k) 0 0 (B ^+ k).
Proof.
elim: k=> [|k IHk].
  by rewrite !expr0 -scalar_mx_block.
rewrite !exprS IHk /GRing.mul /= (mulmx_block A 0 0 B (A ^+ k)).
by rewrite !mulmx0 !mul0mx !add0r !addr0.
Qed.

(* TODO: PR MathComp ? *)
Lemma char_block_mx m n (A : 'M[R]_m) (B : 'M[R]_n) :
  char_poly_mx (block_mx A 0 0 B) =
  block_mx (char_poly_mx A) 0 0 (char_poly_mx B).
Proof.
apply/matrixP=> i j; rewrite !mxE.
case: splitP=> k Hk; rewrite !mxE; case: splitP=> l Hl; rewrite !mxE;
rewrite -!(inj_eq (@ord_inj _)) Hk Hl ?subr0 ?eqn_add2l //.
  by rewrite ltn_eqF // ltn_addr.
by rewrite gtn_eqF // ltn_addr.
Qed.

End matrix_ringType.

Section matrix_comUnitRingType.

Variable R : comUnitRingType.

(* TODO: PR MathComp ? *)
Lemma invmx_block n1 n2  (Aul : 'M[R]_n1.+1) (Adr : 'M[R]_n2.+1) :
   (block_mx Aul 0 0 Adr) \in unitmx ->
  (block_mx Aul 0 0 Adr)^-1 = block_mx Aul^-1 0 0 Adr^-1.
Proof.
move=> Hu.
have Hu2: (block_mx Aul 0 0 Adr) \is a GRing.unit by [].
rewrite unitmxE det_ublock unitrM in Hu.
case/andP: Hu; rewrite -!unitmxE => HAul HAur.
have H: block_mx Aul 0 0 Adr *  block_mx Aul^-1 0 0 Adr^-1 = 1.
  rewrite /GRing.mul /= (mulmx_block Aul _ _ _ Aul^-1) !mulmxV //.
  by rewrite !mul0mx !mulmx0 !add0r addr0 -scalar_mx_block.
by apply: (mulrI Hu2); rewrite H mulrV.
Qed.

End matrix_comUnitRingType.

End Matrix.

Section Poly.

Variable R : idomainType.
Import GRing.Theory.
Local Open Scope ring_scope.

(* TODO: PR MathComp ? *)
Lemma coprimep_factor (a b : R) : (b - a)%R \is a GRing.unit ->
   coprimep ('X - a%:P) ('X - b%:P).
Proof.
move=> Hab; apply/Bezout_coprimepP.
exists ((b - a)^-1%:P , -(b - a) ^-1%:P).
rewrite /= !mulrBr !mulNr opprK -!addrA (addrC (- _)) !addrA addrN.
by rewrite add0r -mulrBr -rmorphB -rmorphM mulVr // eqpxx.
Qed.

End Poly.

(****************************************************************************)
(****************************************************************************)
(************ left pseudo division, it is complement of polydiv. ************)
(****************************************************************************)
(****************************************************************************)
(* TODO: PR vers polydiv dans MathComp ? *)
Import GRing.Theory.
Import Pdiv.Ring.
Import Pdiv.RingMonic.

Local Open Scope ring_scope.

Module RPdiv.

Section RingPseudoDivision.

Variable R : ringType.
Implicit Types d p q r : {poly R}.

Definition id_converse_def := (fun x : R => x : R^c).
Lemma add_id : additive id_converse_def.
Proof. by []. Qed.

Definition id_converse := Additive add_id.

Lemma expr_rev (x : R) k : (x : R^c) ^+ k = x ^+ k.
Proof. by elim:k=> // k IHk; rewrite exprS exprSr IHk. Qed.

Definition phi (p : {poly R}^c) := map_poly id_converse p.

Fact phi_is_rmorphism : rmorphism phi.
Proof.
split=> //; first exact:raddfB.
split=> [p q|]; apply/polyP=> i; last by rewrite coef_map !coef1.
by rewrite coefMr coef_map coefM; apply: eq_bigr => j _; rewrite !coef_map.
Qed.

Canonical phi_rmorphism := RMorphism phi_is_rmorphism.

Definition phi_inv (p : {poly R^c}) :=
  map_poly (fun x : R^c => x : R) p : {poly R}^c.

Lemma phiK : cancel phi phi_inv.
Proof. by move=> p; rewrite /phi_inv -map_poly_comp_id0 // map_poly_id. Qed.

Lemma phi_invK : cancel phi_inv phi.
Proof. by move=> p; rewrite /phi -map_poly_comp_id0 // map_poly_id. Qed.

Lemma phi_bij : bijective phi.
Proof. by exists phi_inv; first exact: phiK; exact: phi_invK. Qed.

Lemma monic_map_inj (aR rR : ringType) (f : aR -> rR) (p : {poly aR}) :
  injective f -> f 0 = 0 -> f 1 = 1 -> map_poly f p \is monic = (p \is monic).
Proof.
move=> inj_f eq_f00 eq_f11; rewrite !monicE lead_coef_map_inj ?rmorph0 //.
by rewrite -eq_f11 inj_eq.
Qed.

Definition redivp_l (p q : {poly R}) : nat * {poly R} * {poly R} :=
  let:(d,q,p) := (redivp (phi p) (phi q)) in
  (d, phi_inv q, phi_inv p).

Definition rdivp_l p q := ((redivp_l p q).1).2.
Definition rmodp_l p q := (redivp_l p q).2.
Definition rscalp_l p q := ((redivp_l p q).1).1.
Definition rdvdp_l p q := rmodp_l q p == 0.
Definition rmultp_l := [rel m d | rdvdp_l d m].

Lemma ltn_rmodp_l p q : (size (rmodp_l p q) < size q) = (q != 0).
Proof.
have := ltn_rmodp (phi p) (phi q).
rewrite -(rmorph0 phi_rmorphism) (inj_eq (can_inj phiK)) => <-.
rewrite /rmodp_l /redivp_l /rmodp; case: (redivp _ _)=> [[k q'] r'] /=.
by rewrite !size_map_inj_poly.
Qed.

End RingPseudoDivision.

Module mon.

Section MonicDivisor.

Variable R : ringType.
Implicit Types p q r : {poly R}.

Variable d : {poly R}.
Hypothesis mond : d \is monic.

Lemma rdivp_l_eq p :
  p = d * (rdivp_l p d) + (rmodp_l p d).
Proof.
have mon_phi_d: phi d \is monic by rewrite monic_map_inj.
apply:(can_inj (@phiK R)); rewrite {1}[phi p](rdivp_eq mon_phi_d) rmorphD.
rewrite rmorphM /rdivp_l /rmodp_l /redivp_l /rdivp /rmodp.
by case: (redivp _ _)=> [[k q'] r'] /=; rewrite !phi_invK.
Qed.

End MonicDivisor.

End mon.

End RPdiv.


Section prelude.
Variable R : comRingType.

Let lreg := GRing.lreg.
Let rreg := GRing.rreg.

(* TODO: PR MathComp ? *)
Lemma monic_lreg (p : {poly R}) : p \is monic -> lreg p.
Proof. by rewrite monicE=> /eqP lp1; apply/lreg_lead; rewrite lp1; apply/lreg1. Qed.

(* TODO: PR MathComp ? *)
Lemma monic_rreg (p : {poly R}) : p \is monic -> rreg p.
Proof. by rewrite monicE=> /eqP lp1; apply/rreg_lead; rewrite lp1; apply/rreg1. Qed.

(* TODO: PR MathComp ? *)
Lemma lregMl (a b: R) : lreg (a * b) -> lreg b.
Proof. by move=> rab c c' eq_bc;  apply/rab; rewrite -!mulrA eq_bc. Qed.

(* TODO: PR MathComp ? *)
Lemma rregMr (a b: R) : rreg (a * b) -> rreg a.
Proof. by move=> rab c c' eq_ca;  apply/rab; rewrite !mulrA eq_ca. Qed.

End prelude.

(****************************************************************************)
(****************************************************************************)
(****************************************************************************)
(****************************************************************************)
