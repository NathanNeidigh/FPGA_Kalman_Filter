module tb ();

  logic ch3, ch4;
  logic ch6, ch7, ch8;
  logic switch;
  logic rLed, gLed, bLed;
  logic clk = 1'b0;
  always #100 clk <= ~clk;

  trigger #() trigger_inst (
      .clk (clk),
      .sw2 (switch),
      .rLed(rLed),
      .gLed(gLed),
      .bLed(bLed),
      .ch3 (ch3),
      .ch4 (ch4),
      .ch6 (ch6),
      .ch7 (ch7),
      .ch8 (ch8)
  );

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb);

    $display("=== Combinational Trigger test ===");
    switch <= 1'b1;
    @(posedge clk);
    switch <= 1'b0;
    @(posedge clk);
    switch <= 1'b1;
    @(posedge clk);
    switch <= 1'b0;
    #200

    @(ch6 == 1'b1 & ch7 == 1'b0 & ch8 == 1'b1) begin
      repeat (9)
      @(posedge clk) begin
        $display("Ch3: %0b Ch4: %0b", ch3, ch4);
      end
    end

    @(posedge clk);
    $display("=== Edge-based Trigger ===");
    switch <= 1'b1;
    @(posedge clk);
    switch <= 1'b0;
    #200

    @(negedge ch8) begin
      @(posedge clk);
      repeat (9)
      @(posedge clk) begin
        $display("Ch3: %0b Ch4: %0b", ch3, ch4);
      end
    end

    $display("Finished Simulation!");
    $finish();
  end
endmodule
