
`include "bsg_defines.v"

`default_nettype none

program testbench  #(parameter `BSG_INV_PARAM(width_p)
    , parameter `BSG_INV_PARAM(els_p)
)
(
     input                      clk_i
   , output logic               reset_o

   , output logic               clr_v_o
   , output logic               deq_v_o
   , output logic               roll_v_o

   , output logic [width_p-1:0] data_o
   , output logic               v_o
   , output logic               last_o
   , output logic               error_o
   , input                      ready_i

   , input        [width_p-1:0] data_i
   , input                      v_i
   , input                      last_i
   , output logic               ready_o
);

initial begin
/*
    // Test continuous last_o
    reset_o = 1'b1;
    last_o = 1'b1; error_o = 1'b0;
    ready_o = 1'b0;
    v_o = 1'b0;

    clr_v_o = 1'b0;
    deq_v_o = 1'b0;
    roll_v_o = 1'b0;
    @(posedge clk_i);
    reset_o = 1'b0;
    v_o = 1'b1; data_o = 8'haa;
    ready_o = 1'b1;
    @(posedge clk_i);
    v_o = 1'b1; data_o = 8'hbb;
    ready_o = 1'b0;
    deq_v_o = 1'b1;
    @(posedge clk_i);
    v_o = 1'b1; data_o = 8'hcc;
    deq_v_o = 1'b0;
    @(posedge clk_i);
    v_o = 1'b0;
    @(posedge clk_i);
    @(posedge clk_i);
    @(posedge clk_i);
*/
/*
    // Test overflow and write pointer reset after overflow
    reset_o = 1'b1;
    last_o = 1'b0; error_o = 1'b0;
    ready_o = 1'b0;
    v_o = 1'b0;

    clr_v_o = 1'b0;
    deq_v_o = 1'b0;
    roll_v_o = 1'b0;
    @(posedge clk_i);
    reset_o = 1'b0;
    v_o = 1'b1;
    for(int i = 0;i < 16;i++) begin
        data_o = 8'h11 * i;
        @(posedge clk_i);
    end
    last_o = 1'b1;
    @(posedge clk_i);
    last_o = 1'b0;
    @(posedge clk_i);
    @(posedge clk_i);
*/
/*
    // Test last without error
    reset_o = 1'b1;
    last_o = 1'b0; error_o = 1'b0;
    ready_o = 1'b0;

    clr_v_o = 1'b0;
    deq_v_o = 1'b0;
    roll_v_o = 1'b0;

    @(posedge clk_i);
    reset_o = 1'b0;
    v_o = 1'b1;
    for(int i = 0;i < 4;i++) begin
        if(i == 3)
            last_o = 1'b1;
        data_o = 8'h11 * i;
        @(posedge clk_i);
    end
    last_o = 1'b0;
    @(posedge clk_i);
    @(posedge clk_i);
*/
/*
    // Test last without error
    reset_o = 1'b1;
    last_o = 1'b0; error_o = 1'b0;
    ready_o = 1'b0;

    clr_v_o = 1'b0;
    deq_v_o = 1'b0;
    roll_v_o = 1'b0;

    @(posedge clk_i);
    reset_o = 1'b0;
    v_o = 1'b1;
    for(int i = 0;i < 4;i++) begin
        if(i == 3)
            last_o = 1'b1;
        data_o = 8'h11 * i;
        @(posedge clk_i);
    end
    last_o = 1'b0;
    @(posedge clk_i);
    @(posedge clk_i);
*/

    // Test last with error
/*
    reset_o = 1'b1;
    last_o = 1'b0; error_o = 1'b0;
    ready_o = 1'b0;

    clr_v_o = 1'b0;
    deq_v_o = 1'b0;
    roll_v_o = 1'b0;

    @(posedge clk_i);
    reset_o = 1'b0;
    v_o = 1'b1;
    for(int i = 0;i < 4;i++) begin
        if(i == 3) begin
            last_o = 1'b1;
            error_o = 1'b1;
        end
        data_o = 8'h11 * i;
        @(posedge clk_i);
    end
    last_o = 1'b0;
    error_o = 1'b0;
    @(posedge clk_i);
    @(posedge clk_i);
*/
/*
    // Test asserting clr_v_i during overflow
    fork
      begin
        reset_o = 1'b1;
        last_o = 1'b0; error_o = 1'b0;
        ready_o = 1'b0;
        v_o = 1'b0;

        clr_v_o = 1'b0;
        deq_v_o = 1'b0;
        roll_v_o = 1'b0;
        @(posedge clk_i);
        reset_o = 1'b0;
        v_o = 1'b1;
        for(int i = 0;i < 16;i++) begin
          data_o = 8'h11 * i;
          @(posedge clk_i);
        end
        last_o = 1'b1;
        @(posedge clk_i);
        last_o = 1'b0;
        @(posedge clk_i);
        @(posedge clk_i);
      end
      begin
        for(int i = 0;i < 10;i++) begin
          @(posedge clk_i);
        end
        clr_v_o = 1'b1;
        @(posedge clk_i);
        clr_v_o = 1'b0;
      end
    join
*/
/*
    // Test backpressure when FIFO is non-empty
        reset_o = 1'b1;
        last_o = 1'b0; error_o = 1'b0;
        ready_o = 1'b0;
        v_o = 1'b0;

        clr_v_o = 1'b0;
        deq_v_o = 1'b0;
        roll_v_o = 1'b0;
        @(posedge clk_i);
        reset_o = 1'b0;
        v_o = 1'b1;
        data_o = 8'h00;
        last_o = 1'b1;
        @(posedge clk_i);
        last_o = 1'b0;
        v_o = 1'b1;
        for(int i = 0;i < 16;i++) begin
          data_o = 8'h11 * i;
          @(posedge clk_i);
        end
        v_o = 1'b0;
        @(posedge clk_i);
        @(posedge clk_i);
*/        
        reset_o = 1'b1;
        last_o = 1'b0; error_o = 1'b0;
        ready_o = 1'b0;
        v_o = 1'b0;

        clr_v_o = 1'b0;
        deq_v_o = 1'b0;
        roll_v_o = 1'b0;
        @(posedge clk_i);
        reset_o = 1'b0;
        v_o = 1'b1;
        // First frame
        for(int i = 0;i < els_p;i++) begin
          data_o = 8'h11 * i;
          if(i == els_p - 1)
            last_o = 1'b1;
          @(posedge clk_i);
        end
        last_o = 1'b0;
        v_o = 1'b1;
        // Second packet
        for(int i = 0;i < els_p;i++) begin
          data_o = 8'h11 * i;
          if(i == els_p - 1)
            last_o = 1'b1;
          @(posedge clk_i);
        end
        last_o = 1'b0;
        v_o = 1'b0;
        @(posedge clk_i);
        @(posedge clk_i);
        @(posedge clk_i);
end

endprogram


module wrapper();

parameter width_p = 8;
parameter els_p = 4;
parameter write_no_backpressure_p = 1;

bit                 clk_i;
logic               reset_lo;

logic               clr_v_lo;
logic               deq_v_lo;
logic               roll_v_lo;

logic [width_p-1:0] data_lo;
logic               v_lo;
logic               last_lo;
logic               error_lo;
logic               ready_li;

logic [width_p-1:0] data_li;
logic               v_li;
logic               last_li;
logic               ready_lo;

logic               yumi_lo;


always #1 clk_i = ~clk_i;

initial begin
    $vcdplusfile("dump.vpd");
    $vcdpluson();
end

testbench #(
     .width_p(width_p)
    ,.els_p(els_p)
) testbench (
     .clk_i(clk_i)
    ,.reset_o(reset_lo)

    ,.clr_v_o(clr_v_lo)
    ,.deq_v_o(deq_v_lo)
    ,.roll_v_o(roll_v_lo)

    ,.data_o(data_lo)
    ,.v_o(v_lo)
    ,.last_o(last_lo)
    ,.error_o(error_lo)
    ,.ready_i(ready_li)

    ,.data_i(data_li)
    ,.v_i(v_li)
    ,.last_i(last_li)
    ,.ready_o(ready_lo)
);

assign yumi_lo = v_li & ready_lo;

bsg_fifo_1r1w_rolly #(
     .width_p(width_p)
    ,.els_p(els_p)
    ,.write_no_backpressure_p(write_no_backpressure_p)
) dut (
     .clk_i(clk_i)
    ,.reset_i(reset_lo)

    ,.clr_v_i(clr_v_lo)
    ,.deq_v_i(deq_v_lo)
    ,.roll_v_i(roll_v_lo)

    ,.data_i(data_lo)
    ,.v_i(v_lo)
    ,.last_i(last_lo)
    ,.error_i(error_lo)
    ,.ready_o(ready_li)

    ,.data_o(data_li)
    ,.v_o(v_li)
    ,.last_o(last_li)
    ,.yumi_i(yumi_lo)

    ,.good_packet_o()
    ,.incomplete_packet_o()
    ,.bad_packet_o()
);

endmodule
