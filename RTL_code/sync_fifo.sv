`timescale 1ns/1ps

module sync_fifo #(
    parameter DATA_WIDTH = 66,
    parameter DEPTH      = 1000
)
(
    input  logic                    clk,
    input  logic                    rst_n,

    // Write Interface
    input  logic                    wr_en,
    input  logic [DATA_WIDTH-1:0]   data_in,
    output logic                    full,

    // Read Interface
    input  logic                    rd_en,
    output logic [DATA_WIDTH-1:0]   data_out,
    output logic                    empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    // Memory
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers
    logic [ADDR_WIDTH-1:0] wr_ptr;
    logic [ADDR_WIDTH-1:0] rd_ptr;

    // Number of stored entries
    logic [ADDR_WIDTH:0] count;

    //-------------------------------------------------
    // Write Logic
    //-------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_ptr <= 0;
        end
        else if(wr_en && !full) begin

            mem[wr_ptr] <= data_in;

            if(wr_ptr == DEPTH-1)
                wr_ptr <= 0;
            else
                wr_ptr <= wr_ptr + 1;

        end
    end

    //-------------------------------------------------
    // Read Logic
    //-------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_ptr   <= 0;
            data_out <= 0;
        end
        else if(rd_en && !empty) begin

            data_out <= mem[rd_ptr];

            if(rd_ptr == DEPTH-1)
                rd_ptr <= 0;
            else
                rd_ptr <= rd_ptr + 1;

        end
    end

    //-------------------------------------------------
    // Count Logic
    //-------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            count <= 0;
        else begin

            case ({wr_en && !full, rd_en && !empty})

                2'b10 : count <= count + 1;

                2'b01 : count <= count - 1;

                2'b11 : count <= count;

                default : count <= count;

            endcase

        end
    end

    //-------------------------------------------------
    // Status Flags
    //-------------------------------------------------
    always_comb begin
        full  = (count == DEPTH);
        empty = (count == 0);
    end

endmodule


