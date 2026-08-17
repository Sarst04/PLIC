////////////////////////////////////////////////////////////////////////////////
// File       : PLIC_irqGatewayArray.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-08-15
// Description: 
//   Parametrizable array of interrupt gateways for a PLIC.
//	 This module instantiates 'NUM_IRQS' instances of the 'irqGateway'
//   module to handle multiple interrupt sources efficiently.
//
// Revisions:
//   2026-08-15 - Initial release (Sayyid Amirreza Sayyid Torabi)
////////////////////////////////////////////////////////////////////////////////
module PLIC_gatewayArray #(
    parameter int 				 	NUM_IRQS = 32,
    parameter bit [NUM_IRQS-1:0]	EDGE_CFG = '0 
)(
    input  wire                   clk,
    input  wire                   rst,
    
    input  wire  [NUM_IRQS-1:0]   irqSignals_i,
    input  wire  [NUM_IRQS-1:0]   completeIrq_i,

    output logic [NUM_IRQS-1:0]   irqRequest_o
);

	genvar i;
	generate
    	for (i = 0; i < NUM_IRQS; i++) begin : genGateways
        	if (i == 0) begin
            	assign irqRequest_o[0] = 1'b0;
        	end else begin
            	PLIC_irqGateway #(
                	.EDGE_SENSITIVE (EDGE_CFG[i])
            	) gateway (
                	.clk           (clk),
                	.rst           (rst),
                	.irqSignal_i   (irqSignals_i[i]),
                	.completeIrq_i (completeIrq_i[i]),
                	.irqRequest_o  (irqRequest_o[i])
            	);
        	end
    	end
	endgenerate
endmodule
