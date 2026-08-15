`timescale 1ns/1ps

module descrambler (
    input logic         clk,
    input logic         rst_n,

    input logic         valid_in,
    input logic         scrambled_bit,

    output logic        valid_out,
    output logic [65:0] descrambled_data
);
    //Internal Registers
    // Stores the 66-bit block received from the scrambler
    logic [1:0]  sync_header;
    logic [63:0] recovered_data;

    // Stores the previous scrambled bits (history register)
    logic [57:0] history_reg;

    logic [6:0]  bit_count;
    logic        descramble_bit;

    assign descramble_bit = scrambled_bit ^ history_reg[57] ^ history_reg[38];

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            valid_out        <= 1'b0;
            descrambled_data <= '0;
            sync_header      <= '0;
            recovered_data   <= '0;
            history_reg      <= '0;
            bit_count        <= '0;
        end

        else begin
            valid_out <= 1'b0;
            if(valid_in)begin
                case(bit_count)
                    0:  sync_header[1] <= scrambled_bit;
                    1:  sync_header[0] <= scrambled_bit;
                    default: begin
                        history_reg <= {history_reg[56:0], scrambled_bit};
                        recovered_data[65-bit_count] <= descramble_bit;
                    end
                endcase
                
                if (bit_count == 65) begin
                    valid_out        <= 1'b1;
                    descrambled_data <= {sync_header, {recovered_data[63:1], descramble_bit}};
                    bit_count        <= '0;
                    sync_header      <= '0;
                    recovered_data   <= '0;
                end
                else begin
                    bit_count <= bit_count + 1;
                end
            end
        end
    end
endmodule