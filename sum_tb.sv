`timescale  1ns/1ps

interface avg_if #(parameter WIDTH = 32)();
    reg clk;
    reg rst_n;   
    reg data_first; // start packet
    reg data_last; // end of packet
    reg [WIDTH-1:0] data_in; // data to process
    reg [WIDTH:0] data_out; // data to process
    int data_out_check;
    wire busy;
    wire done;
    event check_data_out;
endinterface

class driver #(parameter WIDTH = 32);
    virtual avg_if _if;
    int fd_input, fd_cycles, fd_output;

    // Constractor
    function new(string in_file, string cycles_file, string output_file);
        fd_input = $fopen(in_file, "r"); // input file
        fd_cycles = $fopen(cycles_file,"r"); // number of inputs to read per iteration 
        fd_output = $fopen(output_file,"w"); // output file 
    endfunction

    // Reset values
    function reset();
        _if.clk = 'b0;
        _if.rst_n = 'b0;
        _if.data_first = 'b0;
        _if.data_last = 'b0;
        _if.data_in = 0; 
    endfunction

    // Drive data to the iterface signals
    task read_data();
        int cycles;
        _if.data_out_check = 0;
        if($feof(fd_cycles))
            return;
        $fscanf(fd_cycles, "%d\n", cycles);
        if (cycles <= 0) begin
            $fatal("ERROR","ERROR: cycle file is empty or contains negative values (%d)",cycles);
            $finish;
        end else if (cycles == 1) begin // only one one valid data
            _if.data_first = 1; // raise up signal for one cycle
            _if.data_last = 1 ;
            $fscanf(fd_input, "%d\n", _if.data_in);
            _if.data_out_check += _if.data_in;
        end else begin
            _if.data_first = 1; // raise up signal for one cycle
            $fscanf(fd_input, "%d\n", _if.data_in);
            _if.data_out_check += _if.data_in;
            @(negedge _if.clk) ;
            for (int i=1; i< cycles-1; ++i) begin
                $fscanf(fd_input, "%d\n", _if.data_in);
                _if.data_first = 0;   
                _if.data_out_check += _if.data_in;
                @(negedge _if.clk) ;
            end
            // in the last cycle hold data_last signal on high for one cycle
            _if.data_first = 0;
            _if.data_last = 1;
            $fscanf(fd_input, "%d\n", _if.data_in); 
            _if.data_out_check += _if.data_in;
        end    

        @(negedge _if.clk) ;
        _if.data_first = 0;        
        _if.data_last = 0;

    endtask

    task run();
        _if.rst_n = 'b1;
        @ (negedge _if.clk); // wait one cycle
        
        forever begin
            @ (negedge _if.clk); // wait one cycle            
            if(_if.done && $feof(fd_cycles)) begin
                $fclose(fd_input);
                $fclose(fd_cycles);
                $fclose(fd_output);
                $finish;
            end
            read_data();
            while(!_if.done) @ (negedge _if.clk);  // wait for busy signal to raise up
            ->_if.check_data_out;
        end

    endtask

    task check();
        $fdisplay(fd_output,"# EX_2 %s %d", "Moshe Israeli",123456789);
        $fdisplay(fd_output,"_if.data_out_check, _if.data_out, _if.data_out_check == _if.data_out");
        $fdisplay(fd_output,"--------------------------------------------------------------------");
        forever begin
            @(_if.check_data_out);
            $fdisplay(fd_output, "%d,\t\t %d,\t\t %d",_if.data_out_check, _if.data_out, _if.data_out_check == _if.data_out);
            // $display("%d, %d, %d",_if.data_out_check, _if.data_out, _if.data_out_check == _if.data_out);
        end
    endtask //automatic
endclass


module sub_tb;

    // parameters
    parameter WIDTH = 32;
    parameter cycle_period = 5;
    parameter hcycle_period = cycle_period / 2;
    parameter VEC_NUM = 8;

    // interface and drivers 
    avg_if _if();
    driver d0;
    // files
    string input_file = "../input/d_input.txt";
    string cycles_file = "../input/d_length.txt";
    string output_file = "../output/sum_output.txt";
    initial begin
        $display("Running sum");
        d0 = new(input_file, cycles_file, output_file);
        d0._if = _if;
        d0.reset();
        #100
        fork
            d0.run(); // inject input
            d0.check(); // checker (between ref and sim)
        join_any
    end    

    always begin
        #hcycle_period _if.clk =~ _if.clk;
    end

    // assign _if.done = 1;

    Sum #(WIDTH) sum(
        .clk(_if.clk),
        .rst_n(_if.rst_n),
        .data_first(_if.data_first),
        .data_last(_if.data_last),
        .data_in(_if.data_in),
        .data_out(_if.data_out),
        .busy(_if.busy),    
        .done(_if.done)    
    );

endmodule
