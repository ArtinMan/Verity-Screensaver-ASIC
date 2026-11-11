/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// ------------------------------------------------------------
// VGA 640x480 @ 60 Hz timing (needs ~25.175 MHz clock)
// ------------------------------------------------------------
module vga_sync (
    input  wire       clk,
    input  wire       rst_n,
    output wire       hsync,      // active low
    output wire       vsync,      // active low
    output wire       video_on,
    output wire [9:0] x,
    output wire [9:0] y
);

  localparam H_VISIBLE = 640;
  localparam H_FRONT   = 16;
  localparam H_SYNC    = 96;
  localparam H_TOTAL   = 800;

  localparam V_VISIBLE = 480;
  localparam V_FRONT   = 10;
  localparam V_SYNC    = 2;
  localparam V_TOTAL   = 525;

  reg [9:0] h_count;
  reg [9:0] v_count;

  always @(posedge clk) begin
    if (!rst_n) begin
      h_count <= 10'd0;
      v_count <= 10'd0;
    end else if (h_count == H_TOTAL - 1) begin
      h_count <= 10'd0;
      if (v_count == V_TOTAL - 1)
        v_count <= 10'd0;
      else
        v_count <= v_count + 10'd1;
    end else begin
      h_count <= h_count + 10'd1;
    end
  end

  assign hsync = ~((h_count >= H_VISIBLE + H_FRONT) &&
                   (h_count <  H_VISIBLE + H_FRONT + H_SYNC));
  assign vsync = ~((v_count >= V_VISIBLE + V_FRONT) &&
                   (v_count <  V_VISIBLE + V_FRONT + V_SYNC));

  assign video_on = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
  assign x = h_count;
  assign y = v_count;

endmodule

// ===== END OF SECTION 1 — paste section 2 below this line =====
// ------------------------------------------------------------
// Bouncing smiley (16x16 bitmap, scaled 4x -> 64x64 pixels)
// ------------------------------------------------------------
module smiley_bounce (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       frame_tick,   // one-cycle pulse per frame
    input  wire       video_on,
    input  wire [9:0] x,
    input  wire [9:0] y,
    output reg  [5:0] rgb           // {R[1:0], G[1:0], B[1:0]}
);

  localparam H_RES = 640;
  localparam V_RES = 480;
  localparam SIZE  = 64;
  localparam SPEED = 2;

  // ---------------- Position / direction ----------------
  reg [9:0] x_pos, y_pos;
  reg       dx_right, dy_down;
  reg [2:0] color_idx;

  wire hit_right = dx_right  && (x_pos + SPEED >= H_RES - SIZE);
  wire hit_left  = !dx_right && (x_pos <= SPEED);
  wire hit_down  = dy_down   && (y_pos + SPEED >= V_RES - SIZE);
  wire hit_up    = !dy_down  && (y_pos <= SPEED);

  always @(posedge clk) begin
    if (!rst_n) begin
      x_pos     <= 10'd100;
      y_pos     <= 10'd80;
      dx_right  <= 1'b1;
      dy_down   <= 1'b1;
      color_idx <= 3'd0;
    end else if (frame_tick) begin
      // Horizontal movement
      if (hit_right) begin
        x_pos    <= H_RES - SIZE;
        dx_right <= 1'b0;
      end else if (hit_left) begin
        x_pos    <= 10'd0;
        dx_right <= 1'b1;
      end else if (dx_right)
        x_pos <= x_pos + SPEED;
      else
        x_pos <= x_pos - SPEED;

      // Vertical movement
      if (hit_down) begin
        y_pos   <= V_RES - SIZE;
        dy_down <= 1'b0;
      end else if (hit_up) begin
        y_pos   <= 10'd0;
        dy_down <= 1'b1;
      end else if (dy_down)
        y_pos <= y_pos + SPEED;
      else
        y_pos <= y_pos - SPEED;

      // Change color on any wall hit
      if (hit_right || hit_left || hit_down || hit_up)
        color_idx <= color_idx + 3'd1;
    end
  end

