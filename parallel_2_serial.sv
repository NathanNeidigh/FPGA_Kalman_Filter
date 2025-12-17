// -----------------------------------------------------------------------------
// Module: parallel_2_serial (Clock-Driven, No Strobe)
// Description: Continuously serializes 16-bit parallel data on every 16th clock.
//              Samples Filter_Input_Data every 16 spi_sck cycles and transmits MSB-first.
// -----------------------------------------------------------------------------
module parallel_2_serial (
    input  logic        spi_sck,              // Serial clock (drives everything)
    input  logic [15:0] filtered_data,    // Parallel data (updated by same clock domain)
    output logic        Filter_Output         // Serial output (MSB first, idle high)
);

    logic [15:0] shift_reg;
    logic [3:0]  tx_bit_count;   // 0 to 15 (transmit bit counter)

    // Output is MSB during transmission, idle high otherwise
    assign Filter_Output = shift_reg[15];

    always_ff @(posedge spi_sck) begin
        if (tx_bit_count == 4'd15) begin
            // End of current word: load next parallel data and reset counter
            shift_reg <= filtered_data;  // Sample new data
            tx_bit_count <= 4'd0;
        end
        else begin
            // Normal shift: move MSB out, shift left
            shift_reg <= {shift_reg[14:0], 1'b0};
            tx_bit_count <= tx_bit_count + 1;
        end
    end

    // Optional: initialize to avoid X in simulation
    initial begin
        shift_reg = 16'd0;
        tx_bit_count = 4'd0;
    end

endmodule