<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project generates a 640x480 @ 60 Hz VGA signal and draws a smiley face
that bounces around the screen, like the classic DVD screensaver.

It is made of three Verilog modules:

- `vga_sync`: counts pixels and lines (800 x 525 total) and produces the HSYNC
  and VSYNC pulses, a `video_on` flag for the visible area, and the current
  pixel position (x, y).
- `smiley_bounce`: keeps the smiley's position and direction. Once per frame it
  moves 2 pixels in each direction, and it reverses direction when it hits a
  screen edge. Each wall hit also switches the face to the next of 8 colors.
  The face is a 16x16 bitmap scaled 4x to 64x64 pixels, with black eyes and a
  black smile.
- `tt_um_example`: the Tiny Tapeout top module. It connects the two modules
  above and registers HSYNC, VSYNC and the color bits together so they stay
  aligned on the output pins.

Color is 2 bits per channel (R, G, B), because only 8 output pins are
available. The output pins follow the TinyVGA PMOD layout.

## How to test

1. Connect a TinyVGA PMOD to the output pins (`uo[7:0]`) and plug it into a
   VGA monitor.
2. Set the project clock to about 25.175 MHz (25 MHz also works on most
   monitors).
3. Reset the design (`rst_n` low, then high).
4. A smiley face should appear and start bouncing around the screen, changing
   color each time it hits an edge.

The inputs (`ui_in`, `uio_in`) are not used.

## External hardware

- TinyVGA PMOD (or any resistor-DAC VGA adapter with the same pinout)
- VGA monitor