
(* This file is free software, part of gen. See file "license" for more details. *)

(** {1 Generators}

    Label version of {!Gen}

    @since 0.2.4 *)

(** {2 Global type declarations} *)

type 'a t = unit -> 'a option
(** A generator may be called several times, yielding the next value
    each time. It returns [None] when no elements remain *)

type 'a gen = 'a t

module type S = GenLabels_intf.S

(** {2 Transient generators} *)

val get : 'a t -> 'a option
(** Get the next value *)

val next : 'a t -> 'a option
(** Synonym for {!get} *)

val get_exn : 'a t -> 'a
(** Get the next value, or fails
    @raise Invalid_argument if no element remains *)

val junk : 'a t -> unit
(** Drop the next value, discarding it. *)

val repeatedly : (unit -> 'a) -> 'a t
(** Call the same function an infinite number of times (useful for instance
    if the function is a random generator). *)

include S with type 'a t := 'a gen
(** Operations on {b transient} generators *)

(** {2 Restartable generators} *)

module Restart : sig
  type 'a t = unit -> 'a gen

  type 'a restartable = 'a t

  include S with type 'a t := 'a restartable

  val cycle : 'a t -> 'a t
  (** Cycle through the enum, endlessly. The enum must not be empty. *)

  val lift : ('a gen -> 'b) -> 'a t -> 'b

  val lift2 : ('a gen -> 'b gen -> 'c) -> 'a t -> 'b t -> 'c
end

(** {2 Utils} *)

val persistent : 'a t -> 'a Restart.t
(** Store content of the transient generator in memory, to be able to iterate
    on it several times later. If possible, consider using combinators
    from {!Restart} directly instead. *)

val persistent_lazy : ?caching:bool -> ?max_chunk_size:int ->
  'a t -> 'a Restart.t
(** Same as {!persistent}, but consumes the generator on demand (by chunks).
    This allows to make a restartable generator out of an ephemeral one,
    without paying a big cost upfront (nor even consuming it fully).
    Optional parameters: see {!GenMList.of_gen_lazy}.
    @since 0.2.2 *)

val peek : 'a t -> ('a * 'a option) t
(** [peek g] transforms the generator [g] into a generator
    of [x, Some next] if [x] was followed by [next] in [g], or [x, None] if [x]
    was the last element of [g]
    @since 0.4 *)

val peek_n : n:int -> 'a t -> ('a * 'a array) t
(** [peek_n ~n g] iterates on [g], returning along with each element
    the array of the (at most) [n] elements that follow it immediately
    @raise Invalid_argument if the int is [< 1]
    @since 0.4 *)

val start : 'a Restart.t -> 'a t
(** Create a new transient generator.
    [start gen] is the same as [gen ()] but is included for readability. *)

(** {2 Basic IO}

    Very basic interface to manipulate files as sequence of chunks/lines. *)

module IO : sig
  val with_in : ?mode:int -> ?flags:open_flag list ->
    file:string ->
    (char t -> 'a) -> 'a
  (** [with_in ~file f] opens [file] and calls [f g],
      where [g] is a generator of characters from the file.
      The generator is only valid within
      the scope in which [f] is called. *)

  val with_lines : ?mode:int -> ?flags:open_flag list ->
    file:string -> (string t -> 'a) -> 'a
  (** [with_lines ~file f] opens file [file] and calls [f g],
      where [g] is a generator that iterates on the lines from the file.
      Do not use the generator outside of the scope of [f]
      @since 0.4 *)

  val write_str : ?mode:int -> ?flags:open_flag list ->  ?sep:string ->
    file:string -> string t -> unit
  (** [write_to ~file g] writes all strings from [g] into the given
      file. It takes care of opening and closing the file. Does not
      add [sep] after the last string.
      @param mode default [0o644]
      @param flags used by [open_out_gen]. Default: [[Open_creat;Open_wronly]].
      @param sep separator between each string (e.g. newline) *)

  val write : ?mode:int -> ?flags:open_flag list ->
    file:string -> char t -> unit
  (** Same as {!write_str} but with individual characters *)

  val write_lines : ?mode:int -> ?flags:open_flag list ->
    file:string -> string t -> unit
  (** [write_lines ~file g] is similar to [write_str file g ~sep:"\n"] but
      also adds ['\n'] at the end of the file
      @since 0.4 *)
end
