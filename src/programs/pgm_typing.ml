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

open Format
open Why
open Util
open Ident
open Ty
open Term
open Theory
open Denv
open Ptree
open Pgm_effect
open Pgm_ttree
open Pgm_types

let debug = ref false

type error =
  | Message of string

exception Error of error

let error ?loc e = match loc with
  | None -> raise (Error e)
  | Some loc -> raise (Loc.Located (loc, Error e))

let errorm ?loc f =
  let buf = Buffer.create 512 in
  let fmt = Format.formatter_of_buffer buf in
  Format.kfprintf
    (fun _ ->
       Format.pp_print_flush fmt ();
       let s = Buffer.contents buf in
       Buffer.clear buf;
       error ?loc (Message s))
    fmt f

let report fmt = function
  | Message s ->
      fprintf fmt "%s" s

let id_result = "result"

(* parsing LOGIC strings using functions from src/parser/
   requires proper relocation *)

let reloc loc lb =
  lb.Lexing.lex_curr_p <- loc;
  lb.Lexing.lex_abs_pos <- loc.Lexing.pos_cnum
    
let parse_string f loc s =
  let lb = Lexing.from_string s in
  reloc loc lb;
  f lb

let logic_list0_decl (loc, s) = parse_string Lexer.parse_list0_decl loc s
  
let lexpr (loc, s) = parse_string Lexer.parse_lexpr loc s

(* phase 1: typing programs (using destructive type inference) **************)

let dty_bool gl = Tyapp (gl.ts_bool, [])
let dty_unit gl = Tyapp (gl.ts_unit, [])
let dty_label gl = Tyapp (gl.ts_label, [])

type denv = {
  env   : env;
  locals: dtype_v Mstr.t;
  denv  : Typing.denv;
}

let create_denv gl = 
  { env = gl;
    locals = Mstr.empty;
    denv = Typing.create_denv gl.uc; }

let rec specialize_type_v ~loc htv = function
  | Tpure ty ->
      DTpure (Denv.specialize_ty ~loc htv ty)
  | Tarrow (bl, c) ->
      DTarrow (List.map (specialize_binder ~loc htv) bl, 
	       specialize_type_c ~loc htv c)

and specialize_type_c ~loc htv c =
  { dc_result_type = specialize_type_v ~loc htv c.c_result_type;
    dc_effect      = specialize_effect c.c_effect;
    dc_pre         = specialize_fmla ~loc htv c.c_pre;
    dc_post        = specialize_post ~loc htv c.c_post; }

and specialize_binder ~loc htv (vs, tyv) =
  vs.vs_name.id_string, specialize_type_v ~loc htv tyv

let specialize_global loc x gl =
  let s, tyv = Mstr.find x gl.globals in
  s, specialize_type_v loc (Htv.create 17) tyv

let specialize_exception loc x gl =
  if not (Mstr.mem x gl.exceptions) then errorm ~loc "unbound exception %s" x;
  let s = Mstr.find x gl.exceptions in
  match Denv.specialize_lsymbol ~loc s with
    | tyl, Some ty -> s, tyl, ty
    | _, None -> assert false

let create_type_var loc =
  let tv = Ty.create_tvsymbol (id_user "a" loc) in
  Tyvar (create_ty_decl_var ~loc ~user:false tv)

let dcurrying gl tyl ty =
  let make_arrow_type ty1 ty2 = Tyapp (gl.ts_arrow, [ty1; ty2]) in
  List.fold_right make_arrow_type tyl ty

let uncurrying gl ty =
  let rec uncurry acc ty = match ty.ty_node with
    | Ty.Tyapp (ts, [t1; t2]) when ts_equal ts gl.ts_arrow -> 
	uncurry (t1 :: acc) t2
    | _ -> 
	List.rev acc, ty
  in
  uncurry [] ty

let expected_type e ty =
  if not (Denv.unify e.dexpr_type ty) then
    errorm ~loc:e.dexpr_loc 
      "this expression has type %a, but is expected to have type %a"
      print_dty e.dexpr_type print_dty ty

let pure_type env = Typing.dty env.denv

let rec dpurify env = function
  | DTpure ty -> 
      ty
  | DTarrow (bl, c) -> 
      dcurrying env.env (List.map (fun (_,ty) -> dpurify env ty) bl)
	(dpurify env c.dc_result_type)

let check_reference_type gl loc ty =
  let ty_ref = Tyapp (gl.ts_ref, [create_type_var loc]) in
  if not (Denv.unify ty ty_ref) then
    errorm ~loc "this expression has type %a, but is expected to be a reference"
      print_dty ty
  
let dreference env id =
  if Typing.mem_var id.id env.denv then
    (* local variable *)
    let ty = Typing.find_var id.id env.denv in
    check_reference_type env.env id.id_loc ty;
    DRlocal id.id
  else 
    let p = Qident id in
    let s, _, ty = Typing.specialize_fsymbol p env.env.uc in
    check_reference_type env.env id.id_loc ty;
    DRglobal s

