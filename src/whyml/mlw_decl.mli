(**************************************************************************)
(*                                                                        *)
(*  Copyright (C) 2010-2012                                               *)
(*    François Bobot                                                      *)
(*    Jean-Christophe Filliâtre                                           *)
(*    Claude Marché                                                       *)
(*    Guillaume Melquiond                                                 *)
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

open Why3
open Ident
open Ty
open Term
open Mlw_ty
open Mlw_ty.T
open Mlw_expr

(** {2 Type declaration} *)

type constructor = plsymbol * plsymbol option list

type data_decl = itysymbol * constructor list

(** {2 Declaration type} *)

type pdecl = private {
  pd_node : pdecl_node;
  pd_news : Sid.t;         (* idents introduced in declaration *)
  pd_tag  : int;           (* unique tag *)
}

and pdecl_node = private
  | PDtype of itysymbol
  | PDdata of data_decl list
  | PDval  of let_sym
  | PDlet  of let_defn
  | PDrec  of rec_defn
  | PDexn  of xsymbol

(** {2 Declaration constructors} *)

type pre_constructor = preid * (pvsymbol * bool) list

type pre_data_decl = itysymbol * pre_constructor list

val create_data_decl : pre_data_decl list -> pdecl

val create_ty_decl : itysymbol -> pdecl

val create_val_decl : let_sym -> pdecl

val create_let_decl : let_defn -> pdecl

val create_rec_decl : rec_defn -> pdecl

val create_exn_decl : xsymbol -> pdecl

(** {2 Known identifiers} *)

type known_map = pdecl Mid.t

val known_id : known_map -> ident -> unit
val known_add_decl : Decl.known_map -> known_map -> pdecl -> known_map
val merge_known : known_map -> known_map -> known_map

val find_constructors : known_map -> itysymbol -> constructor list
