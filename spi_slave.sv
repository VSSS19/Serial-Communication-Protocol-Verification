module spi_slave (
    input  logic SCLK,
    input  logic SS_n,
    input  logic MOSI,
    output logic MISO,
    input  logic CPOL, CPHA,
    input  logic [7:0] data_in,
    output logic [7:0] data_out
);

    logic [7:0] tx_reg, rx_reg;
    logic [3:0] bit_cnt;

    // Driving MISO
    always_ff @(posedge SCLK or negedge SCLK or posedge SS_n) begin
        if (SS_n) begin
            bit_cnt <= 0;
            tx_reg  <= data_in;
            // Preload MISO for CPHA=0
            if (CPHA == 0) MISO <= data_in[7];
        end else begin
            // Shift Out Logic
            if ((CPHA == 0 && SCLK == CPOL) || (CPHA == 1 && SCLK != CPOL)) begin
                // This is the "Shift Edge" (Trailing for CPHA=0, Leading for CPHA=1)
                if (CPHA == 0) begin
                    MISO <= tx_reg[6];
                    tx_reg <= {tx_reg[6:0], 1'b0};
                end else begin
                    MISO <= tx_reg[7];
                    tx_reg <= {tx_reg[6:0], 1'b0};
                end
            end
        end
    end

    // Sampling MOSI
    always_ff @(posedge SCLK or negedge SCLK) begin
        if (!SS_n) begin
            if ((CPHA == 0 && SCLK != CPOL) || (CPHA == 1 && SCLK == CPOL)) begin
                // This is the "Sample Edge" (Leading for CPHA=0, Trailing for CPHA=1)
                rx_reg <= {rx_reg[6:0], MOSI};
            end
        end
    end

    assign data_out = rx_reg;

endmodule