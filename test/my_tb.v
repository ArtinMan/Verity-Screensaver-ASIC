`default_nettype none
`timescale 1ns / 1ps

module my_tb;
  reg  [7:0] ui_in = 0;
  wire [7:0] uo_out;
  wire [7:0] uio_out, uio_oe;

  tt_um_example dut (
      .ui_in(ui_in), .uo_out(uo_out),
      .uio_in(8'b0), .uio_out(uio_out), .uio_oe(uio_oe),
      .ena(1'b1), .clk(1'b0), .rst_n(1'b1)
  );

  integer a, b, sel, errors = 0;
  reg [3:0] expected;

  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, my_tb);
    for (sel = 0; sel < 2; sel = sel + 1)
      for (a = 0; a < 4; a = a + 1)
        for (b = 0; b < 4; b = b + 1) begin
          ui_in = {3'b0, sel[0], b[1:0], a[1:0]};
          #1;
          expected = sel ? a * b : a + b;
          if (uo_out !== {4'b0, expected}) begin
            errors = errors + 1;
            $display("FAIL sel=%0d a=%0d b=%0d got=%0d exp=%0d", sel, a, b, uo_out, expected);
          end
        end
    if (errors == 0) $display("PASS: all 32 cases correct");
    else $display("%0d errors", errors);
    $finish;
  end
endmodule