let dexception env id =
  let _, _, ty as r = specialize_exception id.id_loc id.id env.env in
  let ty_exn = Tyapp (env.env.ts_exn, []) in
  if not (Denv.unify ty ty_exn) then
    errorm ~loc:id.id_loc
      "this expression has type %a, but is expected to be an exception"
      print_dty ty;
  r

let deffect env e =
  { de_reads  = List.map (dreference env) e.Pgm_ptree.pe_reads;
    de_writes = List.map (dreference env) e.Pgm_ptree.pe_writes;
    de_raises = 
      List.map (fun id -> let ls,_,_ = dexception env id in ls) 
	e.Pgm_ptree.pe_raises; }

let dpost env ty (q, ql) =
  let dexn (id, l) =
    let s, tyl, _ = dexception env id in
    let denv = match tyl with
      | [] -> env.denv
      | [ty] -> Typing.add_var id_result ty env.denv
      | _ -> assert false
    in
    s, (denv, lexpr l)
  in
  let denv = Typing.add_var id_result ty env.denv in
  (denv, lexpr q), List.map dexn ql

let rec dtype_v env = function
  | Pgm_ptree.Tpure pt -> 
      DTpure (pure_type env pt)
  | Pgm_ptree.Tarrow (bl, c) -> 
      let env, bl = map_fold_left dbinder env bl in
      let c = dtype_c env c in
      DTarrow (bl, c) 

and dtype_c env c = 
  let ty = dtype_v env c.Pgm_ptree.pc_result_type in
  { dc_result_type = ty;
    dc_effect      = deffect env c.Pgm_ptree.pc_effect;
    dc_pre         = env.denv, lexpr c.Pgm_ptree.pc_pre;
    dc_post        = dpost env (dpurify env ty) c.Pgm_ptree.pc_post;
  }

and dbinder env ({id=x; id_loc=loc}, v) =
  let v = match v with
    | Some v -> dtype_v env v 
    | None -> DTpure (create_type_var loc)
  in
  let ty = dpurify env v in
  let env = { env with denv = Typing.add_var x ty env.denv } in
  env, (x, v)

let dvariant uc (l, p) =
  let l = lexpr l in
  let s, _ = Typing.specialize_psymbol p uc in
  let loc = Typing.qloc p in
  begin match s.ls_args with
    | [t1; t2] when Ty.ty_equal t1 t2 -> 
	()
    | _ -> 
	errorm ~loc "predicate %s should be a binary relation" 
	  s.ls_name.id_string
  end;
  l, s

let dloop_annotation uc a =
  { dloop_invariant = option_map lexpr a.Pgm_ptree.loop_invariant;
    dloop_variant   = option_map (dvariant uc) a.Pgm_ptree.loop_variant; }

let rec dexpr env e = 
  let d, tyv = dexpr_desc env e.Pgm_ptree.expr_loc e.Pgm_ptree.expr_desc in
  let ty = dpurify env tyv in
  { dexpr_desc = d; dexpr_loc = e.Pgm_ptree.expr_loc;
    dexpr_denv = env.denv; dexpr_type = ty; dexpr_type_v = tyv }

