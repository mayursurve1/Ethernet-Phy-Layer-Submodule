# UVM Verification
## Ethernet PHY Layer Sub-module
---
```systemverilog

`timescale 1ns / 1ps

`include "uvm_macros.svh"

import ethernet_pkg::*;
import uvm_pkg::*;

interface eth_interface(input logic clk);
    import ethernet_pkg::*;

    logic rst_n;
    
    logic [63:0] txd;
    logic [7:0] txc;
    logic    valid_in;

    logic [63:0] rxd;
    logic [7:0]  rxc;
    logic   valid_out;
    logic  decode_error;

    logic [65:0] encoded_block;
    logic   encoder_valid;
    
    logic [65:0] descrambled_block;
    logic   descr_valid;


    clocking drv_cb @(posedge clk);
        default input #1ns output #1ns;
        output txd, txc, valid_in;
        input  rst_n;
    endclocking

    //MONITOR CLOCKING BLOCK
    clocking mon_cb @(posedge clk);
        default input #1ns;
        input txd, txc, valid_in;
        input rxd, rxc, valid_out, decode_error;
        input encoded_block, encoder_valid;
        input descrambled_block, descr_valid;
    endclocking
endinterface

```
---
```systemverilog

class eth_transaction extends uvm_sequence_item;

    //DUT Inputs
    rand logic [63:0] txd;
    rand logic [7:0]  txc;

    rand int mode; // 0=Data, 1=Idle, 2=Start, 3=Terminate, 4=Error
    rand int term_pos; // 0 to 7

    //Encoder Outputs
    logic [65:0] encoded_block;
    logic  encoder_valid;

    //Descrambler Outputs
    logic [65:0] descrambled_block;
    logic  descr_valid;  
    
    //Final Outputs
    logic [63:0] rxd;
    logic [7:0]  rxc;
    logic   valid_out;
    logic  decode_error;

    

    //UVM Registration
    `uvm_object_utils_begin(eth_transaction)
        `uvm_field_int(txd, UVM_ALL_ON)
        `uvm_field_int(txc, UVM_ALL_ON)
	      `uvm_field_int(mode, UVM_ALL_ON)
        `uvm_field_int(term_pos, UVM_ALL_ON)
        `uvm_field_int(rxd, UVM_ALL_ON)
        `uvm_field_int(rxc, UVM_ALL_ON)
        `uvm_field_int(valid_out, UVM_ALL_ON)
        `uvm_field_int(decode_error, UVM_ALL_ON)
        `uvm_field_int(encoded_block, UVM_ALL_ON)
        `uvm_field_int(encoder_valid, UVM_ALL_ON)
        `uvm_field_int(descrambled_block, UVM_ALL_ON)
        `uvm_field_int(descr_valid, UVM_ALL_ON)
    `uvm_object_utils_end

    // Constructor
    function new(string name = "eth_transaction");
        super.new(name);
    endfunction

    // Constraints
     
    constraint simple_rules {
        
        //Keep the random numbers in range
        mode inside {[0:4]};
        term_pos inside {[0:7]};

        //DATA Block (Mode 0)
        if (mode == 0) {
            txc == 8'h00;
        }
        
        //IDLE Block (Mode 1)
        else if (mode == 1) {
            txc == 8'hFF;
            txd == 64'h07070707_07070707;
        }
        
        //START Block (Mode 2)
        else if (mode == 2) {
            txc == 8'h01;
            txd[7:0] == 8'hFB;
        }
        
        //TERMINATE Block (Mode 3)

        else if (mode == 3) {
            if (term_pos == 0) { txc == 8'hFF; txd == 64'h07070707_070707FD; }
            if (term_pos == 1) { txc == 8'hFE; txd[63:8] == 56'h07070707_0707FD; }
            if (term_pos == 2) { txc == 8'hFC; txd[63:16] == 48'h07070707_07FD; }
            if (term_pos == 3) { txc == 8'hF8; txd[63:24] == 40'h07070707_FD; }
            if (term_pos == 4) { txc == 8'hF0; txd[63:32] == 32'h070707FD; }
            if (term_pos == 5) { txc == 8'hE0; txd[63:40] == 24'h0707FD; }
            if (term_pos == 6) { txc == 8'hC0; txd[63:48] == 16'h07FD; }
            if (term_pos == 7) { txc == 8'h80; txd[63:56] == 8'hFD; }
        }
        
        //ERROR Block
        else if (mode == 4) {
            txc == 8'hFF;
            txd == 64'hEEEEEEEE_EEEEEEEE;
        }
    }


  endclass
```
---
```systemverilog

class eth_generator extends uvm_sequence #(eth_transaction);
    `uvm_object_utils(eth_generator)
    
    eth_transaction tr;

    function new(string name ="eth_generator");
        super.new(name);
    endfunction

    virtual task body();
        repeat (100) begin
            tr = eth_transaction::type_id::create("tr");
            start_item(tr);                      
          
            if(!tr.randomize()) begin
                `uvm_error("GEN", "Randomization Failed");
            end
            
            finish_item(tr);
            `uvm_info("GEN", $sformatf("generated data txd =%0h and txc =%0h", tr.txd, tr.txc), UVM_LOW)
        end
    endtask
