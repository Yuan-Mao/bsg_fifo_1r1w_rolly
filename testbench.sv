
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
   , input                      ready_i

   , input        [width_p-1:0] data_i
   , input                      v_i
   , output logic               ready_o
);

initial begin
    reset_o = 1'b1;
    clr_v_o = 1'b0;
    deq_v_o = 1'b0;
    roll_v_o = 1'b0;
    v_o = 1'b0;
    ready_o = 1'b1;
    @(posedge clk_i);
    reset_o = 1'b0;
    data_o = 8'haa;
    v_o = 1'b1;
    @(posedge clk_i);
    @(posedge clk_i);
    @(posedge clk_i);
    v_o = 1'b0;
    @(posedge clk_i);
    @(posedge clk_i);
    @(posedge clk_i);
    @(posedge clk_i);
    roll_v_o = 1'b1;
    @(posedge clk_i);
    roll_v_o = 1'b0;
    @(posedge clk_i);
    @(posedge clk_i);
    ready_o = 1'b0;
    @(posedge clk_i);
    @(posedge clk_i);
    @(posedge clk_i);
    clr_v_o = 1'b1;
    @(posedge clk_i);
    clr_v_o = 1'b0;
    @(posedge clk_i);
    @(posedge clk_i);
    @(posedge clk_i);

end

endprogram


module wrapper();

parameter width_p = 8;
parameter els_p = 4;

bit                 clk_i;
logic               reset_lo;

logic               clr_v_lo;
logic               deq_v_lo;
logic               roll_v_lo;

logic [width_p-1:0] data_lo;
logic               v_lo;
logic               ready_li;

logic [width_p-1:0] data_li;
logic               v_li;
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
    ,.ready_i(ready_li)

    ,.data_i(data_li)
    ,.v_i(v_li)
    ,.ready_o(ready_lo)
);

assign yumi_lo = v_li & ready_lo;

bsg_fifo_1r1w_rolly #(
     .width_p(width_p)
    ,.els_p(els_p)
) dut (
     .clk_i(clk_i)
    ,.reset_i(reset_lo)

    ,.clr_v_i(clr_v_lo)
    ,.deq_v_i(deq_v_lo)
    ,.roll_v_i(roll_v_lo)

    ,.data_i(data_lo)
    ,.v_i(v_lo)
    ,.ready_o(ready_li)

    ,.data_o(data_li)
    ,.v_o(v_li)
    ,.yumi_i(yumi_lo)
);

endmodule
