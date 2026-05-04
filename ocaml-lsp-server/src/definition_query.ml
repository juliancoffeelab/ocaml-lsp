open Import
open Fiber.O

let maybe_remember_borrowed_config
      (state : State.t)
      (doc : Document.Merlin.t)
      source_uri
      locate_result
  =
  let should_borrow path =
    let in_workspace = Workspaces.contains_path (State.workspaces state) path in
    let in_build_dir =
      Option.is_some
        (String.substr_index path ~pattern:(Filename.dir_sep ^ "_build" ^ Filename.dir_sep))
    in
    (not in_workspace) || in_build_dir
  in
  match locate_result with
  | `Found (Some path, _) when not (String.equal path (Uri.to_path source_uri)) ->
    if not (should_borrow path)
    then Fiber.return ()
    else (
      let target_uri = Uri.of_path path in
      match Document_store.get_opt state.store target_uri with
      | Some _ -> Fiber.return ()
      | None ->
        let+ config = Document.Merlin.mconfig doc in
        Merlin_config.DB.remember_borrowed state.merlin_config ~uri:target_uri ~config)
  | _ -> Fiber.return ()
;;

let location_of_merlin_loc uri : _ -> (_, string) result = function
  | `At_origin -> Error "Already at definition point"
  | `Builtin s ->
    Error (sprintf "%S is a builtin, it is not possible to jump to its definition" s)
  | `File_not_found s -> Error (sprintf "File_not_found: %s" s)
  | `Invalid_context -> Error "Not a valid identifier"
  | `Not_found (ident, where) ->
    let msg =
      let msg = sprintf "%S not found." ident in
      match where with
      | None -> msg
      | Some w -> sprintf "%s last looked in %s" msg w
    in
    Error msg
  | `Not_in_env m -> Error (sprintf "Not in environment: %s" m)
  | `Found (path, lex_position) ->
    Ok
      (Position.of_lexical_position lex_position
       |> Option.map ~f:(fun position ->
         let range = { Range.start = position; end_ = position } in
         let uri =
           match path with
           | None -> uri
           | Some path -> Uri.of_path path
         in
         let locs = [ { Location.uri; range } ] in
         `Location locs))
;;

let run kind (state : State.t) ?prefix uri position =
  let* () = Fiber.return () in
  let doc = Document_store.get state.store uri in
  match Document.kind doc with
  | `Other -> Fiber.return None
  | `Merlin doc ->
    let command, name =
      let pos = Position.logical position in
      match kind with
      | `Definition -> Query_protocol.Locate (prefix, `ML, pos), "definition"
      | `Declaration -> Query_protocol.Locate (prefix, `MLI, pos), "declaration"
      | `Type_definition -> Query_protocol.Locate_type pos, "type definition"
    in
    let* result = Document.Merlin.dispatch_exn ~name doc command in
    let* () = maybe_remember_borrowed_config state doc uri result in
    (match location_of_merlin_loc uri result with
     | Ok s -> Fiber.return s
     | Error err_msg ->
       let kind =
         match kind with
         | `Definition -> "definition"
         | `Declaration -> "declaration"
         | `Type_definition -> "type definition"
       in
       Jsonrpc.Response.Error.raise
         (Jsonrpc.Response.Error.make
            ~code:Jsonrpc.Response.Error.Code.RequestFailed
            ~message:(sprintf "Request \"Jump to %s\" failed." kind)
            ~data:(`String (sprintf "Locate: %s" err_msg))
            ()))
;;
