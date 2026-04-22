module spi_master (
    input  logic clk, rst_n, start,
    input  logic [7:0] data_in,
    input  logic CPOL, CPHA,
    output logic SCLK, MOSI, SS_n,
    input  logic MISO,
    output logic done,
    output logic [7:0] data_out
);

    logic [7:0] shift_reg;
    logic [3:0] edge_cnt; 
    typedef enum logic [1:0] {IDLE, TRANSFER, DONE} state_t;
    state_t state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            SCLK     <= 0;
            SS_n     <= 1;
            done     <= 0;
            MOSI     <= 0;
            data_out <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    SCLK <= CPOL;
                    SS_n <= 1;
                    if (start) begin
                        SS_n      <= 0;
                        shift_reg <= data_in;
                        edge_cnt  <= 0;
                        state     <= TRANSFER;
                        // For CPHA=0, MOSI must be valid before the first edge
                        if (CPHA == 0) MOSI <= data_in[7];
                    end
                end

                TRANSFER: begin
                    SCLK <= ~SCLK;
                    edge_cnt <= edge_cnt + 1;

                    // Logic for Leading Edge (edge_cnt: 1, 3, 5...)
                    if (edge_cnt[0] == 0) begin
                        if (CPHA == 0) begin
                            // Sample on leading edge
                            data_out <= {data_out[6:0], MISO};
                        end else begin
                            // Shift on leading edge
                            MOSI <= shift_reg[7];
                            shift_reg <= {shift_reg[6:0], 1'b0};
                        end
                    end 
                    // Logic for Trailing Edge (edge_cnt: 2, 4, 6...)
                    else begin
                        if (CPHA == 0) begin
                            // Shift on trailing edge
                            shift_reg <= {shift_reg[6:0], 1'b0};
                            MOSI <= shift_reg[6]; // Next bit
                        end else begin
                            // Sample on trailing edge
                            data_out <= {data_out[6:0], MISO};
                        end
                    end

                    if (edge_cnt == 15) state <= DONE;
                end

                DONE: begin
                    SS_n  <= 1;
                    done  <= 1;
                    SCLK  <= CPOL;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
