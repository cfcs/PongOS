# PongOS v1.0

PongOS, the operating system that satisfies all your multiplayer pong gaming needs (and does nothing else).

![pong-os-v1 0](https://user-images.githubusercontent.com/9653993/34456516-b47a4238-ed98-11e7-9e3a-36e920df9fdd.png)
*Actual in-game footage*

## What is this?

This is a [MirageOS](https://mirage.io) unikernel written in OCaml.

It uses [mirage-framebuffer](https://github.com/cfcs/mirage-framebuffer) to handle the drawing and input handling. It is built on top of the [mirage-qubes](https://github.com/talex5/mirage-qubes) library.

It can run as a Xen unikernel under QubesOS or as an SDL application under Linux/FreeBSD.

## Gameplay

This is a multiplayer game.

Player One controls the left bar using `W` (up) and `S` (down).

Player Two uses the arrows keys.

## Limitations

The *only* thing you can with this is play pong. Both because it is single-purpose unikernel, but also the redrawing is unoptimized to the point where it struggles to keep up the pace. PRs welcome!

- no networked play (yet)

## Credits

- OS UX lead architect and co-founder, @halfd
- Lead Experimental Advanced Math Consultant, @azet + a lot of moral support, and very good ideas re: the UI.
- Senior Backbone Infrastructure Operations Architect @reynir, thank you so much for tethering from your phone!

