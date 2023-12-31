(*
 * Bitset - Efficient bit sets
 * Copyright (C) 2003 Nicolas Cannasse
 * Copyright (C) 2009 David Teller, LIFO, Universite d'Orleans
 * Copyright (C) 2012 Sylvain Le Gall
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version,
 * with the special exception on linking described in file LICENSE.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA
 *)

type t = Bytes.t ref

let print_array =
  let buf = Buffer.create 8 in
  let print_bchar c =
    let rc = ref c in
    Buffer.clear buf;
    for _i = 1 to 8 do
      Buffer.add_char buf
        (if !rc land 1 == 1 then '1' else '0');
      rc := !rc lsr 1
    done;
    Buffer.contents buf
  in
  Array.init 256 print_bchar

let print out t =
  let buf = !t in
  for i = 0 to (Bytes.length buf) - 1 do
    BatInnerIO.nwrite out
      (Array.unsafe_get print_array (Char.code (Bytes.unsafe_get buf i)))
  done

let capacity t = (Bytes.length !t) * 8

let empty () = ref (Bytes.create 0)

let create_ sfun c n = (* n is in bits *)
  if n < 0 then invalid_arg ("BitSet." ^ sfun ^ ": negative size");
  let size = n / 8 + (if n mod 8 = 0 then 0 else 1) in
  ref (Bytes.make size c)

let create =
  create_ "create" '\000'

let copy t = ref (Bytes.copy !t)

let extend t n = (* len in bits *)
  if n > capacity t then
    let t' = create n in
    Bytes.blit !t 0 !t' 0 (Bytes.length !t);
    t := !t'

type bit_op =
  | Set
  | Unset
  | Toggle

let rec apply_bit_op sfun op t x =
  let pos = x / 8 in
  if pos < 0 then
    invalid_arg ("BitSet." ^ sfun ^ ": negative index")
  else if pos < Bytes.length !t then
    let delta = x mod 8 in
    let c = Char.code (Bytes.unsafe_get !t pos) in
    let mask = 1 lsl delta in
    let v = (c land mask) <> 0 in
    let bset c = Bytes.unsafe_set !t pos (Char.unsafe_chr c) in
    match op with
    | Set ->
      if not v then
        bset (c lor mask)
    | Unset ->
      if v then
        bset (c lxor mask)
    (* TODO: shrink *)
    | Toggle ->
      bset (c lxor mask);
  else
    match op with
    | Set | Toggle ->
      extend t (x+1);
      apply_bit_op sfun op t x
    | Unset ->
      ()

let set t x = apply_bit_op "set" Set t x

let unset t x = apply_bit_op "unset" Unset t x

let toggle t x = apply_bit_op "toggle" Toggle t x

let mem t x =
  let pos = x / 8 in
  if pos < 0 then
    invalid_arg "BitSet.mem: negative index"
  else if pos < Bytes.length !t then
    let delta = x mod 8 in
    let c = Char.code (Bytes.unsafe_get !t pos) in
    (c land (1 lsl delta)) <> 0
  else
    false

let add x t = let dup = copy t in set dup x; dup

let remove x t = let dup = copy t in unset dup x; dup

(*$T
  let b = empty() in ignore(add 1 b); count b = 0
  let b = empty() in count(add 1 b) = 1
  let b = create_full 5 in ignore(remove 1 b); count b = 5
  let b = create_full 5 in count(remove 1 b) = 4
*)

let put t =
  function
  | true -> set t
  | false -> unset t

let create_full n =
  let t = create_ "create_full" '\255' n in
  (* Fix the tail *)
  for i = n to (capacity t) - 1 do
    unset t i
  done;
  t

(*$Q
  Q.small_int (fun n -> count (create_full n) = n)
*)

let compare t1 t2 =
  let len1 = Bytes.length !t1 in
  let len2 = Bytes.length !t2 in
  if len1 = len2 then
    Bytes.compare !t1 !t2
  else
    let diff = ref 0 in
    let idx = ref 0 in
    let clen = min len1 len2 in
    while !diff = 0 && !idx < clen do
      diff := Char.compare
          (Bytes.unsafe_get !t1 !idx)
          (Bytes.unsafe_get !t2 !idx);
      incr idx
    done;
    if len1 < len2 then
      while !diff = 0 && !idx < len2 do
        diff := Char.compare '\000' (Bytes.unsafe_get !t2 !idx);
        incr idx
      done
    else
      while !diff = 0 && !idx < len1 do
        diff := Char.compare (Bytes.unsafe_get !t1 !idx) '\000';
        incr idx
      done;
    !diff

(*$T
  compare (of_list [1;2]) (of_list [1]) > 0
*)

let equal t1 t2 =
  compare t1 t2 = 0

let ord = BatOrd.ord compare

