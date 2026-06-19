module uart_tx
(
    input logic clk,
    input logic rst,

    input logic tx_start,
    input logic [7:0] tx_data,

    output logic tx,
    output logic tx_busy
);

typedef enum logic [1:0]
{
    IDLE,
    START,
    DATA,
    STOP
} state_t;

state_t state;

logic [7:0] shift_reg;
logic [3:0] bit_cnt;

always_ff @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        state    <= IDLE;
        tx       <= 1'b1;
        tx_busy  <= 0;
        bit_cnt  <= 0;
    end
    else
    begin
        case(state)

        IDLE:
        begin
            tx <= 1'b1;
            tx_busy <= 0;

            if(tx_start)
            begin
                shift_reg <= tx_data;
                tx_busy <= 1;
                state <= START;
            end
        end

        START:
        begin
            tx <= 0;
            bit_cnt <= 0;
            state <= DATA;
        end

        DATA:
        begin
            tx <= shift_reg[bit_cnt];

            if(bit_cnt == 7)
                state <= STOP;
            else
                bit_cnt <= bit_cnt + 1;
        end

        STOP:
        begin
            tx <= 1;
            tx_busy <= 0;
            state <= IDLE;
        end

        endcase
    end
end

endmodule
