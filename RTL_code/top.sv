`timescale 1ns/1ps

import ethernet_pkg::*;

module top (

    input  logic         clk,
    input  logic         rst_n,

    //==========================
    // XGMII Transmit Interface
    //==========================
    input  logic [63:0]  txd,
    input  logic [7:0]   txc,
    input  logic         valid_in,

    //==========================
    // XGMII Receive Interface
    //==========================
    output logic [63:0]  rxd,
    output logic [7:0]   rxc,
    output logic         valid_out,
    output logic         decode_error

);

    // Encoder -> FIFO

    logic [65:0] encoded_block;
    logic        encoder_valid;

    // FIFO Signals

    logic [65:0] fifo_dout;

    logic fifo_full;
    logic fifo_empty;

    logic fifo_wr_en;
    logic fifo_rd_en;

    // Scrambler

    logic serial_bit;
    logic scr_valid;

    // Descrambler

    logic [65:0] descrambled_block;
    logic        descr_valid;

    // FIFO Control
    assign fifo_wr_en = encoder_valid & !fifo_full;
    
    // Encoder
    encoder u_encoder (

        .clk            (clk),
        .rst_n          (rst_n),

        .txd            (txd),
        .txc            (txc),

        .valid_in       (valid_in),

        // Encoder should only accept when FIFO has space
        .ready_in       (!fifo_full),

        .encoded_block  (encoded_block),
        .valid_out      (encoder_valid)

    );

    // FIFO

    sync_fifo #(

        .DATA_WIDTH (66),
        .DEPTH      (1000)

    ) u_fifo (

        .clk        (clk),
        .rst_n      (rst_n),

        .wr_en      (fifo_wr_en),
        .data_in    (encoded_block),
        .full       (fifo_full),

        .rd_en      (fifo_rd_en),
        .data_out   (fifo_dout),
        .empty      (fifo_empty)

    );

    // Scrambler

    scrambler u_scrambler (

        .clk            (clk),
        .rst_n          (rst_n),

        .fifo_data      (fifo_dout),
        .fifo_empty     (fifo_empty),
        .fifo_rd_en     (fifo_rd_en),

        .scrambled_bit  (serial_bit),
        .valid_out      (scr_valid)

    );

    // Descrambler

    descrambler u_descrambler (

        .clk                (clk),
        .rst_n              (rst_n),

        .valid_in           (scr_valid),
        .scrambled_bit      (serial_bit),

        .valid_out          (descr_valid),
        .descrambled_data   (descrambled_block)

    );

    // Decoder

    decoder u_decoder (

        .clk                (clk),
        .rst_n              (rst_n),

        .valid_in           (descr_valid),
        .descrambled_data   (descrambled_block),

        .rxd                (rxd),
        .rxc                (rxc),
        .valid_out          (valid_out),
        .decode_error       (decode_error)

    );

endmodule