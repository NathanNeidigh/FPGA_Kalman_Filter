module tb ();
  locaparam STATE_BITS = 16;

  logic clk = 1'b0;
  always #100 clk <= ~clk;
  logic [STATE_BITS-1:0] z;
  logic [STATE_BITS-1:0] x;
  logic x_valid;

  kalman_filter #(
      .STATE_BITS(STATE_BITS),  // signed [STATE_BITS-1:0]  (Q = STATE_Q)
      .STATE_Q(15),  // fractional bits for state & measurement (Q15)
      .VAR_BITS(64),  // unsigned [COV_BITS-1:0] for P, Q_var, R_var (Q = VAR_Q)
      .VAR_Q(30),  // fractional bits for variances (Q30)
      .K_Q(31),  // fractional bits for Kalman gain
      // wide intermediates use 128-bit vectors in calculations
      .INTER_W(128)
  ) kf_inst (
      .clk(clk),
      .z_in(z),
      .x_out(x),
      .x_valid(x_valid)
  );

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb);

    $display("=== Starting Kalman Filter Test ===");
    z <= 16'h4009;  // corrosponds to sensor value of 16393 which is about 1 g
    @(posedge clk);
    @(posedge x_valid);
    $display("X=%0h", x);
  end
endmodule
