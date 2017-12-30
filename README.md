# PongOS v1.0

PongOS, the operating system that satisfies all your multiplayer pong gaming needs (and does nothing else).

![pong-os-v1 0](https://user-images.githubusercontent.com/9653993/34456516-b47a4238-ed98-11e7-9e3a-36e920df9fdd.png)

## What is this?

This is a [MirageOS](https://mirage.io) unikernel written in OCaml.

It uses [mirage-framebuffer](https://github.com/cfcs/mirage-framebuffer) to handle the drawing and input handling.

It can run as a Xen unikernel under QubesOS or as an SDL application under Linux/FreeBSD.

## Limitations

The *only* thing you can with this is play pong. Both because it is single-purpose unikernel, but also the redrawing is unoptimized to the point where it struggles to keep up the pace. PRs welcome!

## Gameplay

This is a multiplayer game.

Player One controls the left bar using `W` (up) and `S` (down).

Player Two uses the arrows keys.
