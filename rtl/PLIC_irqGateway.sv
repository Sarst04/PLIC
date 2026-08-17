////////////////////////////////////////////////////////////////////////////////
// File       : PLIC_irqGateway.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-08-15
// Description:
//   Converts a raw interrupt (level or edge) into a single cycle PLIC request.
//   	EDGE_SENSITIVE=0 : Level sensitive
//  	EDGE_SENSITIVE=1 : Rising edge detection 
//   
// Revisions:
//   2026-08-15 - Initial release (Sayyid Amirreza Sayyid Torabi)
////////////////////////////////////////////////////////////////////////////////
module PLIC_irqGateway #(
	parameter bit EDGE_SENSITIVE = 0
)(
	input  wire			clk,
	input  wire			rst,

	input  wire			irqSignal_i,
	input  wire			completeIrq_i,

	output logic		irqRequest_o
);

	logic	irqSignalPrev;
	always_ff @(posedge clk or posedge rst) begin
		if (rst) begin
			irqSignalPrev	<= 1'b0;
		end else begin
			irqSignalPrev	<= irqSignal_i;
		end
	end

	logic 	irqSignal;
	assign 	irqSignal	= EDGE_SENSITIVE ? irqSignal_i & !irqSignalPrev : irqSignal_i;

	logic	pending;
	always_ff @(posedge clk or posedge rst) begin
		if (rst) begin
			pending 			<= 1'b0;
			irqRequest_o 		<= 1'b0;
		end else begin
			irqRequest_o 		<= 1'b0;
			if (completeIrq_i) begin 
				pending 		<= 1'b0;
			end else if (irqSignal & !pending) begin
				pending 		<= 1'b1;
				irqRequest_o 	<= 1'b1;
			end 
		end
	end
endmodule
