(**************************************************************************)
(*                                                                        *)
(*  Copyright (C) 2010-                                                   *)
(*    Francois Bobot                                                      *)
(*    Jean-Christophe Filliatre                                           *)
(*    Johannes Kanig                                                      *)
(*    Andrei Paskevich                                                    *)
(*                                                                        *)
(*  This software is free software; you can redistribute it and/or        *)
(*  modify it under the terms of the GNU Library General Public           *)
(*  License version 2.1, with the special exception on linking            *)
(*  described in file LICENSE.                                            *)
(*                                                                        *)
(*  This software is distributed in the hope that it will be useful,      *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                  *)
(*                                                                        *)
(**************************************************************************)

open Why

type loc = Loc.position

type constant = Term.constant

type assertion_kind = Pgm_ptree.assertion_kind

type lazy_op = Pgm_ptree.lazy_op

(*****************************************************************************)
(* phase 1: destructive typing *)

type dreference = 
  | DRlocal  of string
  | DRglobal of Term.lsymbol

type deffect = {
  de_reads  : dreference list;
  de_writes : dreference list;
  de_raises : Term.lsymbol list;
}

type dpre = Denv.dfmla

type dpost = Denv.dfmla * (Term.lsymbol * Denv.dfmla) list

type dtype_v = 
  | DTpure of Denv.dty
  | DTarrow of dbinder list * dtype_c

and dtype_c = 
  { dc_result_type : dtype_v;
    dc_effect      : deffect;
    dc_pre         : dpre;
    dc_post        : dpost; }

and dbinder = string * dtype_v

type dvariant = Denv.dterm * Term.lsymbol

type dloop_annotation = {
  dloop_invariant : Denv.dfmla option;
  dloop_variant   : dvariant option;
}

type dexpr = {
  dexpr_desc  : dexpr_desc;
  dexpr_denv  : Typing.denv;
  dexpr_type  : Denv.dty;
  dexpr_type_v: dtype_v;
  dexpr_loc   : loc;
}

and dexpr_desc =
  | DEconstant of constant
  | DElocal of string
  | DEglobal of Term.lsymbol
  | DElogic of Term.lsymbol
  | DEapply of dexpr * dexpr
  | DEfun of dbinder list * dtriple
  | DElet of string * dexpr * dexpr
  | DEletrec of 
      ((string * Denv.dty) * dbinder list * dvariant option * dtriple) list * 
      dexpr

  | DEsequence of dexpr * dexpr
  | DEif of dexpr * dexpr * dexpr
  | DEloop of dloop_annotation * dexpr
  | DElazy of lazy_op * dexpr * dexpr
  | DEmatch of dexpr list * (Denv.dpattern list * dexpr) list
  | DEskip
  | DEabsurd 
  | DEraise of Term.lsymbol * dexpr option
  | DEtry of dexpr * (Term.lsymbol * string option * dexpr) list

  | DEassert of assertion_kind * Denv.dfmla
  | DElabel of string * dexpr
  | DEany of dtype_c

and dtriple = dpre * dexpr * dpost

(*****************************************************************************)
(* phase 2: typing annotations *)

type variant = Term.term * Term.lsymbol

type reference = Pgm_effect.reference

type pre = Pgm_types.pre

type post = Pgm_types.post

type type_v = Pgm_types.type_v

type type_c = Pgm_types.type_c

type binder = Pgm_types.binder

type loop_annotation = {
  loop_invariant : Term.fmla option;
  loop_variant   : variant option;
}

type label = Term.vsymbol

type iexpr = {
  iexpr_desc : iexpr_desc;
  iexpr_type : Ty.ty;
  iexpr_loc  : loc;
}

and iexpr_desc =
  | IElogic of Term.term
  | IElocal of Term.vsymbol
  | IEglobal of Term.lsymbol
  | IEapply of iexpr * Term.vsymbol
  | IEapply_ref of iexpr * reference
  | IEfun of binder list * itriple
  | IElet of Term.vsymbol * iexpr * iexpr
  | IEletrec of irecfun list * iexpr

  | IEsequence of iexpr * iexpr
  | IEif of iexpr * iexpr * iexpr
  | IEloop of loop_annotation * iexpr
  | IElazy of lazy_op * iexpr * iexpr
  | IEmatch of iexpr list * (Term.pattern list * iexpr) list
  | IEskip 
  | IEabsurd
  | IEraise of Term.lsymbol * iexpr option
  | IEtry of iexpr * (Term.lsymbol * Term.vsymbol option * iexpr) list

  | IEassert of assertion_kind * Term.fmla
  | IElabel of label * iexpr
  | IEany of type_c

and irecfun = Term.vsymbol * binder list * variant option * itriple

and itriple = pre * iexpr * post


(*****************************************************************************)
(* phase 3: inferring effects *)

type expr = {
  expr_desc  : expr_desc;
  expr_type  : Ty.ty;
  expr_type_v: type_v;
  expr_effect: Pgm_effect.t;
  expr_loc   : loc;
}

and expr_desc =
  | Elogic of Term.term
  | Elocal of Term.vsymbol
  | Eglobal of Term.lsymbol
  | Efun of binder list * triple
  | Elet of Term.vsymbol * expr * expr
  | Eletrec of recfun list * expr

  | Esequence of expr * expr
  | Eif of expr * expr * expr
  | Eloop of loop_annotation * expr
  | Elazy of lazy_op * expr * expr
  | Ematch of expr list * (Term.pattern list * expr) list
  | Eskip 
  | Eabsurd
  | Eraise of Term.lsymbol * expr option
  | Etry of expr * (Term.lsymbol * Term.vsymbol option * expr) list

  | Eassert of assertion_kind * Term.fmla
  | Eghost of expr
  | Elabel of label * expr
  | Eany of type_c

and recfun = Term.vsymbol * binder list * variant option * triple

and triple = pre * expr * post

type decl =
  | Dlet    of Term.lsymbol * expr
  | Dletrec of (Term.lsymbol * recfun) list
  | Dparam  of Term.lsymbol * type_v

type file = decl list


(*
Local Variables: 
compile-command: "unset LANG; make -C ../.. testl"
End: 
*)
