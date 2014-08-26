(*
 * Copyright (c) 2013-2014 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Printf
open Bin_prot.Std
open Sexplib.Std

type 'a equal = 'a -> 'a -> bool
type 'a compare = 'a -> 'a -> int
type 'a to_sexp = 'a -> Sexplib.Sexp.t
type 'a to_json = 'a -> Ezjsonm.t
type 'a of_json = Ezjsonm.t -> 'a
type 'a writer = 'a -> Cstruct.t -> Cstruct.t
type 'a reader = Cstruct.t -> (Cstruct.t * 'a) option

module type I0 = sig
  type t
  val equal: t equal
  val compare: t compare
  val to_sexp: t to_sexp
  val to_json: t to_json
  val of_json: t of_json
  val write: t writer
  val read: t reader
end

module type I1 = sig
  type 'a t
  val equal: 'a equal -> 'a t equal
  val compare: 'a compare -> 'a t compare
  val to_sexp: 'a to_sexp -> 'a t to_sexp
  val to_json: 'a to_json -> 'a t to_json
  val of_json: 'a of_json -> 'a t of_json
  val write: 'a writer -> 'a t writer
  val read: 'a reader -> 'a t reader
end

module type I2 = sig
  type ('a, 'b) t
  val equal: 'a equal -> 'b equal -> ('a, 'b) t equal
  val compare: 'a compare -> 'b compare -> ('a, 'b) t compare
  val to_sexp: 'a to_sexp -> 'b to_sexp -> ('a, 'b) t to_sexp
  val to_json: 'a to_json -> 'b to_json -> ('a, 'b) t to_json
  val of_json: 'a of_json -> 'b of_json -> ('a, 'b) t of_json
  val write: 'a writer -> 'b writer -> ('a, 'b) t writer
  val read: 'a reader -> 'b reader -> ('a, 'b) t reader
end

let pretty fn x = Sexplib.Sexp.to_string_hum (fn x)

module Reader = struct

  let to_bin_prot read_t =
    let raise_err pos =
      Bin_prot.Common.(raise_read_error (ReadError.Silly_type "?") pos)
    in
    fun buf ~pos_ref ->
      let off = !pos_ref in
      let b = Cstruct.of_bigarray ~off buf in
      match read_t b with
      | None -> raise_err off
      | Some (b, a) ->
        pos_ref := b.Cstruct.off;
        a

  let of_bin_prot bin_read_t =
    fun ({ Cstruct.buffer; off; _ } as buf) ->
      try
        let pos_ref = ref off in
        let t = bin_read_t buffer ~pos_ref in
        let buf = Cstruct.shift buf (!pos_ref - off) in
        Some (buf, t)
      with Bin_prot.Common.Read_error _ ->
        None

  let pair a b =
    of_bin_prot (Bin_prot.Read.bin_read_pair (to_bin_prot a) (to_bin_prot b))

  let list a =
    of_bin_prot (Bin_prot.Read.bin_read_list (to_bin_prot a))

  let map f = function
    | None  -> None
    | Some (b, t) -> Some (b, f t)

end

module Writer = struct

  let to_bin_prot write =
    fun buf ~pos t ->
      let b = Cstruct.of_bigarray ~off:pos buf in
      let b = write t b in
      b.Cstruct.off

  let of_bin_prot bin_write_t =
    fun t ({ Cstruct.buffer; off; _ } as buf) ->
      let pos = bin_write_t buffer ~pos:off t in
      Cstruct.shift buf (pos - off)

  let pair a b =
    of_bin_prot (Bin_prot.Write.bin_write_pair (to_bin_prot a) (to_bin_prot b))

  let list a =
    of_bin_prot (Bin_prot.Write.bin_write_list (to_bin_prot a))

end

module Compare = struct

  let pair a b (k1, v1) (k2, v2) =
    match a k1 k2 with
    | 0 -> b v1 v2
    | x -> x

  let list a l1 l2 =
    let rec aux l1 l2 = match l1, l2 with
      | [], [] -> 0
      | [], _  -> -1
      | _ , [] -> 1
      | h1::t1, h2::t2 ->
        match a h1 h2 with
        | 0 -> aux t1 t2
        | x -> x
    in
    aux l1 l2

