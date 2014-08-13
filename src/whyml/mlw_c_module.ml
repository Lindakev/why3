(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2014   --   INRIA - CNRS - Paris-Sud University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(*                                                                  *)
(********************************************************************)

let fmt = Printf.sprintf

type builder = line list ref

and line =
  | Text of string
  | Block of (string * builder)

type global =
  | Global of string
  | Function of (string * builder)

type value = string

type ty =
  | TyValue
  | TyValuePtr
  | TyExnTag

let unit_value = "why3__Tuple0__Tuple0"
let null_value = "NULL"
let true_value = "why3__Bool__True"
let false_value = "why3__Bool__False"
let env_value = "Env"
let exn_value = "Exn"

let c_keywords =
  [ "auto"; "break"; "case"; "char"; "const"; "continue"; "default"; "do"
  ; "double"; "else"; "enum"; "extern"; "float"; "for"; "goto"; "if"; "int"
  ; "long"; "register"; "return"; "short"; "signed"; "sizeof"; "static"
  ; "struct"; "switch"; "typedef"; "union"; "unsigned"; "void"; "volatile"
  ; "while"; unit_value; null_value; true_value; false_value; env_value
  ; exn_value
  ]

let header = ref ["#include \"why3.c\""]
let modul = ref []
let sanitizer = Ident.sanitizer Ident.char_to_alpha Ident.char_to_alnumus
let printer =
  Ident.create_ident_printer c_keywords ~sanitizer

let clean_fname fname =
  let fname = Filename.basename fname in
  (try Filename.chop_extension fname with _ -> fname)

let modulename ?(separator="__") ?fname path t =
  let fname = match fname, path with
    | Some fname, _ -> clean_fname fname
    | None, [] -> "why3"
    | None, _ -> String.concat separator path
  in
  fname ^ separator ^ t

type info = {
  info_syn: Printer.syntax_map;
  converters: Printer.syntax_map;
  current_theory: Theory.theory;
  current_module: Mlw_module.modul option;
  th_known_map: Decl.known_map;
  mo_known_map: Mlw_decl.known_map;
  fname: string option;
}

let get_ident ?(separator="__") info id =
  try
    let lp, t, p =
      try Mlw_module.restore_path id
      with Not_found -> Theory.restore_path id
    in
    let s = String.concat separator p in
    let s = sanitizer s in
    let fname = if lp = [] then info.fname else None in
    let m = modulename ~separator ?fname lp t in
    fmt "%s%s%s" m separator s
  with Not_found ->
    Ident.id_unique printer id

let unamed_id () =
  Ident.string_unique printer "X__"

let append_global x =
  modul := x :: !modul

let append_function name g =
  let builder = ref [] in
  g builder;
  append_global (Function (name, builder))

let append_expr x builder =
  builder := Text x :: !builder

let append_header str =
  header := str :: !header

let define_global_closure info name v =
  let tmp = unamed_id () in
  let name = get_ident info name in
  append_header (fmt "struct closure* %s;" name);
  append_global (Global (fmt "struct closure %s = {%s, NULL}" tmp v));
  append_global (Global (fmt "struct closure* %s = &%s" name tmp))

let define_local_var ty name value builder =
  append_expr (fmt "%s %s = %s" ty name value) builder

let append_block x g builder =
  let builder' = ref [] in
  g builder';
  builder := Block (x, builder') :: !builder

let dump_builder fmt builder =
  let indent_level = 2 in
  let add_string indent str =
    Format.pp_print_string fmt (String.make indent ' ');
    Format.pp_print_string fmt str;
  in
  let rec aux indent = function
    | Text s ->
        add_string indent s;
        Format.fprintf fmt ";\n";
    | Block (s, builder) ->
        add_string indent s;
        Format.fprintf fmt "\n";
        add_string indent "{\n";
        let builder = List.rev !builder in
        List.iter (aux (indent + indent_level)) builder;
        add_string indent "}\n";
  in
  let builder = List.rev !builder in
  List.iter (aux indent_level) builder

let dump_global fmt = function
  | Global s ->
      Format.fprintf fmt "%s;\n\n" s;
  | Function (s, builder) ->
      Format.pp_print_string fmt s;
      Format.fprintf fmt "\n{\n";
      dump_builder fmt builder;
      Format.fprintf fmt "}\n\n"

let dump fmt =
  let dump_header () =
    let h = List.rev !header in
    List.iter (Format.fprintf fmt "%s\n") h;
    Format.fprintf fmt "\n";
    header := [];
  in
  let dump_module () =
    let m = List.rev !modul in
    List.iter (dump_global fmt) m;
    Format.fprintf fmt "\n";
    modul := [];
  in
  begin match !header with
  | [] -> ()
  | _::_ -> dump_header ()
  end;
  begin match !modul with
  | [] -> ()
  | _::_ -> dump_module ()
  end

(************************)
(* High-level functions *)
(************************)

let string_of_ty = function
  | TyValue -> "value"
  | TyValuePtr -> "value*"
  | TyExnTag -> "exn_tag"

let create_value ?(ty=TyValue) value builder =
  let name = unamed_id () in
  define_local_var (string_of_ty ty) name value builder;
  name

let create_named_value info id value builder =
  let name = get_ident info id in
  define_local_var "value" name value builder;
  name

let create_exn builder =
  let name = unamed_id () in
  define_local_var "struct exn*" name null_value builder;
  name

let create_mpz str base builder =
  let name = unamed_id () in
  append_expr (fmt "mpz_ptr %s = GC_malloc(sizeof(mpz_t))" name) builder;
  append_expr (fmt "mpz_init_set_str(%s, %S, %d)" name str base) builder;
  name

let create_array size builder =
  let name = unamed_id () in
  append_expr (fmt "value %s[%d] = {NULL}" name size) builder;
  name

let clone_mpz value builder =
  let name = unamed_id () in
  append_expr (fmt "mpz_ptr %s = GC_malloc(sizeof(mpz_t))" name) builder;
  append_expr (fmt "mpz_init_set(%s, %s)" name value) builder;
  name

let cast_to_closure value builder =
  let name = unamed_id () in
  define_local_var "struct closure*" name value builder;
  name

let cast_to_record ~st value builder =
  let name = unamed_id () in
  define_local_var (fmt "struct %s*" st) name value builder;
  name

let cast_to_variant value builder =
  let name = unamed_id () in
  define_local_var "struct variant*" name value builder;
  name

let cast_to_function ~raises params_nbr value builder =
  let name = unamed_id () in
  let params = Lists.make params_nbr "value" in
  let params = String.concat ", " params in
  let params = params ^ ", value*" in
  let params = if raises then params ^ ", struct exn**" else params in
  append_expr (fmt "value (*%s)(%s) = %s" name params value) builder;
  name

let malloc_closure builder =
  let name = unamed_id () in
  define_local_var "struct closure*" name "GC_malloc(sizeof(struct closure))" builder;
  name

let malloc_exn builder =
  let name = unamed_id () in
  define_local_var "struct exn*" name "GC_malloc(sizeof(struct exn))" builder;
  name

let malloc_env size builder = match size with
  | 0 ->
      null_value
  | size ->
      let name = unamed_id () in
      define_local_var "value*" name (fmt "GC_malloc(sizeof(value) * %d)" size) builder;
      name

let malloc_variant builder =
  let name = unamed_id () in
  define_local_var "struct variant*" name "GC_malloc(sizeof(struct variant))" builder;
  name

let malloc_record st builder =
  let name = unamed_id () in
  define_local_var (fmt "struct %s*" st) name (fmt "GC_malloc(sizeof(struct %s))" st) builder;
  name

let create_function info ?name ~params ~raises f =
  let name = match name with
    | Some name -> "F_" ^ get_ident info name
    | None -> unamed_id ()
  in
  let params = List.map (fun x -> get_ident info x) params in
  let exn = if raises then ", struct exn **Exn" else "" in
  let f builder =
    let raise_expr value builder =
      if raises then begin
        append_expr (fmt "*Exn = %s" value) builder;
        append_expr "return NULL" builder;
      end else begin
        append_expr "abort()" builder;
      end
    in
    let v = f ~raise_expr ~params builder in
    append_expr (fmt "return %s" v) builder
  in
  let params = String.concat ", value " params in
  append_function (fmt "value %s(value %s, value* Env%s)" name params exn) f;
  name

let create_pure_function info ~name ~params f =
  let name = get_ident info name in
  let params = List.map (fun x -> get_ident info x) params in
  let f builder =
    let v = f ~params builder in
    append_expr (fmt "return %s" v) builder
  in
  let params = String.concat ", value " params in
  append_function (fmt "value %s(value %s)" name params) f;
  name

let define_record name fields =
  let fields =
    let aux = fmt "%s value %s;\n" in
    List.fold_left aux "" fields
  in
  append_header (fmt "struct %s {\n%s};" name fields)

let build_equal x y builder =
  create_value (fmt "%s == %s" x y) builder

let build_store x y builder =
  append_expr (fmt "%s = %s" x y) builder

let build_store_array x i y builder =
  append_expr (fmt "%s[%d] = %s" x i y) builder

let build_store_array_from_array x i y j builder =
  append_expr (fmt "%s[%d] = %s[%d]" x i y j) builder

let build_store_field x field y builder =
  append_expr (fmt "%s->%s = %s" x field y) builder

let build_store_field_int x field y builder =
  append_expr (fmt "%s->%s = %d" x field y) builder

let build_break =
  append_expr "break"

let build_if_not_null v f builder =
  append_block (fmt "if(%s != NULL)" v) f builder

let build_if_true v f builder =
  append_block (fmt "if(%s == %s)" v true_value) f builder

let build_if_false v f builder =
  append_block (fmt "if(%s == %s)" v false_value) f builder

let build_if_cmp_zero cmp signe f =
  append_block (fmt "if(%s %s 0)" cmp signe) f

let build_if cmp f =
  append_block (fmt "if(%s)" cmp) f

let build_else_if cmp f =
  append_block (fmt "else if(%s)" cmp) f

let build_else f =
  append_block "else" f

let build_if_else_if_else l else_case builder =
  let aux (cond, f) = build_else_if cond f builder in
  match l with
  | [] -> else_case builder
  | (cmp, f)::xs ->
      build_if cmp f builder;
      List.iter aux xs;
      build_else else_case builder

let build_access_array v i builder =
  create_value (fmt "%s[%d]" v i) builder

let build_access_field ?ty v field builder =
  create_value ?ty (fmt "%s->%s" v field) builder

let build_not v builder =
  create_value
    (fmt "((struct variant*)(%s)->key) ? %s : %s" v false_value true_value)
    builder

let build_do_while f builder =
  append_block "do" f builder;
  append_expr "while(false)" builder

let build_abort =
  append_expr "abort()"

let build_switch e l =
  let aux builder = function
    | (None, f) ->
        append_block "default: " f builder;
        build_break builder;
    | (Some i, f) ->
        append_block (fmt "case %d: " i) f builder;
        build_break builder;
  in
  append_block
    (fmt "switch(%s->key)" e)
    (fun builder -> List.iter (aux builder) l)

let build_while f =
  append_block "while(true)" f

let build_mpz_cmp x y builder =
  let name = unamed_id () in
  define_local_var "int" name (fmt "mpz_cmp(%s, %s)" x y) builder;
  name

let build_mpz_succ value =
  append_expr (fmt "mpz_add_ui(%s, %s, 1)" value value)

let build_call closure params ?exn builder =
  let f = build_access_field closure "f" builder in
  let raises = exn <> None in
  let f = cast_to_function ~raises (List.length params) f builder in
  let params = String.concat ", " params in
  match exn with
  | None ->
      create_value (fmt "%s(%s, %s->env)" f params closure) builder
  | Some exn ->
      create_value (fmt "%s(%s, %s->env, &%s)" f params closure exn) builder

let build_pure_call f params builder =
  let params = String.concat ", " params in
  create_value (fmt "%s(%s)" f params) builder

let const_access_array = fmt "%s[%d]"

let const_equal = fmt "%s == %s"

let append_global_exn name value =
  let name = fmt "exn_tag %s" name in
  append_global (Global (fmt "%s = \"%s\"" name value))

let syntax_arguments x tl builder =
  let buf = Buffer.create 32 in
  let fmt = Format.formatter_of_buffer buf in
  Printer.syntax_arguments x (fun fmt -> Format.fprintf fmt "%s") fmt tl;
  Format.pp_print_flush fmt ();
  create_value (Buffer.contents buf) builder