and dexpr_desc env loc = function
  | Pgm_ptree.Econstant (ConstInt _ as c) ->
      DEconstant c, DTpure (Tyapp (Ty.ts_int, []))
  | Pgm_ptree.Econstant (ConstReal _ as c) ->
      DEconstant c, DTpure (Tyapp (Ty.ts_real, []))
  | Pgm_ptree.Eident (Qident {id=x}) when Mstr.mem x env.locals ->
      (* local variable *)
      let ty = Mstr.find x env.locals in
      DElocal x, ty
  | Pgm_ptree.Eident (Qident {id=x}) when Mstr.mem x env.env.globals ->
      (* global variable *)
      let s, tyv = specialize_global loc x env.env in
      DEglobal s, tyv
  | Pgm_ptree.Eident p ->
      let s, tyl, ty = Typing.specialize_fsymbol p env.genv.uc in
      DElogic s, DTpure (dcurrying env.genv tyl ty)
  | Pgm_ptree.Eapply (e1, e2) ->
      let e1 = dexpr env e1 in
      let e2 = dexpr env e2 in
      let ty2 = create_type_var loc and ty = create_type_var loc in
      if not (Denv.unify e1.dexpr_type (Tyapp (env.genv.ts_arrow, [ty2; ty]))) 
      then
	errorm ~loc:e1.dexpr_loc "this expression is not a function";
      expected_type e2 ty2;
      DEapply (e1, e2), ty
  | Pgm_ptree.Efun (bl, t) ->
      let env, bl = map_fold_left dbinder env bl in
      let (_,e,_) as t = dtriple env t in
      let tyl = List.map (fun (x,_) -> Typing.find_var x env.denv) bl in
      let ty = dcurrying env.genv tyl e.dexpr_type in
      DEfun (bl, t), ty
  | Pgm_ptree.Elet ({id=x}, e1, e2) ->
      let e1 = dexpr env e1 in
      let ty1 = e1.dexpr_type in
      let env = { env with denv = Typing.add_var x ty1 env.denv } in
      let e2 = dexpr env e2 in
      DElet (x, e1, e2), e2.dexpr_type
  | Pgm_ptree.Eletrec (dl, e1) ->
      let env, dl = dletrec env dl in
      let e1 = dexpr env e1 in
      DEletrec (dl, e1), e1.dexpr_type
  | Pgm_ptree.Etuple el ->
      let n = List.length el in
      let s = Typing.fs_tuple n in
      let tyl = List.map (fun _ -> create_type_var loc) el in
      let ty = Tyapp (Typing.ts_tuple n, tyl) in
      let create d ty = 
	{ dexpr_desc = d; dexpr_denv = env.denv;
	  dexpr_type = ty; dexpr_loc = loc }
      in
      let apply e1 e2 ty2 = 
	let e2 = dexpr env e2 in
	assert (Denv.unify e2.dexpr_type ty2);
	let ty = create_type_var loc in
	assert (Denv.unify e1.dexpr_type 
		  (Tyapp (env.genv.ts_arrow, [ty2; ty])));
	create (DEapply (e1, e2)) ty
      in
      let e = create (DElogic s) (dcurrying env.genv tyl ty) in
      let e = List.fold_left2 apply e el tyl in
      e.dexpr_desc, ty

  | Pgm_ptree.Esequence (e1, e2) ->
      let e1 = dexpr env e1 in
      expected_type e1 (dty_unit env.genv);
      let e2 = dexpr env e2 in
      DEsequence (e1, e2), e2.dexpr_type
  | Pgm_ptree.Eif (e1, e2, e3) ->
      let e1 = dexpr env e1 in
      expected_type e1 (dty_bool env.genv);
      let e2 = dexpr env e2 in
      let e3 = dexpr env e3 in
      expected_type e3 e2.dexpr_type;
      DEif (e1, e2, e3), e2.dexpr_type
  | Pgm_ptree.Eloop (a, e1) ->
      let e1 = dexpr env e1 in
      expected_type e1 (dty_unit env.genv);
      DEloop (dloop_annotation env.genv.uc a, e1), (dty_unit env.genv)
  | Pgm_ptree.Elazy (op, e1, e2) ->
      let e1 = dexpr env e1 in
      expected_type e1 (dty_bool env.genv);
      let e2 = dexpr env e2 in
      expected_type e2 (dty_bool env.genv);
      DElazy (op, e1, e2), (dty_bool env.genv)
  | Pgm_ptree.Ematch (el, bl) ->
      let el = List.map (dexpr env) el in
      let tyl = List.map (fun e -> e.dexpr_type) el in
      let ty = create_type_var loc in (* the type of all branches *)
      let branch (pl, e) =
	let denv, pl = Typing.dpat_list env.denv tyl pl in
	let env = { env with denv = denv } in
	let e = dexpr env e in
	expected_type e ty;
	pl, e
      in
      let bl = List.map branch bl in
      DEmatch (el, bl), ty
  | Pgm_ptree.Eskip ->
      DEskip, (dty_unit env.genv)
  | Pgm_ptree.Eabsurd ->
      DEabsurd, create_type_var loc
  | Pgm_ptree.Eraise (id, e) ->
      let ls, tyl, _ = dexception env id in
      let e = match e, tyl with
	| None, [] ->  
	    None
	| Some _, [] ->
	    errorm ~loc "expection %s has no argument" id.id
	| None, [ty] ->
	    errorm ~loc "exception %s is expecting an argument of type %a"
	      id.id print_dty ty;
	| Some e, [ty] -> 
	    let e = dexpr env e in
	    expected_type e ty;
	    Some e
	| _ -> 
	    assert false
      in
      DEraise (ls, e), create_type_var loc
  | Pgm_ptree.Etry (e1, hl) ->
      let e1 = dexpr env e1 in
      let handler (id, x, h) =
	let ls, tyl, _ = dexception env id in
	let x, env = match x, tyl with
	  | Some _, [] -> 
	      errorm ~loc "expection %s has no argument" id.id
	  | None, [] -> 
	      None, env
	  | None, [ty] ->
	      errorm ~loc "exception %s is expecting an argument of type %a"
		id.id print_dty ty;
	  | Some x, [ty] -> 
	      Some x.id, { env with denv = Typing.add_var x.id ty env.denv } 
	  | _ ->
	      assert false
	in
	let h = dexpr env h in
	expected_type h e1.dexpr_type;
	(ls, x, h)
      in
      DEtry (e1, List.map handler hl), e1.dexpr_type

  | Pgm_ptree.Eassert (k, le) ->
      DEassert (k, lexpr le), dty_unit env.genv
  | Pgm_ptree.Elabel ({id=s}, e1) ->
      if Typing.mem_var s env.denv then 
	errorm ~loc "clash with previous label %s" s;
      let ty = dty_label env.genv in
      let env = { env with denv = Typing.add_var s ty env.denv } in
      let e1 = dexpr env e1 in
      DElabel (s, e1), e1.dexpr_type
  | Pgm_ptree.Ecast (e1, ty) ->
      let e1 = dexpr env e1 in
      let ty = pure_type env ty in
      expected_type e1 ty;
      e1.dexpr_desc, ty
  | Pgm_ptree.Eany c ->
      let c = dtype_c env c in
      DEany c, dpurify env c.dc_result_type