end

module Equal = struct

  let pair a b (k1, v1) (k2, v2) =
      a k1 k2 && b v1 v2

  let list a l1 l2 =
    let rec aux l1 l2 = match l1, l2 with
      | [], [] -> true
      | [], _  | _, [] -> false
      | h1::t1, h2::t2 -> a h1 h2 && aux l1 l2
    in
    aux l1 l2

end

module JSON = struct

  let rec of_sexp = function
    | Sexplib.Type.Atom x -> IrminMisc.encode_json_string x
    | Sexplib.Type.List l -> Ezjsonm.list of_sexp l

  let rec to_sexp json =
    match IrminMisc.decode_json_string json with
    | Some s -> Sexplib.Type.Atom s
    | None   ->
      match json with
      | `A l -> Sexplib.Type.List (List.map to_sexp l)
      | _    -> failwith (sprintf "sexp_of_json: %s" (Ezjsonm.to_string json))

end

let invalid_argf fmt =
    ksprintf (fun str ->
      Invalid_argument str
    ) fmt

module I0 (S: sig type t with sexp, bin_io, compare end) = struct

  include S
  let equal x y = compare x y = 0
  let to_sexp = S.sexp_of_t
  let to_json t = JSON.of_sexp (S.sexp_of_t t)
  let of_json t = S.t_of_sexp (JSON.to_sexp t)

  open Bin_prot.Type_class

  let read ({ Cstruct.buffer; off; _ } as buf) =
    try
      let pos_ref = ref off in
      let t = bin_t.reader.read ~pos_ref buffer in
      let buf = Cstruct.shift buf (!pos_ref - off) in
      Some (buf, t)
    with Bin_prot.Common.Read_error _ ->
      None

  let write t ({ Cstruct.buffer; off; _ } as buf) =
    let k = bin_t.writer.write buffer ~pos:off t in
    Cstruct.shift buf k

end

module String = struct
  include I0(struct type t = string with sexp, compare, bin_io end)
  let of_json = IrminMisc.decode_json_string_exn
  let to_json = IrminMisc.encode_json_string
  let is_empty t = t = ""
  let sub str ~pos ~len = String.sub str pos len

  let split str ~on =
    let len = String.length str in
    let rec loop acc i =
      if i < 0 then acc else (
        Printf.printf "i=%d\n%!" i;
        let j =
          try String.rindex_from str i on
          with Not_found -> -42
        in
        match j with
        | -42 -> String.sub str 0 i :: acc
        | _  ->
          let sub = String.sub str (j + 1) (i - j) in
          loop (sub :: acc) (j - 1)
      )
    in
    loop [] (len - 1)

end

module Int = struct
  include I0(struct type t = int with sexp, compare, bin_io end)
  let of_json = Ezjsonm.get_int
  let to_json = Ezjsonm.int
  let max_value = max_int
end

module Bigstring = struct
  open Bigarray
  module M = struct
    include Bin_prot.Std
    include Sexplib.Conv
    type t = bigstring with bin_io
    let sexp_of_t = Sexplib.Conv.sexp_of_bigstring
    let t_of_sexp = Sexplib.Conv.bigstring_of_sexp
    let compare = Pervasives.compare (* FIXME *)
  end
  include I0(M)
  let create len = Array1.create char c_layout len
  let length t = Array1.dim t
end

module Unit = I0(struct type t = unit with sexp, bin_io, compare end)

module Int64 = struct
  include I0(struct type t = int64 with sexp, bin_io, compare end)
  let (+) = Int64.add
end

module Char = struct
  include I0(struct type t = char with sexp, compare, bin_io end)
  let to_int = Char.code
  let of_int i = if i >= 0 && i <= 255 then Some (Char.chr i) else None
  let of_int_exn i = match of_int i with
    | None   -> raise (invalid_argf "Char.of_int_exn: %d is out of range." i)
    | Some c -> c
end

module I1 (S: sig type 'a t with sexp, compare, bin_io end):
  I1 with type 'a t = 'a S.t
= struct

  include S

  let equal equal_a x y =
    try S.compare (fun x y -> if equal_a x y then 0 else raise Exit) x y = 0
    with Exit -> false

  let to_sexp = S.sexp_of_t

  let to_json json_of_a t =
    let open Sexplib.Type in
    let sexprs = ref [] in
    let sexp_of_a a =
      let marker = "__JSON__" ^ string_of_int (Random.int max_int) in
      sexprs := (marker, a) :: !sexprs;
      Atom marker in
    let rec json_of_sexp = function
      | List l -> Ezjsonm.list json_of_sexp l
      | Atom x ->
        try json_of_a (List.assq x !sexprs)
        with Not_found -> String.to_json x
    in
    json_of_sexp (S.sexp_of_t sexp_of_a t)

  let of_json a_of_json t =
    let open Sexplib.Type in
    let sexprs = ref [] in
    let rec sexp_of_json json =
      let e = match IrminMisc.decode_json_string json with
        | Some s -> Atom s
        | None   -> match json with
          | `A l -> List (List.map sexp_of_json l)
          | json  -> Atom (Ezjsonm.to_string json)
      in
      sexprs := (e, json) :: !sexprs;
      e
    in
    let a_of_sexp e = a_of_json (List.assq e !sexprs) in
    S.t_of_sexp a_of_sexp (sexp_of_json t)

  let read read_a =
    let bin_read_a = Reader.to_bin_prot read_a in
    Reader.of_bin_prot (bin_read_t bin_read_a)

  let write write_a =
    let bin_write_a = Writer.to_bin_prot write_a in
    Writer.of_bin_prot (bin_write_t bin_write_a)

