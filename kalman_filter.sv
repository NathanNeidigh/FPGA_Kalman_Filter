// 1D Kalman Filter (A=1, B=0, H=1) - fixed point, single-cycle update
module kalman_filter #(
    // Configurable widths (you accepted these defaults)
    parameter int STATE_BITS = 16,    // signed [STATE_BITS-1:0]  (Q = STATE_Q)
    parameter int STATE_Q    = 15,    // fractional bits for state & measurement (Q15)

    parameter int VAR_BITS = 64,  // unsigned [COV_BITS-1:0] for P, Q_var, R_var (Q = VAR_Q)
    parameter int VAR_Q    = 30,  // fractional bits for variances (Q30)

    parameter int K_Q     = 31,  // fractional bits for Kalman gain
    // wide intermediates use 128-bit vectors in calculations
    parameter int INTER_W = 128
) (
    input logic clk,
    input logic reset_n,

    // measurement input (signed Q15)
    input logic                         z_valid,
    input logic signed [STATE_BITS-1:0] z_in,     // measurement in Q = STATE_Q

    // process & measurement variances (signed Q30)
    input logic [VAR_BITS-1:0] Q_var,  // process noise variance (Q30)
    input logic [VAR_BITS-1:0] R_var,  // measurement noise variance (Q30)

    // output estimate (signed Q15)
    output logic signed [STATE_BITS-1:0] x_out,
    output logic                         x_valid
);

  // Internal state registers
  logic signed [STATE_BITS-1:0] x_reg;  // x in Q = STATE_Q
  logic        [  VAR_BITS-1:0] P_reg;  // P in Q = VAR_Q
  logic                         is_init;

  // helper functions ----------------------------------------------------
  // round-right-shift for signed wide integers:
  //   - input 'val' (signed [INTER_W-1:0])
  //   - shift right by 'shr' bits with round-to-nearest (signed-aware)
  function automatic logic signed [INTER_W-1:0] round_shr_signed(
      input logic signed [INTER_W-1:0] val, input int shr);
    logic signed [INTER_W-1:0] bias;
    begin
      if (shr <= 0) begin
        round_shr_signed = val;
      end else begin
        // bias magnitude is 1 << (shr-1)
        bias = ({{(INTER_W - (shr)) {1'b0}}, 1'b1} << (shr - 1));
        // adjust bias sign according to val (round toward nearest)
        if (val >= 0) round_shr_signed = (val + bias) >>> shr;  // arithmetic shift
        else round_shr_signed = (val - bias) >>> shr;
      end
    end
  endfunction

  // saturate a signed INTER_W-wide value to signed [W-1:0]
  function automatic logic signed [127:0] sat_to_bits_signed(input logic signed [INTER_W-1:0] val,
                                                             input int W);
    logic signed [INTER_W-1:0] maxv;
    logic signed [INTER_W-1:0] minv;
    begin
      // compute max and min as INTER_W width constants
      // max =  (1 << (W-1)) - 1
      // min = -(1 << (W-1))
      maxv = (({{(INTER_W - (W)) {1'b0}}, 1'b1} << (W - 1)) - 1);
      minv = -(({{(INTER_W - (W)) {1'b0}}, 1'b1} << (W - 1)));
      if (val > maxv) sat_to_bits_signed = maxv;
      else if (val < minv) sat_to_bits_signed = minv;
      else sat_to_bits_signed = val;
    end
  endfunction

  // Cast helpers to wider intermediate signed vector
  function automatic logic signed [INTER_W-1:0] cast64_to_inter(input logic signed [63:0] in64);
    logic signed [INTER_W-1:0] outv;
    begin
      // sign-extend
      outv = {{(INTER_W - 64) {in64[63]}}, in64};
      cast64_to_inter = outv;
    end
  endfunction

  // Main update (single-cycle) ------------------------------------------------
  // We'll do: when z_valid is high, perform:
  //   P_minus = P + Q_var                   (Q = VAR_Q)
  //   x_minus = x                           (Q = STATE_Q)
  //   denom = P_minus + R_var               (Q = VAR_Q)
  //   K = (P_minus << K_Q) / denom          (K in Q = K_Q)
  //   innovation = z_in - x_minus           (Q = STATE_Q)
  //   x_new = x_minus + (K * innovation >> K_Q)  -> result in Q = STATE_Q
  //   P_new = ((1 - K) * P_minus) >> K_Q    -> result in Q = VAR_Q

  always_ff @(posedge clk) begin
    if (!is_init) begin
      // already initialized above; redundant but explicit
      x_reg   <= '0;
      P_reg   <= (1'sd1 <<< VAR_Q);
      x_valid <= 1'b0;
      is_init <= 1'b1;
    end else begin
      x_valid <= 1'b0;  // default

      if (z_valid) begin
        // widen P_reg, Q_var, R_var to INTER_W
        logic signed [INTER_W-1:0] P_minus_inter;
        logic signed [INTER_W-1:0] Qvar_inter;
        logic signed [INTER_W-1:0] Rvar_inter;
        logic signed [INTER_W-1:0] denom_inter;

        P_minus_inter = {{(INTER_W - VAR_BITS) {P_reg[VAR_BITS-1]}}, P_reg};
        Qvar_inter  = {{(INTER_W - VAR_BITS) {Q_var[VAR_BITS-1]}}, Q_var};
        Rvar_inter  = {{(INTER_W - VAR_BITS) {R_var[VAR_BITS-1]}}, R_var};

        // Predict step (P_minus = P + Q)
        P_minus_inter = P_minus_inter + Qvar_inter;

        // compute K = (P_minus << K_Q) / denom  -> K in Q = K_Q
        denom_inter = P_minus_inter + Rvar_inter;

        // Left shift P_minus by K_Q (wide intermediate)
        logic [INTER_W-1:0] numer_K_inter;
        logic [INTER_W-1:0] K_inter;  // K in Q=K_Q (but still in INTER_W container)

        numer_K_inter = P_minus_inter <<< K_Q;  // P_minus * 2^K_Q
        // division: unsigned division - synthesizable but expensive
        K_inter = numer_K_inter / denom_inter;  // result in Q=K_Q

        // Bound K_inter to [0, 1<<K_Q] realistically (can't be <0; clamp)
        // max_K = (1 << K_Q) (represents value 1.0)
        logic signed [INTER_W-1:0] maxK_inter;
        maxK_inter = ({{(INTER_W - (K_Q + 1)) {1'b0}}, 1'b1} << K_Q);  // 1 << K_Q
        if (K_inter > maxK_inter) K_inter = maxK_inter;

        // residual = z_in - x_reg  (both are STATE_Q)
        logic signed [INTER_W-1:0] residual_inter;
        // sign-extend both to INTER_W with their Q alignment in mind
        logic signed [INTER_W-1:0] z_inter;
        logic signed [INTER_W-1:0] x_inter;
        z_inter = {{(INTER_W - STATE_BITS) {z_in[STATE_BITS-1]}}, z_in};
        x_inter = {{(INTER_W - STATE_BITS) {x_reg[STATE_BITS-1]}}, x_reg};
        residual_inter = z_inter - x_inter;  // Q = STATE_Q

        // Compute x_new:
        // temp = (K * residual) >> K_Q  (K is Q=K_Q, residual Q=STATE_Q)
        // - Multiply K_inter * residual_inter -> product Q = K_Q + STATE_Q
        // - Right shift by K_Q to get back to Q = STATE_Q
        logic signed [INTER_W-1:0] prod_K_residual;
        logic signed [INTER_W-1:0] temp_shifted;  // Q = STATE_Q after shift

        prod_K_residual = K_inter * residual_inter;  // wide product (Q = K_Q + STATE_Q)
        // round and shift by K_Q to go back to STATE_Q
        temp_shifted = round_shr_signed(prod_K_residual, K_Q);

        // Now produce x_new = x_reg + temp_shifted (both Q = STATE_Q)
        logic signed [INTER_W-1:0] x_new_inter;
        x_new_inter = x_inter + temp_shifted;

        // saturate x_new to STATE_BITS
        logic signed [INTER_W-1:0] x_new_sat_inter;
        x_new_sat_inter = sat_to_bits_signed(x_new_inter, STATE_BITS);

        // Convert back to STATE_BITS width
        logic signed [STATE_BITS-1:0] x_new_reg;
        x_new_reg = x_new_sat_inter[STATE_BITS-1:0];

        // Compute P_new = ((1 - K) * P_minus) >> K_Q   (Q = VAR_Q)
        // one_minus_K = (1 << K_Q) - K_inter  (Q = K_Q)
        logic signed [INTER_W-1:0] one_minus_K_inter;
        one_minus_K_inter = maxK_inter - K_inter;  // (1<<K_Q) - K

        // Multiply one_minus_K_inter (Q=K_Q) * P_minus_inter (Q=VAR_Q) -> Q = K_Q + VAR_Q
        logic signed [INTER_W-1:0] prod_omk_pminus;
        prod_omk_pminus = one_minus_K_inter * P_minus_inter;

        // right shift by K_Q (with rounding) to return to Q = VAR_Q
        logic signed [INTER_W-1:0] P_new_inter;
        P_new_inter = round_shr_signed(prod_omk_pminus, K_Q);

        // saturate P_new to COV_BITS
        logic signed [INTER_W-1:0] P_new_sat_inter;
        P_new_sat_inter = sat_to_bits_signed(P_new_inter, COV_BITS);

        logic signed [COV_BITS-1:0] P_new_reg;
        P_new_reg = P_new_sat_inter[COV_BITS-1:0];

        // Update registers (single-cycle)
        x_reg   <= x_new_reg;
        P_reg   <= P_new_reg;

        // valid output next cycle (we set x_out combinationally below to reflect x_reg)
        x_valid <= 1'b1;
      end else begin
        // No update this cycle; keep previous values
        x_reg   <= x_reg;
        P_reg   <= P_reg;
        x_valid <= 1'b0;
      end
    end
  end

  // Output assignments (present latest estimate)
  assign x_out = x_reg;

endmodule
