(*
 * Copyright (c) 2013 Thomas Gazagnaire <thomas@gazagnaire.org>
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

(** {2 Irminsule stores} *)

module type S = sig

  (** Base types for stores. *)

  type key
  (** Type of keys. *)

  type value
  (** Type of values. *)

  val write: value -> key Lwt.t
  (** Write the contents of a value to the store. *)

  val read: key -> value option Lwt.t
  (** Read a value from the store. *)

end

module type RAW = S
  with type key := string
   and type value := IrminBuffer.t
(** Raw stores. *)

module Make (S: RAW) (K: IrminKey.S) (V: IrminBase.S):
  S with type key = K.t
     and type value = V.t
(** Build a typed store. *)