end


module I2 (S: sig type ('a, 'b) t with sexp, compare, bin_io end):
  I2 with type ('a, 'b) t = ('a, 'b) S.t
= struct

  include S

  let equal equal_a equal_b x y =
    let compare_a x y = if equal_a x y then 0 else raise Exit in
    let compare_b x y = if equal_b x y then 0 else raise Exit in
    try S.compare compare_a compare_b x y = 0
    with Exit -> false

  let to_sexp = sexp_of_t

  let read read_a read_b =
    let bin_read_a = Reader.to_bin_prot read_a in
    let bin_read_b = Reader.to_bin_prot read_b in
    Reader.of_bin_prot (bin_read_t bin_read_a bin_read_b)

  let write write_a write_b =
    let bin_write_a = Writer.to_bin_prot write_a in
    let bin_write_b = Writer.to_bin_prot write_b in
    Writer.of_bin_prot (bin_write_t bin_write_a bin_write_b)

  let to_json json_of_a json_of_b t =
    let open Sexplib.Type in
    let sexprs_a = ref [] in
    let sexp_of_a a =
      let marker = "__JSON__A_" ^ string_of_int (Random.int max_int) in
      sexprs_a := (marker, a) :: !sexprs_a;
      Atom marker in
    let sexprs_b = ref [] in
    let sexp_of_b b =
      let marker = "__JSON__B_" ^ string_of_int (Random.int max_int) in
      sexprs_b := (marker, b) :: !sexprs_b;
      Atom marker in
    let rec json_of_sexp = function
      | List l -> Ezjsonm.list json_of_sexp l
      | Atom x ->
        try json_of_a (List.assq x !sexprs_a)
        with Not_found ->
          try json_of_b (List.assq x !sexprs_b)
          with Not_found -> String.to_json x
    in
    json_of_sexp (S.sexp_of_t sexp_of_a sexp_of_b t)

  let of_json a_of_json b_of_json t =
    let open Sexplib.Type in
    let sexprs = ref [] in
    let rec sexp_of_json json =
      let e = match IrminMisc.decode_json_string json with
        | Some s -> Atom s
        | None   -> match json with
          | `A l -> List (List.map sexp_of_json l)
          | json  -> Atom (Ezjsonm.to_string json)
      in
      sexprs := (e, json) :: !sexprs;
      e
    in
    let a_of_sexp e = a_of_json (List.assq e !sexprs) in
    let b_of_sexp e = b_of_json (List.assq e !sexprs) in
    S.t_of_sexp a_of_sexp b_of_sexp (sexp_of_json t)

end

module Out_channel = struct
  type t = out_channel
  let create = open_out
  let close = close_out
end

module Option = struct
  include I1(struct type 'a t = 'a option with sexp, bin_io, compare end)
end

module List = struct
  include I1(struct type 'a t = 'a list with sexp, compare, bin_io end)
  let length = List.length
  let iter t ~f = List.iter f t
  let rev = List.rev
  let sort t ~cmp = List.sort cmp t
  let for_all2 t ~f = List.for_all2 f t
  let fold_left t ~init ~f = List.fold_left f init t
  let mem t x = List.mem x t
  let map t ~f = List.map f t

  let partition_map t ~f =
    let rec aux fst snd = function
      | []   -> List.rev fst, List.rev snd
      | h::t ->
        match f h with
        | `Fst x -> aux (x :: fst) snd t
        | `Snd x -> aux fst (x :: snd) t
    in
    aux [] [] t

  let filter_map t ~f =
    let rec aux acc = function
      | []   -> List.rev acc
      | h::t ->
        match f h with
        | None   -> aux acc t
        | Some x -> aux (x::acc) t
    in
    aux [] t

  let dedup ?(compare=Pervasives.compare) t =
    let t = List.sort compare t in
    let rec aux acc = function
      | []      -> List.rev acc
      | [x]     -> aux (x :: acc) []
      | x::(y::t as tl) ->
        match compare x y with
        | 0 -> aux acc tl
        | _ -> aux (x :: acc) tl
    in
    aux [] t

  module Assoc = struct

    include I2(struct
        type ('a, 'b) t = ('a * 'b) list with sexp, compare, bin_io
      end)

    let find_exn t ?(equal=(=)) a =
      let fn (k, _) = equal k a in
      snd (List.find fn t)

    let find t ?equal a =
      try Some (find_exn t ?equal a)
      with Not_found -> None

  end

end

module ListLike0
    (S: sig
       type t
       module K: I0
       val to_list: t -> K.t list
       val of_list: K.t list -> t
     end) =
struct
  let equal t1 t2 = List.equal S.K.equal (S.to_list t1) (S.to_list t2)
  let compare t1 t2 = List.compare S.K.compare (S.to_list t1) (S.to_list t2)
  let to_sexp t = List.to_sexp S.K.to_sexp (S.to_list t)
  let to_json t = List.to_json S.K.to_json (S.to_list t)
  let of_json j = S.of_list (List.of_json S.K.of_json j)
  let read buf = Reader.map S.of_list (List.read S.K.read buf)
  let write t = List.write S.K.write (S.to_list t)
end

module ListLike1
    (S: sig
       type 'a t
       val to_list: 'a t -> 'a list
       val of_list: 'a list -> 'a t
     end) =
struct
  let equal equal_a t1 t2 = List.equal equal_a (S.to_list t1) (S.to_list t2)
  let compare compare_a t1 t2 = List.compare compare_a (S.to_list t1) (S.to_list t2)
  let to_sexp to_sexp_a t = List.to_sexp to_sexp_a (S.to_list t)
  let to_json to_json_a t = List.to_json to_json_a (S.to_list t)
  let of_json of_json_a j = S.of_list (List.of_json of_json_a j)
  let read read_a buf = Reader.map S.of_list (List.read read_a buf)
  let write write_a t = List.write write_a (S.to_list t)
end

module Queue = struct
  module L = struct
    type 'a t = 'a Queue.t
    let enqueue t x = Queue.push x t
    let dequeue_exn t = Queue.pop t
    let dequeue t =
      try Some (dequeue_exn t)
      with Queue.Empty -> None

    let to_list t =
      let l = ref [] in
      Queue.iter (fun x -> l := x :: !l) t;
      !l

    let of_list l =
      let t = Queue.create () in
      List.iter ~f:(enqueue t) l;
      t
  end
  include L
  include ListLike1(L)
end

module Stack = struct
  module L = struct
    type 'a t = 'a Stack.t
    let create = Stack.create
    let push t x = Stack.push x t
    let pop_exn = Stack.pop

    let pop t =
      try Some (pop_exn t)
      with Stack.Empty -> None

    let to_list t =
      let l = ref [] in
      Stack.iter (fun e -> l := e :: !l) t;
      List.rev !l

    let of_list l =
      let t = Stack.create () in
      List.iter ~f:(push t) (List.rev l);
      t
  end
  include L
  include ListLike1(L)
end

module Set = struct
  module type S = sig
    include I0
    type elt
    val of_list: elt list -> t
    val to_list: t -> elt list
  end
  module Make (K: I0) = struct
    module L = struct
      module Set = Set.Make(K)
      module K = K
      type t = Set.t
      type elt = K.t

      let to_list t =
        let l = ref [] in
        Set.iter (fun k ->
            l := k :: !l
          ) t;
        List.rev !l

      let of_list l =
        let t = ref Set.empty in
        List.iter ~f:(fun k ->
            t := Set.add k !t
          ) l;
        !t
    end
    include L
    include ListLike0(L)
  end
end

module type DICT = sig
  include I1
  type key
  val to_alist: 'a t -> (key * 'a) list
  val of_alist: (key * 'a) list -> [`Ok of 'a t | `Duplicate_key of key]
  val of_alist_exn: (key * 'a) list -> 'a t
  val keys: 'a t -> key list
  val is_empty: 'a t -> bool
  val mem: 'a t -> key -> bool
  val find: 'a t -> key -> 'a option
  val fold: 'a t -> init:'b -> f:(key:key -> data:'a -> 'b -> 'b) -> 'b
  val map: 'a t -> f:('a -> 'b) -> 'b t
  val iter: 'a t -> f:(key:key -> data:'a -> unit) -> unit
  val filter: 'a t -> f:(key:key -> data:'a -> bool) -> 'a t
