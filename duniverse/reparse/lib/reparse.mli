(*-------------------------------------------------------------------------
 * Copyright (c) 2020, 2021 Bikal Gurung. All rights reserved.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License,  v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * reparse v3.1.0
 *-------------------------------------------------------------------------*)

(** {1 Overview} *)

(** Parser provides functions and types to construct robust, performant and
    reusable parsers. At the core is a type {!type:Reparse.PARSER.t} which
    represents a constructed parser definition. A parser
    {!type:Reparse.PARSER.t} is defined by composing together one or more
    parsers or {!type:Reparse.t}s via usage of parser operators.

    An instance of {!type:Reparse.PARSER.t} represents an un-evaluated parser.
    Use {!val:Reparse.PARSER.parse} function to evaluate it.

    {!type:Reparse.INPUT} represents a generalization of data input to
    {!val:Reparse.parse}. Implement the interface to create new input types.

    Parser functions are broadly organized into following categories:

    - Monadic parsers
    - Char/String parsers
    - Alternate parsers
    - Boolean parsers
    - Repetition parsers
    - RFC 5234 parsers
    - Others *)

module type PARSER = sig
  (** Represents a parser which can parse value ['a]. Use {{:#parse} parse
      functions} to evaluate a parser. *)
  type 'a t

  type 'a promise

  type input

  type pos = int

  val parse : ?pos:pos -> input -> 'a t -> ('a * pos, string) result promise
  (** [parse ?pos input p] parses [input] using parser [p] from given [pos]. It
      returns a tuple ['a * pos] which represents a parsed value ['a] and the
      final parser position [pos].

      Default value for [pos] is [0]. *)

  (** {2 Monadic operators} *)

  val return : 'a -> 'a t
  (** [return v] always parses value [v].

      {4:return_examples Examples}

      {[
        module P = Reparse.String.String;;

        let input = new P.string_input "" in
        let v1 = P.(parse input (return 5)) in
        let v2 = P.(parse input (return "hello")) in
        v1 = 5 && v2 = "hello"
      ]} *)

  val unit : unit t
  (** [unit] always parses to [():unit] value. *)

  val ignore : _ t -> unit t
  (** [ignore p] ignore any result from [p] upon success and return [()]
      instead. *)

  val fail : string -> 'a t
  (** [fail err_msg] returns a parser that always fails with [err_msg].

      {4:fail_examples Examples}

      {[
        module P = Reparse.String;;

        let input = new P.string_input "" in
        let r =
          try
            let _ = P.(parse input (fail "hello error")) in
            assert false
          with e -> e
        in
        r
        = P.Parser
            {offset= 0; line_number= 0; column_number= 0; msg= "hello error"}
      ]} *)

  val bind : ('a -> 'b t) -> 'a t -> 'b t
  (** [bind f p] is prefix version of [p >>= f]. *)

  val both : 'a t -> 'b t -> ('a * 'b) t
  (** [both p q] is evaluates to [(a,b)] when [a] is evaluted from [p] and [b]
      is evaluated from [q]. *)

  val apply : ('a -> 'b) t -> 'a t -> 'b t

  val map : ('a -> 'b) -> 'a t -> 'b t
  (** [map f p] is prefix version of [p >>| f]. *)

  val map2 : ('a -> 'b -> 'c) -> 'a t -> 'b t -> 'c t

  val map3 : ('a -> 'b -> 'c -> 'd) -> 'a t -> 'b t -> 'c t -> 'd t

  val map4 :
    ('a -> 'b -> 'c -> 'd -> 'e) -> 'a t -> 'b t -> 'c t -> 'd t -> 'e t

  module Infix : sig
    val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t
    (** [p >>= f] returns a new parser b where,

        - [a] is the parsed value of [p]
        - [b] is [f a] Also known as [bind] operation.

        {4:infix_bind_examples Examples}

        {[
          module P = Reparse.String
          open P;;

          let f a = P.pure (Char.code a) in
          let p = P.char 'h' in
          let p = p >>= f in
          let v = P.parse_string p "hello" in
          v = 104
        ]} *)

    val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t
    (** [p >>| f] returns a new parser encapsulating value [b] where,

        - [a] is the parsed value of [p].
        - [b] is [f a]. Also known as [map] operation.

        {4:infix_map_examples Examples}

        {[
          module P = Reparse.String
          open P;;

          let f a = Char.code a in
          let p = P.char 'h' in
          let p = p >>| f in
          let v = P.parse_string p "hello" in
          v = 104
        ]} *)

    val ( <*> ) : 'a t -> ('a -> 'b) t -> 'b t
    (** [pf <*> q] returns a new parser encapsulating value [b] where

        - [pf] and [q] are evaluated sequentially in order as given.
        - [f] is the parsed value of [pf]
        - [a] is the parsed value of [q]
        - [b] is [f a] Also known as [Applicative] operation.

        {4:infix_applicative_examples Examples}

        {[
          module P = Reparse
          open P;;

          let f a = a + 2 in
          let pf = P.pure f in
          let q = P.pure 2 in
          let p = pf <*> q in
          let v = P.parse_string p "hello" in
          v = 4
        ]} *)

    val ( <$> ) : 'a t -> ('a -> 'b) -> 'b t
    (** [f <$> p] is [return f <*> p]. *)

    val ( <$$> ) : 'a t * 'b t -> ('a -> 'b -> 'c) -> 'c t

    val ( <$$$> ) : 'a t * 'b t * 'c t -> ('a -> 'b -> 'c -> 'd) -> 'd t

    val ( <$$$$> ) :
      'a t * 'b t * 'c t * 'd t -> ('a -> 'b -> 'c -> 'd -> 'e) -> 'e t

    val ( <$ ) : 'a -> 'b t -> 'a t
    (** [v <$ p] replaces the parse value of [p] with [v].

        {4:infix_replace_examples Examples}

        {[
          module P = Reparse.String
          open P;;

          let v = "hello" in
          let p = P.char 'h' in
          let p = v <$ p in
          let v2 = P.parse_string p "hello" in
          v2 = "hello"
        ]} *)

    val ( $> ) : 'a t -> 'b -> 'b t
    (** [p $> v] is inverse of [v <$ p]. *)

    val ( *> ) : _ t -> 'b t -> 'b t
    (** [p *> q] returns a parser encapsulating value [a] where,

        - [p], [q] are evaluated sequentially in order as given.
        - [a] is parsed value of [q].
        - The parsed value of [p] is discarded. Also known as [discard left].

        {4:infix_discard_left_examples Examples}

        {[
          module P = Reparse.String
          open P;;

          let p = P.string "world" in
          let q = P.pure "hello" in
          let p = p *> q in
          let v = P.parse_string p "world" in
          v = "hello"
        ]} *)

    val ( <* ) : 'a t -> _ t -> 'a t
    (** [p <* q] returns a parser encapsulating value [a] where,

        - [p], [q] are evaluated sequentially in order as given.
        - [a] is parsed value of [p].
        - The parsed value of [q] is discarded. Also know as discard_right.

        {4:infix_discard_right_examples Examples}

        {[
          module P = Reparse.String
          open P;;

          let p = P.string "world" in
          let q = P.pure "hello" in
          let p = p <* q in
          let v = P.parse_string p "world" in
          v = "world"
        ]} *)

    val ( <|> ) : 'a t -> 'a t -> 'a t
    (** [p <|> q] returns a parser encapsulating value [a] where,

        - [p],[q] are evaluated sequentially in order as given.
        - [a] is the parsed value of [p] if [p] is successful
        - [a] is the parsed value of [q] if [p] is a failure and [q] is a
          success.
        - If both - [p] and [q] - fails, then the parser fails.

        {4:infix_alternate_examples Examples}

        [p] fails and [q] succeeds, therefore we return [q]'s parsed value ['w']

        {[
          module P = Reparse.String
          open P;;

          let p = P.char 'h' in
          let q = P.char 'w' in
          let p = p <|> q in
          let v = P.parse_string p "world" in
          v = 'w'
        ]}

        [p] succeeds therefore we return its parsed value ['h']

        {[
          let p = P.char 'h' in
          let q = P.char 'w' in
          let p = p <|> q in
          let v = P.parse_string p "hello" in
          v = 'h'
        ]}

        The parser fails if both [p] and [q] fails.

        {[
          let p = P.char 'h' in
          let q = P.char 'w' in
          let p = p <|> q in
          let v =
            try
              let _ = P.parse_string p "" in
              false
            with _ -> true
          in
          v = true
        ]} *)

    val ( let* ) : 'a t -> ('a -> 'b t) -> 'b t
    (** [let*] is a let syntax binding for {!val:Reparse.Infix.(>>=)}

        {4:infix_let_bind_examples Examples}

        {[
          module P = Reparse.String
          open P;;

          let p =
            let* a = P.pure 5 in
            let total = a + 5 in
            P.pure total
          in
          let v = P.parse_string p "" in
          v = 10
        ]} *)

    val ( and* ) : 'a t -> 'b t -> ('a * 'b) t

    val ( let+ ) : 'a t -> ('a -> 'b) -> 'b t
    (** [let*] is a let syntax binding for {!val:Reparse.(>|=)}

        {4:infix_let_map_examples Examples}

        {[
          module P = Reparse.String
          open P;;

          let p =
            let+ a = P.pure 5 in
            let total = a + 5 in
            total
          in
          let v = P.parse_string p "" in
          v = 10
        ]} *)

    val ( and+ ) : 'a t -> 'b t -> ('a * 'b) t

    val ( <?> ) : 'a t -> string -> 'a t
    (** [p <?> err_msg] parses [p] to value [a] and returns a new parser
        encapsulating [a]. If [p] is a failure, then it fails with error message
        [err_msg]. Often used as a last choice in [<|>], e.g.
        [a <|> b <|> c <?> "expected a b c"].

        {4:infix_error_named_examples Examples}

        {[
          module P = Reparse.String
          open P;;

          let p = P.char 'h' <|> P.char 'w' in
          let err_msg = "[error]" in
          let p = p <?> err_msg in
          let v =
            try
              let _ = P.parse_string p "" in
              false
            with
            | P.Parser
                {offset= 0; line_number= 0; column_number= 0; msg= "[error]"} ->
                true
            | _ -> false
          in
          v = true
        ]} *)
  end

  include module type of Infix

  (** [ppx_let] syntax support module. *)
  module Let_syntax : sig
    val return : 'a -> 'a t

    val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

    val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t

    module Let_syntax : sig
      val return : 'a -> 'a t

      val map : 'a t -> f:('a -> 'b) -> 'b t

      val bind : 'a t -> f:('a -> 'b t) -> 'b t

      val both : 'a t -> 'b t -> ('a * 'b) t

      val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t

      val map3 : 'a t -> 'b t -> 'c t -> f:('a -> 'b -> 'c -> 'd) -> 'd t

      val map4 :
        'a t -> 'b t -> 'c t -> 'd t -> f:('a -> 'b -> 'c -> 'd -> 'e) -> 'e t
    end
  end

  module Promise : sig
    type 'a t = 'a promise

    val return : 'a -> 'a t

    val catch : (unit -> 'a t) -> (exn -> 'a t) -> 'a t

    val bind : ('a -> 'b t) -> 'a t -> 'b t

    val ( >>| ) : 'a t -> ('a -> 'b) -> 'b t

    val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t
  end

  (** {2 Char/String parsers} *)

  val peek_char : char t
  (** [peek_char t] parses the next character from input without consuming it.
      It fails if [EOI] is reached.

      {4:peek_char_examples Examples}

      {[
        module P = Reparse.String;;

        let p = P.peek_char in
        let v = P.parse_string p "hello" in
        v = 'h'
      ]}

      Input is not consumed. *)

  val peek_char_opt : char option t
  (** [peek_char_opt] is the exception safe version of [peek_char]. It returns
      an option rather than throwing [exn] when [EOI] is reached. *)

  val peek_string : int -> string t
  (** [peek_string n] parse a string of length [n] without consuming it.

      {4:peek_string_examples Examples}

      {[
        module P = Reparse.String
        open P;;

        let p = P.peek_string 5 in
        let v = P.parse_string p "hello" in
        v = "hello"
      ]}

      Input is not consumed. *)

  val any_char : char t
  (** [any_char] parses the next character from input. Fails if input has
      reached end of input.

      {4:next_examples Examples}

      {[
        module P = Reparse.String;;

        let v = P.(parse_string any_char "hello") in
        v = 'h'
      ]} *)

  val unsafe_any_char : char t
  (** [unsafe_any_char] is same as [any_char] except the returned char value is
      not buffered by the input. {b Important} don't use this parser with
      backtracking parsers such as [<|>], [alt], [any] etc.

      {b Note} Ensure you call [trim_input_buffer] after calling this parser. *)

  val char : char -> char t
  (** [char c] parses character [c] exactly.

      {4:char_examples Examples}

      {[
        module P = Reparse.String;;

        let p = P.char 'h' in
        let v = P.parse_string p "hello" in
        v = 'h'
      ]} *)

  val char_if : (char -> bool) -> char t
  (** [char_if f] parses a character [c] if [f c] is [true].

      {4:char_if_examples Examples}

      {[
        module P = Reparse.String;;

        let p = P.char_if (function 'a' -> true | _ -> false) in
        let v = P.parse_string p "abc" in
        v = 'a'
      ]} *)

  val string_cs : string -> string t
  (** [string_cs s] parses a string [s] exactly. String comparison is case
      sensitive.

      {4:string_examples Examples}

      {[
        module P = Reparse.String;;

        let p = P.string_cs "hello" in
        let v = P.parse p (P.of_string "hello world") in
        v = "hello"
      ]} *)

  val string_ci : string -> string t

  val string_of_chars : char list -> string t
  (** [string_of_chars l] converts [char list] [l] to string

      {4:string_of_chars_examples Examples}

      {[
        module P = Reparse.String;;

        let p = P.(take ~sep_by:space next >>= string_of_chars) in
        let v = P.parse_string p "h e l l o" in
        v = "hello"
      ]} *)

  val take_string : int -> string t
  (** [take_string n] returns a string of length [n] exactly from input. *)

  val take_cstruct : int -> Cstruct.t t
  (** [take_cstruct n] returns a [Cstruct.t] of length [n] exactly from input.
      This is usually a zero copy if input is an unbuffered input type. *)

  val unsafe_take_cstruct : int -> Cstruct.t t
  (** [unsafe_take_cstruct n] reads [n] bytes exactly from input without
      buffering. Since the read [n] bytes is unbuffered, the parser is unable to
      backtrack beyond position [pos + n] where [pos] is the input position
      before the parser is called.

      [Note:] Ensure that [unsafe_take_cstruct] is not being run as part of
      combinators that require backtracking such as [<|>, any]. Additionally it
      is recommended to call [trim_input_buffer] after calling
      [unsafe_take_cstruct]. *)

  val unsafe_take_cstruct_ne : int -> Cstruct.t t
  (** [unsafe_take_cstruct_ne n] is same as [unsafe_take_cstruct n] except that
      [n] represents the maximum number of bytes read. *)

  (** {2 Alternate parsers} *)

  val any : ?failure_msg:string -> 'a t list -> 'a t
  (** [any l] parses the value of the first successful parser in list [l].
      Specified parsers in [l] are evaluated sequentially from left to right. A
      failed parser doesn't consume any input, i.e. [offset] is unaffected. The
      parser fails if none of the parsers in [l] are evaluated successfully.

      {4:any_examples Examples}

      First successful parser result is returned

      {[
        module P = Reparse.String;;

        let p = P.(any [char 'z'; char 'x'; char 'a']) in
        let v = P.parse_string p "zabc" in
        v = 'z'
        ;;

        let p = P.(any [char 'z'; char 'x'; char 'a']) in
        let v = P.parse_string p "xabc" in
        v = 'x'
        ;;

        let p = P.(any [char 'z'; char 'x'; char 'a']) in
        let v = P.parse_string p "abc" in
        v = 'a'
      ]}

      Parser fails when none of the parsers in [l] are successful.

      {[
        let p = P.(any [char 'z'; char 'x'; char 'a']) in
        let v =
          try
            let _ = P.parse_string p "yyy" in
            false
          with _ -> true
        in
        v = true
      ]} *)

  val alt : 'a t -> 'a t -> 'a t
  (** [alt p q] is [p <|> q]. See {!val:Reparse.Infix.(<|>)} *)

  val optional : 'a t -> 'a option t
  (** [optional p] parses [Some a] if successful and [None] otherwise. [a] is
      the parsed value of [p].

      {4:optional_examples Examples}

      {[
        module P = Reparse.String
        open P;;

        let p = P.(optional (char 'a')) in
        let v = P.parse_string p "ab" in
        v = Some 'a'
        ;;

        let p = P.(optional (char 'z')) in
        let v = P.parse_string p "ab" in
        v = None
      ]}*)

  (** {2 Boolean} *)

  val not_ : 'a t -> unit t
  (** [not_ p] parses value [()] if and only if [p] fails to parse, otherwise
      the parse fails.

      {4:not__examples Examples}

      {[
        module P = Reparse.String;;

        let p = P.(not_ (char 'a')) in
        let v = P.parse_string p "bbb" in
        v = ()
      ]} *)

  val is : 'a t -> bool t
  (** [is p] parses [true] if [p] is successful, [false] otherwise. {b Note}
      evaluation of [p] doesn't consume any input.

      {4:is_examples Examples}

      {[
        module P = Reparse.String;;

        let p = P.(is (char 'b')) in
        let v = P.parse_string p "bcb" in
        v = true
      ]} *)

  val is_not : 'a t -> bool t
  (** [is_not p] parses value [true] if [p] fails to parse and [false]
      otherwise. {b Note} evaluating [p] doesn't consume any input.

      {4:is_not_examples Examples}

      {[
        module P = Reparse.String;;

        let p = P.(is_not (char 'a')) in
        let v = P.parse_string p "bbb" in
        v = true
      ]} *)

  (** {2 Repetition} *)

  val recur : ('a t -> 'a t) -> 'a t
  (** [recur f] returns a recursive parser. Function value [f] accepts a parser
      [p] as its argument and returns a parser [q]. Parser [q] in its definition
      can refer to [p] and [p] can refer to [q] in its own definition. Such
      parsers are also known as a fixpoint or y combinator. *)

  val all : 'a t list -> 'a list t
  (** [all parsers] parses all parsers in [parsers] and returns a list of
      successful parse result. All of the [parsers] must succeed for [all] to
      succeed. *)

  val all_unit : _ t list -> unit t
  (** [all_unit parsers] parses [parsers] and discards their results. All of the
      [parsers] must succeed for [all_unit] to succeed. *)

  val skip : ?at_least:int -> ?up_to:int -> _ t -> int t
  (** [skip ~at_least ~up_to p] repeatedly parses [p] and discards its value.
      The lower and upper bound of repetition is specified by arguments
      [at_least] and [up_to] respectively. The default value of [at_least] is 0.
      The default value of [up_to] is unspecified, i.e. there is no upper limit.
      The repetition ends when one of the following occurs:

      - [p] evaluates to failure
      - [up_to] upper bound value is reached The parser encapsulates the count
        of times [p] was evaluated successfully.

      {4:skip_examples Examples}

      {[
        module P = Reparse.String;;

        let p = P.(skip space) in
        let v = P.parse_string p "     " in
        v = 5
      ]} *)

  val take : ?at_least:int -> ?up_to:int -> ?sep_by:_ t -> 'a t -> 'a list t
  (** [take ~at_least ~up_to ~sep_by p] repeatedly parses [p] and returns the
      parsed values. The lower and upper bound of repetition is specified by
      arguments [at_least] and [up_to] respectively. The default value of
      [at_least] is [0]. The default value of [up_to] is unspecified, i.e. there
      is no upper limit. If [sep_by] is specified then the evaluation of [p]
      must be followed by a successful evaluation of [sep_by]. The parsed value
      of [sep_by] is discarded. The repetition ends when one of the following
      occurs:

      - [p] evaluates to failure
      - [sep_by] evaluates to failure
      - [up_to] upper boudn value is reached The parser fails if the count of
        repetition of [p] does not match the value specified by [at_least].

      {4:take_examples Examples}

      Default behaviour.

      {[
        module P = Reparse.String;;

        let p = P.(take (char 'a')) in
        let v = P.parse_string p "aaaaa" in
        v = ['a'; 'a'; 'a'; 'a'; 'a']
      ]}

      Specify [~sep_by].

      {[
        module P = Reparse.String;;

        let p = P.(take ~sep_by:(char ',') (char 'a')) in
        let v = P.parse_string p "a,a,a,a,a" in
        v = ['a'; 'a'; 'a'; 'a'; 'a']
      ]}

      Specify lower bound argument [at_least].

      {[
        module P = Reparse.String;;

        let p = P.(take ~at_least:3 ~sep_by:(char ',') (char 'a')) in
        let v = P.parse_string p "a,a,a,a,a" in
        v = ['a'; 'a'; 'a'; 'a'; 'a']
      ]}

      Lower bound not met results in error.

      {[
        module P = Reparse.String;;

        let p = P.(take ~at_least:5 ~sep_by:(char ',') (char 'a')) in
        let v =
          try
            let _ = P.parse_string p "a,a,a,a" in
            false
          with _ -> true
        in
        v = true
      ]}

      Specify upper bound [up_to].

      {[
        module P = Reparse.String;;

        let p = P.(take ~up_to:3 ~sep_by:(char ',') (char 'a')) in
        let v = P.parse_string p "a,a,a,a,a" in
        v = ['a'; 'a'; 'a']
      ]} *)

  val take_while_cb :
    ?sep_by:_ t -> while_:bool t -> on_take_cb:('a -> unit t) -> 'a t -> unit t
  (** [take_while_cb ~sep_by ~while_ ~on_take p] repeatedly parses [p] and calls
      callback [on_take_cb] with the parsed value. [p] is evaluated if and only
      if [while_] evaluates to [true]. If [sep_by] is specified then the
      evaluation of [p] must be followed by a successful evaluation of [sep_by].
      The parsed value of [sep_by] is discarded. [p] is evaluated repeatedly.
      The repetition ends when one of the following occurs: [on_take_cb] is the
      callback function that is called every time [p] is evaluated.

      - [p] evaluates to failure
      - [while_] returns [false]
      - [sep_by] evaluates to failure [take_while_cb] is the general version of
        {!val:Reparse.take_while}. It allows to specify how the value [a] is to
        be collected. {b Note} [while_] does not consume input.

      {4:take_while_cb_examples Examples}

      {[
        module P = Reparse.String
        open P;;

        let buf = Buffer.create 0 in
        let on_take_cb a = Buffer.add_char buf a in
        let p =
          P.(take_while_cb (char 'a') ~while_:(is_not (char 'b')) ~on_take_cb)
        in
        let v = P.parse_string p "aaab" in
        let s = Buffer.contents buf in
        v = 3 && s = "aaa"
      ]} *)

  val take_while : ?sep_by:_ t -> while_:bool t -> 'a t -> 'a list t
  (** [take_while ~sep_by p ~while_ p] repeatedly parses [p] and returns its
      value. [p] is evaluated if and only if [while_] evaluates to [true]. If
      [sep_by] is specified then the evaluation of [p] must be followed by a
      successful evaluation of [sep_by]. The parsed value of [sep_by] is
      discarded. The repetition ends when one of the following occurs:

      - [p] evaluates to failure
      - [while_] returns [false]
      - [sep_by] evaluates to failure {b Note} [while_] does not consume input.

      {4:take_while_examples Examples}

      Default behaviour.

      {[
        module P = Reparse.String;;

        let p = P.(take_while ~while_:(is_not (char 'b')) (char 'a')) in
        let v = P.parse_string p "aab" in
        v = ['a'; 'a']
      ]}

      Specify [sep_by].

      {[
        module P = Reparse.String;;

        let p =
          P.(
            take_while ~sep_by:(char ',') ~while_:(is_not (char 'b')) (char 'a'))
        in
        let v = P.parse_string p "a,a,ab" in
        v = ['a'; 'a'; 'a']
      ]} *)

  val take_between : ?sep_by:_ t -> start:_ t -> end_:_ t -> 'a t -> 'a list t
  (** [take_between ~sep_by ~start ~end_ p] parses [start] and then repeatedly
      parses [p] while the parsed value of [p] doesn't equal to parsed value of
      [end_]. After the repetition end, it parses [end_]. The parser returns the
      list of parsed values of [p]. Both [start] and [end_] parser values are
      discarded. If [sep_by] is specified then the evaluation of [p] must be
      followed by a successful evaluation of [sep_by]. The parsed value of
      [sep_by] is discarded. The repetition ends when one of the following
      occurs:

      - [p] evaluates to failure
      - [end_] parsed value matches [p] parsed value
      - [sep_by] evaluates to failure

      {4:take_between_examples Examples}

      {[
        module P = Reparse.String;;

        let p =
          P.(
            take_between ~sep_by:(char ',') ~start:(P.char '(') ~end_:(char ')')
              next)
        in
        let v = P.parse_string p "(a,a,a)" in
        v = ['a'; 'a'; 'a']
      ]} *)

  (** {1:rfc5234 RFC 5234}

      Parsers as defined in RFC 5234, Appendix B.1.

      @see <https://tools.ietf.org/html/rfc5234#appendix-B> *)

  val alpha : char t
  (** [alpha] parses a character in range [A- Z] or [a-z].

      {4:alpha_examples Examples}

      {[
        module P = Reparse
        open P;;

        let p = P.(take alpha) in
        let v = P.parse_string p "abcdABCD" in
        v = ['a'; 'b'; 'c'; 'd'; 'A'; 'B'; 'C'; 'D']
      ]} *)

  val alpha_num : char t
  (** [alpha_num] parses a character in range [A-Z] or [a-z] or [0-9].

      {4:alpha_num_examples Examples}

      {[
        module P = Reparse
        open P;;

        let p = P.(take alpha_num) in
        let v = P.parse_string p "ab123ABCD" in
        v = ['a'; 'b'; '1'; '2'; '3'; 'A'; 'B'; 'C'; 'D']
      ]} *)

  val lower_alpha : char t
  (** [lower_alpha] parses a character in range [a-z].

      {4:lower_alpha_examples Examples}

      {[
        module P = Reparse
        open P;;

        let p = P.(take lower_alpha) in
        let v = P.parse_string p "abcd" in
        v = ['a'; 'b'; 'c'; 'd']
      ]} *)

  val upper_alpha : char t
  (** [upper_alpha] parses a character in range [A-Z].

      {4:upper_alpha_examples Examples}

      {[
        module P = Reparse
        open P;;

        let p = P.(take upper_alpha) in
        let v = P.parse_string p "ABCD" in
        v = ['A'; 'B'; 'C'; 'D']
      ]} *)

  val bit : char t
  (** [bit] parses a character which is either ['0'] or ['1'].

      {4:bit_examples Examples}

      {[
        module P = Reparse;;

        let p = P.(take bit) in
        let v = P.parse_string p "0110 ab" in
        v = ['0'; '1'; '1'; '0']
      ]} *)

  val ascii_char : char t
  (** [ascii_char] parses any US-ASCII character.

      {4:ascii_char_examples Examples}

      {[
        module P = Reparse;;

        let p = P.(take ascii_char) in
        let v = P.parse_string p "0110 abc '" in
        v = ['0'; '1'; '1'; '0'; ' '; 'a'; 'b'; 'c'; ' '; '\'']
      ]} *)

  val cr : char t
  (** [cr] parses character ['\r'].

      {4:cr_examples Examples}

      {[
        module P = Reparse;;

        let v = P.(parse_string cr "\rab") in
        v = '\r'
      ]} *)

  val crlf : string t
  (** [crlf] parses string ["\r\n"].

      {4:crlf_examples Examples}

      {[
        module P = Reparse;;

        let v = P.(parse_string crlf "\r\n abc") in
        v = "\r\n"
      ]} *)

  val control : char t
  (** [control] parses characters in range [0x00 - 0x1F] or character [0x7F].

      {4:control_examples Examples}

      {[
        module P = Reparse;;

        let v = P.(parse_string control "\x00") in
        v = '\x00'
      ]} *)

  val digit : char t
  (** [digit] parses one of the digit characters, [0 .. 9].

      {4:digit_examples Examples}

      {[
        module P = Reparse;;

        let p = P.(take digit) in
        let v = P.parse_string p "0123456789a" in
        v = ['0'; '1'; '2'; '3'; '4'; '5'; '6'; '7'; '8'; '9']
      ]} *)

  val digits : string t
  (** [digits] parses one or more digit characters, [0 .. 9].

      {4:digits_examples Examples}

      {[
        module P = Reparse;;

        let v = P.(parse_string digits "1234 +") in
        v = "1234"
      ]} *)

  val dquote : char t
  (** [dquote] parses double quote character ['"'].

      {4:dquote_examples Examples}

      {[
        module P = Reparse;;

        let v = P.(parse_string dquote "\"hello ") in
        v = '"'
      ]} *)

  val hex_digit : char t
  (** [hex_digit] parses any of the hexadecimal digits -
      [0..9, A, B, C, D, E, F].

      {4:hex_digit_examples Examples}

      {[
        module P = Reparse;;

        let p = P.(take hex_digit) in
        let v = P.parse_string p "0ABCDEFa" in
        v = ['0'; 'A'; 'B'; 'C'; 'D'; 'E'; 'F']
      ]} *)

  val htab : char t
  (** [htab] parses a horizontal tab character ['\t'].

      {4:htab_examples Examples}

      {[
        module P = Reparse;;

        let v = P.(parse_string htab "\t") in
        v = '\t'
      ]} *)

  val lf : char t
  (** [lf] parses a linefeed ['\n'] character.

      {4:lf_examples Examples}

      {[
        module P = Reparse;;

        let v = P.(parse_string lf "\n") in
        v = '\n'
      ]} *)

  val octet : char t
  (** [octect] parses any character in the range [\x00 - \xFF]. Synonym for
      {!val:Reparse.next}

      {4:octet_examples Examples}

      {[
        module P = Reparse;;

        let p = P.(take octet) in
        let v = P.parse_string p "0110 abc '" in
        v = ['0'; '1'; '1'; '0'; ' '; 'a'; 'b'; 'c'; ' '; '\'']
      ]} *)

  val space : char t
  (** [space] parses a space character.

      {4:space_examples Examples}

      {[
        module P = Reparse;;

        let v = P.(parse_string space " abc '") in
        v = ' '
      ]} *)

  val vchar : char t
  (** [vchar] parses any of the visible - printable - characters.

      {4:vchar_examples Examples}

      {[
        module P = Reparse;;

        let p = P.(take vchar) in
        let v = P.parse_string p "0110abc\x00" in
        v = ['0'; '1'; '1'; '0'; 'a'; 'b'; 'c']
      ]} *)

  val whitespace : char t
  (** [whitespace] parses a space [' '] or horizontal tab ['\t'] character.

      {4:whitespace_examples Examples}

      {[
        module P = Reparse;;

        let p = P.(take whitespace) in
        let v = P.parse_string p "\t \t " in
        v = ['\t'; ' '; '\t'; ' ']
      ]} *)

  (** {2 Input manipulation} *)

  val advance : int -> unit t
  (** [advance n] advances input by [n] bytes. *)

  val eoi : unit t
  (** [eoi] parses end of input. Fails if parser is not at end of input.

      {4:eoi_examples Examples}

      {[
        module P = Reparse.String;;

        let v = P.(parse_string eoi "") in
        v = ()
        ;;

        let v =
          try
            let _ = P.(parse_string eoi "a") in
            false
          with _ -> true
        in
        v = true
      ]} *)

  val trim_input_buffer : unit t
  (** [trim_input_buffer ()] calls [INPUT.trim_buffer] with the current parser
      position. Use this function to control the memory consumption of the input
      buffer.

      {b Note} Once trimmed the parser is unable to backtrack beyond the
      position of [last_trimmed_pos]. This may affect a correct functioning of
      [<|>] parser as it backtracks when trying various alternatives. *)

  val pos : int t
  (** [pos] returns the current parser position. *)

  val last_trimmed_pos : int t
  (** [last_trimmed_pos] returns the last trimmed input position marker. *)

  val input_buffer_size : int option t
  (** [input_buffer_size] returns current input buffer size in bytes if input is
      a buffered input otherwise it returns [None] for unbuffered input. *)

  val of_promise : 'a promise -> 'a t
end

module type PROMISE = sig
  type 'a t

  val return : 'a -> 'a t

  val catch : (unit -> 'a t) -> (exn -> 'a t) -> 'a t

  val bind : ('a -> 'b t) -> 'a t -> 'b t
end

module type INPUT = sig
  (** Represents the input. *)
  type t

  (** Represents an input promise. *)
  type 'a promise

  type input

  val create : input -> t

  val trim_buffer : t -> pos:int -> unit promise
  (** [trim_buffer t ~pos] removes data from the input buffer up till [pos].

      {b Note} After the input buffer is trimmed the parser is unable to
      backtrack to [pos] less than [pos]. *)

  val get_char : t -> pos:int -> [`Char of char | `Eof] promise

  val get_char_unbuffered : t -> pos:int -> [`Char of char | `Eof] promise

  val get_cstruct :
    t -> pos:int -> len:int -> [`Cstruct of Cstruct.t | `Eof] promise
  (** [get t ~pos ~len] returns [`String s] where [String.length s <= len] or
      [`Eof] if [EOI] is reached. *)

  val get_cstruct_unbuffered :
    t -> pos:int -> len:int -> [`Cstruct of Cstruct.t | `Eof] promise

  val last_trimmed_pos : t -> int promise

  val buffer_size : t -> int option promise
end

(** {2 Buffered Input} *)

module type BUFFERED_INPUT = sig
  type t

  type 'a promise

  val read : t -> len:int -> [`Cstruct of Cstruct.t | `Eof] promise
end

(** Makes a buffered [INPUT] module. Buffered input provide backtracking
    functionality in [Reparse] for those input that doesn't support random
    seeking, for eg. Unix socket descriptors, Lwt input channels, Lwt streams,
    etc. *)
module Make_buffered_input : functor
  (Promise : PROMISE)
  (Input : BUFFERED_INPUT with type 'a promise = 'a Promise.t)
  -> INPUT with type 'a promise = 'a Promise.t with type input = Input.t

(** {2 Unbuffered Input} *)

module type UNBUFFERED_INPUT = sig
  type t

  type 'a promise

  val read : t -> pos:int -> len:int -> [`Cstruct of Cstruct.t | `Eof] promise
end

(** Makes a unbuffered [INPUT] module. Unbuffered input doesn't buffer any input
    since it natively supports random access and thus backtracking functionality
    is in-built to the input itself. *)
module Make_unbuffered_input : functor
  (Promise : PROMISE)
  (Input : UNBUFFERED_INPUT with type 'a promise = 'a Promise.t)
  -> INPUT with type 'a promise = 'a Promise.t with type input = Input.t

(** {2 Make a parser} *)

(** A functor to create parsers based on the given [Promise] and [Input] module. *)
module Make : functor
  (Promise : PROMISE)
  (Input : INPUT with type 'a promise = 'a Promise.t)
  -> PARSER with type 'a promise = 'a Input.promise with type input = Input.t

(** {2 String Parser} *)

module String : sig
  include PARSER with type 'a promise = 'a

  val create_input : Cstruct.t -> input

  val create_input_from_string : string -> input

  val create_input_from_bigstring :
    ?off:int -> ?len:int -> Cstruct.buffer -> input
end
