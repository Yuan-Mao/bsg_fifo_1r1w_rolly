
`include "bsg_defines.v"

`default_nettype none

program testbench #(parameter `BSG_INV_PARAM(width_p)
    , parameter `BSG_INV_PARAM(els_p)
)
(
     input                      clk_i
   , output logic               reset_o

   , output logic               deq_v_o
   , output logic               rollback_v_o
   , output logic               ack_v_o

   , output logic               clr_v_o
   , output logic               commit_not_drop_v_o
   , output logic               commit_not_drop_o

   , output logic [width_p-1:0] data_o
   , output logic               v_o
   , input                      ready_i

   , input        [width_p-1:0] data_i
   , input                      v_i
   , output logic               ready_o
);

initial begin
    reset_o = 1'b1;

    deq_v_o = 1'b0;
    rollback_v_o = 1'b0;
    ack_v_o = 1'b0;
    clr_v_o = 1'b0;
    commit_not_drop_v_o = 1'b0;

    v_o = 1'b0;
    ready_o = 1'b0;
    @(posedge clk_i);
    reset_o = 1'b0;
    v_o = 1'b1;
    data_o = 8'haa;
    @(posedge clk_i);
    data_o = 8'hbb;
    @(posedge clk_i);
    data_o = 8'hcc;
    @(posedge clk_i);
    data_o = 8'hdd;
    commit_not_drop_v_o = 1'b1;
    commit_not_drop_o = 1'b1;
    @(posedge clk_i);
    commit_not_drop_v_o = 1'b0;
    commit_not_drop_o = 1'b0;
    @(posedge clk_i);
    @(posedge clk_i);
    ready_o = 1'b1;
    @(posedge clk_i);
    @(posedge clk_i);
    @(posedge clk_i);
    @(posedge clk_i);
    @(posedge clk_i);
    ack_v_o = 1'b1;
    deq_v_o = 1'b1;
    @(posedge clk_i);
    ack_v_o = 1'b0;
    @(posedge clk_i);
end

endprogram


module wrapper();

parameter width_p = 8;
parameter els_p = 4;
parameter harden_p = 1;

bit                 clk_i;
logic               reset_lo;

logic               deq_v_lo;
logic               rollback_v_lo;
logic               ack_v_lo;

logic               clr_v_lo;
logic               commit_not_drop_v_lo;
logic               commit_not_drop_lo;

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

    ,.deq_v_o(deq_v_lo)
    ,.rollback_v_o(rollback_v_lo)
    ,.ack_v_o(ack_v_lo)

    ,.clr_v_o(clr_v_lo)
    ,.commit_not_drop_v_o(commit_not_drop_v_lo)
    ,.commit_not_drop_o(commit_not_drop_lo)

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
    ,.harden_p(harden_p)
) dut (
     .clk_i(clk_i)
    ,.reset_i(reset_lo)

    ,.deq_v_i(deq_v_lo)
    ,.rollback_v_i(rollback_v_lo)
    ,.ack_v_i(ack_v_lo)

    ,.clr_v_i(clr_v_lo)
    ,.commit_not_drop_v_i(commit_not_drop_v_lo)
    ,.commit_not_drop_i(commit_not_drop_lo)

    ,.data_i(data_lo)
    ,.v_i(v_lo)
    ,.ready_o(ready_li)

    ,.data_o(data_li)
    ,.v_o(v_li)
    ,.yumi_i(yumi_lo)
);

endmodule