end

module Hashtbl = struct
  module type S = sig
    include DICT
    val create: ?size:int -> unit -> 'a t
    val clear: 'a t -> unit
    val of_alist_add: (key * 'a) list -> 'a t
    val replace: 'a t -> key:key -> data:'a -> unit
    val add: 'a t -> key:key -> data:'a -> [`Ok | `Duplicate]
    val add_exn: 'a t -> key:key -> data:'a -> unit
    val add_multi: 'a list t -> key:key -> data:'a -> unit
    val remove: 'a t -> key -> unit
  end

  let hash = Hashtbl.hash

  module Make (K: I0): S with type key = K.t = struct

    type 'a t = (K.t, 'a) Hashtbl.t
    type key = K.t

    let to_sexp sexp_of_a = Sexplib.Conv.sexp_of_hashtbl K.to_sexp sexp_of_a

    let of_alist_add l =
      let acc = Hashtbl.create (List.length l) in
      List.iter ~f:(fun (k, v) ->
          Hashtbl.add acc k v
        ) l;
      acc

    exception D of K.t

    let of_alist l =
      let acc = Hashtbl.create (List.length l) in
      try
        List.iter ~f:(fun (k, v) ->
            if Hashtbl.mem acc k then raise (D k)
            else Hashtbl.add acc k v
          ) l;
        `Ok acc
      with D k ->
        `Duplicate_key k

    let of_alist_exn l =
      match of_alist l with
      | `Ok acc -> acc
      | `Duplicate_key k ->
        raise (invalid_argf "Duplicate key: %s" (pretty K.to_sexp k))

    let of_json a_of_json json =
      let dict = Ezjsonm.get_list (Ezjsonm.get_pair K.of_json a_of_json) json in
      of_alist_add dict

    let to_alist t =
      let acc = ref [] in
      Hashtbl.iter (fun k v ->
          acc := (k, v) :: !acc
        ) t;
      List.rev !acc

    let to_json json_of_a t =
      let dict = to_alist t in
      Ezjsonm.list (Ezjsonm.pair K.to_json json_of_a) dict

    let read read_a =
      let bin_read_k = Reader.to_bin_prot K.read in
      let bin_read_a = Reader.to_bin_prot read_a in
      let bin_t = Bin_prot.Read.bin_read_hashtbl bin_read_k bin_read_a in
      Reader.of_bin_prot bin_t

    let write write_a =
      let bin_write_k = Writer.to_bin_prot K.write in
      let bin_write_a = Writer.to_bin_prot write_a in
      let bin_t = Bin_prot.Write.bin_write_hashtbl bin_write_k bin_write_a in
      Writer.of_bin_prot bin_t

    let compare compare_a t1 t2 =
      let cmp = Compare.pair K.compare compare_a in
      let l1 = List.sort ~cmp (to_alist t1) in
      let l2 = List.sort ~cmp (to_alist t2) in
      Compare.list cmp l1 l2

    let equal equal_a t1 t2 =
      let cmp = Compare.pair K.compare (fun _ _ -> 0) in
      let l1 = List.sort ~cmp (to_alist t1) in
      let l2 = List.sort ~cmp (to_alist t2) in
      Equal.list (Equal.pair K.equal equal_a) l1 l2

    let remove = Hashtbl.remove
    let mem = Hashtbl.mem
    let clear = Hashtbl.clear
    let create ?(size=128) () = Hashtbl.create (if size < 1 then 128 else size)
    let replace t ~key ~data = Hashtbl.replace t key data
    let iter t ~f = Hashtbl.iter (fun key data -> f ~key ~data) t
    let is_empty t = Hashtbl.length t = 0

    let add t ~key ~data =
      if Hashtbl.mem t key then `Duplicate
      else (
        Hashtbl.add t key data;
        `Ok
      )

    let add_exn t ~key ~data =
      match add t ~key ~data with
      | `Ok -> ()
      | `Duplicate ->
        raise (invalid_argf "Duplicate key: %s" (pretty K.to_sexp key))

    let keys t =
      let acc = ref [] in
      Hashtbl.iter (fun k _ ->
          acc := k :: !acc
        ) t;
      List.rev !acc

    let map t ~f =
      let acc = create ~size:(Hashtbl.length t) () in
      Hashtbl.iter (fun k v ->
          Hashtbl.add acc k (f v)
        ) t;
      acc

    let fold t ~init ~f =
      let acc = ref init in
      Hashtbl.iter (fun key data ->
          acc := f ~key ~data !acc
        ) t;
      !acc

    let filter t ~f =
      let acc = create ~size:(Hashtbl.length t) () in
      Hashtbl.iter (fun key data ->
          if f ~key ~data then Hashtbl.add acc key data
        ) t;
      acc

    let find t key =
      try Some (Hashtbl.find t key)
      with Not_found -> None

    let add_multi t ~key ~data =
      match find t key with
      | None -> replace t ~key ~data:[data]
      | Some l -> replace t ~key ~data:(data :: l)

  end

