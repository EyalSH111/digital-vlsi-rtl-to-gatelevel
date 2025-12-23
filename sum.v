`timescale 1ns/1ps

module Sum #(
    parameter int NOF_BITS = 32
) (
    input  logic                clk,
    input  logic                rst_n,
    input  logic                data_first,
    input  logic                data_last,
    input  logic [NOF_BITS-1:0] data_in,
    output logic [NOF_BITS:0]   data_out,
    output logic                busy,
    output logic                done
);

    // Internal Registers
    logic [NOF_BITS:0] sum_reg, sum_next;
    logic              busy_reg, busy_next;
    logic              done_reg, done_next;
    logic [NOF_BITS:0] data_out_reg, data_out_next;

    // -----------------------------------------------------------
    // Combinational Block: Logic & Arithmetic
    // -----------------------------------------------------------
    always_comb begin
        // 1. Default Assignments (Prevent Latches)
        sum_next      = sum_reg;
        busy_next     = busy_reg;
        done_next     = 1'b0;        // Pulse defaults to 0
        data_out_next = data_out_reg;

        // 2. Logic Implementation
        if (data_first) begin
            sum_next  = {1'b0, data_in}; // Clear and load first value
            busy_next = 1'b1;
            
            // Handle case where series length is 1
            if (data_last) begin
                 data_out_next = {1'b0, data_in};
                 done_next     = 1'b1;
                 busy_next     = 1'b0;
            end
        end
        else if (busy_reg) begin
            sum_next = sum_reg + {1'b0, data_in}; // Arithmetic here only!
            
            if (data_last) begin
                data_out_next = sum_reg + {1'b0, data_in};
                done_next     = 1'b1;
                busy_next     = 1'b0;
            end
        end
    end

    // -----------------------------------------------------------
    // Sequential Block: Registers Update Only
    // -----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_reg      <= '0;
            busy_reg     <= 1'b0;
            done_reg     <= 1'b0;
            data_out_reg <= '0;
        end else begin
            sum_reg      <= sum_next;
            busy_reg     <= busy_next;
            done_reg     <= done_next;
            data_out_reg <= data_out_next;
        end
    end

    // Output Assignments
    assign data_out = data_out_reg;
    assign busy     = busy_reg;
    assign done     = done_reg;

endmodule