`timescale 1ns/1ps

import ethernet_pkg::*;

module encoder (

    // Global Signals
    input  logic         clk,
    input  logic         rst_n,

    // XGMII Interface
    input  logic [63:0]  txd,
    input  logic [7:0]   txc,

    // Handshake
    input  logic         valid_in,
    input  logic         ready_in,

    // Output Interface
    output logic [65:0]  encoded_block,
    output logic         valid_out
);

// Internal Signals
// Character Decoder
character_t char_type [8];

// Block Detector
block_type_t block_type;
logic [2:0] term_pos;

// Block Formatter
logic [63:0] payload;

// Header Generator
logic [1:0] sync_header;


//---------------------------------------------------------
// Character Decoder
//---------------------------------------------------------
function automatic character_t decode_character(
    input logic [7:0] byte_data,
    input logic       control
);

    // Data byte
    if (!control)
        return CH_DATA;

    // Control byte
    unique case (byte_data)

        8'h07 : return CH_IDLE;      // /I/
        8'hFB : return CH_START;     // /S/
        8'hFD : return CH_TERM;      // /T/
        8'hFE : return CH_ERROR;     // /E/
        8'h9C : return CH_SEQ_OS;    // /Q/

        default : return CH_UNKNOWN;

    endcase

endfunction

//---------------------------------------------------------
// Character Decode
//---------------------------------------------------------
always_comb begin
    for (int i = 0; i < 8; i++) begin
        char_type[i] = decode_character(txd[(8*i)+:8], txc[i]);
    end
end

//---------------------------------------------------------
// Detect Terminate Position
//---------------------------------------------------------
function automatic logic [2:0] detect_term_pos(
    input character_t char_type [8]
);
    for (int i = 0; i < 8; i++) begin
        if (char_type[i] == CH_TERM)
            return i[2:0];  // bit slicing in 3 bits from 32 bits bcouse int is 32 bits
    end
    return 3'd0;
endfunction

//---------------------------------------------------------
// Validate Terminate Pattern 
// ex. D D T I I I I I   -> Valid
//     D D T T D D D D   -> Invalid
//  or D D T D D D D D   -> Invalid
//  After terminate only IDLE is valid
//---------------------------------------------------------
function automatic logic valid_terminate(
    input character_t char_type [8]
);

    logic found_term;

    found_term = 0;

    for (int i = 0; i < 8; i++) begin
        if (!found_term) begin

            if (char_type[i] == CH_TERM)
                found_term = 1;

            else if (char_type[i] != CH_DATA)
                return 1'b0;

        end
        else begin

            if (char_type[i] != CH_IDLE)
                return 1'b0;

        end

    end
    return found_term;

endfunction

//---------------------------------------------------------
// Block Detector
//---------------------------------------------------------
function automatic block_type_t detect_block_type(
    input character_t char_type [8]
);

    logic all_data;
    logic all_idle;
    logic found_term;

    all_data   = 1'b1;
    all_idle   = 1'b1;
    found_term = 1'b0;

    // Check every character
    for (int i = 0; i < 8; i++) begin

        if (char_type[i] != CH_DATA)
            all_data = 1'b0;

        if (char_type[i] != CH_IDLE)
            all_idle = 1'b0;

        if (char_type[i] == CH_TERM)
            found_term = 1'b1;

    end

    // DATA BLOCK
    if (all_data)
        return BLK_DATA;

    // IDLE BLOCK
    // FIX: was BLK_CONTROL, which does not match the BLK_IDLE
    // checked later in the payload mux -> idle blocks used to
    // fall through to the default (zero payload) case.
    if (all_idle)
        return BLK_IDLE;

    // START BLOCK
    if ( char_type[0] == CH_START &&
         char_type[1] == CH_DATA  &&
         char_type[2] == CH_DATA  &&
         char_type[3] == CH_DATA  &&
         char_type[4] == CH_DATA  &&
         char_type[5] == CH_DATA  &&
         char_type[6] == CH_DATA  &&
         char_type[7] == CH_DATA )
    begin
        return BLK_START;
    end

    // TERMINATE BLOCK
    if (found_term) begin
        if (valid_terminate(char_type))
            return BLK_TERMINATE;
    end

    // Unsupported Pattern
    return BLK_ERROR;

endfunction


//---------------------------------------------------------
// Block Detection
//---------------------------------------------------------
always_comb begin

    block_type = detect_block_type(char_type);

    term_pos   = detect_term_pos(char_type);

end

function automatic logic [63:0] format_data(
    input logic [63:0] txd
);
    return txd;
endfunction

// code 0x00, per IEEE 802.3 Table 49-1 -- not the raw XGMII
// /I/ byte value (0x07) that used to be copied in from txd.
function automatic logic [63:0] format_idle();
    return {IDLE_BLOCK_TYPE, 56'h0};
endfunction

function automatic logic [63:0] format_start(
    input logic [63:0] txd
);

    logic [63:0] temp;
    temp = {
        START_BLOCK_TYPE,
        txd[63:8]
    };
    return temp;
endfunction


// Correct layout for TERMn: n real data bytes taken from
// txd[(8*n)-1 : 0], followed by (7-n) idle control-code bytes
// (0x00 each), following the block-type byte.
function automatic logic [63:0] format_terminate(

    input logic [63:0] txd,
    input logic [2:0] term_pos

);
    logic [63:0] temp;

    unique case(term_pos)
        3'd0:
            temp = {TERM0_BLOCK_TYPE, 56'h0};
        3'd1:
            temp = {TERM1_BLOCK_TYPE, txd[7:0], 48'h0};
        3'd2:
            temp = {TERM2_BLOCK_TYPE, txd[15:0], 40'h0};
        3'd3:
            temp = {TERM3_BLOCK_TYPE, txd[23:0], 32'h0};
        3'd4:
            temp = {TERM4_BLOCK_TYPE, txd[31:0], 24'h0};
        3'd5:
            temp = {TERM5_BLOCK_TYPE, txd[39:0], 16'h0};
        3'd6:
            temp = {TERM6_BLOCK_TYPE, txd[47:0], 8'h0};
        3'd7:
            temp = {TERM7_BLOCK_TYPE, txd[55:0]};
        default:
            temp = 64'd0;
    endcase
    return temp;
endfunction

always_comb begin
    payload = 64'd0;
    unique case(block_type)
        BLK_DATA:
            payload = format_data(txd);
        BLK_IDLE:
            payload = format_idle();
        BLK_START:
            payload = format_start(txd);
        BLK_TERMINATE:
            payload = format_terminate(txd, term_pos);
            
        // corrupted block-type bytes.
        BLK_ERROR:
            payload = {FAULT_BLOCK_TYPE, 56'h0};
        default:
            payload = 64'd0;
    endcase
end

always_comb begin
    if (block_type == BLK_DATA)
        sync_header = 2'b01;
    else
        sync_header = 2'b10;
end


always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin
        encoded_block <= '0;
        valid_out     <= 1'b0;
    end
    else if (valid_in && ready_in) begin
        encoded_block <= {sync_header, payload};
        valid_out     <= 1'b1;
    end
    else begin
        valid_out <= 1'b0;
    end
end


endmodule