end

module Map = struct
  module type S = sig
    include DICT
    val empty: 'a t
    val add: 'a t -> key:key -> data:'a -> 'a t
    val remove: 'a t -> key -> 'a t
    module Lwt: sig
      val merge: 'v1 t ->'v2 t ->
        f:(key:key -> [ `Both of 'v1 * 'v2 | `Left of 'v1 | `Right of 'v2 ] -> 'v3 option Lwt.t) ->
        'v3 t Lwt.t
      val iter2: 'v1 t -> 'v2 t ->
        f:(key:key ->data:[ `Both of 'v1 * 'v2 | `Left of 'v1 | `Right of 'v2 ] -> unit Lwt.t) ->
        unit Lwt.t
    end
  end
  module Make (K: I0) = struct

    module Map = Map.Make(K)

    type 'a t = 'a Map.t
    type key = Map.key

    let mem t k = Map.mem k t
    let add t ~key ~data = Map.add key data t
    let remove t k = Map.remove k t
    let empty = Map.empty
    let filter t ~f = Map.filter (fun key data -> f ~key ~data) t
    let map t ~f = Map.map f t
    let is_empty = Map.is_empty
    let keys t = List.map ~f:fst (Map.bindings t)
    let iter t ~f = Map.iter (fun key data -> f ~key ~data) t

    let find t k =
      try Some (Map.find k t)
      with Not_found -> None

    let fold t ~init ~f =
      let acc = ref init in
      Map.iter (fun key data ->
          acc := f ~key ~data !acc
        ) t;
      !acc

    let to_alist t =
      let acc = ref [] in
      Map.iter (fun k v ->
          acc := (k, v) :: !acc
        ) t;
      List.rev !acc

    let of_alist alist =
      let result = ref None in
      try
        let map = List.fold_left ~f:(fun t (key,data) ->
            if mem t key then (
              result := Some (`Duplicate_key key);
              raise Exit
            ) else add t ~key ~data
          ) ~init:Map.empty alist
        in
        `Ok map
      with Exit ->
        match !result with
        | Some x -> x
        | None   -> assert false

    let of_alist_exn alist =
      match of_alist alist with
      | `Ok x -> x
      | `Duplicate_key k -> raise (
          invalid_argf "Map.of_alist_exn: duplicate key %s"
            (Sexplib.Sexp.to_string (K.to_sexp k))
        )

    let to_sexp sexp_of_a t =
      let l = to_alist t in
      List.to_sexp (Sexplib.Conv.sexp_of_pair K.to_sexp sexp_of_a) l

    let to_json json_of_a t =
      let l = to_alist t in
      Ezjsonm.(list (pair K.to_json json_of_a) l)

    let of_json a_of_json json =
      let l = Ezjsonm.(get_list (get_pair K.of_json a_of_json) json) in
      of_alist_exn l

    let read read_a buf =
      match List.read (Reader.pair K.read read_a) buf with
      | None          -> None
      | Some (buf, l) ->
        match of_alist l with
        | `Ok l -> Some (buf, l)
        | `Duplicate_key _ -> None

    let write write_a t =
      let bin_write_k = Writer.to_bin_prot K.write in
      let bin_write_a = Writer.to_bin_prot write_a in
      let bindings =
        let bin = Bin_prot.Write.bin_write_pair bin_write_k bin_write_a in
        Writer.of_bin_prot bin
      in
      List.write bindings (to_alist t)

    let compare_bindings compare_a (k1, v1) (k2, v2) =
      match K.compare k1 k2 with
      | 0 -> compare_a v1 v2
      | x -> x

    let compare compare_a m1 m2 =
      let cmp = compare_bindings compare_a in
      let l1 = List.sort ~cmp (to_alist m1) in
      let l2 = List.sort ~cmp (to_alist m2) in
      let rec aux t1 t2 = match t1, t2 with
        | [], [] -> 0
        | [], _  -> -1
        | _ , [] -> 1
        | h1::t1, h2::t2 ->
          match cmp h1 h2 with
          | 0 -> aux t1 t2
          | x -> x
      in
      aux l1 l2

    let equal equal_a t1 t2 =
      let cmp = compare_bindings (fun _ _ -> 0) in
      let l1 = List.sort ~cmp (to_alist t1) in
      let l2 = List.sort ~cmp (to_alist t2) in
      let f (k1, v1) (k2, v2) = K.equal k1 k2 && equal_a v1 v2 in
      List.for_all2 ~f l1 l2

    let mem t key = Map.mem key t
    let add t ~key ~data = Map.add key data t

    let iter2 ~f t1 t2 =
      let rec aux l1 l2 = match l1, l2 with
        | [], t -> List.iter ~f:(fun (key, v) -> f ~key ~data:(`Right v)) t
        | t, [] -> List.iter ~f:(fun (key, v) -> f ~key ~data:(`Left v)) t
        | (k1,v1)::t1, (k2,v2)::t2 ->
          match K.compare k1 k2 with
          | 0 ->
            f ~key:k1 ~data:(`Both (v1, v2));
            aux t1 t2
          | x -> if x < 0 then (
              f ~key:k1 ~data:(`Left v1);
              aux t1 l2
            ) else (
              f ~key:k2 ~data:(`Right v2);
              aux l1 t2
            )
      in
      aux (Map.bindings t1) (Map.bindings t2)

    module Lwt = struct
      open Lwt
      let iter2 m1 m2 ~f =
        let m3 = ref [] in
        iter2 ~f:(fun ~key ~data ->
            m3 := f ~key ~data :: !m3
          ) m1 m2;
        Lwt_list.iter_p
          (fun b -> b >>= fun () -> return_unit) (List.rev !m3)

      let merge m1 m2 ~f =
        let l3 = ref [] in
        let f ~key ~data =
          f ~key data >>= function
          | None   -> return_unit
          | Some v -> l3 := (key, v) :: !l3; return_unit
        in
        iter2 m1 m2 ~f >>= fun () ->
        let m3 = of_alist_exn !l3 in
        return m3

    end
  end
end
