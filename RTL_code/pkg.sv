package ethernet_pkg;

typedef enum logic [2:0] {
    BLK_DATA,
    BLK_IDLE,
    BLK_START,
    BLK_TERMINATE,
    BLK_ERROR
} block_type_t;


typedef enum logic [2:0] {
    CH_DATA,
    CH_IDLE,
    CH_START,
    CH_TERM,
    CH_ERROR,
    CH_SEQ_OS,
    CH_UNKNOWN
} character_t;

//---------------------------------------------------------
typedef enum logic [2:0] {
    DATA,
    IDLE,
    START,
    TERMINATE,
    FAULT
} command_type_e;

//---------------------------------------------------------
// IEEE Block Type Constants
//---------------------------------------------------------
localparam logic [7:0] IDLE_BLOCK_TYPE   = 8'h1E;

localparam logic [7:0] START_BLOCK_TYPE  = 8'h78;

localparam logic [7:0] TERM0_BLOCK_TYPE  = 8'h87;
localparam logic [7:0] TERM1_BLOCK_TYPE  = 8'h99;
localparam logic [7:0] TERM2_BLOCK_TYPE  = 8'hAA;
localparam logic [7:0] TERM3_BLOCK_TYPE  = 8'hB4;
localparam logic [7:0] TERM4_BLOCK_TYPE  = 8'hCC;
localparam logic [7:0] TERM5_BLOCK_TYPE  = 8'hD2;
localparam logic [7:0] TERM6_BLOCK_TYPE  = 8'hE1;
localparam logic [7:0] TERM7_BLOCK_TYPE  = 8'hFF;

localparam logic [7:0] FAULT_BLOCK_TYPE  = 8'h4B;


typedef struct {

    int packet_no;

    logic [63:0] txd;
    logic [7:0]  txc;

    logic [63:0] rxd;
    logic [7:0]  rxc;

    bit valid_out;
    bit decode_error;

    string status;

} packet_result_t;


typedef struct {

    int          packet_no;
    logic [63:0] txd;
    logic [7:0]  txc;
    logic [1:0] sync_head;

    logic [65:0] expected_block;
    logic [65:0] actual_block;

    string       status;

} enc_result_t;


typedef struct {

    int          packet_no;

    logic [65:0] encoder_block;
    logic [65:0] descrambled_block;

    string       status;

} scr_descr_result_t;

endpackage