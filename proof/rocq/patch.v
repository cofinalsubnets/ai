(* proof/patch.v -- the PATCH GROUPOID, the first slice machine-checked in Rocq.

   The design lives in doc/proto/patch.l (the runnable toy + the argument that a
   distribution, a namespace, and a repo state are ONE algebra of selectable sets,
   with COMMUTE the primitive underneath). That toy DEMONSTRATES the laws at
   runtime; this file upgrades demonstrate toward PROVE -- the commute laws as
   theorems in a consistent metatheory.

   Scope: the NAMED-SLOT model -- a tree is a total map (key -> value), a patch is
   a single slot-change carrying its context (old -> new). This is darcs's "file
   of named lines" abstraction, where commutation is the CLEAN case (independent
   patches touch different slots and do not shift). Proven here, axiom-free:
     (L1) commute is involutive           commute_involutive
     (L2) inverse round-trips (in ctx)    invert_roundtrip
     (L3a) independent patches are        commute_sound  (the semantic heart:
           order-free                       reordering independent patches
                                            preserves the tree -- what MAKES
                                            merge/cherry-pick sound)
     (L3b) a FRONTIER is stable under      aponl_swap    (a whole patch list is
           reordering independent patches   invariant under an adjacent swap of
                                            independent patches -- the
                                            reproducibility tie: a frontier's
                                            MEANING does not depend on pull order,
                                            so its content-hash is a sound identity)

   Deliberately out of this first slice (the next rung, doc/proto/patch.l's
   "form-tree" fork): POSITIONAL / STRUCTURAL patches, where a commuted q' is a
   genuine re-aim (an index shift, a tree-path rewrite) rather than the identity,
   and CONFLICTORS -- the `None` branch of commute already models the partial
   merge, but the pushout/confluence law for the general structural case wants the
   rewrite/unifier machinery (wev, boxfix, kanren) and its own file. The full
   merge-as-pushout (L3 in the .l header) is that slice; the semantic core it
   rests on is proven below.

   Method note, matching gc.v / spec.v house rule: NO Axiom, NO Admitted, NO
   classical / funext escape hatch. Trees are functions, so equality of trees is
   POINTWISE (forall k, ...) throughout -- we never assume functional
   extensionality; every theorem quantifies the key.

   PROVENANCE -- this file is SCAFFOLDING, not the destination. It is hand-authored
   (spec.v tier), and a hand-authored proof model DRIFTS from the code it mirrors
   -- the lesson wm2uu already banked when it retired the hand StackSet model for a
   generated-and-gated one. The house pattern is: the ai implementation is the
   source of truth; the Rocq/Lean is EMITTED and drift-gated. Two rungs get us
   there. (1) An executable ai spec (test/patch.l) states the model + laws as
   asserts, green under `make test` -- the drift anchor. (2) The laws are
   universally quantified structural theorems, so tools/spec2coq.l (which only
   discharges CLOSED computations by vm_compute) can witness ground INSTANCES but
   cannot prove the forall; the real generator is the uu route -- encode L1..L3b as
   uu proof TERMS and let tools/uu2coq.l + tools/uu2lean.l emit them into BOTH
   kernels (as uugen.v / uugen.lean already do for ~200 laws). The named-slot model
   FITS uu's MLTT: pointwise equality (no funext), decidable Nat.eqb case-splits (no
   classical), list induction for the frontier. When that lands, this .v is
   DELETED. Until then it pins the theorem statements and proves the slice is real.

   Written by Claude (Anthropic), the Opus 4.8 model. *)

From Stdlib Require Import PeanoNat List.
Import ListNotations.

(* ============================================================ *)
(* the model: a named-slot tree and a context-carrying patch    *)
(* ============================================================ *)

(* A tree is a total map key -> value; both are nat. A missing slot is not a
   special case here -- a total map is the mathematical closure of the .l's
   "missing slot reads 0". *)
Definition tree := nat -> nat.

(* A patch touches one slot, carrying its context: it changes pk from pa to pb.
   The context (pa) is what makes a patch BELONG somewhere -- not a bare diff. *)
Record patch := mk { pk : nat ; pa : nat ; pb : nat }.

(* apon: lay a patch's new value at its slot (the .l's apon). *)
Definition apon (t : tree) (p : patch) : tree :=
  fun k => if Nat.eqb k (pk p) then pb p else t k.

(* valid: a patch belongs on t iff its context matches the current value. *)
Definition valid (t : tree) (p : patch) : bool := Nat.eqb (t (pk p)) (pa p).

(* invert: every patch has an inverse -- unpull is apply-the-inverse. *)
Definition invert (p : patch) : patch := mk (pk p) (pb p) (pa p).

