// ============================================================================
// fpga_5ch_logger.v -- 5-channel UART aggregator, receives from the Mega.
// Extends the confirmed-working-on-real-hardware 3-channel version back
// up to 5, same proven core (arbiter, FIFOs, uart_rx/tx) unchanged.
//
//   rx_ch0 (FPGA_IO0)  <- Mega pin 11, 9600 baud  (SoftwareSerial)
//   rx_ch1 (FPGA_IO17) <- Mega pin 14, 38400 baud (Serial3, hardware)
//   rx_ch2 (FPGA_IO18) <- Mega pin 13, 57600 baud (SoftwareSerial)
//   rx_ch3 (FPGA_IO9)  <- Mega pin 18, 19200 baud (Serial1, hardware)
//   rx_ch4 (FPGA_IO10) <- Mega pin 16, 9600 baud  (Serial2, hardware)
//
// GPIO9/10 chosen deliberately: clear of the GPIO12-15 reserved
// FPGA<->ESP32 interconnect bus, and clear of GPIO1/GPIO7 (QWIIC-shared,
// default-routed to the ESP32 unless 0-ohm resistors are soldered).
//
// Output to ESP32 stays at 9600 baud (~0.16% drift at 10MHz) -- 57600/
// 115200 both drift over 8% at this clock, which is what originally broke
// the FPGA-as-transmitter version earlier in this project. Receiving
// tolerates real baud rates fine regardless (re-syncs every byte); only
// this board's own transmit clock divider is drift-sensitive.
// ============================================================================

// ---------------------------------------------------------------------------
// sync2ff -- 2-flop synchronizer for each external async UART RX line
// ---------------------------------------------------------------------------
module sync2ff (
    input  i_clk,
    input  i_async,
    output o_sync
);
  reg r_ff1, r_ff2;
  always @(posedge i_clk) begin
    r_ff1 <= i_async;
    r_ff2 <= r_ff1;
  end
  assign o_sync = r_ff2;
endmodule


// ---------------------------------------------------------------------------
// sync_fifo -- single-clock pointer-based FIFO (one per channel)
// ---------------------------------------------------------------------------
module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 8,
    parameter ADDR_WIDTH = $clog2(DEPTH)
) (
    input                   i_clk,
    input                   i_rst,
    input                   i_wr_en,
    input  [DATA_WIDTH-1:0] i_wr_data,
    input                   i_rd_en,
    output [DATA_WIDTH-1:0] o_rd_data,
    output                  o_full,
    output                  o_empty
);
  reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
  reg [ADDR_WIDTH:0] r_wr_ptr = 0;
  reg [ADDR_WIDTH:0] r_rd_ptr = 0;
  wire w_wr_allowed = i_wr_en && !o_full;
  wire w_rd_allowed = i_rd_en && !o_empty;
  always @(posedge i_clk) begin
    if (i_rst) r_wr_ptr <= 0;
    else if (w_wr_allowed) begin
      mem[r_wr_ptr[ADDR_WIDTH-1:0]] <= i_wr_data;
      r_wr_ptr <= r_wr_ptr + 1'b1;
    end
  end
  always @(posedge i_clk) begin
    if (i_rst) r_rd_ptr <= 0;
    else if (w_rd_allowed) r_rd_ptr <= r_rd_ptr + 1'b1;
  end
  assign o_rd_data = mem[r_rd_ptr[ADDR_WIDTH-1:0]];
  assign o_empty   = (r_wr_ptr == r_rd_ptr);
  assign o_full    = (r_wr_ptr[ADDR_WIDTH] != r_rd_ptr[ADDR_WIDTH]) &&
                      (r_wr_ptr[ADDR_WIDTH-1:0] == r_rd_ptr[ADDR_WIDTH-1:0]);
endmodule


