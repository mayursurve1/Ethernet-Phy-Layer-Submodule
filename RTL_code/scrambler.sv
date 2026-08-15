`timescale 1ns/1ps

module scrambler (

    input  logic clk,
    input  logic rst_n,

    // FIFO Interface
    input  logic [65:0] fifo_data,
    input  logic        fifo_empty,

    output logic        fifo_rd_en,

    // Serial Output
    output logic        scrambled_bit,
    output logic        valid_out
);


    //------------------------------------------------
    // Registers
    //------------------------------------------------

    logic [1:0]  sync_header;
    logic [63:0] shift_reg;

    // Previous scrambled data history
    logic [57:0] history_reg;

    logic [6:0] bit_count;


    //------------------------------------------------
    // FSM
    //------------------------------------------------
    typedef enum logic [1:0]
    {
        IDLE,
        READ_FIFO,
        SHIFT
    } state_t;
    state_t current_state, next_state;

    // Scrambler equation
    logic scramble_bit_next;

    assign scramble_bit_next =
                shift_reg[63] ^
                history_reg[57] ^
                history_reg[38];


    assign fifo_rd_en = (current_state == IDLE) && !fifo_empty;

    // State Register
    always_ff @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next State Logic
    always_comb
    begin
        next_state = current_state;

        case(current_state)
            IDLE:
            begin
                if(!fifo_empty)
                    next_state = READ_FIFO;
            end

            READ_FIFO:
            begin
                next_state = SHIFT;
            end

            SHIFT:
            begin
                if(bit_count == 7'd65)
                    next_state = IDLE;
            end

            default:
                next_state = IDLE;

        endcase

    end

    // Datapath
    always_ff @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin

            // fifo_rd_en no longer lives here -- it's now the
            // combinational assign above, driven directly by
            // current_state (which itself resets to IDLE), so it
            // needs no explicit reset value of its own.

            scrambled_bit <= 1'b0;
            valid_out     <= 1'b0;

            sync_header <= 0;
            shift_reg   <= 0;
            history_reg <= 0;

            bit_count <= 0;

        end

        else
        begin
            case(current_state)
            // Wait for FIFO data
            IDLE:
            begin
                valid_out <= 1'b0;
                scrambled_bit <= 1'b0;
                bit_count <= 0;
                // fifo_rd_en request is now handled by the
                // combinational assign above, not here.
            end
            // Load FIFO output

            READ_FIFO:
            begin
                sync_header <= fifo_data[65:64];
                shift_reg   <= fifo_data[63:0];
                bit_count   <= 0;
            end

            // Serial scrambling
            SHIFT:
            begin
                valid_out <= 1'b1;
                // First two bits are sync header
                if(bit_count == 0)
                begin
                    scrambled_bit <= sync_header[1];
                end
                else if(bit_count == 1)
                begin
                    scrambled_bit <= sync_header[0];
                end

                // Scramble 64-bit payload
                else
                begin
                    scrambled_bit <= scramble_bit_next;

                    history_reg <={history_reg[56:0], scramble_bit_next};

                    shift_reg <={shift_reg[62:0], 1'b0};

                end
                bit_count <= bit_count + 1;
            end
            default:
            begin
                valid_out <= 0;
            end
            endcase
        end
    end

endmodule