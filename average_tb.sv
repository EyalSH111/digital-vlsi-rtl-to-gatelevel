`timescale 1ns/1ps

interface avg_if #(parameter WIDTH = 32)();
    reg clk;
    reg start;
    reg rst_n;   
    reg data_first;          // Start of packet
    reg data_last;           // End of packet
    reg [WIDTH-1:0] data_in; // Data to process
    wire [WIDTH:0] data_out; // Average result
    wire busy;
    wire done;
    wire TO;
    
    event check_data_out;
    int data_out_check;      // For scoreboard comparison
endinterface

class driver #(parameter WIDTH = 32);
    virtual avg_if _if;
    int fd_output;

    function new();
    endfunction

    // Reset task to initialize signals
    function reset();
        _if.clk = 'b0;
        _if.start = 'b0;
        _if.rst_n = 'b0;
        _if.data_first = 'b0;
        _if.data_last = 'b0;
        _if.data_in = 0; 
    endfunction

    // Task to generate random data packets
    task generate_data(
        input int max_iterations // Maximum number of iterations
    );

        int cycles;
        int random_data;

        _if.data_out_check = 0;
        // Generate a random number of cycles between 1 and 20
        cycles = $urandom_range(1, 20);

        if (cycles == 1) begin // Only one valid data
            _if.data_first = 1; // Raise signal for one cycle
            _if.data_last = 1;

            // Generate random data in the range 1 to 20
            random_data = $urandom_range(1, 20);
            _if.data_in = random_data;
            _if.data_out_check = _if.data_in; 
        end else begin

            _if.data_first = 1; // Raise signal for one cycle
            random_data = $urandom_range(1, 20);
            _if.data_in = random_data;
            _if.data_out_check = _if.data_out_check + _if.data_in; 

            @(negedge _if.clk);
            for (int i = 1; i < cycles-1; ++i) begin
                // Generate random data for the first cycle
                random_data = $urandom_range(1, 20);
                _if.data_in = random_data;
                _if.data_out_check = _if.data_out_check + _if.data_in; 
                _if.data_first = 0;
                @(negedge _if.clk);
            end

            // For the last cycle, hold `data_last` signal high for one cycle
            random_data = $urandom_range(1, 20);
            _if.data_in = random_data;
            _if.data_out_check = (_if.data_out_check + _if.data_in); 
            _if.data_first = 0;
            _if.data_last = 1;
        end

        @(negedge _if.clk);
        _if.data_first = 0;
        _if.data_last = 0;
        // Calculate expected average (integer division)
        _if.data_out_check = (_if.data_out_check) / (cycles); 

    endtask

    // Main run task
    task run(
        input int max_iterations // Maximum number of iterations
    );
        string output_file = "../reports/average_output_part1.txt"; // Adjusted path to standard reports dir
        int iteration_count = 0; // Counter for the number of iterations
        int wait2start = 0;
        
        // Open a check file
        fd_output = $fopen(output_file, "w");
        if (fd_output == 0) begin
             $display("Error: Could not open output file: %s", output_file);
             $finish;
        end
        
        _if.rst_n = 'b1;
        @ (negedge _if.clk); // Wait one cycle

        while (iteration_count < max_iterations) begin
            _if.start = 1;
            @ (negedge _if.clk); // Wait one cycle
            _if.start = 0;

            // ============================================================
            // OPTIONAL: Timeout (TO) Test
            // ============================================================
            if ($urandom_range(0,4) == 0) begin
                int cycles = 0;

                // Hold inputs idle: no valid data_first/data_last
                _if.data_first = 1'b0;
                _if.data_last  = 1'b0;
                _if.data_in    = '0;

                // Wait up to 11 cycles. 
                // If it takes more than 10, TO should assert.
                // So by cycle 11 we expect TO to have happened.
                while (!_if.TO && (cycles < 11)) begin
                    @(negedge _if.clk);
                    cycles++;
                end

                if (_if.TO) begin
                     $display("TO OK: timeout triggered (after %0d cycles) (iteration %0d, time %0t)",
                              cycles, iteration_count, $time);
                    
                    // Check TO is exactly 1 cycle pulse
                    @(negedge _if.clk);
                    if(_if.TO) begin
                       $error("TO ERROR: TO stayed high more than 1 cycle (iteration %0d, time %0t)",
                             iteration_count, $time);
                    end
                end  
                else begin
                   $error("TO ERROR: timeout did NOT trigger by 11 cycles (iteration %0d, time %0t)",
                          iteration_count, $time);  
                end
 
                // Skip the normal average flow for this iteration
                iteration_count = iteration_count + 1;

                // Random delay before the next start
                wait2start = $urandom_range(1, 20);
                repeat (wait2start) @(negedge _if.clk);

                continue; 
            end
            // ============================================================

            generate_data(max_iterations);
            
            // Wait for processing to finish
            while(!_if.done) @ (negedge _if.clk);  

            ->_if.check_data_out; // Trigger scoreboard check            
       
            // Increment the iteration counter
            iteration_count = iteration_count + 1;
       
            // Add a delay to the stop condition
            wait2start = $urandom_range(1, 20);
            repeat(wait2start) @(negedge _if.clk);
       
        end

        // Stop the simulation after reaching max_iterations
        $display("Simulation finished after %0d iterations (max_iterations=%0d).", iteration_count, max_iterations);
        $fclose(fd_output);
        $finish;

    endtask

    // Checker / Scoreboard task
    task check();
        // Header printing
        $fdisplay(fd_output,"# EX_3 part 1"",111111);
        $fdisplay(fd_output,"Expected, Actual, Match (1=Yes)");
        $fdisplay(fd_output,"--------------------------------------------------------------------");
        
        forever begin
            @(_if.check_data_out);
            $fdisplay(fd_output, "%d,\t\t %d,\t\t %d",_if.data_out_check, _if.data_out, _if.data_out_check == _if.data_out);
            $display("Check: Exp=%d, Act=%d, Match=%d",_if.data_out_check, _if.data_out, _if.data_out_check == _if.data_out);                
        end
    endtask

endclass


module average_tb; // Renamed to standard average_tb

    // Parameters
    parameter WIDTH = 32;
    parameter cycle_period = 5;
    parameter hcycle_period = cycle_period / 2;
    parameter VEC_NUM = 8;

    // Interface and drivers 
    avg_if _if();
    driver d0;
    int max_iterations;

    // Read the stop condition from a plusarg, defaulting to 100 if not provided
    initial begin
        if (!$value$plusargs("max_iterations=%d", max_iterations)) begin
            max_iterations = 100; // Default value
        end
    end

    // ------------------------------------------------------------
    // WAVEFORM DUMPING CONFIGURATION
    // ------------------------------------------------------------
    initial begin
        // Open the SHM database
        $shm_open("waves.shm");
        // Probe all signals in the hierarchy
        $shm_probe("AS");
    end
    // ------------------------------------------------------------

    initial begin
        $display("Running average simulation...");
        d0 = new();
        d0._if = _if;
        d0.reset();
        #100;
        fork
            d0.run(max_iterations);
            d0.check();
        join_any
    end    

    // Clock Generation
    initial begin
        _if.clk = 0;
        forever #hcycle_period _if.clk = ~_if.clk;
    end

    // Device Under Test (DUT) Instantiation
    average #(WIDTH) avg(
        .clk        (_if.clk),
        .start      (_if.start),
        .rst_n      (_if.rst_n),   
        .data_first (_if.data_first),
        .data_last  (_if.data_last),
        .data_in    (_if.data_in),
        .data_out   (_if.data_out),
        .TO         (_if.TO),
        .busy       (_if.busy),    
        .done       (_if.done) 
    );

endmodule