(*$Q
  (Q.pair (Q.list Q.small_int) (Q.list Q.small_int)) (fun (l1,l2) -> \
    let of_list' l = of_list (List.map abs l) in \
    let b1 = of_list' l1 and b2 = of_list' l2 in \
    ord b1 b2 = BatOrd.rev_ord0 (ord b2 b1))
*)

(* Array that return the count of bits for a char *)
let count_array =
  let rec count_bits i =
    if i = 0 then
      0
    else
      (count_bits (i / 2)) + (i mod 2)
  in
  Array.init 256 count_bits

let count t =
  let c = ref 0 in
  for i = 0 to (Bytes.length !t) - 1 do
    c := !c +
        Array.unsafe_get count_array (Char.code (Bytes.unsafe_get !t i))
  done;
  !c

(* Array of array that given a char and a delta return the delta of the next
 * set bit.
*)
let next_set_bit_array =
  let eighth_bit = 1 lsl 7 in
  let mk c =
    let arr = Array.make 8 ~-1 in
    let rec mk' last_set_bit i v =
      if i >= 0 then
        let last_set_bit =
          if v land eighth_bit <> 0 then
            i
          else
            last_set_bit
        in
        arr.(i) <- last_set_bit;
        mk' last_set_bit (i - 1) (v lsl 1)
    in
    mk' ~-1 7 c;
    arr
  in
  Array.init 256 mk

(* DEBUG bit arrays.
   let () =
   Array.iteri
    (fun idx arr ->
       let buf = Buffer.create 8 in
         for i = 0 to 7 do
           let c =
             if (idx land (1 lsl (7 - i))) = 0 then
               '0'
             else
               '1'
           in
             Buffer.add_char buf c
         done;
         Buffer.add_string buf  ": ";
         for i = 0 to 7 do
           Buffer.add_string buf
             (Printf.sprintf "%d -> %d; "
                i arr.(i))
         done;
         Buffer.add_char buf '\n';
         Buffer.output_buffer stderr buf)
    next_set_bit_array;
   flush stderr
*)

(* Find the first set bit in the bit array *)
let rec next_set_bit t x =
  if x < 0 then
    invalid_arg "BitSet.next_set_bit"
  else
    let pos = x / 8 in
    if pos < Bytes.length !t then
      begin
        let delta = x mod 8 in
        let c = Char.code (Bytes.unsafe_get !t pos) in
        let delta_next =
          Array.unsafe_get
            (Array.unsafe_get next_set_bit_array c)
            delta
        in
        if delta_next < 0 then
          next_set_bit t ((pos + 1) * 8)
        else
          Some (pos * 8 + delta_next)
      end
    else
      begin
        None
      end

let enum t =
  let rec make n cnt =
    let cur = ref n in
    let cnt = ref cnt in
    let next () =
      match next_set_bit t !cur with
        Some elem ->
        decr cnt;
        cur := (elem+1);
        elem
      | None ->
        raise BatEnum.No_more_elements
    in
    BatEnum.make
      ~next
      ~count:(fun () -> !cnt)
      ~clone:(fun () -> make !cur !cnt)
  in
  make 0 (count t)

(*$T
  BitSet.of_list [5;3;2;1] |> BitSet.enum |> Enum.skip 1 |> Enum.count = 3
  let e = BitSet.of_list [5;3;2;1] |> enum in \
    Enum.junk e; Enum.iter (fun _ -> ()) (Enum.clone e); (Enum.count e = 3)
*)

(*$Q
  (Q.list Q.small_int) (fun l -> \
    let b = BitSet.of_list (List.map abs l) in \
    b |> BitSet.enum |> BitSet.of_enum |> equal b)
*)

let of_enum ?(cap=128) e = let bs = create cap in BatEnum.iter (set bs) e; bs

let of_list ?(cap=128) lst = let bs = create cap in List.iter (set bs) lst; bs

type set_op =
  | Inter
  | Diff
  | Unite
  | DiffSym

let apply_set_op op t1 t2 =
  let idx  = ref 0 in
  let len1 = Bytes.length !t1 in
  let len2 = Bytes.length !t2 in
  let clen = min len1 len2 in
  let apply_op = match op with
    | Inter   -> (fun c1 c2 -> c1 land c2)
    | Diff    -> (fun c1 c2 -> c1 land (lnot c2))
    | Unite   -> (fun c1 c2 -> c1 lor c2)
    | DiffSym -> (fun c1 c2 -> c1 lxor c2)
  in
  (* this operates on the common substring only *)
  while !idx < clen do
    let c1 = Char.code (Bytes.unsafe_get !t1 !idx) in
    let c2 = Char.code (Bytes.unsafe_get !t2 !idx) in
    let cr = apply_op c1 c2 in
    Bytes.unsafe_set !t1 !idx (Char.unsafe_chr cr);
    incr idx
  done;
  (* handles the non-shared suffixes as well *)
  begin match op with
    | Inter ->
      (* clear the non-shared suffix of t1 *)
      if len1 > len2 then begin
        Bytes.fill !t1 len2 (len1 - len2) (Char.chr 0)
      end
    | Diff ->
      (* keep the non-shared suffix of t1, that is, do nothing *)
      ()
    | Unite ->
      (* copy the non-shared suffix of t2 *)
      if len1 < len2 then begin
        extend t1 (len2 * 8);
        Bytes.blit !t2 len1 !t1 len1 (len2 - len1)
      end
    | DiffSym ->
      (* copy the non-shared suffix of t2 *)
      if len1 < len2 then begin
        let tmp = Bytes.copy !t2 in
        Bytes.blit !t1 0 tmp 0 len1;
        t1 := tmp
      end
  end

let intersect t1 t2 = apply_set_op Inter t1 t2

let differentiate t1 t2 = apply_set_op Diff t1 t2

let unite t1 t2 = apply_set_op Unite t1 t2

let differentiate_sym t1 t2 = apply_set_op DiffSym t1 t2

let biop_with_copy f a b =
  let a' = copy a in
  f a' b;
  a'

let inter a b =
  biop_with_copy intersect a b

let union a b =
  biop_with_copy unite a b

let diff a b =
  biop_with_copy differentiate a b

let sym_diff a b =
  biop_with_copy differentiate_sym a b
