
package spi_uvm_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

// ============================================================
//  1. SEQ ITEM
// ============================================================
class spi_seq_item extends uvm_sequence_item;

    // ---- Declare ALL fields FIRST before utils block ----
    // Stimulus (randomisable)
    rand bit [7:0] master_data_in;
    rand bit [7:0] slave_data_in;
    rand bit       CPOL;
    rand bit       CPHA;

    // Response (filled by driver / monitor)
    bit [7:0] master_data_out;
    bit [7:0] slave_data_out;
    bit       done;

    // ---- utils block comes AFTER field declarations ----
    `uvm_object_utils_begin(spi_seq_item)
        `uvm_field_int(master_data_in,  UVM_ALL_ON)
        `uvm_field_int(slave_data_in,   UVM_ALL_ON)
        `uvm_field_int(CPOL,            UVM_ALL_ON)
        `uvm_field_int(CPHA,            UVM_ALL_ON)
        `uvm_field_int(master_data_out, UVM_ALL_ON)
        `uvm_field_int(slave_data_out,  UVM_ALL_ON)
        `uvm_field_int(done,            UVM_ALL_ON)
    `uvm_object_utils_end

    // Constraints
    constraint c_spi_mode {
        CPOL inside {1'b0, 1'b1};
        CPHA inside {1'b0, 1'b1};
    }

    constraint c_data {
        master_data_in dist { 8'h00 := 5, [8'h01:8'hFE] := 85, 8'hFF := 10 };
        slave_data_in  dist { 8'h00 := 5, [8'h01:8'hFE] := 85, 8'hFF := 10 };
    }

    function new(string name = "spi_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf(
            "CPOL=%0b CPHA=%0b | MST_TX=0x%02h SLV_TX=0x%02h | MST_RX=0x%02h SLV_RX=0x%02h | done=%0b",
            CPOL, CPHA,
            master_data_in, slave_data_in,
            master_data_out, slave_data_out,
            done);
    endfunction

endclass : spi_seq_item


// ============================================================
//  2. SEQUENCES
// ============================================================

// ------------------------------------------------------------
//  Base sequence helper
// ------------------------------------------------------------
class spi_base_seq extends uvm_sequence #(spi_seq_item);
    `uvm_object_utils(spi_base_seq)

    function new(string name = "spi_base_seq");
        super.new(name);
    endfunction

    task send_one(
        input bit [7:0] mst_data,
        input bit [7:0] slv_data,
        input bit       cpol,
        input bit       cpha
    );
        spi_seq_item item;
        item = spi_seq_item::type_id::create("item");
        start_item(item);
        if (!item.randomize() with {
            master_data_in == mst_data;
            slave_data_in  == slv_data;
            CPOL           == cpol;
            CPHA           == cpha;
        }) `uvm_fatal("RAND", "spi_seq_item randomize failed")
        finish_item(item);
    endtask

endclass : spi_base_seq


// ------------------------------------------------------------
//  Random sequence
// ------------------------------------------------------------
class spi_random_seq extends spi_base_seq;
    `uvm_object_utils(spi_random_seq)

    int unsigned num_transactions = 20;

    function new(string name = "spi_random_seq");
        super.new(name);
    endfunction

    task body();
        spi_seq_item item;
        repeat(num_transactions) begin
            item = spi_seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize())
                `uvm_fatal("RAND", "spi_seq_item randomize failed")
            finish_item(item);
        end
    endtask

endclass : spi_random_seq



// ============================================================
//  3. DRIVER
// ============================================================
class spi_driver extends uvm_driver #(spi_seq_item);
    `uvm_component_utils(spi_driver)

    virtual spi_if.drv_mp vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual spi_if.drv_mp)::get(
                this, "", "vif", vif))
            `uvm_fatal("CFG", "spi_driver: virtual interface not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        spi_seq_item req;

        // Initialise all driven signals
        vif.driver_cb.rst_n          <= 1'b0;
        vif.driver_cb.start          <= 1'b0;
        vif.driver_cb.master_data_in <= 8'h00;
        vif.driver_cb.slave_data_in  <= 8'h00;
        vif.driver_cb.CPOL           <= 1'b0;
        vif.driver_cb.CPHA           <= 1'b0;

        // Hold reset for 5 clocks then release
        vif.wait_clks(5);
        vif.driver_cb.rst_n <= 1'b1;
        vif.wait_clks(2);

        forever begin
            seq_item_port.get_next_item(req);
            drive_transaction(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_transaction(spi_seq_item req);

        // ----------------------------------------------------------------
        // STEP 1: Set slave_data_in BEFORE SS_n rises.
        // The slave RTL latches tx_reg <= data_in on @(posedge SS_n).
        // We must have slave_data_in stable before that rising edge.
        // ----------------------------------------------------------------
        vif.driver_cb.CPOL           <= req.CPOL;
        vif.driver_cb.CPHA           <= req.CPHA;
        vif.driver_cb.slave_data_in  <= req.slave_data_in;
        vif.driver_cb.master_data_in <= req.master_data_in;

        // ----------------------------------------------------------------
        // STEP 2: Wait until SS_n is HIGH and stable.
        // SS_n goes high in the master DONE state (1 cycle), so by the
        // time we reach here after the idle gap it is already high.
        // Poll: if somehow we are early, wait for the rising edge.
        // Then hold 2 more clocks so slave always_ff fully settles.
        // ----------------------------------------------------------------
        if (vif.driver_cb.SS_n !== 1'b1) begin
            @(posedge vif.driver_cb.SS_n);
        end
        vif.wait_clks(2);

        // ----------------------------------------------------------------
        // STEP 3: Assert start for exactly one clock.
        // ----------------------------------------------------------------
        vif.driver_cb.start <= 1'b1;
        vif.wait_clks(1);
        vif.driver_cb.start <= 1'b0;

        // ----------------------------------------------------------------
        // STEP 4: Wait for done with watchdog
        // ----------------------------------------------------------------
        fork
            begin : wait_done
                @(posedge vif.driver_cb.done);
            end
            begin : wdog
                vif.wait_clks(200);
                `uvm_fatal("TIMEOUT",
                    "SPI transaction did not complete within 200 clocks")
            end
        join_any
        disable fork;

        // ----------------------------------------------------------------
        // STEP 5: Capture response one settle cycle after done
        // ----------------------------------------------------------------
        vif.wait_clks(1);
        req.master_data_out = vif.driver_cb.master_data_out;
        req.slave_data_out  = vif.driver_cb.slave_data_out;
        req.done            = 1'b1;

        `uvm_info("DRV", req.convert2string(), UVM_HIGH)

        // Idle gap ? SS_n stays HIGH here so slave latches next data_in
        vif.wait_clks(4);

    endtask : drive_transaction

endclass : spi_driver


// ============================================================
//  4. MONITOR
// ============================================================
class spi_monitor extends uvm_monitor;
    `uvm_component_utils(spi_monitor)

    virtual spi_if.mon_mp vif;

    uvm_analysis_port #(spi_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual spi_if.mon_mp)::get(
                this, "", "vif", vif))
            `uvm_fatal("CFG", "spi_monitor: virtual interface not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        spi_seq_item tr;

        // Wait for reset release
        @(posedge vif.monitor_cb.rst_n);
        vif.wait_clks(2);

        forever begin
            // Detect start of a new SPI transaction
            @(posedge vif.monitor_cb.start);

            tr = spi_seq_item::type_id::create("mon_tr");

            // Capture stimulus at start
            tr.CPOL           = vif.monitor_cb.CPOL;
            tr.CPHA           = vif.monitor_cb.CPHA;
            tr.master_data_in = vif.monitor_cb.master_data_in;
            tr.slave_data_in  = vif.monitor_cb.slave_data_in;

            // Wait for done with watchdog
            fork
                begin : mon_done
                    @(posedge vif.monitor_cb.done);
                end
                begin : mon_wdog
                    vif.wait_clks(250);
                    `uvm_error("MON_TO", "Monitor: done never asserted")
                    disable mon_done;
                end
            join_any
            disable fork;

            // Capture response after one settle cycle
            vif.wait_clks(1);
            tr.master_data_out = vif.monitor_cb.master_data_out;
            tr.slave_data_out  = vif.monitor_cb.slave_data_out;
            tr.done            = vif.monitor_cb.done;

            `uvm_info("MON", tr.convert2string(), UVM_MEDIUM)

            ap.write(tr);
        end
    endtask

endclass : spi_monitor


// ============================================================
//  5. SCOREBOARD
// ============================================================
class spi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(spi_scoreboard)

    uvm_analysis_imp #(spi_seq_item, spi_scoreboard) analysis_export;

    int unsigned total_checks = 0;
    int unsigned pass_count   = 0;
    int unsigned fail_count   = 0;

    // Indexed by {CPOL,CPHA} ? 0..3
    int unsigned mode_pass [4];
    int unsigned mode_fail [4];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        analysis_export = new("analysis_export", this);
        for (int i = 0; i < 4; i++) begin
            mode_pass[i] = 0;
            mode_fail[i] = 0;
        end
    endfunction

    function void write(spi_seq_item tr);
        bit ok_mst, ok_slv;
        int unsigned midx;

        midx = {tr.CPOL, tr.CPHA};
        total_checks++;

        // MISO path: master received what slave transmitted
        ok_mst = (tr.master_data_out === tr.slave_data_in);

        // MOSI path: slave received what master transmitted
        ok_slv = (tr.slave_data_out  === tr.master_data_in);

        if (ok_mst && ok_slv) begin
            pass_count++;
            mode_pass[midx]++;
            `uvm_info("SB",
                $sformatf("[PASS] Mode=%0b%0b | MST_TX=0x%02h->SLV_RX=0x%02h | SLV_TX=0x%02h->MST_RX=0x%02h",
                    tr.CPOL, tr.CPHA,
                    tr.master_data_in, tr.slave_data_out,
                    tr.slave_data_in,  tr.master_data_out),
                UVM_MEDIUM)
        end else begin
            fail_count++;
            mode_fail[midx]++;
            if (!ok_mst)
                `uvm_error("SB",
                    $sformatf("[FAIL] Mode=%0b%0b | MISO: SLV_TX=0x%02h but MST_RX=0x%02h",
                        tr.CPOL, tr.CPHA,
                        tr.slave_data_in, tr.master_data_out))
            if (!ok_slv)
                `uvm_error("SB",
                    $sformatf("[FAIL] Mode=%0b%0b | MOSI: MST_TX=0x%02h but SLV_RX=0x%02h",
                        tr.CPOL, tr.CPHA,
                        tr.master_data_in, tr.slave_data_out))
        end
    endfunction

    function void check_phase(uvm_phase phase);
        string mode_names [4];
        mode_names[0] = "Mode0 (CPOL=0,CPHA=0)";
        mode_names[1] = "Mode1 (CPOL=0,CPHA=1)";
        mode_names[2] = "Mode2 (CPOL=1,CPHA=0)";
        mode_names[3] = "Mode3 (CPOL=1,CPHA=1)";

        `uvm_info("SB","============================================", UVM_NONE)
        `uvm_info("SB","        SPI SCOREBOARD SUMMARY              ", UVM_NONE)
        `uvm_info("SB","============================================", UVM_NONE)
        `uvm_info("SB", $sformatf("  Total : %0d", total_checks), UVM_NONE)
        `uvm_info("SB", $sformatf("  PASS  : %0d", pass_count),   UVM_NONE)
        `uvm_info("SB", $sformatf("  FAIL  : %0d", fail_count),   UVM_NONE)
        `uvm_info("SB","--------------------------------------------", UVM_NONE)
        for (int i = 0; i < 4; i++)
            `uvm_info("SB",
                $sformatf("  %-24s  PASS=%0d  FAIL=%0d",
                    mode_names[i], mode_pass[i], mode_fail[i]),
                UVM_NONE)
        `uvm_info("SB","============================================", UVM_NONE)

        if (fail_count != 0)
            `uvm_error("SB",
                $sformatf("%0d transactions FAILED ? see errors above", fail_count))
        else
            `uvm_info("SB", "** ALL CHECKS PASSED **", UVM_NONE)
    endfunction

endclass : spi_scoreboard


// ============================================================
//  6. AGENT
// ============================================================
class spi_agent extends uvm_agent;
    `uvm_component_utils(spi_agent)

    uvm_sequencer #(spi_seq_item) seqr;
    spi_driver                    drv;
    spi_monitor                   mon;

    uvm_analysis_port #(spi_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap  = new("ap", this);
        mon = spi_monitor::type_id::create("mon", this);
        if (get_is_active() == UVM_ACTIVE) begin
            seqr = uvm_sequencer #(spi_seq_item)::type_id::create("seqr", this);
            drv  = spi_driver::type_id::create("drv",  this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(seqr.seq_item_export);
        mon.ap.connect(ap);
    endfunction

endclass : spi_agent


// ============================================================
//  7. ENV
// ============================================================
class spi_env extends uvm_env;
    `uvm_component_utils(spi_env)

    spi_agent      agent;
    spi_scoreboard sb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = spi_agent::type_id::create("agent", this);
        sb    = spi_scoreboard::type_id::create("sb",    this);
    endfunction

    function void connect_phase(uvm_phase phase);
        agent.ap.connect(sb.analysis_export);
    endfunction

endclass : spi_env


// ============================================================
//  8. TESTS
// ============================================================

// ------------------------------------------------------------
//  Base test
// ------------------------------------------------------------
class spi_base_test extends uvm_test;
    `uvm_component_utils(spi_base_test)

    spi_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = spi_env::type_id::create("env", this);
    endfunction

    function void report_phase(uvm_phase phase);
        uvm_report_server rs = uvm_report_server::get_server();
        `uvm_info("TEST","============================================", UVM_NONE)
        `uvm_info("TEST", $sformatf("  Test   : %s", get_type_name()),  UVM_NONE)
        `uvm_info("TEST", $sformatf("  Errors : %0d",
            rs.get_severity_count(UVM_ERROR)), UVM_NONE)
        `uvm_info("TEST", $sformatf("  Fatals : %0d",
            rs.get_severity_count(UVM_FATAL)), UVM_NONE)
        `uvm_info("TEST","============================================", UVM_NONE)
    endfunction

endclass : spi_base_test


// ------------------------------------------------------------
//  Random test
// ------------------------------------------------------------
class spi_random_test extends spi_base_test;
    `uvm_component_utils(spi_random_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        spi_random_seq seq;
        phase.raise_objection(this);
        seq = spi_random_seq::type_id::create("seq");
        seq.num_transactions = 30;
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask

endclass : spi_random_test


endpackage : spi_uvm_pkg
