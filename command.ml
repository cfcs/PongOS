open Lwt

module Flow = Qubes.RExec.Flow

let src = Logs.Src.create "command" ~doc:"qrexec command handler"
module Log = (val Logs.src_log src : Logs.LOG)

let echo ~user flow =
  Flow.writef flow "Hi %s! Please enter a string:" user >>= fun () ->
  Flow.read_line flow >>= function
  | `Eof -> return 1
  | `Ok input ->
  Flow.writef flow "You wrote %S. Bye." input >|= fun () -> 0

let download flow =
  (* adapted from do_unpack in qubes-linux-utils/qrexec-lib/unpack.c*)

  (* step 1: read struct file_header "untrusted_hdr"
             - if namelen == 0:
               reply with send_status_and_crc(errno, last filename)
     step 2: process_one_file(&untrusted_hdr)
             - read_all_with_crc(filename, untrusted_hdr->namelen)
     step 3: match hdr.mode with (* S_ISREG/S_ISLNK/S_ISDIR *)
             | -> process_one_file_reg(hdr, name)
             | process_one_file_link(hdr, name)
             | process_one_file_dir(hdr, name)
     step 4: goto 1
  *)
  let open Qubes.Formats.Rpc_filecopy in
  Flow.read flow >>= function
  | `Eof -> return 1
  | `Ok hdr when Cstruct.len hdr < sizeof_file_header -> return 1
  | `Ok hdr_much ->
    let hdr, filename, first_filedata =
      Cstruct.split hdr_much sizeof_file_header
      |> fun (hdr, extra) ->
      Cstruct.split extra (get_file_header_namelen hdr |> Int32.to_int)
      |> fun (filename, filedata) ->
      hdr, Cstruct.to_string filename, filedata
    in
    Log.warn (fun m -> m "filename: %S" filename) ;
    let rec loop acc =
      Flow.read flow >>= function
      | `Eof -> return 1
      | `Ok input ->
        Log.warn (fun m -> m "read: @[<v>%a@]"
                     Cstruct.hexdump_pp input) ;
        loop (input::acc)
    in
    loop [first_filedata]

let handler ~user cmd flow =
  (* Write a message to the client and return an exit status of 1. *)
  let error fmt =
    fmt |> Printf.ksprintf @@ fun s ->
    Log.warn (fun f -> f "<< %s" s);
    Flow.ewritef flow "%s [while processing %S]" s cmd >|= fun () -> 1 in
  match cmd with
  | "echo" -> echo ~user flow
  | "QUBESRPC qubes.Filecopy dom0" -> download flow
  | cmd -> error "Unknown command %S" cmd