and dletrec env dl =
  (* add all functions into environment *)
  let add_one env (id, bl, var, t) = 
    let ty = create_type_var id.id_loc in
    let env = { env with denv = Typing.add_var id.id ty env.denv } in
    env, ((id, ty), bl, option_map (dvariant env.genv.uc) var, t)
  in
  let env, dl = map_fold_left add_one env dl in
  (* then type-check all of them and unify *)
  let type_one ((id, tyres), bl, v, t) = 
    let env, bl = map_fold_left dbinder env bl in
    let (_,e,_) as t = dtriple env t in
    let tyl = List.map (fun (x,_) -> Typing.find_var x env.denv) bl in
    let ty = dcurrying env.genv tyl e.dexpr_type in
    if not (Denv.unify ty tyres) then 
      errorm ~loc:id.id_loc
	"this expression has type %a, but is expected to have type %a"
	print_dty ty print_dty tyres;
    ((id.id, tyres), bl, v, t)
  in
  env, List.map type_one dl

and dtriple env (p, e, q) =     
  let p = env.denv, lexpr p in
  let e = dexpr env e in
  let ty = e.dexpr_type in
  let q = dpost env ty q in
  (p, e, q)

(* phase 2: remove destructive types and type annotations *****************)

let reference _uc env = function
  | DRlocal x -> Rlocal (Mstr.find x env)
  | DRglobal ls -> Rglobal ls

let effect uc env e =
  let reads ef r = add_read (reference uc env r) ef in
  let writes ef r = add_write (reference uc env r) ef in
  let raises ef l = add_raise l ef in
  let ef = List.fold_left reads Pgm_effect.empty e.de_reads in
  let ef = List.fold_left writes ef e.de_writes in
  List.fold_left raises ef e.de_raises

let pre env (denv, l) = Typing.type_fmla denv env l

let post env ty (q, ql) =
  let exn (ls, (denv, l)) =
    let v, env = match ls.ls_args with
      | [] -> 
	  None, env
      | [ty] -> 
	  let v_result = create_vsymbol (id_fresh id_result) ty in
	  Some v_result, Mstr.add id_result v_result env
      | _ -> 
	  assert false
    in
    (ls, (v, Typing.type_fmla denv env l))
  in
  let denv, l = q in 
  let v_result = create_vsymbol (id_fresh id_result) ty in
  let env = Mstr.add id_result v_result env in
  (v_result, Typing.type_fmla denv env l), List.map exn ql

let variant denv env (t, ps) =
  let loc = t.pp_loc in
  let t = Typing.type_term denv env t in
  match ps.ls_args with
    | [t1; _] when Ty.ty_equal t1 t.t_ty -> 
	t, ps
    | [t1; _] -> 
	errorm ~loc "variant has type %a, but is expected to have type %a"
	  Pretty.print_ty t.t_ty Pretty.print_ty t1
    | _ -> 
	assert false

let rec type_v uc env = function
  | DTpure ty -> 
      Tpure (Denv.ty_of_dty ty)
  | DTarrow (bl, c) -> 
      let env, bl = map_fold_left (binder uc) env bl in
      Tarrow (bl, type_c uc env c)

and type_c uc env c = 
  let tyv = type_v uc env c.dc_result_type in
  let ty = purify uc tyv in
  { c_result_type = tyv;
    c_effect      = effect uc env c.dc_effect;
    c_pre         = pre env c.dc_pre;
    c_post        = post env ty c.dc_post;
  }
    
and binder uc env (x, tyv) = 
  let tyv = type_v uc env tyv in
  let v = create_vsymbol (id_fresh x) (purify uc tyv) in
  let env = Mstr.add x v env in
  env, (v, tyv)

let mk_iexpr loc ty d = { iexpr_desc = d; iexpr_loc = loc; iexpr_type = ty }

