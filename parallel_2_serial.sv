// -----------------------------------------------------------------------------
// Module: parallel_2_serial (Clock-Driven, No Strobe)
// Description: Continuously serializes 16-bit parallel data on every 16th clock.
//              Samples Filter_Input_Data every 16 rp2350_sck cycles and transmits MSB-first.
// -----------------------------------------------------------------------------
module parallel_2_serial (
    input  logic [15:0] filtered_data,        // Parallel data (updated by same clock domain)
    input  logic        filter_done,          // Strobe indicating new data is ready to send
    input  logic        rp2350_sck,           // Serial clock from RP2350 (drives everything)

    output logic        rpi_mosi,            // Serial output (MSB first, idle high)
    output logic        rpi_cs,              // Chip Select for Raspberry Pi (active low)
    output logic        rpi_sck              // Serial Clock for Raspberry Pi
);

    logic [15:0] shift_reg;
    logic [3:0]  tx_bit_count;   // 0 to 15 (transmit bit counter)

    // Output is MSB during transmission, idle high otherwise
    assign rpi_mosi = shift_reg[15];

    always_ff @(posedge rp2350_sck) begin
        if (tx_bit_count == 4'd15) begin
            // End of current word: load next parallel data only if Filter_Done is asserted
            if (filter_done) begin
                shift_reg <= filtered_data;  // Sample new data only when ready
                tx_bit_count <= 4'd0;
            end else begin
                // Hold current data and do not advance counter if no new data ready
                tx_bit_count <= 4'd0;
            end
        end
        else begin
            // Normal shift: move MSB out, shift left
            shift_reg <= {shift_reg[14:0], 1'b0};
            tx_bit_count <= tx_bit_count + 1;
        end
    end

    assign rpi_sck = rp2350_sck;          // Direct clock connection
    assign rpi_cs  = ~(filter_done);    // Active low CS when data is ready
    
    // Optional: initialize to avoid X in simulation
    initial begin
        shift_reg = 16'd0;
        tx_bit_count = 4'd0;
    end

endmodule