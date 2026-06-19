`timescale 1ns/1ps
module i2c_master
(
    input logic clk,
    input logic rst,
    input logic start,
    input logic rw,
    input logic [6:0] slave_addr,
    input logic [7:0] wr_data,
    output logic [7:0] rd_data,
    output logic busy,
    output logic done,
    output logic ack_error,
    output logic scl,
    output logic sda_out,
    output logic sda_oe,
    input logic sda_in
);
typedef enum logic [3:0]
{
    IDLE,
    START_COND,
    SEND_ADDR,
    ADDR_ACK,
    WRITE_DATA,
    WRITE_ACK,
    READ_DATA,
    READ_ACK,
    STOP_COND,
    COMPLETE
} state_t;
state_t state;
logic [7:0] shift_reg;
logic [3:0] bit_cnt;
logic [7:0] scl_div;
always_ff @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        scl_div <= 0;
        scl <= 1'b1;
    end
    else
    begin
        scl_div <= scl_div + 1;
        if(scl_div == 8'd20)
        begin
            scl <= ~scl;
            scl_div <= 0;
        end
    end
end
always_ff @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        state <= IDLE;
        busy <= 0;
        done <= 0;
        ack_error <= 0;
        rd_data <= 8'h00;
        sda_out <= 1'b1;
        sda_oe <= 1'b1;
        bit_cnt <= 0;
        shift_reg <= 0;
    end
    else
    begin
        case(state)
        IDLE:
        begin
            busy <= 0;
            done <= 0;
            ack_error <= 0;
            sda_out <= 1'b1;
            sda_oe <= 1'b1;
            if(start)
            begin
                busy <= 1'b1;
                state <= START_COND;
            end
        end
        START_COND:
        begin
            sda_out <= 1'b0;
            sda_oe <= 1'b1;
            shift_reg <= {slave_addr,rw};
            bit_cnt <= 7;
            state <= SEND_ADDR;
        end
        SEND_ADDR:
        begin
            sda_out <= shift_reg[bit_cnt];
            if(bit_cnt == 0)
            begin
                sda_oe <= 1'b0;
                state <= ADDR_ACK;
            end
            else
            begin
                bit_cnt <= bit_cnt - 1;
            end
        end
        ADDR_ACK:
        begin
            if(sda_in != 1'b0)
            begin
                ack_error <= 1'b1;
            end
            if(rw == 1'b0)
            begin
                shift_reg <= wr_data;
                bit_cnt <= 7;
                sda_oe <= 1'b1;
                state <= WRITE_DATA;
            end
            else
            begin
                bit_cnt <= 7;
                sda_oe <= 1'b0;
                state <= READ_DATA;
            end
        end
        WRITE_DATA:
        begin
            sda_out <= shift_reg[bit_cnt];
            if(bit_cnt == 0)
            begin
                sda_oe <= 1'b0;
                state <= WRITE_ACK;
            end
            else
            begin
                bit_cnt <= bit_cnt - 1;
            end
        end
        WRITE_ACK:
        begin
            if(sda_in != 1'b0)
            begin
                ack_error <= 1'b1;
            end
            state <= STOP_COND;
        end
        READ_DATA:
        begin
            rd_data[bit_cnt] <= sda_in;
            if(bit_cnt == 0)
            begin
                state <= READ_ACK;
            end
            else
            begin
                bit_cnt <= bit_cnt - 1;
            end
        end
        READ_ACK:
        begin
            sda_oe <= 1'b1;
            sda_out <= 1'b0;
            state <= STOP_COND;
        end
        STOP_COND:
        begin
            sda_oe <= 1'b1;
            sda_out <= 1'b1;
            state <= COMPLETE;
        end
        COMPLETE:
        begin
            busy <= 1'b0;
            done <= 1'b1;
            state <= IDLE;
        end
        default:
        begin
            state <= IDLE;
        end
        endcase
    end
end
endmodule
