////////////////////////////////////////////////////////////////////////////////
// File       : PLIC.sv
// Author(s)  : Sayyid Amirreza Sayyid Torabi <sayyidtorabi@gmail.com>
// Created    : 2026-08-15
// Description: RISC-V PLIC Top Level (Gateways, Registers, Arbiter)
//
// Revisions:
//   2026-08-15 - Initial release (Sayyid Amirreza Sayyid Torabi)
////////////////////////////////////////////////////////////////////////////////
module PLIC #(
	parameter int	NUM_SOURCES = 16,
	parameter int 	NUM_CONTEXTS = 2,
	parameter int 	PRIORITY_WIDTH = 3,
    parameter bit 	[NUM_SOURCES-1:0] EDGE_MASK = '0
)(
	input  wire						clk,
	input  wire						rst,

	// Core Side
	output logic [NUM_CONTEXTS-1:0]	irq_o,

	// Source Side
	input  wire   [NUM_SOURCES-1:0]	irq_i,
	
	// Bus Side
	input  wire						readRequest,
    input  wire         			writeRequest,
    input  wire  [31:0]				address,
    input  wire  [31:0]				dataIn,
    output logic [31:0]				dataOut
);

	logic 	[NUM_SOURCES-1:0] completeIrq_G_i;
	wire 	[NUM_SOURCES-1:0] irqRequest_G_o;

	PLIC_gatewayArray #(
		.NUM_IRQS(NUM_SOURCES),
    	.EDGE_CFG(EDGE_MASK) 
	) gateWayArray (
		.clk           (clk),	
		.rst           (rst),

		.irqSignals_i  (irq_i),
		.completeIrq_i (completeIrq_G_i),

		.irqRequest_o  (irqRequest_G_o)
	);

	logic [NUM_SOURCES-1:0] pendingIrq;
	logic [10:0]            claimId, claimId_q;
	logic                   claimValid, claimValid_q;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            claimValid_q <= 1'b0;
            claimId_q    <= '0;
        end else begin
            claimValid_q <= claimValid;
            claimId_q    <= claimId;
        end
    end

	always_ff @(posedge clk or posedge rst) begin
		if (rst) begin
			pendingIrq <= '0;
		end else begin
			for (int i = 0; i < NUM_SOURCES; i++) begin
				if (irqRequest_G_o[i]) begin
					pendingIrq[i] <= 1'b1;
				end
			end
			if (claimValid_q) begin
				pendingIrq[claimId_q] <= 1'b0;
			end
		end
	end

	logic [PRIORITY_WIDTH-1:0] 	priorityReg [0:NUM_SOURCES-1];
	logic 						enableReg 	[0:NUM_CONTEXTS-1][0:NUM_SOURCES-1];
	logic [PRIORITY_WIDTH-1:0] 	thresholdReg[0:NUM_CONTEXTS-1];


    localparam PRIORITY_BASE          	= 32'h0000_0004; 
    localparam PRIORITY_END           	= 32'h0000_0FFC;
    localparam PENDING_BASE           	= 32'h0000_1000;
    localparam PENDING_END            	= 32'h0000_107C;
    localparam ENABLE_BASE            	= 32'h0000_2000;
    localparam ENABLE_END             	= 32'h001F_1FFC;
    localparam THRESHOLD_COMPLETE_BASE	= 32'h0020_0000;
    localparam THRESHOLD_COMPLETE_END 	= 32'h002F_FFFC; 

    wire [15:0] priority_offset     	= address[11: 2];
    wire [15:0] pending_word_idx    	= address[ 6: 2];
    wire [15:0] enable_word_idx     	= address[ 6: 2];
    wire [15:0] enable_context_idx  	= address[11: 7]; 
    wire [15:0] offset_context      	= address[19:12];
    wire [15:0] ctx_offset          	= address[11: 0];

	localparam	THRESHOLD				= 12'h000;
	localparam	CLAIM					= 12'h004;

    logic [10:0] idToComplete;
	always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < NUM_SOURCES; i++) 
				priorityReg[i] <= '0;
            for (int t = 0; t < NUM_CONTEXTS; t++) begin
                thresholdReg[t] <= '0;
                for (int i = 0; i < NUM_SOURCES; i++) begin
					enableReg[t][i] <= 1'b0;
				end
            end
            completeIrq_G_i <= '0;
        end else begin
            completeIrq_G_i <= '0;

            if (writeRequest) begin
                if (address >= PRIORITY_BASE && address <= PRIORITY_END) begin
                    if (priority_offset > 0 && priority_offset < NUM_SOURCES)
                        priorityReg[priority_offset] <= dataIn[PRIORITY_WIDTH-1:0];
                end
                else if (address >= ENABLE_BASE && address <= ENABLE_END) begin
                    if (enable_context_idx < NUM_CONTEXTS) begin
                        for (int i = 0; i < 32; i++) begin
                            if ((enable_word_idx * 32) + i < NUM_SOURCES)
                                enableReg[enable_context_idx][(enable_word_idx * 32) + i] <= dataIn[i];
                        end
                    end
                end
                else if (address >= THRESHOLD_COMPLETE_BASE && address <= THRESHOLD_COMPLETE_END) begin
                    if (offset_context < NUM_CONTEXTS) begin
                        if (ctx_offset == THRESHOLD) begin // Threshold
                            thresholdReg[offset_context] <= dataIn[PRIORITY_WIDTH-1:0];
                        end 
                        else if (ctx_offset == CLAIM) begin // Complete
                            idToComplete = dataIn[10:0];
                            if (idToComplete != 0 && idToComplete < NUM_SOURCES) begin
                                completeIrq_G_i[idToComplete] <= 1'b1;
                            end
                        end
                    end
                end
            end
        end
    end


    logic [10:0] highestPriorities_o [0:NUM_CONTEXTS-1];
    PLIC_arbiter #(
        .NUM_SOURCES    (NUM_SOURCES),
        .NUM_CONTEXTS   (NUM_CONTEXTS),
        .PRIORITY_WIDTH (PRIORITY_WIDTH)
    ) arbiter (
        .clk(clk),
        .rst(rst),

        .pending_i(pendingIrq),
        .sourcePriority_i(priorityReg),
        .enable_i(enableReg),
        .contextThreshold_i(thresholdReg),

        .highestPriorities_o(highestPriorities_o),
        .contextIrq_o(irq_o)
    );
	logic [10:0] highestPriority;

    always_comb begin
        dataOut    = 32'h0;
        claimId    = '0;
        claimValid = 1'b0;
		highestPriority = 10'b0;

        if (readRequest) begin
            if (address >= PRIORITY_BASE && address <= PRIORITY_END) begin
                if (priority_offset < NUM_SOURCES)
                    dataOut = {{32-PRIORITY_WIDTH{1'b0}}, priorityReg[priority_offset]};
            end
            else if (address >= PENDING_BASE && address <= PENDING_END) begin
                for (int i = 0; i < 32; i++) begin
                    if ((pending_word_idx * 32) + i < NUM_SOURCES)
                        dataOut[i] = pendingIrq[(pending_word_idx * 32) + i];
                    else
                        dataOut[i] = 1'b0;
                end
            end
            else if (address >= ENABLE_BASE && address <= ENABLE_END) begin
                if (enable_context_idx < NUM_CONTEXTS) begin
                    for (int i = 0; i < 32; i++) begin
                        if ((enable_word_idx * 32) + i < NUM_SOURCES)
                            dataOut[i] = enableReg[enable_context_idx][(enable_word_idx * 32) + i];
                        else
                            dataOut[i] = 1'b0;
                    end
                end
            end
            else if (address >= THRESHOLD_COMPLETE_BASE && address <= THRESHOLD_COMPLETE_END) begin
                if (offset_context < NUM_CONTEXTS) begin
                    if (ctx_offset == THRESHOLD) begin // Threshold
                        dataOut = { {32-PRIORITY_WIDTH{1'b0}}, thresholdReg[offset_context] };
                    end 
                    else if (ctx_offset == CLAIM) begin // Claim
                        highestPriority = highestPriorities_o[offset_context];
                        dataOut    = {21'h0, highestPriority};
                        if (irq_o[offset_context]) begin
                            claimId    = highestPriority;
                            claimValid = 1'b1;
                        end
                    end
                end
            end
        end
    end
endmodule
