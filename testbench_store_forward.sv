
`include "bsg_defines.v"

`default_nettype none

/*
 *   This random test checks:
 * 1. if the data can go through the FIFO properly
 * 2. good/incomplete/bad packet status
 * 3. internal wptr, wcptr
 *
 */

program testbench  #(parameter `BSG_INV_PARAM(width_p)
    , parameter `BSG_INV_PARAM(els_p)
    , parameter `BSG_INV_PARAM(write_no_backpressure_p)
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


localparam mtu_lp = els_p;
localparam packet_count_lp = 1024;
localparam buffer_size = packet_count_lp * mtu_lp;

// data + last
bit [width_p+1-1:0] buffer [buffer_size];

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


task automatic send_and_check_packet(
    input int els
  , input int mtu
  , input int count
);
  int unsigned data_seq = 0;
  bit error_tmp;
  int unsigned wcptr_tracker = 0;
  for(int i = 0;i < count;) begin
    error_tmp = $urandom() & 1'b1;
    for(int j = 0;j < els;) begin
      v_o = $urandom() & 1'b1;
      if(v_o == 1'b1) begin
        data_o = (width_p)'(data_seq * els + j);
        last_o = (j == els - 1);
        if(last_o == 1'b1) begin
          error_o = error_tmp;
        end
      end
      @(cb);
      // check the sampled data
      if(cb.ready_i == 1'b1 & v_o == 1'b1) begin
        // handshaking completed
        if(error_tmp == 1'b0) begin
          buffer[i * els + j] = {data_o, last_o};
        end
        j++;
      end else begin
        // handshaking not completed
      end
    end

    if(good_packet_i) begin
      wcptr_tracker = (wcptr_tracker + els) % (2 * mtu);
      i++;
    end

    // send complete
    if(write_no_backpressure_p == 0) begin
      if(error_tmp == 1'b0) begin
        // good
        assert(good_packet_i) else $finish;
      end else begin
        // bad
        assert(bad_packet_i) else $finish;
      end
      // never incomplete
      assert(incomplete_packet_i == 1'b0) else $finish;
    end else begin
      // one of them must be high
      assert($onehot({good_packet_i, bad_packet_i, incomplete_packet_i})) else $finish;
    end
    // check wptr, wcptr
    assert(wcptr_tracker == wrapper.dut.fifo.wcptr_r) else $finish;
    assert(wrapper.dut.fifo.wcptr_r == wrapper.dut.fifo.wptr_r) else $finish;

    data_seq++;

  end
  v_o = 1'b0;
endtask

task automatic receive_and_check_packet(
    input int count
);
  int idx = 0;
  // keep receiving until 'count' packets are received
  for(int i = 0;i < count;i++) begin
    forever begin
      ready_o = $urandom() & 1'b1;
      @(cb);
      if(cb.v_i & ready_o) begin
        // received a beat: check it
        assert(idx < buffer_size) else $finish;
        assert(buffer[idx++] == {cb.data_i, cb.last_i}) else $finish;
        $display("%x %x", cb.data_i, cb.last_i);
        if(cb.last_i == 1'b1)
          break;
      end
    end
  end
endtask

int valid_count;
initial begin
  reset_o = 1'b1;
  v_o = 1'b0;
  last_o = 1'b0;
  error_o = 1'b0;
  ready_o = 1'b0;
  @(cb);
  reset_o = 1'b0;
  fork
    send_and_check_packet(mtu_lp - 1, mtu_lp, packet_count_lp);
    receive_and_check_packet(packet_count_lp);
  join
  $display("Test completed");
end

endprogram


module wrapper();

// change parameters here:
parameter width_p = 8;
parameter els_p = 4;
parameter harden_p = 1;
parameter write_no_backpressure_p = 1;

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
end

testbench #(
     .width_p(width_p)
    ,.els_p(els_p)
    ,.write_no_backpressure_p(write_no_backpressure_p)
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
    ,.harden_p(harden_p)
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
