////////////////////////////////////////////////////////////////////////////////
// File       : PLIC_arbiter.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-08-15
// Description: PLIC arbiter module
//              Selects the highest priority pending interrupt for each context
//              based on priority levels and threshold values. 
//				Outputs the interrupt ID and generates an interrupt request per context.
// Revisions:
//   2026-08-15 - Initial release (Sayyid Amirreza Sayyid Torabi)
//	 2026-08-17 - unit was at critical path -> changed to pipeline (Sayyid Amirreza Sayyid Torabi)
////////////////////////////////////////////////////////////////////////////////
module PLIC_arbiter #(
	parameter int	NUM_SOURCES 	= 16,
	parameter int 	NUM_CONTEXTS 	= 2,
	parameter int 	PRIORITY_WIDTH 	= 3
)(
    input  wire                         clk,
    input  wire                         rst,

    input  wire  [NUM_SOURCES-1:0]      pending_i,
    input  wire  [PRIORITY_WIDTH-1:0]   sourcePriority_i  [0:NUM_SOURCES-1],
    input  wire                         enable_i          [0:NUM_CONTEXTS-1][0:NUM_SOURCES-1],
    input  wire  [PRIORITY_WIDTH-1:0]   contextThreshold_i[0:NUM_CONTEXTS-1],

    output logic [10:0]                 highestPriorities_o [0:NUM_CONTEXTS-1],
    output logic [NUM_CONTEXTS-1:0]     contextIrq_o
);

	localparam int GROUP_SIZE 	= int'($sqrt(NUM_SOURCES));
	localparam int NUM_GROUPS	= (NUM_SOURCES + GROUP_SIZE - 1) / GROUP_SIZE;

	logic [10:0]               nextStage1Id   [0:NUM_CONTEXTS-1][0:NUM_GROUPS-1];
	logic [PRIORITY_WIDTH-1:0] nextStage1Prio [0:NUM_CONTEXTS-1][0:NUM_GROUPS-1];

	logic [10:0]               localId;
	logic [PRIORITY_WIDTH-1:0] localPrioity;
	int                        srcIdx;

	always_comb begin
		for (int c = 0; c < NUM_CONTEXTS; c++) begin
			for (int g = 0; g < NUM_GROUPS; g++) begin
				nextStage1Id[c][g]   = '0;
				nextStage1Prio[c][g] = '0;
			end
		end
		for (int c = 0; c < NUM_CONTEXTS; c++) begin
			for (int g = 0; g < NUM_GROUPS; g++) begin
				localId      = '0;
				localPrioity = '0;
				for (int s = 0; s < GROUP_SIZE; s++) begin
					srcIdx = g * GROUP_SIZE + s;
					if (srcIdx > 0 && srcIdx < NUM_SOURCES) begin
						if (pending_i[srcIdx] & enable_i[c][srcIdx] & (sourcePriority_i[srcIdx] > contextThreshold_i[c])) begin
							if (sourcePriority_i[srcIdx] > localPrioity) begin
								localId      = srcIdx[10:0];
								localPrioity = sourcePriority_i[srcIdx];
							end
						end
					end
				end
				nextStage1Id[c][g]   = localId;
				nextStage1Prio[c][g] = localPrioity;
			end
		end
	end

	logic [10:0]               stage1Id   [0:NUM_CONTEXTS-1][0:NUM_GROUPS-1];
	logic [PRIORITY_WIDTH-1:0] stage1Prio [0:NUM_CONTEXTS-1][0:NUM_GROUPS-1];

	always_ff @(posedge clk or posedge rst) begin
		if (rst) begin
			for (int c = 0; c < NUM_CONTEXTS; c++) begin
				for (int g = 0; g < NUM_GROUPS; g++) begin
					stage1Id[c][g]   <= '0;
					stage1Prio[c][g] <= '0;
				end
			end
		end else begin
			stage1Id   <= nextStage1Id;
			stage1Prio <= nextStage1Prio;
		end
	end

	logic [10:0]               globalId;
	logic [PRIORITY_WIDTH-1:0] globalPrio;

	always_comb begin
		for (int c = 0; c < NUM_CONTEXTS; c++) begin
			highestPriorities_o[c] = '0;
			contextIrq_o[c]        = 1'b0;
		end

		for (int c = 0; c < NUM_CONTEXTS; c++) begin
			globalId   = '0;
			globalPrio = '0;

			for (int g = 0; g < NUM_GROUPS; g++) begin
				if (stage1Prio[c][g] > globalPrio) begin
					globalId   = stage1Id[c][g];
					globalPrio = stage1Prio[c][g];
				end
			end
			highestPriorities_o[c] = globalId;
			contextIrq_o[c]        = (globalId != 0);
		end
	end

endmodule
