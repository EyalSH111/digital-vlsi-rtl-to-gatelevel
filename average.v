`timescale 1ns/1ps

module average #(
    parameter int NOF_BITS = 32
) (
    input  logic                clk,
    input  logic                rst_n,
    input  logic                start,
    input  logic                data_first,
    input  logic                data_last,
    input  logic [NOF_BITS-1:0] data_in,
    output logic [NOF_BITS:0]   data_out,
    output logic                busy,
    output logic                TO,
    output logic                done
);

    // -----------------------------------------------------------
    // Parameters & State Definition
    // -----------------------------------------------------------
    localparam logic [1:0] ST_IDLE       = 2'b00;
    localparam logic [1:0] ST_WAIT_FIRST = 2'b01;
    localparam logic [1:0] ST_CALC       = 2'b10;
    localparam logic [1:0] ST_DIV        = 2'b11;

    localparam int TIMEOUT_LIMIT = 10;

    // -----------------------------------------------------------
    // Internal Signals & Registers
    // -----------------------------------------------------------
    logic [1:0] state_reg, state_next;
    
    // Counters
    logic [$clog2(TIMEOUT_LIMIT+1)-1:0] wait_cnt_reg, wait_cnt_next;
    logic [NOF_BITS-1:0]                elem_cnt_reg, elem_cnt_next;
    
    // Outputs (Internal Next Signals)
    logic [NOF_BITS:0] data_out_next;
    logic              busy_next;
    logic              TO_next;
    logic              done_next;

    // Submodule Signals
    logic [NOF_BITS:0] sum_val;
    logic              sum_busy, sum_done;
    logic [NOF_BITS:0] div_result;
    logic              div_done, div_valid; // Assuming div interface based on usage

    // -----------------------------------------------------------
    // Submodules Instantiation
    // -----------------------------------------------------------
    Sum #(NOF_BITS) s_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .data_first (data_first),
        .data_last  (data_last),
        .data_in    (data_in),
        .data_out   (sum_val),
        .busy       (sum_busy),
        .done       (sum_done)
    );

    // Assuming divu_int interface matches your original code
    divu_int #(NOF_BITS+1) d_inst (
        .clk   (clk),
        .rst_n (rst_n),
        .start (sum_done),
        .busy  (),          // Not strictly used in main logic
        .done  (div_done),
        .valid (div_valid),
        .dbz   (),
        .a     (sum_val),
        .b     ({1'b0, elem_cnt_reg}),
        .val   (div_result),
        .rem   ()
    );

    // -----------------------------------------------------------
    // Combinational Block: Next State & Arithmetic Logic
    // -----------------------------------------------------------
    always_comb begin
        // 1. Default Assignments (Latch Prevention)
        state_next    = state_reg;
        wait_cnt_next = wait_cnt_reg;
        elem_cnt_next = elem_cnt_reg;
        
        // Output defaults
        busy_next     = (state_reg != ST_IDLE); // Helper for busy logic
        TO_next       = 1'b0;
        done_next     = 1'b0;
        data_out_next = data_out; // Keep previous value by default

        // 2. State Machine Logic
        case (state_reg)
            ST_IDLE: begin
                busy_next = 1'b0;
                if (start) begin
                    state_next    = ST_WAIT_FIRST;
                    wait_cnt_next = '0;
                    elem_cnt_next = '0;
                    busy_next     = 1'b1;
                end
            end

            ST_WAIT_FIRST: begin
                if (data_first) begin
                    wait_cnt_next = '0;
                    elem_cnt_next = {{(NOF_BITS-1){1'b0}}, 1'b1}; // Set to 1
                    
                    if (data_last) begin
                         state_next = ST_DIV; 
                    end else begin
                         state_next = ST_CALC;
                    end
                end 
                else begin
                    // Timeout Logic
                    if (wait_cnt_reg == TIMEOUT_LIMIT - 1) begin
                        state_next = ST_IDLE;
                        TO_next    = 1'b1;     // Pulse TO
                        busy_next  = 1'b0;
                    end else begin
                        wait_cnt_next = wait_cnt_reg + 1'b1;
                    end
                end
            end

            ST_CALC: begin
                // Sum module handles summation, we assume valid data every cycle
                elem_cnt_next = elem_cnt_reg + 1'b1;
                
                if (data_last) begin
                    state_next = ST_DIV;
                end
            end

            ST_DIV: begin
                // Wait for divider to finish
                if (div_done) begin
                    data_out_next = div_result;
                    done_next     = 1'b1;
                    state_next    = ST_IDLE;
                    busy_next     = 1'b0;
                end
            end

            default: state_next = ST_IDLE;
        endcase
    end

    // -----------------------------------------------------------
    // Sequential Block: Registers Update Only
    // -----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg    <= ST_IDLE;
            wait_cnt_reg <= '0;
            elem_cnt_reg <= '0;
            data_out     <= '0;
            busy         <= 1'b0;
            TO           <= 1'b0;
            done         <= 1'b0;
        end else begin
            state_reg    <= state_next;
            wait_cnt_reg <= wait_cnt_next;
            elem_cnt_reg <= elem_cnt_next;
            
            // Output registers
            data_out     <= data_out_next;
            busy         <= busy_next;
            TO           <= TO_next;
            done         <= done_next;
        end
    end

endmodule