(* apply ls to a list of expressions, introducing let's if necessary

  ls [e1; e2; ...; en]
->
  let x1 = e1 in
  let x2 = e2 in
  ...
  let xn = en in
  ls(x1,x2,...,xn)
*)
let make_logic_app loc ty ls el =
  let rec make args = function
    | [] -> 
	IElogic (t_app ls (List.rev args) ty)
    | ({ expr_desc = IElogic t }, _) :: r ->
	make (t :: args) r
    | ({ expr_desc = IElocal vs }, _) :: r ->
	make (t_var vs :: args) r
    | ({ expr_desc = IEglobal ls; expr_type = ty }, _) :: r ->
	make (t_app ls [] ty :: args) r
    | (e, _) :: r ->
	let v = create_vsymbol (id_fresh "x") e.expr_type in
	let d = mk_iexpr loc ty (make (t_var v :: args) r) in
	Elet (v, e, d)
  in
  make [] el

let is_reference_type gl ty  = match ty.ty_node with
  | Ty.Tyapp (ts, _) -> Ty.ts_equal ts gl.ts_ref
  | _ -> false

(* same thing, but for an abritrary expression f (not an application)
   f [e1; e2; ...; en]
-> let x1 = e1 in ... let xn = en in (...((f x1) x2)... xn)
*)
let make_app gl loc ty f el =
  let rec make k = function
    | [] ->
	k f
    | ({ iexpr_type = ty } as e, tye) :: r when is_reference_type gl ty ->
	begin match e.iexpr_desc with
	  | IElocal v -> 
	      make (fun f -> mk_iexpr loc tye (IEapply_ref (k f, Rlocal v))) r
	  | IEglobal v ->
	      make (fun f -> mk_iexpr loc tye (IEapply_ref (k f, Rglobal v))) r
	  | _ ->
	      let v = create_vsymbol (id_fresh "x") e.expr_type in
	      let d = 
		make (fun f -> mk_iexpr loc tye (IEapply_ref (k f, Rlocal v))) r
	      in
	      mk_iexpr loc ty (Elet (v, e, d))
	end
    | ({ expr_desc = IElocal v }, tye) :: r ->
	make (fun f -> mk_iexpr loc tye (IEapply (k f, v))) r
    | (e, tye) :: r ->
	let v = create_vsymbol (id_fresh "x") e.expr_type in
	let d = make (fun f -> mk_iexpr loc tye (IEapply (k f, v))) r in
	mk_iexpr loc ty (IElet (v, e, d))
  in
  make (fun f -> f) el

let rec iexpr gl env e =
  let ty = Denv.ty_of_dty e.dexpr_type in
  let d = iexpr_desc gl env e.dexpr_denv e.dexpr_loc ty e.dexpr_desc in
  { expr_desc = d; expr_type = ty; expr_loc = e.dexpr_loc }

and iexpr_desc gl env denv loc ty = function
  | DEconstant c ->
      IElogic (t_const c ty)
  | DElocal x ->
      IElocal (Mstr.find x env)
  | DEglobal ls ->
      IEglobal ls
  | DElogic ls ->
      begin match ls.ls_args with
	| [] -> 
	    Elogic (t_app ls [] ty)
	| al -> 
	    errorm ~loc "function symbol %s is expecting %d arguments"
	      ls.ls_name.id_string (List.length al)
      end
  | DEapply (e1, e2) ->
      let f, args = decompose_app gl env e1 [iexpr gl env e2, ty] in
      begin match f.dexpr_desc with
	| DElogic ls ->
	    let n = List.length ls.ls_args in
	    if List.length args <> n then 
	      errorm ~loc "function symbol %s is expecting %d arguments"
		ls.ls_name.id_string n;
	    make_logic_app loc ty ls args
	| _ ->
	    let f = iexpr gl env f in
	    (make_app gl loc ty f args).iexpr_desc
      end
  | DEfun (bl, e1) ->
      let env, bl = map_fold_left (binder gl.uc) env bl in
      IEfun (bl, triple gl env e1)
  | DElet (x, e1, e2) ->
      let e1 = iexpr gl env e1 in
      let v = create_vsymbol (id_fresh x) e1.iexpr_type in
      let env = Mstr.add x v env in
      IElet (v, e1, iexpr gl env e2)
  | DEletrec (dl, e1) ->
      let env, dl = letrec gl env dl in
      let e1 = iexpr gl env e1 in
      IEletrec (dl, e1)

  | DEsequence (e1, e2) ->
      IEsequence (iexpr gl env e1, iexpr gl env e2)
  | DEif (e1, e2, e3) ->
      IEif (iexpr gl env e1, iexpr gl env e2, iexpr gl env e3)
  | DEloop (la, e1) ->
      let la = 
	{ loop_invariant = 
	    option_map (Typing.type_fmla denv env) la.dloop_invariant;
	  loop_variant   = 
	    option_map (variant denv env) la.dloop_variant; }
      in
      IEloop (la, iexpr gl env e1)
  | DElazy (op, e1, e2) ->
      IElazy (op, iexpr gl env e1, iexpr gl env e2)
  | DEmatch (el, bl) ->
      let el = List.map (iexpr gl env) el in
      let branch (pl, e) = 
        let env, pl = map_fold_left Typing.pattern env pl in
        (pl, iexpr gl env e)
      in
      let bl = List.map branch bl in
      IEmatch (el, bl)
  | DEskip ->
      IEskip
  | DEabsurd ->
      IEabsurd
  | DEraise (ls, e) ->
      IEraise (ls, option_map (iexpr gl env) e)
  | DEtry (e, hl) ->
      let handler (ls, x, h) =
	let x, env = match x with
	  | Some x -> 
	      let ty = match ls.ls_args with [ty] -> ty | _ -> assert false in
	      let v = create_vsymbol (id_fresh x) ty in
	      Some v, Mstr.add x v env 
	  | None ->
	      None, env
	in
	(ls, x, iexpr gl env h)
      in
      IEtry (iexpr gl env e, List.map handler hl)

  | DEassert (k, f) ->
      let f = Typing.type_fmla denv env f in
      IEassert (k, f)
  | DElabel (s, e1) ->
      let ty = Ty.ty_app gl.ts_label [] in
      let v = create_vsymbol (id_fresh s) ty in
      let env = Mstr.add s v env in 
      IElabel (v, iexpr gl env e1)
  | DEany c ->
      let c = type_c gl.uc env c in
      IEany c

