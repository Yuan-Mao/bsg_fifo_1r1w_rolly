
`include "bsg_defines.v"

`default_nettype none

program testbench  #(parameter `BSG_INV_PARAM(width_p)
    , parameter `BSG_INV_PARAM(els_p)
)
(
     input                      clk_i
   , output logic               reset_o

   , output logic [width_p-1:0] data_o
   , output logic               v_o
   , output logic               last_o
   , output logic               error_o
   , input                      ready_i

   , input [width_p-1:0]        data_i
   , input                      v_i
   , input                      last_i
   , output logic               ready_o

   , input                      good_packet_i
   , input                      incomplete_packet_i
   , input                      bad_packet_i

);

clocking cb @(posedge clk_i);
  output data_o;
  output v_o;
  output last_o;
  output error_o;
  input  ready_i;

  input  data_i;
  input  v_i;
  input  last_i;
  output ready_o;

  input  good_packet_i;
  input  incomplete_packet_i;
  input  bad_packet_i;
endclocking


task automatic keep_sending_packet();
  int i;
  v_o = 1'b1;
  forever begin
    i = 0;
    forever begin
      data_o = 8'h11 * i;
      if(i == 2)
        last_o = 1'b1;
      @(cb);
      // check the sampled data
      if(cb.ready_i == 1'b1) begin
        // handshaking completed
        i++;
      end else begin
        // handshaking not completed
      end
      if(i == 3) // finish sending all 3 data
        break;
    end
    last_o = 1'b0;
  end
  v_o = 1'b0;
endtask

initial begin
  reset_o = 1'b1;
  v_o = 1'b0;
  last_o = 1'b0;
  error_o = 1'b0;
  ready_o = 1'b0;
  @(cb);
  reset_o = 1'b0;
  fork
    keep_sending_packet();
    begin
      for(int i = 0;i < 32;i++) begin
        ready_o = $urandom() & 1'b1;
        @(cb);
      end
      $finish;
    end
  join
end

endprogram


module wrapper();

parameter width_p = 8;
parameter els_p = 4;
parameter write_no_backpressure_p = 0;

bit                 clk_i;
logic               reset_lo;

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

logic               good_packet_li;
logic               incomplete_packet_li;
logic               bad_packet_li;


always #1 clk_i = ~clk_i;

initial begin
    $vcdplusfile("dump.vpd");
    $vcdpluson();
//    for(int i = 0;i < 64;i++)
//      @(posedge clk_i);
//    $display("Timeout");
//    $finish;
end

testbench #(
     .width_p(width_p)
    ,.els_p(els_p)
) testbench (
     .clk_i(clk_i)
    ,.reset_o(reset_lo)

    ,.data_o(data_lo)
    ,.v_o(v_lo)
    ,.last_o(last_lo)
    ,.error_o(error_lo)
    ,.ready_i(ready_li)

    ,.data_i(data_li)
    ,.v_i(v_li)
    ,.last_i(last_li)
    ,.ready_o(ready_lo)

    ,.good_packet_i(good_packet_li)
    ,.incomplete_packet_i(incomplete_packet_li)
    ,.bad_packet_i(bad_packet_li)
);

assign yumi_lo = v_li & ready_lo;

bsg_store_and_forward #(
     .width_p(width_p)
    ,.els_p(els_p)
    ,.write_no_backpressure_p(write_no_backpressure_p)
) dut (
     .clk_i(clk_i)
    ,.reset_i(reset_lo)

    ,.data_i(data_lo)
    ,.v_i(v_lo)
    ,.last_i(last_lo)
    ,.error_i(error_lo)
    ,.ready_o(ready_li)

    ,.data_o(data_li)
    ,.v_o(v_li)
    ,.last_o(last_li)
    ,.yumi_i(yumi_lo)

    ,.good_packet_o(good_packet_li)
    ,.incomplete_packet_o(incomplete_packet_li)
    ,.bad_packet_o(bad_packet_li)
);

endmodule
