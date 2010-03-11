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

(** Identifiers *)

type ident = {
  id_short : string;    (* non-unique name for string-based lookup *)
  id_long : string;     (* non-unique name for pretty printing *)
  id_origin : origin;   (* origin of the ident *)
  id_tag : int;         (* unique numeric tag *)
}

and origin =
  | User of Loc.position
  | Derived of ident
  | Fresh

module Id = struct
  type t = ident
  let equal = (==)
  let hash id1 = id1.id_tag
  let compare id1 id2 = Pervasives.compare id1.id_tag id2.id_tag
end
module Mid = Map.Make(Id)
module Sid = Set.Make(Id)
module Hid = Hashtbl.Make(Id)

type preid = ident

(* constructors *)

let gentag = let r = ref 0 in fun () -> incr r; !r

let id_register id = { id with id_tag = gentag () }

let create_ident short long origin = {
  id_short  = short;
  id_long   = long;
  id_origin = origin;
  id_tag    = -1
}

let id_fresh sh = create_ident sh sh Fresh
let id_fresh_long sh ln = create_ident sh ln Fresh

let id_user sh loc = create_ident sh sh (User loc)
let id_user_long sh ln loc = create_ident sh ln (User loc)

let id_derive sh id = create_ident sh sh (Derived id)
let id_derive_long sh ln id = create_ident sh ln (Derived id)

let id_clone id = create_ident id.id_short id.id_long (Derived id)
let id_dup id = { id with id_tag = -1 }

(* Utils *)
let rec derived_from i1 i2 = 
  i1 == i2 || (match i1.id_origin with Derived i3 -> derived_from i1 i2 | _ -> false)

(** Unique names for pretty printing *)

type ident_printer =
  (string, int) Hashtbl.t * (int, string) Hashtbl.t * (string -> string)

let rec find_index indices name ind =
  if Hashtbl.mem indices (name ^ string_of_int ind)
  then find_index indices name (succ ind) else ind

let find_unique indices name =
  let name = try
    let ind = Hashtbl.find indices name + 1 in
    let ind = find_index indices name ind in
    Hashtbl.replace indices name ind;
    name ^ string_of_int ind
  with Not_found -> name in
  Hashtbl.replace indices name 0;
  name

let same x = x

let create_ident_printer ?(sanitizer = same) sl =
  let indices = Hashtbl.create 1997 in
  let block n = ignore (find_unique indices n) in
  List.iter block sl;
  indices, Hashtbl.create 1997, sanitizer

let id_unique (indices,values,san0) ?(sanitizer = same) id =
  try
    Hashtbl.find values id.id_tag
  with Not_found ->
    let name = sanitizer (san0 id.id_long) in
    let name = find_unique indices name in
    Hashtbl.replace values id.id_tag name;
    name

let forget_id (indices,values,_) id =
  try
    let name = Hashtbl.find values id.id_tag in
    Hashtbl.remove indices name;
    Hashtbl.remove values id.id_tag
  with Not_found -> ()

let forget_all (indices,values,_) =
  Hashtbl.clear indices; Hashtbl.clear values

(** Sanitizers *)

exception Unsanitizable

let char_to_alpha c = match c with
  | 'a'..'z' | 'A'..'Z' -> String.make 1 c
  | ' ' -> "sp" | '_'  -> "us" | '#' -> "sh"
  | '`' -> "bq" | '~'  -> "tl" | '!' -> "ex"
  | '@' -> "at" | '$'  -> "dl" | '%' -> "pc"
  | '^' -> "cf" | '&'  -> "et" | '*' -> "as"
  | '(' -> "lp" | ')'  -> "rp" | '-' -> "mn"
  | '+' -> "pl" | '='  -> "eq" | '[' -> "lb"
  | ']' -> "rb" | '{'  -> "lc" | '}' -> "rc"
  | ':' -> "cl" | '\'' -> "qt" | '"' -> "dq"
  | '<' -> "ls" | '>'  -> "gt" | '/' -> "sl"
  | '?' -> "qu" | '\\' -> "bs" | '|' -> "br"
  | ';' -> "sc" | ','  -> "cm" | '.' -> "dt"
  | '0' -> "zr" | '1'  -> "un" | '2' -> "du"
  | '3' -> "tr" | '4'  -> "qr" | '5' -> "qn"
  | '6' -> "sx" | '7'  -> "st" | '8' -> "oc"
  | '9' -> "nn" | _ -> raise Unsanitizable

let char_to_lalpha c = String.uncapitalize (char_to_alpha c)
let char_to_ualpha c = String.capitalize (char_to_alpha c)

let char_to_alnum c =
  match c with '0'..'9' -> String.make 1 c | _ -> char_to_alpha c

let char_to_alnumus c =
  match c with '_' | ' ' -> "_" | _ -> char_to_alnum c

let sanitizer head rest n =
  let lst = ref [] in
  let code c = lst := rest c :: !lst in
  let n = if n = "" then "zilch" else n in
  String.iter code n;
  let rst = List.tl (List.rev !lst) in
  let cs = head (String.get n 0) :: rst in
  String.concat "" cs

