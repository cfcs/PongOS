(* Copyright (C) 2017, Thomas Leonard <thomas.leonard@unikernel.com>
   See the README file for details. *)

(** Configuration for the "mirage" tool. *)

open Mirage

type framebuffer_ty = Framebuffer
let framebuffer = Type Framebuffer

let config_framebuffer =
  impl @@ object inherit Mirage.base_configurable
    method module_name = "Framebuffer_placeholder_goes_here"
    method name = "my framebuffer, hello!"
    method ty = framebuffer
    method! packages : package list value =
    (Key.match_ Key.(value target) @@ begin function
      | `Xen -> [package ~min:"0.4" "mirage-qubes";
                 package "mirage-framebuffer-qubes"]
      | `Unix | `MacOSX ->
         [package "mirage-unix"; package "mirage-framebuffer-tsdl"]
      | `Qubes | `Hvt | `Virtio -> []
      end)
    |> Mirage.Key.map (List.cons (package "mirage-framebuffer"))
    method! deps = []
    method! connect mirage_info _modname _args =
      Key.eval (Info.context mirage_info) @@
      Key.match_ Key.(value target) @@ begin function
        | `Unix | `MacOSX ->
            {| Lwt.return (fun () ->
                 let b =
                   let module X = Framebuffer.Make(Framebuffer_tsdl) in
                   X.init ()
                 in
                 Lwt.return ((), b))
            |}
        | `Xen ->
            {| Lwt.return (fun () ->
                 Qubes.RExec.connect ~domid:0 () >>= fun qrexec ->
                 Qubes.GUI.connect ~domid:0 () >>= fun gui ->

                 let b =
                   let module X = Framebuffer.Make(Framebuffer_qubes) in
                   X.init gui
                 in
                 let agent_listener = Qubes.RExec.listen qrexec Command.handler
                 in
                 Lwt.async (Qubes.GUI.listen gui) ;
                 Lwt.async (fun () ->
                   OS.Lifecycle.await_shutdown_request ()
                   >>= fun (`Poweroff | `Reboot) ->
                   Qubes.RExec.disconnect qrexec
                 );

                 Lwt.return ((agent_listener, qrexec, gui),b))
            |}
        | `Virtio | `Hvt ->
          failwith "Mirage_Framebuffer is not implemented for Virtio | Uvkm"
        | `Qubes ->
          failwith "Mirage_framebuffer must be used with -t xen for Qubes"
      end
  end

let main =
  foreign
    ~deps:[abstract config_framebuffer]
    ~packages:[
      package "cstruct";
      package "mirage-logs";
      package "mirage-framebuffer-imagelib";
    ] "Unikernel.Main" (time @-> job)

let () =
  register "pong" [ main $ default_time ] ~argv:no_argv