(* commute: the ONE primitive. p;q -> q;p (partial: None when they collide on a
   slot -- a dependency). In this named model the swapped pair is (q,p) unchanged;
   the structural slice is where q' becomes a real re-aim. *)
Definition commute (p q : patch) : option (patch * patch) :=
  if Nat.eqb (pk p) (pk q) then None else Some (q, p).

(* aponl: fold a whole frontier (patch list) onto a tree. *)
Definition aponl (t : tree) (ps : list patch) : tree := fold_left apon ps t.

(* ============================================================ *)
(* (L1) commute is involutive                                   *)
(* ============================================================ *)

(* commute p q = (q',p')  =>  commute q' p' = (p,q). Reordering back is the same
   op -- the groupoid's swap is self-inverse. *)
Theorem commute_involutive : forall p q q' p',
  commute p q = Some (q', p') -> commute q' p' = Some (p, q).
Proof.
  intros p q q' p' H. unfold commute in *.
  destruct (Nat.eqb (pk p) (pk q)) eqn:E; [discriminate|].
  injection H as Hq Hp; subst q' p'.
  destruct (Nat.eqb (pk q) (pk p)) eqn:E2; [|reflexivity].
  apply Nat.eqb_eq in E2. apply Nat.eqb_neq in E. congruence.
Qed.

(* ============================================================ *)
(* (L2) inverse round-trips, in context                         *)
(* ============================================================ *)

(* If p belongs on t (valid), then applying p and then its inverse restores t
   -- pointwise. This is the groupoid inverse law, the honest (context-checked)
   version: without validity the old value is not recoverable. *)
Theorem invert_roundtrip : forall t p, valid t p = true ->
  forall k, apon (apon t p) (invert p) k = t k.
Proof.
  intros t p Hv k. unfold valid in Hv. apply Nat.eqb_eq in Hv.
  unfold apon, invert. simpl.
  destruct (Nat.eqb k (pk p)) eqn:E.
  - apply Nat.eqb_eq in E. subst k. symmetry. exact Hv.
  - reflexivity.
Qed.

(* ============================================================ *)
(* (L3a) independent patches are order-free -- the semantic core *)
(* ============================================================ *)

(* The raw form: distinct slots => the two application orders agree pointwise. *)
Lemma apon_comm : forall p q, pk p <> pk q ->
  forall t k, apon (apon t p) q k = apon (apon t q) p k.
Proof.
  intros p q H t k. unfold apon.
  destruct (Nat.eqb k (pk q)) eqn:Eq; destruct (Nat.eqb k (pk p)) eqn:Ep;
    try reflexivity.
  apply Nat.eqb_eq in Eq; apply Nat.eqb_eq in Ep; congruence.
Qed.

(* Tied to commute: a successful commute WITNESSES order-freedom. This is the law
   that makes merge and cherry-pick sound -- pulling p then q, or q then p, lands
   the same tree exactly when they commute. *)
Theorem commute_sound : forall p q,
  commute p q = Some (q, p) ->
  forall t k, apon (apon t p) q k = apon (apon t q) p k.
Proof.
  intros p q Hc. apply apon_comm. unfold commute in Hc.
  destruct (Nat.eqb (pk p) (pk q)) eqn:E; [discriminate|].
  apply Nat.eqb_neq in E. exact E.
Qed.

(* ============================================================ *)
(* (L3b) a frontier is stable under reordering independent patches *)
(* ============================================================ *)

(* Pointwise congruence for a single apon, then for a whole fold: applying the
   same patch list to pointwise-equal trees keeps them pointwise-equal. This is
   the lift that carries a local swap through the rest of the frontier. *)
Lemma apon_ext : forall t1 t2 p, (forall k, t1 k = t2 k) ->
  forall k, apon t1 p k = apon t2 p k.
Proof.
  intros t1 t2 p H k. unfold apon. destruct (Nat.eqb k (pk p)); auto.
Qed.

Lemma fold_apon_ext : forall ps t1 t2, (forall k, t1 k = t2 k) ->
  forall k, fold_left apon ps t1 k = fold_left apon ps t2 k.
Proof.
  induction ps as [|p ps IH]; intros t1 t2 H k; simpl.
  - apply H.
  - apply IH. intro k'. apply apon_ext. exact H.
Qed.

(* THE frontier theorem: a patch list is invariant (pointwise) under swapping any
   two adjacent INDEPENDENT patches. By induction on the general Permutation this
   lifts to "any reordering of a pairwise-independent frontier yields the same
   tree" -- the standard bubble-sort argument, the next slice. What that buys the
   distribution: a frontier's MEANING is order-free, so identifying a version by
   the (unordered) content-hash of its patch set is SOUND -- the reproducibility
   claim, resting here rather than on trust. *)
Theorem aponl_swap : forall pre p q post t,
  pk p <> pk q ->
  forall k, aponl t (pre ++ p :: q :: post) k = aponl t (pre ++ q :: p :: post) k.
Proof.
  intros pre p q post t Hpq k. unfold aponl.
  rewrite !fold_left_app. cbn [fold_left].
  apply fold_apon_ext. intro k'. apply apon_comm. exact Hpq.
Qed.