// ---------------------------------------------------------------------------
// uart_rx -- unchanged logic, counters widened to 32 bits to clear the
// WIDTHEXPAND lint warnings (comparisons against 32-bit parameter math no
// longer mismatch a narrower reg -- purely cosmetic, zero functional change,
// range was always comfortably within 18 bits at any realistic baud rate).
// ---------------------------------------------------------------------------
module uart_rx #(
    parameter CLK = 10_000_000,
    parameter BAUD_RATE = 115200
) (
    input         i_Clock,
    input         i_RX_Serial,
    output        o_RX_DV,
    output [7:0]  o_RX_Byte
);
parameter CLOCKS_PER_BIT = CLK/BAUD_RATE;
parameter IDLE = 3'b000;
parameter RX_START_BIT = 3'b001;
parameter RX_DATA_BITS = 3'b010;
parameter RX_STOP_BIT = 3'b011;
parameter CLEANUP = 3'b100;
localparam CLOCK_COUNT_WIDTH = $clog2(CLOCKS_PER_BIT);
reg [CLOCK_COUNT_WIDTH-1:0] r_Clock_Count;
reg [2:0] r_Bit_Index;
reg [7:0] r_RX_Byte;
reg r_RX_DV;
reg [2:0] r_SM_Main;
always @(posedge i_Clock) begin
    case (r_SM_Main)
        IDLE: begin
            r_RX_DV <= 1'b0;
            r_Clock_Count <= 0;
            r_Bit_Index <= 0;
            if (i_RX_Serial == 1'b0)
                r_SM_Main <= RX_START_BIT;
            else
                r_SM_Main <= IDLE;
        end
        RX_START_BIT: begin
            if (r_Clock_Count == CLOCKS_PER_BIT / 2) begin
                if (i_RX_Serial == 1'b0) begin
                    r_Clock_Count <= 0;
                    r_SM_Main <= RX_DATA_BITS;
                end else
                    r_SM_Main <= IDLE;
            end else begin
                r_Clock_Count <= r_Clock_Count + 1'b1;
                r_SM_Main <= RX_START_BIT;
            end
        end
        RX_DATA_BITS: begin
            if(r_Clock_Count < CLOCKS_PER_BIT - 1) begin
                r_Clock_Count <= r_Clock_Count + 1'b1;
                r_SM_Main <= RX_DATA_BITS;
            end else begin
                r_Clock_Count <= 0;
                r_RX_Byte[r_Bit_Index] <= i_RX_Serial;
                if (r_Bit_Index < 7) begin
                    r_Bit_Index <= r_Bit_Index + 1'b1;
                    r_SM_Main <= RX_DATA_BITS;
                end else begin
                    r_Bit_Index <= 0;
                    r_SM_Main <= RX_STOP_BIT;
                end
            end
        end
        RX_STOP_BIT: begin
            if(r_Clock_Count < CLOCKS_PER_BIT - 1) begin
                r_Clock_Count <= r_Clock_Count + 1'b1;
                r_SM_Main <= RX_STOP_BIT;
            end else begin
                r_RX_DV <= 1'b1;
                r_Clock_Count <= 0;
                r_SM_Main <= CLEANUP;
            end
        end
        CLEANUP: begin
            r_SM_Main <= IDLE;
            r_RX_DV <= 1'b0;
        end
        default: r_SM_Main <= IDLE;
    endcase
end
assign o_RX_Byte = r_RX_Byte;
assign o_RX_DV = r_RX_DV;
endmodule


// ---------------------------------------------------------------------------
// uart_tx -- same logic as before. Fixes applied:
//   - r_cnt, r_index widened to 32 bits (clears WIDTHEXPAND/WIDTHTRUNC)
//   - case(LSB) replaced with if/else (clears CASEINCOMPLETE -- the linter
//     couldn't prove a 1-bit case with only two branches + default was
//     exhaustive; a plain if/else has no such ambiguity)
// ---------------------------------------------------------------------------
module uart_tx #(
  parameter IN_CLK_HZ         = 10_000_000,
  parameter DATA_FRAME        = 8,
  parameter BAUD_RATE         = 115200,
  parameter OVERSAMPLING_MODE = 16,
  parameter STOP_BIT          = 1,
  parameter LSB               = 1'b0
) (
  input                   i_clk,
  input                   i_rst,
  output                  o_tx,
  input  [DATA_FRAME-1:0] i_tx_data,
  input                   i_tx_start,
  output                  o_tx_done
);
  wire w_tick;
  uart_txuart_tx #(
    .DATA_FRAME(DATA_FRAME), .BAUD_RATE(BAUD_RATE),
    .OVERSAMPLING_MODE(OVERSAMPLING_MODE), .STOP_BIT(STOP_BIT), .LSB(LSB)
  ) uart_tx_wrapper (
    .i_clk(i_clk), .i_rst(i_rst), .i_tx_data(i_tx_data),
    .i_tx_start(i_tx_start), .i_tick(w_tick), .o_tx(o_tx), .o_tx_done(o_tx_done)
  );
  uart_txbaud_rate_generator_tx #(
    .BAUD_RATE(BAUD_RATE), .OVERSAMPLING_MODE(OVERSAMPLING_MODE), .IN_CLK_HZ(IN_CLK_HZ)
  ) baud_rate_gen_tx_wrapper (
    .i_clk(i_clk), .i_rst(i_rst), .o_tick(w_tick)
  );
