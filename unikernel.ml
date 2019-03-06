(* Copyright (C) 2016, Thomas Leonard
   See the README file for details. *)

open Rresult
open Lwt.Infix

let src = Logs.Src.create "pong" ~doc:"pong mirage main module"
module Log = (val Logs.src_log src : Logs.LOG)

type side = One | Two

module Main
    (Time: Mirage_time_lwt.S)
=
struct

  module MiragePong(FB : Framebuffer.S)=
struct
  module Img = Framebuffer_image.Make(FB)

  type direction = Up | Down

  type player =
    { length : int ;
      width : int ;
      coordinate : int ;
      points : int ;
      side : side ;
      color : FB.color ;
      input : direction Lwt_mvar.t ;
    }

  type ball =
    { x : float ;
      y : float ;
      direction : float ; (* degrees, starting at 9, going clockwise *)
      size : float ;
      color: FB.color ;
      speed : float ;
    }

  type state =
    { player1 : player ;
      player2 : player ;
      ball : ball ;
      width: int;
      height : int;
    }

  let draw fb t =
    FB.rect fb ~x:0 ~y:0 ~x_end:t.width ~y_end:t.height FB.(compile_rgb fb);

    let () = (* draw ball: *)
      let {x; y; size; _} = t.ball in
      let x , y, x_end, y_end =
        let iof = int_of_float in
        (iof @@ x-.size), (iof @@ y -. size),
        (iof @@ x +. size), (iof @@ y +. size)
      in
      FB.rect fb ~x ~y ~x_end ~y_end t.ball.color
    in
    let draw_player player =
      let x = match player.side with | One -> 1
                                     | Two -> t.width - player.width - 1 in
      let x_end = x + player.width in
      let y = player.coordinate in
      let y_end = player.coordinate + player.length in
      FB.rect fb ~x ~y ~x_end ~y_end player.color ;
      let points = string_of_int player.points in
      FB.letters fb points
        ~x:(if player.side = One then x+2
            else x+2- ((String.length points -1)*8))
        ~y:(y+((y_end-y)/2-8)) ;
    in

    draw_player t.player1 ;
    draw_player t.player2 ;

    FB.redraw fb

  let new_ball ~width ~height player_dir color =
      {y = (float_of_int height) /. 2. ;
       x = (float_of_int width) /. 2.;
       direction = (Random.float (120./.57.3)) +. (270. /. 57.3)
                   +. (if Random.bool () then 0. else (-180. /. 57.3));
       size = 10. ;
       color ;
       speed = 8. ;
      }

  let setup fb =
    FB.term_size fb
    |> fun (w,h) -> (w*8,h*16) |> fun (width,height) ->
    let new_player side color =
      let length = height / 10 in
      { length ;
        coordinate = (height / 2 ) - (length / 2) ;
        points = 0;
        side ;
        color ;
        input = Lwt_mvar.create_empty () ;
        width = 16 ;
      }
    in
    let player1 = new_player One (FB.compile_rgb ~r:'\xFF' fb) in
    let player2 = new_player Two (FB.compile_rgb ~r:'\xFF' ~g:'\xFF' fb) in
    let ball = new_ball ~width ~height Two (FB.compile_rgb ~g:'\xFF' fb) in
    let state = {player1 ; player2 ; ball ; width; height} in
    draw fb state >>= fun () -> Lwt.return state

  let rec tick fb state =
    Time.sleep_ns 5_000_000_L >>= fun () ->
    let move_player side state =
      let update_player, player =
        (if state.player1.side = side then
          ( (fun p -> {state with player1 = p}), state.player1)
         else
           ( (fun p -> {state with player2 = p}), state.player2)
        )
      in
      match Lwt_mvar.take_available player.input with
      | None -> state
      | Some Up -> update_player
                     { player with coordinate =
                                    max (0)
                                      (player.coordinate - (state.height/40))
                     }
      | Some Down -> update_player
                       { player with coordinate =
                                      min (state.height - player.length)
                                        (player.coordinate + (state.height/40))
                       }
    in
    let state = move_player One state in
    let state = move_player Two state in
    let ball ({direction; speed; x; y; size; _} as ball) =
      let fwidth = state.width |> float_of_int in
      let fheight = state.height |> float_of_int in
      let foi = float_of_int in
      let within_player y player =
        ( y >= (foi player.coordinate) -. size -. size )
        && ( y <= size +. size +. (foi @@ player.coordinate
                                  + player.length))
      in
      let flip_horizontal dir =
        let straight = (180. /. 57.3) in
        straight -. (dir -. straight)
      in
      let flip_vertical dir =
        let straight = (90. /. 57.3) in
        (straight) -. (dir -. straight)
      in
      let winner, direction = match () with
        | () when y +. size > fheight -> None, flip_horizontal direction
        | () when y -. size < 0. -> None, flip_horizontal direction
        | () when x -. size < (foi state.player1.width)
                              && (within_player y state.player1)
          ->
          None, flip_vertical direction
        | () when (x +. size > fwidth -. (foi state.player2.width))
               && (within_player y state.player2)
          ->
          None, flip_vertical direction
        | () when x +. size > fwidth -> Some One, 0. (*player two lost *)
        | () when x < size -> Some Two, 0. (*player one lost *)
        | () -> None, direction
      in
      let next_ball = new_ball ~width:state.width ~height:state.height in
      match winner with
      | None ->
        let x = x +. (cos direction) *. speed in
        let y = y +. (sin direction) *. speed in
        Lwt.return {state with ball = {ball with x ; y; direction;
                                                 speed = ball.speed +. 0.001}}
      | Some One ->
        Time.sleep_ns 2_000_000_000_L >>= fun () -> (* sleep for 2s when score! *)
        Lwt.return {state with
                    player1 = {state.player1 with
                               points = state.player1.points + 1 };
                    ball = next_ball Two state.player1.color
                   }
      | Some Two ->
        Time.sleep_ns 2_000_000_000_L >>= fun () -> (* sleep for 2s when score! *)
        Lwt.return {state with
                    player2 = {state.player2 with
                               points = state.player2.points + 1 } ;
                    ball = next_ball One state.player2.color
                   }
    in
    ball state.ball >>= fun state ->
    draw fb state >>= fun () -> tick fb state

  let input_loop fb ~player1 ~player2 =
    let up player =
      Lwt.async (fun () -> Lwt_mvar.put player.input Up)
    and down player =
      Lwt.async (fun () -> Lwt_mvar.put player.input Down)
    in
    let rec input_loop fb =
      let open Framebuffer__S in
      FB.recv_event fb >>= function
      | Window_close -> ignore @@ failwith "window closed" ; Lwt.return_unit
      | Keypress {pressed = true; keysym; mods; _} as _event ->
        begin match keysym with
          | Some `W -> up player1
          | Some `S -> down player1
          | Some `Up_Arrow -> up player2
          | Some `Down_Arrow -> down player2
          | _ -> ()
        end ; input_loop fb
      | _event ->
        input_loop fb
    in
    input_loop fb

  let start () =
    FB.window ~width:200 ~height:200 >>= fun fb ->
    FB.resize ~width:900 ~height:1000 fb >>= fun () ->
    setup fb >>= fun state ->
    FB.redraw fb >>= fun () ->
    Lwt.async (fun () -> tick fb state) ;
    input_loop fb ~player1:state.player1 ~player2:state.player2
end

let start _time (fb_init: unit -> ('a * (module Framebuffer.S) Lwt.t) Lwt.t) =
  fb_init () >>= fun (_platform_specific, fb_promise) ->
  fb_promise >>= fun fb_module ->
  let module FB : Framebuffer.S= (val (fb_module) : Framebuffer.S) in
  let module App = MiragePong(FB) in
  App.start ()

end
