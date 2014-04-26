`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:43:00 02/08/2014 
// Design Name: 
// Module Name:    main 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
// Specification //
///////////////////
// 
module main(
		// Input Clock
		input SYSTEM_CLOCK,
		// Gameboy Inputs
		input GB_PIXEL_CLOCK,
		input GB_HSYNC,
		input GB_VSYNC,
		input [1:0] GB_DATA,
		// Colors
		output [7:0] Y,
		output [7:0] Pb,
		output [7:0] Pr,
		// Sync
		output H_SYNC,
		output V_SYNC,
		output C_SYNC,
		output PIXEL_CLOCK,
		output VGA_BLANK,
		// Errors
		output [1:0] LED
   );
   
	assign LED = 3;
	// Horizontal and Vertical scan position
	wire [8:0] H_COUNTER;
	wire [8:0] V_COUNTER;
	
	// Put out video signals
	VideoSync sync_signals(	.CLOCK(SYSTEM_CLOCK),
									// Sync Output
									.H_SYNC(PRE_H_SYNC),
									.V_SYNC(PRE_V_SYNC),
									.C_SYNC(C_SYNC),
									.PIXEL_CLOCK(PIXEL_CLOCK),
									.VGA_BLANK(VGA_BLANK),
									// Relevant to module
									.H_COUNTER(H_COUNTER),
									.V_COUNTER(V_COUNTER) );
	// Color of the current pixel being drawn
	reg [1:0] CURRENT_COLOR;
	wire [7:0] COLOR_OUT;
	assign COLOR_OUT[5:0] = 6'b111111;

	/*convertor_samasan sam(
									.clk(SYSTEM_CLOCK),
									// Constants
									.ce(1),
									.pix_en_in(1),
									.sclr(0),
									// Color input
									.r(COLOR_OUT),
									.g(COLOR_OUT),
									.b(COLOR_OUT),
									// Color output
									.y(Y),
									.cb(Pb),
									.cr(Pr),
									// Sync input
									.h_sync_in(PRE_H_SYNC),
									.v_sync_in(PRE_V_SYNC),
									// Sync output
									.h_sync_out(H_SYNC),
									.v_sync_out(V_SYNC) );*/
	assign H_SYNC = PRE_H_SYNC;
	assign V_SYNC = PRE_V_SYNC;
	assign Y = COLOR_OUT;
	assign Pb = COLOR_OUT;
	assign Pr = COLOR_OUT;

	
	// Produce a slightly delayed gameboy hsync for avoiding race conditions between sync signal and FIFO sync signal entry creation.
	reg DELAYED_GB_HSYNC, DELAYED_GB_VSYNC;
	reg FRESH_GB_HSYNC, FRESH_GB_VSYNC;
	// Contents of next new FIFO entry
	wire [3:0] fifo_input;
	assign fifo_input[1:0] = GB_DATA;
	assign fifo_input[2] = GB_HSYNC;
	assign fifo_input[3] = GB_VSYNC;
	// Composite clock signal for FIFO entry creation
	assign create_fifo_entry = GB_PIXEL_CLOCK || DELAYED_GB_HSYNC || DELAYED_GB_VSYNC;
	assign read_clock = H_COUNTER[1] && H_COUNTER > 80;
	// ....
	reg waiting_for_hsync, waiting_for_vsync;
	assign waiting_for_sync = waiting_for_hsync || waiting_for_vsync;
	
	// Bit mask of FIFO entries |VSYNC|HSYNC|COLOR[2]|
	wire [3:0] fifo_output;
	ram fifo(	.din(fifo_input),
					.dout(fifo_output),
					.rd_en(!waiting_for_sync),
					.rd_clk(read_clock),
					.wr_en(1),
					.wr_clk(create_fifo_entry) );
	// TODO: Refactor placement.
	assign COLOR_OUT[7:6] = fifo_output[1:0];
					
	// Change the waiting_for_sync signal as needed in regulating the FIFO.
	always @(fifo_output[2], H_SYNC) begin
		if(H_SYNC) waiting_for_hsync <= 0;
		else if(fifo_output[2]) waiting_for_hsync <= 1;
	end
	always @(fifo_output[3], V_SYNC) begin
		if(V_SYNC) waiting_for_vsync <= 0;
		else if(fifo_output[3]) waiting_for_vsync <= 1;
	end

	reg PREVIOUS_GB_HSYNC, PREVIOUS_GB_VSYNC;
	// This block assumes that the system clock period is at least twice as fast as the Gameboy synchronization signals.
	always @(posedge SYSTEM_CLOCK) begin
		// Guarentees "freshness" of the delayed gameboy hsync/vsync signals.
		// This forces the delayed sync signals to last for only one system clock cycle.
		if(PREVIOUS_GB_HSYNC && !GB_HSYNC) begin
			// @(negedge GB_HSYNC)
			FRESH_GB_HSYNC <= 1;
			PREVIOUS_GB_HSYNC <= 0;
		end else if(GB_HSYNC) begin
			PREVIOUS_GB_HSYNC <= 1;
		end
		if(PREVIOUS_GB_VSYNC && !GB_VSYNC) begin
			// @(negedge GB_VSYNC)
			FRESH_GB_VSYNC <= 1;
			PREVIOUS_GB_VSYNC <= 0;
		end else if(GB_VSYNC) begin
			PREVIOUS_GB_VSYNC <= 1;
		end
		if(DELAYED_GB_HSYNC) begin
			DELAYED_GB_HSYNC <= 0;
			FRESH_GB_HSYNC <= 0;
		end else if(GB_HSYNC && FRESH_GB_HSYNC) begin
			DELAYED_GB_HSYNC <= 1;
		end
		if(DELAYED_GB_VSYNC) begin
			DELAYED_GB_VSYNC <= 0;
			FRESH_GB_VSYNC <= 0;
		end else if(GB_HSYNC && FRESH_GB_VSYNC) begin
			DELAYED_GB_VSYNC <= 1;
		end
	end
	/*
	reg fifo_write = 0;
	reg [7:0] input_column = 0;
	reg [1:0] COLOR_OUT = 0;
	wire [1:0] EVEN_COLOR_OUT;
	wire [1:0] ODD_COLOR_OUT;


	reg OVERFLOW_EVER = 0;
	reg UNDERFLOW_EVER = 0;

	reg HALF_PIXEL_CLOCK = 0;
	wire READ_CLOCK = HALF_PIXEL_CLOCK && H_COUNTER > 80;
	wire ODD_LINE = V_COUNTER[0];
	wire EVEN_LINE = !V_COUNTER[0];
	//wire ODD_FIFO_READ_CLOCK  = READ_CLOCK && ODD_LINE;
	//wire EVEN_FIFO_READ_CLOCK = READ_CLOCK && EVEN_LINE;
	
	//wire EVEN_FIFO_WRITE_CLOCK = GB_PIXEL_CLOCK && EVEN_LINE;

	
	ram odd_fifo(	.din(GB_DATA),	
						.dout(ODD_COLOR_OUT),
						.rd_en(ODD_LINE),
						.wr_en(!GB_HSYNC),
						.rd_clk(READ_CLOCK),
						.wr_clk(GB_PIXEL_CLOCK),
						// Warnings
						.underflow(UNDERFLOW),
						.overflow(OVERFLOW) );
					
	ram even_fifo(	.din(ODD_COLOR_OUT),	
						.dout(EVEN_COLOR_OUT),
						.rd_en(EVEN_LINE),
						.wr_en(!GB_HSYNC && ODD_LINE),
						.rd_clk(READ_CLOCK),
						.wr_clk(GB_PIXEL_CLOCK) );
						// Warnings
						//.UNDERFLOW(UNDERFLOW),
						//.OVERFLOW(OVERFLOW) );

	always @(posedge PIXEL_CLOCK)
	HALF_PIXEL_CLOCK <= HALF_PIXEL_CLOCK + 1;
	*/
	/*always @(posedge GB_PIXEL_CLOCK) begin	
		if(input_column == 160) begin
			input_column <= 0;
		else
			input_column <= input_column + 1;
	end*/
	/*
	always @(EVEN_COLOR_OUT, ODD_COLOR_OUT) begin
		if(EVEN_LINE) begin
			COLOR_OUT <= EVEN_COLOR_OUT;
		end else if(ODD_LINE)
			COLOR_OUT <= ODD_COLOR_OUT;
	end
	
	always @(posedge UNDERFLOW) UNDERFLOW_EVER <= 1;
	always @(posedge OVERFLOW) OVERFLOW_EVER <= 1;

	assign LED[0] = OVERFLOW_EVER;
	assign LED[1] = UNDERFLOW_EVER;
	*/
endmodule