endclass
```
---
```systemverilog

class eth_driver extends uvm_driver #(eth_transaction);
    `uvm_component_utils(eth_driver)

    virtual eth_interface vif;
    
    uvm_analysis_port#(eth_transaction) drvtosb;

    function new(string name="eth_driver", uvm_component parent=null);
        super.new(name,parent);
        drvtosb = new("drvtosb", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual eth_interface)::get(this,"","vif",vif))
            `uvm_fatal("DRV","Virtual Interface Not Set")
    endfunction
 
    task run_phase(uvm_phase phase);

      eth_transaction exp_tr;
      
        // Wait for reset to finish
      wait(vif.rst_n == 1'b1);
      
      forever begin

        // Wait for the clocking block event instead of posedge clk
          @(vif.drv_cb);
          
          seq_item_port.try_next_item(req);
          
          if (req != null) begin
             // Drive through the clocking block
              vif.drv_cb.valid_in <= 1'b1;
              vif.drv_cb.txd      <= req.txd;
              vif.drv_cb.txc      <= req.txc;
              
              exp_tr = eth_transaction::type_id::create("exp_tr");
              exp_tr.copy(req);
              drvtosb.write(exp_tr);
              
              seq_item_port.item_done();
          end 
          else begin
              // Drive IDLEs through the clocking block when no data is ready
              vif.drv_cb.valid_in <= 1'b1; 
              vif.drv_cb.txd      <= 64'h0707070707070707;
              vif.drv_cb.txc      <= 8'hFF;
          end
      end
  endtask
endclass
```
---
```systemverilog

class eth_encoder_monitor extends uvm_monitor;
  `uvm_component_utils(eth_encoder_monitor)

 virtual eth_interface vif;
 logic [65:0] expected_queue[$];

 function new(string name="eth_encoder_monitor", uvm_component parent=null);
     super.new(name,parent);
  endfunction

 function void build_phase(uvm_phase phase);
   super.build_phase(phase);
   if(!uvm_config_db #(virtual eth_interface)::get(this,"","vif",vif))
        `uvm_fatal("ENC_MON","Virtual Interface Not Set");
  endfunction
  

  //encoder predictor
 
  function logic [65:0]get_expected(logic [63:0] d, logic [7:0] c);

        //DATA
        if (c == 8'h00) return {2'b01, d};
        
	// IDLE
	if (c == 8'hFF && d == 64'h07070707_07070707) return {2'b10, 8'h1E, 56'h0};

         // START
	if (c == 8'h01 && d[7:0] == 8'hFB) return {2'b10, 8'h78, d[63:8]}; 

        //TERMINATE
        if (c == 8'hFF && d == 64'h07070707_070707FD) 
		return {2'b10, 8'h87, 56'h0};
        if (c == 8'hFE && d[63:8] ==56'h07070707_0707FD) 
		return {2'b10, 8'h99, d[7:0], 48'h0};
        if (c == 8'hFC && d[63:16] ==48'h07070707_07FD) 
		return {2'b10, 8'hAA, d[15:0], 40'h0};
        if (c == 8'hF8 && d[63:24] ==40'h07070707_FD) 
		return {2'b10, 8'hB4, d[23:0], 32'h0};

        if (c == 8'hF0 && d[63:32] ==32'h070707FD) return {2'b10, 8'hCC, d[31:0], 24'h0};
        if (c == 8'hE0 && d[63:40] ==24'h0707FD) return {2'b10, 8'hD2, d[39:0], 16'h0};
        if (c == 8'hC0 && d[63:48] ==16'h07FD) return {2'b10, 8'hE1, d[47:0], 8'h0};
        if (c == 8'h80 && d[63:56] ==8'hFD) return {2'b10, 8'hFF, d[55:0]};
        
        return {2'b10, 8'hFE, 56'h0};

    endfunction
    

    task run_phase(uvm_phase phase); 
        fork
    // Thread 1: Input Capture
     begin
       forever begin
        @(vif.mon_cb); 
           if (vif.mon_cb.valid_in)
	   begin
             expected_queue.push_back(get_expected(vif.mon_cb.txd, vif.mon_cb.txc));
           end
              end
         end
            
     // Thread 2: Output Checker
      begin
          logic [65:0] exp_block;
          forever begin
           @(vif.mon_cb);
          if (vif.mon_cb.encoder_valid) begin
             if (expected_queue.size() == 0) begin
             `uvm_error("ENC_MON", "Encoder output valid but queue is empty!")
             end 

         else begin

           exp_block = expected_queue.pop_front();
                            
             if(exp_block !== vif.mon_cb.encoded_block)
                 `uvm_error("ENC_MON", $sformatf("FAIL! Exp: %h  Act: %h", exp_block, vif.mon_cb.encoded_block))
             else if (exp_block != 66'h21e00000000000000)
                 `uvm_info("ENC_MON", $sformatf("ENCODER PASS  Exp: %h  Act: %h", exp_block, vif.mon_cb.encoded_block), UVM_LOW)
                
            end
             end
           end
         end
        join
    endtask

endclass
```
---
```systemverilog

  class eth_descrambler_monitor extends uvm_monitor;
    `uvm_component_utils(eth_descrambler_monitor)

    virtual eth_interface vif;
    eth_transaction tr;
    logic [65:0] expected_block;
    logic [65:0] enc_queue[$];

    function new(string name="eth_descrambler_monitor", uvm_component parent=null);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual eth_interface)::get(this,"","vif",vif))
            `uvm_fatal("DESC_MON","Virtual Interface Not Set");
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
          @(vif.mon_cb);            
           if(vif.mon_cb.encoder_valid)

             enc_queue.push_back(vif.mon_cb.encoded_block);
      
      if(vif.mon_cb.descr_valid)
      begin
        tr = eth_transaction::type_id::create("tr");
        tr.descrambled_block = vif.mon_cb.descrambled_block;
        tr.descr_valid   = vif.mon_cb.descr_valid;
        
         if(enc_queue.size() == 0)
	 begin
                    `uvm_error("DESC_MON", "Encoder Queue Empty");
                end
                else begin
                    expected_block = enc_queue.pop_front();

                    if(expected_block === tr.descrambled_block)
                      `uvm_info("DESC_MON", $sformatf("DESCRAMBLER PASS Expected=%h Actual=%h", expected_block, tr.descrambled_block), UVM_LOW)
                    
                    else
                        `uvm_error("DESC_MON", $sformatf("DESCRAMBLER FAIL Expected=%h Actual=%h", expected_block, tr.descrambled_block));
                end
            end
        end
    endtask
endclass
```
---
```systemverilog

class eth_monitor extends uvm_monitor;
    `uvm_component_utils(eth_monitor)
   
    virtual eth_interface vif;
    eth_transaction tr;
    uvm_analysis_port#(eth_transaction) montosb;

    function new(string name ="eth_monitor", uvm_component parent = null);
        super.new(name,parent);
        montosb = new("montosb", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db #(virtual eth_interface)::get(this,"","vif",vif))
            `uvm_fatal("E2E_MON","Virtual Interface Not Set");
    endfunction

    task run_phase(uvm_phase phase);
       forever begin
      @(vif.mon_cb);

      if(vif.mon_cb.valid_out) begin
        tr= eth_transaction::type_id::create("tr");
        tr.rxd = vif.mon_cb.rxd;
        tr.rxc = vif.mon_cb.rxc;
        tr.valid_out =vif.mon_cb.valid_out;
        tr.decode_error =vif.mon_cb.decode_error;

        montosb.write(tr);

      `uvm_info("ENDTOEND_MON", $sformatf("RXD=%h RXC=%h VALID=%0b ERROR=%0b", tr.rxd, tr.rxc, tr.valid_out, tr.decode_error), UVM_LOW)
           
        end

      end

    endtask

endclass
```
---
```systemverilog

class eth_sequencer extends uvm_sequencer #(eth_transaction);
    `uvm_component_utils(eth_sequencer)

    function new(string name = "eth_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass
```
---
```systemverilog

class eth_agent extends uvm_agent;
    `uvm_component_utils(eth_agent)

    eth_sequencer seqr;
    eth_driver  drv;
    eth_encoder_monitor enc_mon;
    eth_descrambler_monitor desc_mon;
    eth_monitor  mon;

    function new(string name = "eth_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        seqr = eth_sequencer::type_id::create("seqr", this);
        drv = eth_driver::type_id::create("drv", this);
        mon = eth_monitor::type_id::create("mon", this);
        enc_mon = eth_encoder_monitor::type_id::create("enc_mon", this);
        desc_mon = eth_descrambler_monitor::type_id::create("desc_mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass
```
---
```systemverilog

`uvm_analysis_imp_decl(_act)
`uvm_analysis_imp_decl(_exp)

class eth_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(eth_scoreboard)
 
    uvm_analysis_imp_exp#(eth_transaction, eth_scoreboard) drvtosb_rec;
    uvm_analysis_imp_act#(eth_transaction, eth_scoreboard) montosb_rec;
   
    eth_transaction tr;
    logic [63:0] expected;
    eth_transaction expected_queue[$];

    function new(string name = "eth_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        montosb_rec = new("montosb_rec", this);
        drvtosb_rec = new("drvtosb_rec", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Do NOT pass `this` into create() for objects (like sequence_items)
        tr = eth_transaction::type_id::create("tr");
    endfunction

    function void write_exp(eth_transaction tr);
        eth_transaction temp;

       if (!(tr.txc == 8'hFF && tr.txd == 64'h07070707_07070707))
     
       begin
	  temp = eth_transaction::type_id::create("temp");
          temp.copy(tr);
          expected_queue.push_back(temp);
        end
    endfunction

   function void write_act(eth_transaction tr);
	   
        eth_transaction exp;
        
       //Ignore IDLE blocks coming out of the DUT so they don't break the comparison
        if (tr.rxc == 8'hFF && tr.rxd == 64'h0707070707070707) begin
            return; 
        end

        
	if(expected_queue.size() == 0)
	begin
          `uvm_error("SB","expected queue empty")
          return;
        end
    
           exp = expected_queue.pop_front();

        if((exp.txd == tr.rxd) && (exp.txc == tr.rxc) && (tr.decode_error == 0))
       	begin
           `uvm_info("SB",$sformatf(" TEST PASS  expected txd=%h and actual rxd=%h",exp.txd,tr.rxd),UVM_LOW)
        end
        else begin
          `uvm_error("SB",$sformatf("TEST FAILED expected txd=%h and actual rxd=%h",exp.txd,tr.rxd))
        end
      endfunction
endclass
```
---
```systemverilog

class eth_coverage extends uvm_subscriber#(eth_transaction);

    `uvm_component_utils(eth_coverage)

    eth_transaction tr;

   
    covergroup eth_cg;
        option.per_instance = 1;

        // 1. Check if all 5 block modes were generated
        cp_mode: coverpoint tr.mode {
            bins data_blk  = {0};
            bins idle_blk  = {1};
            bins start_blk = {2};
            bins term_blk  = {3};
            bins error_blk = {4};
        }

        // 2. Check if all 8 terminate positions were hit
        cp_term_pos: coverpoint tr.term_pos iff (tr.mode == 3) {
            bins pos_0 = {0};
            bins pos_1 = {1};
            bins pos_2 = {2};
            bins pos_3 = {3};
            bins pos_4 = {4};
            bins pos_5 = {5};
            bins pos_6 = {6};
            bins pos_7 = {7};
        }

        // 3. Sequence
	        cp_transitions: coverpoint tr.mode {
            bins idle_to_start = (1 => 2);
            bins start_to_data = (2 => 0);
            bins data_to_term  = (0 => 3);
            bins term_to_idle  = (3 => 1);
        }
    endgroup

    function new(string name = "eth_coverage", uvm_component parent = null);
        super.new(name, parent);
        eth_cg = new();
endfunction

   
    virtual function void write(eth_transaction t);
        tr = t;
        eth_cg.sample();
endfunction
endclass
```
---
```systemverilog

class eth_env extends uvm_env;
    `uvm_component_utils(eth_env)

    eth_agent  agent;
    eth_scoreboard  sb;
    eth_coverage   cov;


    function new(string name = "eth_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = eth_agent::type_id::create("agent", this);
        sb = eth_scoreboard::type_id::create("sb", this);
	cov   = eth_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.drv.drvtosb.connect(sb.drvtosb_rec);
        agent.mon.montosb.connect(sb.montosb_rec);


         agent.drv.drvtosb.connect(cov.analysis_export);

    endfunction
endclass
```
---
```systemverilog

class eth_test extends uvm_test;
    `uvm_component_utils(eth_test)

    eth_env env;
    eth_generator gen;

    function new(string name = "eth_test", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = eth_env::type_id::create("env", this);
    endfunction
   
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        gen = eth_generator::type_id::create("gen");
        gen.start(env.agent.seqr);

        #20000;

        phase.drop_objection(this);
    endtask
endclass
```
---
```systemverilog

module tb_top;

    logic clk;

    // Clock Generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Interface
    eth_interface vif(clk);

    // DUT
    top dut (
        .clk(clk),
        .rst_n (vif.rst_n),
        .txd (vif.txd),
        .txc (vif.txc),
        .valid_in (vif.valid_in),
        .rxd (vif.rxd),
        .rxc (vif.rxc),
        .valid_out(vif.valid_out),
        .decode_error(vif.decode_error)
    );

    //Connect internal DUT signals to interface
    assign vif.encoded_block = dut.encoded_block;
    assign vif.encoder_valid = dut.encoder_valid;
    assign vif.descrambled_block = dut.descrambled_block;
    assign vif.descr_valid = dut.descr_valid;

    initial begin
        vif.rst_n = 0;
       

	repeat(5) @(posedge clk);
        vif.rst_n = 1;
    end

    initial begin
        uvm_config_db #(virtual eth_interface)::set(null, "*", "vif", vif);
        run_test("eth_test");
    end

endmodule

```

