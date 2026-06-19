package uart_pkg;

import uvm_pkg::*;
`include "uvm_macros.svh"

class uart_txn extends uvm_sequence_item;

    rand bit [7:0] data;

    `uvm_object_utils_begin(uart_txn)
        `uvm_field_int(data,UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name="uart_txn");
        super.new(name);
    endfunction

endclass

class uart_sequence extends uvm_sequence #(uart_txn);

    `uvm_object_utils(uart_sequence)

    function new(string name="uart_sequence");
        super.new(name);
    endfunction

    task body();

        repeat(20)
        begin

            uart_txn tx;

            tx = uart_txn::type_id::create("tx");

            start_item(tx);

            assert(tx.randomize());

            finish_item(tx);

        end

    endtask

endclass

class uart_sequencer extends uvm_sequencer #(uart_txn);

    `uvm_component_utils(uart_sequencer)

    function new(string name,
                 uvm_component parent);

        super.new(name,parent);

    endfunction

endclass

class uart_driver extends uvm_driver #(uart_txn);

    `uvm_component_utils(uart_driver)

    virtual uart_if vif;

    function new(string name,
                 uvm_component parent);

        super.new(name,parent);

    endfunction

    function void build_phase(uvm_phase phase);

        if(!uvm_config_db#
           (virtual uart_if)::get
           (this,"","vif",vif))
            `uvm_fatal("DRV","NO VIF")

    endfunction

    task run_phase(uvm_phase phase);

        uart_txn tr;

        wait(vif.rst==0);

        forever
        begin

            seq_item_port.get_next_item(tr);

            @(posedge vif.clk);

            vif.tx_data <= tr.data;
            vif.tx_start <= 1;

            @(posedge vif.clk);

            vif.tx_start <= 0;

            wait(vif.tx_busy==1);
            wait(vif.tx_busy==0);

            `uvm_info("DRV",
            $sformatf("DATA SENT = %0h",
            tr.data),
            UVM_LOW)

            seq_item_port.item_done();

        end

    endtask

endclass

class uart_monitor extends uvm_monitor;

    `uvm_component_utils(uart_monitor)

    virtual uart_if vif;

    uvm_analysis_port #(uart_txn) ap;

    function new(string name,
                 uvm_component parent);

        super.new(name,parent);

        ap = new("ap",this);

    endfunction

    function void build_phase(uvm_phase phase);

        if(!uvm_config_db#
          (virtual uart_if)::get
          (this,"","vif",vif))
            `uvm_fatal("MON","NO VIF")

    endfunction

    task run_phase(uvm_phase phase);

        uart_txn tx;

        forever
        begin

            @(posedge vif.tx_start);

            tx = uart_txn::type_id::create("tx");

            tx.data = vif.tx_data;

            ap.write(tx);

            `uvm_info("MON",
            $sformatf("MONITORED=%0h",
            tx.data),
            UVM_LOW)

        end

    endtask

endclass

class uart_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(uart_scoreboard)

    uvm_analysis_imp#
    (uart_txn,uart_scoreboard) imp;

    int count;

    function new(string name,
                 uvm_component parent);

        super.new(name,parent);

        imp = new("imp",this);

    endfunction

    function void write(uart_txn tx);

        count++;

        `uvm_info("SCB",
        $sformatf("Received = %0h",
        tx.data),
        UVM_LOW)

    endfunction

    function void report_phase
        (uvm_phase phase);

        `uvm_info("SCB",
        $sformatf("TOTAL TXNS=%0d",
        count),
        UVM_NONE)

    endfunction

endclass

class uart_agent extends uvm_agent;

    `uvm_component_utils(uart_agent)

    uart_driver drv;
    uart_monitor mon;
    uart_sequencer seqr;

    function new(string name,
                 uvm_component parent);

        super.new(name,parent);

    endfunction

    function void build_phase
        (uvm_phase phase);

        drv =
        uart_driver::type_id::
        create("drv",this);

        mon =
        uart_monitor::type_id::
        create("mon",this);

        seqr =
        uart_sequencer::type_id::
        create("seqr",this);

    endfunction

    function void connect_phase
        (uvm_phase phase);

        drv.seq_item_port.connect
        (seqr.seq_item_export);

    endfunction

endclass

class uart_env extends uvm_env;

    `uvm_component_utils(uart_env)

    uart_agent agt;
    uart_scoreboard scb;

    function new(string name,
                 uvm_component parent);

        super.new(name,parent);

    endfunction

    function void build_phase
        (uvm_phase phase);

        agt =
        uart_agent::type_id::
        create("agt",this);

        scb =
        uart_scoreboard::type_id::
        create("scb",this);

    endfunction

    function void connect_phase
        (uvm_phase phase);

        agt.mon.ap.connect
        (scb.imp);

    endfunction

endclass

class uart_test extends uvm_test;

    `uvm_component_utils(uart_test)

    uart_env env;

    function new(string name,
                 uvm_component parent);

        super.new(name,parent);

    endfunction

    function void build_phase
        (uvm_phase phase);

        env =
        uart_env::type_id::
        create("env",this);

    endfunction

    task run_phase(uvm_phase phase);

        uart_sequence seq;

        phase.raise_objection(this);

        seq =
        uart_sequence::type_id::
        create("seq");

        seq.start(env.agt.seqr);

        #100;

        phase.drop_objection(this);

    endtask

endclass

endpackage
      
