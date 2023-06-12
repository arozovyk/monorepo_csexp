(*-------------------------------------------------------------------------
 * Copyright (c) 2020, 2021 Bikal Gurung. All rights reserved.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License,  v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * reparse v3.1.0
 *-------------------------------------------------------------------------*)

module Promise = struct
  type 'a t = 'a Lwt.t

  let return = Lwt.return

  let bind f p = Lwt.bind p f

  let catch = Lwt.catch
end

module Stream = struct
  module Input =
    Reparse.Make_buffered_input
      (Promise)
      (struct
        type t = char Lwt_stream.t

        type 'a promise = 'a Lwt.t

        let read_char t =
          let open Lwt.Infix in
          Lwt_stream.get t
          >|= function
          | Some c ->
              let cs = Cstruct.create 1 in
              Cstruct.set_char cs 0 c ; `Cstruct cs
          | None -> `Eof

        let read t ~len =
          let open Lwt.Infix in
          if len = 1 then read_char t
          else
            Lwt_stream.nget len t
            >|= fun chars ->
            let len'' = List.length chars in
            if len'' > 0 then
              `Cstruct
                (chars |> List.to_seq |> String.of_seq |> Cstruct.of_string)
            else `Eof
      end)

  include Reparse.Make (Promise) (Input)

  let create_input stream = Input.create stream
end