and decompose_app gl env e args = match e.dexpr_desc with
  | DEapply (e1, e2) ->
      let ty = Denv.ty_of_dty e.dexpr_type in
      decompose_app gl env e1 ((iexpr gl env e2, ty) :: args)
  | _ ->
      e, args

and iletrec gl env dl =
  (* add all functions into env, and compute local env *)
  let step1 env ((x, dty), bl, var, t) = 
    let ty = Denv.ty_of_dty dty in
    let v = create_vsymbol (id_fresh x) ty in
    let env = Mstr.add x v env in
    env, (v, bl, var, t)
  in
  let env, dl = map_fold_left step1 env dl in
  (* then translate variants and bodies *)
  let step2 (v, bl, var, (_,e,_ as t)) =
    let env, bl = map_fold_left (binder gl.uc) env bl in
    let denv = e.dexpr_denv in
    let var = option_map (variant denv env) var in
    let t = itriple gl env t in
    (v, bl, var, t)
  in
  let dl = List.map step2 dl in
  (* finally, check variants are all absent or all present and consistent *)
  let error e = 
    errorm ~loc:e.iexpr_loc "variants must be all present or all absent"
  in
  begin match dl with
    | [] -> 
	assert false
    | (_, _, None, _) :: r ->
	let check_no_variant (_,_,var,(_,e,_)) = if var <> None then error e in
	List.iter check_no_variant r
    | (_, _, Some (_, ps), _) :: r ->
	let check_variant (_,_,var,(_,e,_)) = match var with
	  | None -> error e
	  | Some (_, ps') -> if not (ls_equal ps ps') then 
	      errorm ~loc:e.iexpr_loc 
		"variants must share the same order relation"
	in
	List.iter check_variant r
  end;
  env, dl

and itriple gl env ((denvp, p), e, q) =
  let p = Typing.type_fmla denvp env p in
  let e = iexpr gl env e in
  let q = post env e.iexpr_type q in
  (p, e, q)

(* pretty-printing (for debugging) *)

open Pp
open Pretty 

let rec print_iexpr fmt e = match e.iexpr_desc with
  | IElogic t ->
      print_term fmt t
  | IElocal vs ->
      fprintf fmt "<local %a>" print_vs vs
  | IEglobal ls ->
      fprintf fmt "<global %a>" print_ls ls
  | IEapply (e, vs) ->
      fprintf fmt "@[((%a) %a)@]" print_iexpr e print_vs vs
  | IEapply_ref (e, r) ->
      fprintf fmt "@[((%a) <ref %a>)@]" print_iexpr e print_reference r
  | IEfun (_, (_,e,_)) ->
      fprintf fmt "@[fun _ ->@ %a@]" print_iexpr e
  | IElet (v, e1, e2) ->
      fprintf fmt "@[let %a = %a in@ %a@]" print_vs v
	print_iexpr e1 print_iexpr e2

  | IEsequence (e1, e2) ->
      fprintf fmt "@[%a;@\n%a@]" print_iexpr e1 print_iexpr e2

  | _ ->
      fprintf fmt "<other>"

(* phase 3: effect inference **********)

let reference_of_term t = match t.t_node with
  | Tvar vs -> E.Rlocal vs
  | Tapp (ls, []) -> E.Rglobal ls
  | _ -> assert false

let rec term_effect env ef t = match t.t_node with
  | Tapp (ls, [t]) when ls_equal ls env.ls_bang ->
      let r = reference_of_term t in
      E.add_read r ef
  | _ ->
      t_fold (term_effect env) (fmla_effect env) ef t

and fmla_effect env ef f =
  f_fold (term_effect env) (fmla_effect env) ef f

let post_effect env ef ((_,q),ql) =
  let exn_effect ef (_,(_,q)) = fmla_effect env ef q in
  List.fold_left exn_effect (fmla_effect env ef q) ql

