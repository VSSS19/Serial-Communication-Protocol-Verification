module tb_spi;
    logic clk, rst_n, start;
    logic [7:0] m_data_in, m_data_out;
    logic [7:0] s_data_in, s_data_out;
    logic SCLK, MOSI, MISO, SS_n, done;
    logic CPOL, CPHA;

    spi_master master (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .data_in(m_data_in),
        .CPOL(CPOL),
        .CPHA(CPHA),
        .SCLK(SCLK),
        .MOSI(MOSI),
        .MISO(MISO),
        .SS_n(SS_n),
        .done(done),
        .data_out(m_data_out)
    );

    spi_slave slave (
        .SCLK(SCLK),
        .SS_n(SS_n),
        .MOSI(MOSI),
        .MISO(MISO),
        .CPOL(CPOL),
        .CPHA(CPHA),
        .data_in(s_data_in),
        .data_out(s_data_out)
    );
    always #5 clk = (clk === 1'b0);

    task run_mode(input bit cpol, input bit cpha);
        begin
            // Apply Reset
            rst_n = 0; #20; rst_n = 1; #10;
            
            CPOL = cpol;
            CPHA = cpha;
            m_data_in = 8'hA5;
            s_data_in = 8'h3C;

            $display("\n=== TEST: CPOL=%0d CPHA=%0d ===", CPOL, CPHA);
            
            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;

            wait(done);
            #50;

            $display("M->S: Sent %h, Recv %h", m_data_in, s_data_out);
            $display("S->M: Sent %h, Recv %h", s_data_in, m_data_out);

            if (m_data_in == s_data_out && s_data_in == m_data_out)
                $display("? PASS");
            else
                $display("? FAIL");
        end
    endtask

    initial begin
        clk = 0;
        run_mode(0,0);
        run_mode(0,1);
        run_mode(1,0);
        run_mode(1,1);
        $finish;
    end
endmodule