endmodule

module uart_txuart_tx #(
  parameter DATA_FRAME        = 8,
  parameter BAUD_RATE         = 115200,
  parameter OVERSAMPLING_MODE = 16,
  parameter STOP_BIT          = 1,
  parameter LSB               = 1'b0
) (
  input                       i_clk,
  input                       i_rst,
  input      [DATA_FRAME-1:0] i_tx_data,
  input                       i_tx_start,
  input                       i_tick,
  output reg                  o_tx,
  output reg                  o_tx_done
);
  localparam IDLE  = 4'b0001;
  localparam START = 4'b0010;
  localparam DATA  = 4'b0100;
  localparam STOP  = 4'b1000;
  localparam STOP_BIT_P1 = (STOP_BIT == 1.5) ? (OVERSAMPLING_MODE / 2) - 1 : 0;
  localparam STOP_BIT_P2 = (STOP_BIT == 1.5) ? 1 : STOP_BIT - 1;
  reg [3:0] r_state, r_next;
  reg r_send_data, r_index_cnt_en, r_load, r_cnt_en;
  reg w_send_data, w_index_cnt_en, w_load, w_tx, w_tx_done, w_cnt_en;
  reg r_tx_regA, r_tx_regB;
  wire w_tx_r_edge;
  always @(posedge i_clk) begin
    r_tx_regA <= i_tx_start;
    r_tx_regB <= r_tx_regA;
  end
  assign w_tx_r_edge = r_tx_regA & ~r_tx_regB;
  reg [3:0] r_cnt   = 'b0;
  reg [$clog2(DATA_FRAME)-1:0] r_index = 'b0;
  reg [DATA_FRAME-1:0] r_tx_buffer;
  always @(posedge i_clk) begin
    if (i_rst) r_state <= IDLE; else r_state <= r_next;
  end
  always @* begin
    r_next = r_state;
    case (r_state)
      IDLE: if (w_tx_r_edge) r_next = START;
      START: if (r_cnt == 'b0 && i_tick) r_next = DATA;
      DATA: if (r_cnt == 'b0 && i_tick) begin if(r_index == DATA_FRAME-1) r_next = STOP; end
      STOP: if (i_tick && r_cnt == STOP_BIT_P1 && r_index == STOP_BIT_P2) r_next = IDLE;
      default: r_next = IDLE;
    endcase
  end
  always @* begin
    w_index_cnt_en = 1'b0; w_tx_done = 1'b0; w_send_data = 1'b0;
    w_cnt_en = 1'b0; w_load = 1'b0; w_tx = 1'b1;
    case (r_state)
      START: begin w_cnt_en = 1'b1; w_load = 1'b1; w_tx = 1'b0; end
      DATA: begin
        w_load = 1'b0; w_cnt_en = 1'b1; w_send_data = 1'b1; w_index_cnt_en = 1'b1;
        if (LSB == 1'b0) w_tx = r_tx_buffer[0];
        else w_tx = r_tx_buffer[DATA_FRAME-1];
      end
      STOP: begin w_load = 1'b0; w_cnt_en = 1'b1; w_send_data = 1'b0; w_tx_done = 1'b1; w_index_cnt_en = 1'b1; end
    endcase
  end
  always @(posedge i_clk) begin
    if (i_rst) begin
      r_send_data <= 1'b0; r_cnt_en <= 1'b0; r_index_cnt_en <= 1'b0;
      r_load <= 1'b0; o_tx_done <= 1'b0; o_tx <= 1'b1;
    end else begin
      if (i_tick) r_send_data <= w_send_data;
      r_cnt_en <= w_cnt_en; r_load <= w_load; o_tx_done <= w_tx_done; o_tx <= w_tx;
      if (i_tick) r_index_cnt_en <= w_index_cnt_en;
    end
  end
  always @(posedge i_clk) begin
    if (i_rst) r_tx_buffer <= 'h0;
    else begin
      if (r_load) r_tx_buffer <= i_tx_data;
      else if (i_tick && r_cnt == 'b0) begin
        if (LSB == 1'b0) r_tx_buffer <= r_tx_buffer >> 1;
        else r_tx_buffer <= r_tx_buffer << 1;
      end
    end
  end
  always @(posedge i_clk) begin
    if (i_rst) r_cnt <= (OVERSAMPLING_MODE) - 1;
    else if (r_cnt_en) begin if (i_tick) r_cnt <= r_cnt - 1; end
    else r_cnt <= (OVERSAMPLING_MODE) - 1;
  end
  always @(posedge i_clk) begin
    if (i_rst) r_index <= 'b0;
    else if (r_index_cnt_en) begin if (i_tick && r_cnt == 'b0) r_index <= r_index + 1; end
    else r_index <= 'b0;
  end
endmodule

module uart_txbaud_rate_generator_tx #(
  parameter IN_CLK_HZ = 10_000_000,
  parameter BAUD_RATE = 115200,
  parameter OVERSAMPLING_MODE = 16
) (
  input      i_clk, input i_rst, output reg o_tick
);
  localparam DIV_CNT_VAL   = (IN_CLK_HZ / (BAUD_RATE * OVERSAMPLING_MODE)) - 1;
  localparam DIV_CNT_WIDTH = $clog2(DIV_CNT_VAL + 1);
  reg [DIV_CNT_WIDTH-1:0] r_count = 0;
  always @(posedge i_clk) begin
    if (i_rst) begin r_count <= 'h0; o_tick <= 'b0; end
    else begin
      r_count <= r_count + 1; o_tick <= 'b0;
      if (r_count == DIV_CNT_VAL) begin r_count <= 'h0; o_tick <= 'b1; end
    end
  end
endmodule


// ---------------------------------------------------------------------------
// top -- 5-channel aggregator + round-robin arbiter (unchanged logic from
// the verified version -- only CLK/baud parameter defaults updated)
// ---------------------------------------------------------------------------
(* top *)
module top #(
    parameter CLK           = 10_000_000,
    parameter BAUD_RATE_0   = 9600,    // Mega pin 11
    parameter BAUD_RATE_1   = 38400,   // Mega pin 14
    parameter BAUD_RATE_2   = 57600,   // Mega pin 13
    parameter BAUD_RATE_3   = 19200,   // Mega pin 18
    parameter BAUD_RATE_4   = 9600,    // Mega pin 16
    parameter OUT_BAUD_RATE = 9600     // to ESP32 -- drift-safe rate
) (
    (* iopad_external_pin, clkbuf_inhibit *) input  clk,
    (* iopad_external_pin *)                 output clk_en,
    (* iopad_external_pin *) input  rx_ch0,  // FPGA_IO0  <- Mega pin 11
    (* iopad_external_pin *) input  rx_ch1,  // FPGA_IO17 <- Mega pin 14
    (* iopad_external_pin *) input  rx_ch2,  // FPGA_IO18 <- Mega pin 13
    (* iopad_external_pin *) input  rx_ch3,  // FPGA_IO9  <- Mega pin 18
    (* iopad_external_pin *) input  rx_ch4,  // FPGA_IO10 <- Mega pin 16
    (* iopad_external_pin *) output tx_out,
    (* iopad_external_pin *) output tx_en
);
  assign clk_en = 1'b1;
  assign tx_en  = 1'b1;

  reg [7:0]  r_por_cnt = 8'd0;
  reg        rst       = 1'b1;
  always @(posedge clk) begin
    if (r_por_cnt < 8'hFF) begin
      r_por_cnt <= r_por_cnt + 1'b1;
      rst       <= 1'b1;
    end else begin
      rst <= 1'b0;
    end
  end

  wire rx_ch0_sync, rx_ch1_sync, rx_ch2_sync, rx_ch3_sync, rx_ch4_sync;
  sync2ff u_sync0 (.i_clk(clk), .i_async(rx_ch0), .o_sync(rx_ch0_sync));
  sync2ff u_sync1 (.i_clk(clk), .i_async(rx_ch1), .o_sync(rx_ch1_sync));
  sync2ff u_sync2 (.i_clk(clk), .i_async(rx_ch2), .o_sync(rx_ch2_sync));
  sync2ff u_sync3 (.i_clk(clk), .i_async(rx_ch3), .o_sync(rx_ch3_sync));
  sync2ff u_sync4 (.i_clk(clk), .i_async(rx_ch4), .o_sync(rx_ch4_sync));

  wire [7:0] rx_data0, rx_data1, rx_data2, rx_data3, rx_data4;
  wire       rx_dv0, rx_dv1, rx_dv2, rx_dv3, rx_dv4;
  uart_rx #(.CLK(CLK), .BAUD_RATE(BAUD_RATE_0)) u_rx0
    (.i_Clock(clk), .i_RX_Serial(rx_ch0_sync), .o_RX_DV(rx_dv0), .o_RX_Byte(rx_data0));
  uart_rx #(.CLK(CLK), .BAUD_RATE(BAUD_RATE_1)) u_rx1
    (.i_Clock(clk), .i_RX_Serial(rx_ch1_sync), .o_RX_DV(rx_dv1), .o_RX_Byte(rx_data1));
  uart_rx #(.CLK(CLK), .BAUD_RATE(BAUD_RATE_2)) u_rx2
    (.i_Clock(clk), .i_RX_Serial(rx_ch2_sync), .o_RX_DV(rx_dv2), .o_RX_Byte(rx_data2));
  uart_rx #(.CLK(CLK), .BAUD_RATE(BAUD_RATE_3)) u_rx3
    (.i_Clock(clk), .i_RX_Serial(rx_ch3_sync), .o_RX_DV(rx_dv3), .o_RX_Byte(rx_data3));
  uart_rx #(.CLK(CLK), .BAUD_RATE(BAUD_RATE_4)) u_rx4
    (.i_Clock(clk), .i_RX_Serial(rx_ch4_sync), .o_RX_DV(rx_dv4), .o_RX_Byte(rx_data4));

  wire [7:0] fifo_rd_data [0:4];
  wire       fifo_empty   [0:4];
  wire       fifo_full    [0:4];
  reg        fifo_rd_en   [0:4];

  sync_fifo #(.DATA_WIDTH(8), .DEPTH(8)) u_fifo0
    (.i_clk(clk), .i_rst(rst), .i_wr_en(rx_dv0), .i_wr_data(rx_data0),
     .i_rd_en(fifo_rd_en[0]), .o_rd_data(fifo_rd_data[0]), .o_full(fifo_full[0]), .o_empty(fifo_empty[0]));
  sync_fifo #(.DATA_WIDTH(8), .DEPTH(8)) u_fifo1
    (.i_clk(clk), .i_rst(rst), .i_wr_en(rx_dv1), .i_wr_data(rx_data1),
     .i_rd_en(fifo_rd_en[1]), .o_rd_data(fifo_rd_data[1]), .o_full(fifo_full[1]), .o_empty(fifo_empty[1]));
  sync_fifo #(.DATA_WIDTH(8), .DEPTH(8)) u_fifo2
    (.i_clk(clk), .i_rst(rst), .i_wr_en(rx_dv2), .i_wr_data(rx_data2),
     .i_rd_en(fifo_rd_en[2]), .o_rd_data(fifo_rd_data[2]), .o_full(fifo_full[2]), .o_empty(fifo_empty[2]));
  sync_fifo #(.DATA_WIDTH(8), .DEPTH(8)) u_fifo3
    (.i_clk(clk), .i_rst(rst), .i_wr_en(rx_dv3), .i_wr_data(rx_data3),
     .i_rd_en(fifo_rd_en[3]), .o_rd_data(fifo_rd_data[3]), .o_full(fifo_full[3]), .o_empty(fifo_empty[3]));
  sync_fifo #(.DATA_WIDTH(8), .DEPTH(8)) u_fifo4
    (.i_clk(clk), .i_rst(rst), .i_wr_en(rx_dv4), .i_wr_data(rx_data4),
     .i_rd_en(fifo_rd_en[4]), .o_rd_data(fifo_rd_data[4]), .o_full(fifo_full[4]), .o_empty(fifo_empty[4]));

  reg  [7:0] tx_data;
  reg        tx_start;
  wire       tx_done;
  uart_tx #(.IN_CLK_HZ(CLK), .DATA_FRAME(8), .BAUD_RATE(OUT_BAUD_RATE),
            .OVERSAMPLING_MODE(16), .STOP_BIT(1), .LSB(1'b0)) u_tx (
    .i_clk(clk), .i_rst(rst), .o_tx(tx_out),
    .i_tx_data(tx_data), .i_tx_start(tx_start), .o_tx_done(tx_done)
  );

  localparam A_IDLE       = 3'd0;
  localparam A_POP        = 3'd1;
  localparam A_SEND_ID    = 3'd2;
  localparam A_WAIT_ID    = 3'd3;
  localparam A_ID_CLEAR   = 3'd4;
  localparam A_SEND_DATA  = 3'd5;
  localparam A_WAIT_DATA  = 3'd6;
  localparam A_DATA_CLEAR = 3'd7;

  reg [2:0] r_state     = A_IDLE;
  reg [2:0] r_scan_ch   = 3'd0;
  reg [7:0] r_latched_byte;
  reg [2:0] r_latched_ch;
  reg       r_tx_done_prev;
  wire tx_done_rise = tx_done & ~r_tx_done_prev;

  integer i;
  always @(posedge clk) begin
    if (rst) begin
      r_state        <= A_IDLE;
      r_scan_ch      <= 3'd0;
      tx_start       <= 1'b0;
      r_tx_done_prev <= 1'b0;
      for (i = 0; i < 5; i = i + 1) fifo_rd_en[i] <= 1'b0;
    end else begin
      r_tx_done_prev <= tx_done;
      tx_start       <= 1'b0;
      for (i = 0; i < 5; i = i + 1) fifo_rd_en[i] <= 1'b0;

      case (r_state)
        A_IDLE: begin
          if (!fifo_empty[r_scan_ch]) begin
            fifo_rd_en[r_scan_ch] <= 1'b1;
            r_latched_ch           <= r_scan_ch;
            r_state                 <= A_POP;
          end else begin
            r_scan_ch <= (r_scan_ch == 3'd4) ? 3'd0 : r_scan_ch + 1'b1;
          end
        end
        A_POP: begin
          r_latched_byte <= fifo_rd_data[r_latched_ch];
          r_state         <= A_SEND_ID;
        end
        A_SEND_ID: begin
          tx_data  <= {5'b0, r_latched_ch};
          tx_start <= 1'b1;
          r_state   <= A_WAIT_ID;
        end
        A_WAIT_ID: if (tx_done_rise) r_state <= A_ID_CLEAR;
        A_ID_CLEAR: if (!tx_done) r_state <= A_SEND_DATA;
        A_SEND_DATA: begin
          tx_data  <= r_latched_byte;
          tx_start <= 1'b1;
          r_state   <= A_WAIT_DATA;
        end
        A_WAIT_DATA: if (tx_done_rise) r_state <= A_DATA_CLEAR;
        A_DATA_CLEAR: begin
          if (!tx_done) begin
            r_scan_ch <= (r_latched_ch == 3'd4) ? 3'd0 : r_latched_ch + 1'b1;
            r_state    <= A_IDLE;
          end
        end
        default: r_state <= A_IDLE;
      endcase
    end
  end
endmodule