let add_binder env (x, v) = add_local x v env
let add_binders = List.fold_left add_binder

let make_apply loc e1 ty c =
  let x = create_vsymbol (id_fresh "f") e1.iexpr_type in
  let v = c.c_result_type and ef = c.c_effect in
  let any_c = { expr_desc = Eany c; expr_type = ty;
		expr_type_v = v; expr_effect = ef; expr_loc = loc } in
  Elet (x, e1, any_c), v, ef

let exn_check = ref true
let without_exn_check f x =
  if !exn_check then begin
    exn_check := false; 
    try let y = f x in exn_check := true; y 
    with e -> exn_check := true; raise e
  end else
    f x

let rec expr env e =
  let ty = e.iexpr_type in
  let loc = e.iexpr_loc in
  let d, v, ef = expr_desc env loc ty e.iexpr_desc in
  { expr_desc = d; expr_type = ty; 
    expr_type_v = v; expr_effect = ef; expr_loc = loc }

and expr_desc env loc ty = function
  | IElogic t ->
      let ef = term_effect env E.empty t in
      Elogic t, Tpure ty, ef
  | IElocal vs ->
      assert (Mvs.mem vs env.locals);
      Elocal vs, Mvs.find vs env.locals, E.empty
  | IEglobal ls ->
      assert (Mls.mem ls env.globals);
      Eglobal ls, Mls.find ls env.globals, E.empty
  | IEapply (e1, vs) ->
      let e1 = expr env e1 in
      let c = apply_type_v env e1.expr_type_v vs in
      make_apply loc e1 ty c
  | IEapply_ref (e1, r) ->
      let e1 = expr env e1 in
      let c = apply_type_v_ref env e1.expr_type_v r in
      make_apply loc e1 ty c
  | IEfun (bl, t) ->
      let env = add_binders env bl in
      let t, c = triple env t in
      Efun (bl, t), Tarrow (bl, c), E.empty
  | IElet (v, e1, e2) ->
      let e1 = expr env e1 in
      let env = add_local v e1.expr_type_v env in
      let e2 = expr env e2 in
      let ef = E.union e1.expr_effect e2.expr_effect in
      Elet (v, e1, e2), e2.expr_type_v, ef
  | IEletrec _ ->
      assert false (*TODO*)

  | IEsequence (e1, e2) ->
      let e1 = expr env e1 in
      let e2 = expr env e2 in
      let ef = E.union e1.expr_effect e2.expr_effect in
      Esequence (e1, e2), e2.expr_type_v, ef
  | IEif (e1, e2, e3) ->
      let e1 = expr env e1 in
      let e2 = expr env e2 in
      let e3 = expr env e3 in
      let ef = E.union e1.expr_effect e2.expr_effect in
      let ef = E.union ef             e3.expr_effect in
      if not (eq_type_v e2.expr_type_v e3.expr_type_v) then
	errorm ~loc "cannot branch on functions";
      Eif (e1, e2, e3), e2.expr_type_v, ef
  | IEloop (a, e1) ->
      let e1 = expr env e1 in
      let ef = e1.expr_effect in
      let ef = match a.loop_invariant with
	| Some f -> fmla_effect env ef f
	| None -> ef
      in
      let ef = match a.loop_variant with
	| Some (t, _) -> term_effect env ef t
	| None -> ef
      in
      Eloop (a, e1), type_v_unit env, ef
  | IElazy _ ->
      assert false (*TODO*)
  | IEmatch _ ->
      assert false (*TODO*)
  | IEskip ->
      Eskip, Tpure ty, E.empty
  | IEabsurd ->
      Eabsurd, Tpure ty, E.empty
  | IEraise (x, e1) ->
      let e1 = option_map (expr env) e1 in
      let ef = match e1 with Some e1 -> e1.expr_effect | None -> E.empty in
      let ef = E.add_raise x ef in
      Eraise (x, e1), Tpure ty, ef
  | IEtry (e1, hl) ->
      let e1 = expr env e1 in
      let ef = e1.expr_effect in
      let handler (x, v, h) =
	if not (Sls.mem x ef.E.raises) && !exn_check then
	  errorm ~loc "exception %a cannot be raised" print_ls x;
	let env = match x.ls_args, v with
	  | [ty], Some v -> add_local v (Tpure ty) env
	  | [], None -> env
	  | _ -> assert false
	in
	x, v, expr env h
      in
      let hl = List.map handler hl in
      let ef = List.fold_left (fun e (x,_,_) -> E.remove_raise x e) ef hl in
      Etry (e1, hl), Tpure ty, ef

  | IEassert (k, f) ->
      let ef = fmla_effect env E.empty f in
      Eassert (k, f), Tpure ty, ef
  | IElabel (lab, e1) ->
      let e1 = expr env e1 in
      Elabel (lab, e1), e1.expr_type_v, e1.expr_effect
  | IEany _ ->
      assert false (*TODO*)