// ===== END OF SECTION 2 (smiley_bounce is still open, no endmodule yet) =====
  // ---------------- Color palette (2 bits per channel) ----------------
  // Format: {R[1:0], G[1:0], B[1:0]}
  reg [5:0] face_color;
  always @(*) begin
    case (color_idx)
      3'd0:    face_color = 6'b11_11_00; // yellow
      3'd1:    face_color = 6'b00_11_11; // cyan
      3'd2:    face_color = 6'b11_00_11; // magenta
      3'd3:    face_color = 6'b00_11_00; // green
      3'd4:    face_color = 6'b11_10_00; // orange
      3'd5:    face_color = 6'b11_00_00; // red
      3'd6:    face_color = 6'b00_10_11; // light blue
      default: face_color = 6'b11_11_11; // white
    endcase
  end

  // ---------------- 16x16 bitmaps ----------------
  // One 16-bit word per row. Bit 15 is the leftmost column.

  // Round face outline (1 = face pixel)
  function [15:0] face_row(input [3:0] r);
    case (r)
      4'd0, 4'd15:                face_row = 16'h07E0; // ......######......
      4'd1, 4'd14:                face_row = 16'h1FF8; // ...##########...
      4'd2, 4'd13:                face_row = 16'h3FFC; // ..############..
      4'd3, 4'd4, 4'd11, 4'd12:   face_row = 16'h7FFE; // .##############.
      default:                    face_row = 16'hFFFF; // rows 5..10, full width
    endcase
  endfunction

  // Eyes and mouth (1 = drawn black on top of the face)
  function [15:0] feature_row(input [3:0] r);
    case (r)
      4'd4, 4'd5: feature_row = 16'h0C30; // eyes (columns 4-5 and 10-11)
      4'd8:       feature_row = 16'h2004; // mouth corners (columns 2 and 13)
      4'd9:       feature_row = 16'h1008; // mouth sides (columns 3 and 12)
      4'd10:      feature_row = 16'h0FF0; // bottom of smile (columns 4-11)
      default:    feature_row = 16'h0000;
    endcase
  endfunction

// ===== END OF SECTION 3 (smiley_bounce is still open, no endmodule yet) =====
  // ---------------- Drawing ----------------
  // Is the current pixel inside the 64x64 sprite box?
  wire in_sprite = (x >= x_pos) && (x < x_pos + SIZE) &&
                   (y >= y_pos) && (y < y_pos + SIZE);

  // Position inside the sprite, then divide by 4 to get the bitmap cell
  wire [9:0] lx  = x - x_pos;
  wire [9:0] ly  = y - y_pos;
  wire [3:0] col = lx[5:2];
  wire [3:0] row = ly[5:2];

  // Put the function results in wires first, then pick one bit.
  // (Verilog doesn't allow face_row(row)[n] directly.)
  wire [15:0] face_bits    = face_row(row);
  wire [15:0] feature_bits = feature_row(row);

  // Bit 15 is the leftmost column, so flip the column index (~col == 15 - col)
  wire [3:0] bit_idx    = ~col;
  wire       face_px    = face_bits[bit_idx];
  wire       feature_px = feature_bits[bit_idx];

  always @(*) begin
    if (video_on && in_sprite && face_px)
      rgb = feature_px ? 6'b00_00_00 : face_color;  // black eyes and mouth
    else
      rgb = 6'b00_00_00;                            // black background
  end

endmodule

// ===== END OF SECTION 4 (smiley_bounce is now closed) =====
// ------------------------------------------------------------
// Tiny Tapeout top module (name and ports must stay as-is)
// ------------------------------------------------------------
module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs (unused)
    output wire [7:0] uo_out,   // Dedicated outputs -> VGA
    input  wire [7:0] uio_in,   // IOs: input path (unused)
    output wire [7:0] uio_out,  // IOs: output path
    output wire [7:0] uio_oe,   // IOs: enable path (0 = input)
    input  wire       ena,      // always 1 when powered
    input  wire       clk,      // ~25.175 MHz pixel clock
    input  wire       rst_n     // active-low reset
);

  wire        hsync, vsync, video_on;
  wire [9:0]  x, y;
  wire [5:0]  rgb;              // {R[1:0], G[1:0], B[1:0]}

  vga_sync vga (
      .clk(clk),
      .rst_n(rst_n),
      .hsync(hsync),
      .vsync(vsync),
      .video_on(video_on),
      .x(x),
      .y(y)
  );

  // One-cycle pulse at the top-left of every frame (~60 Hz)
  wire frame_tick = (x == 10'd0) && (y == 10'd0);

  smiley_bounce smiley (
      .clk(clk),
      .rst_n(rst_n),
      .frame_tick(frame_tick),
      .video_on(video_on),
      .x(x),
      .y(y),
      .rgb(rgb)
  );

  // Register hsync, vsync and color together so they stay aligned
  reg       hsync_r, vsync_r;
  reg [5:0] rgb_r;

  always @(posedge clk) begin
    if (!rst_n) begin
      hsync_r <= 1'b1;
      vsync_r <= 1'b1;
      rgb_r   <= 6'b000000;
    end else begin
      hsync_r <= hsync;
      vsync_r <= vsync;
      rgb_r   <= rgb;
    end
  end

  // TinyVGA PMOD pinout: {hsync, B0, G0, R0, vsync, B1, G1, R1}
  wire [1:0] r = rgb_r[5:4];
  wire [1:0] g = rgb_r[3:2];
  wire [1:0] b = rgb_r[1:0];

  assign uo_out  = {hsync_r, b[0], g[0], r[0], vsync_r, b[1], g[1], r[1]};
  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  // Unused inputs
  wire _unused = &{ena, ui_in, uio_in, 1'b0};

endmodule