and triple env (p, e, q) =
  let e = expr env e in
  let ef = post_effect env (fmla_effect env e.expr_effect p) q in
  let e = { e with expr_effect = ef } in
  let c = 
    { c_result_type = e.expr_type_v;
      c_effect      = ef;
      c_pre         = p;
      c_post        = q }
  in
  (p, e, q), c

and recfun _env _def =
  assert false (*TODO*)


(* typing declarations (combines the three phases together) *)

let type_expr gl e =
  let denv = create_denv gl in
  let e = dexpr denv e in
  expr gl Mstr.empty e

let type_type uc ty =
  let denv = create_denv uc in
  let dty = Typing.dty denv.denv ty in
  Denv.ty_of_dty dty

let loc_of_ls ls = match ls.ls_name.id_origin with
  | User loc -> Some loc
  | _ -> None (* FIXME: loc for recursive functions *)

let add_decl uc ls =
  try
    Theory.add_decl uc (Decl.create_logic_decl [ls, None])
  with Theory.ClashSymbol _ ->
    let loc = loc_of_ls ls in
    errorm ?loc "clash with previous symbol %s" ls.ls_name.id_string
    
let add_decl gl ls = 
  let uc = Typing.with_tuples add_decl gl.uc ls in
  { gl with uc = uc }

let add_global ls gl =
  let x = ls.ls_name.id_string in
  let loc = loc_of_ls ls in
  if mem_global x gl then errorm ?loc "clash with previous symbol %s" x;
  { gl with globals = Mstr.add x ls gl.globals }

let add_global_if_pure gl ls = match ls.ls_args, ls.ls_value with
  | [], Some { ty_node = Ty.Tyapp (ts, _) } when ts_equal ts gl.ts_arrow -> gl
  | [], Some _ -> add_decl gl ls
  | _ -> gl

let add_exception loc ls gl =
  let x = ls.ls_name.id_string in
  if Mstr.mem x gl.exceptions then 
    errorm ~loc "clash with previous exception %s" x;
  { gl with exceptions = Mstr.add x ls gl.exceptions }

let file env uc dl =
  let gl = create_genv uc in
  let gl, dl =
    List.fold_left
      (fun (gl, acc) d -> match d with
	 | Pgm_ptree.Dlogic dl -> 
	     let dl = logic_list0_decl dl in
	     let uc = List.fold_left (Typing.add_decl env Mnm.empty) gl.uc dl in
	     { gl with uc = uc }, acc
	 | Pgm_ptree.Dlet (id, e) -> 
	     let e = type_expr gl e in
	     if !debug then
	       eprintf "@[--typing %s-----@\n  %a@]@." id.id print_expr e;
	     let tyl, ty = uncurrying gl e.expr_type in
	     let ls = create_lsymbol (id_user id.id id.id_loc) tyl (Some ty) in
	     let gl = add_global ls gl in
	     gl, Dlet (ls, e) :: acc
	 | Pgm_ptree.Dletrec dl -> 
	     let denv = create_denv gl in
	     let _, dl = dletrec denv dl in
	     let _, dl = letrec gl Mstr.empty dl in
	     let one gl (v,_,_,_ as r) =
	       let tyl, ty = uncurrying gl v.vs_ty in
	       let id = id_fresh v.vs_name.id_string in
	       let ls = create_lsymbol id tyl (Some ty) in
	       let gl = add_global ls gl in
	       gl, (ls, r)
	     in
	     let gl, dl = map_fold_left one gl dl in
	     gl, Dletrec dl :: acc
	 | Pgm_ptree.Dparam (id, tyv) ->
	     let denv = create_denv gl in
	     let tyv = dtype_v denv tyv in
	     let tyv = type_v gl.uc Mstr.empty tyv in
	     let tyl, ty = uncurrying gl (purify gl.uc tyv) in
	     let ls = create_lsymbol (id_user id.id id.id_loc) tyl (Some ty) in
	     let gl = add_global ls gl in
	     let gl = add_global_if_pure gl ls in
	     gl, Dparam (ls, tyv) :: acc
	 | Pgm_ptree.Dexn (id, ty) ->
	     let tyl = match ty with
	       | None -> []
	       | Some ty -> [type_type gl ty]
	     in
	     let exn = ty_app gl.ts_exn [] in
	     let ls = create_lsymbol (id_user id.id id.id_loc) tyl (Some exn) in
	     let gl = add_exception id.id_loc ls gl in
	     gl, acc
      )
      (gl, []) dl
  in
  gl.uc, List.rev dl

(*
Local Variables: 
compile-command: "unset LANG; make -C ../.. testl"
End: 
*)

(* 
TODO:

- mutually recursive functions: allow order relation to be specified only once

- exhaustivity of pattern-matching (in WP?)

- do not add global references into the theory (add_global_if_pure)

- polymorphic let?

- ghost

- move effect inference here (from pgm_wp), as phase 3
*)
