module synaptic_core #(
    parameter N = 784,
    parameter M = 8
)(
    
    // Global inputs ------------------------------------------
    input  wire           CLK,

    // Inputs from SPI configuration registers ----------------
    input  wire           SPI_GATE_ACTIVITY_sync,
    input  wire[1:0]      CTRL_SPI_ADDR,
    
    // Inputs from controller ---------------------------------
    input wire [9:0] CTRL_PRE_NEURON_ADDRESS,
    input wire [9:0] CTRL_POST_NEURON_ADDRESS,
    
    input wire  CTRL_NEUR_EVENT,
    input wire  CTRL_TSTEP_EVENT,
    input wire  CTRL_TREF_EVENT,
    // Inputs from neurons ------------------------------------
    input wire [7:0] PRE_NEUR_S_CNT,
    input wire [6:0] POST_NEUR_S_CNT_0,
    input wire [6:0] POST_NEUR_S_CNT_1,
    input wire [6:0] POST_NEUR_S_CNT_2,
    input wire [6:0] POST_NEUR_S_CNT_3,
    // Outputs ------------------------------------------------
    output wire [   31:0] SYNARRAY_RDATA
);

    // Internal regs and wires definitions
    wire [   31:0] SYNARRAY_WDATA;
    wire [   31:0] SYNARRAY_WDATA_int;
    wire [  N-1:0] NEUR_V_UP_int, NEUR_V_DOWN_int;
    wire [  N-2:0] syn_sign_dummy;
    
    genvar i;
    // SDSP update logic
    generate
        for (i=0; i<8; i=i+1) begin
        
            sdsp_update #(
                .WIDTH(3)
            ) sdsp_update_gen (
                // Inputs
                    // General
                .SYN_PRE(CTRL_PRE_EN[i] & (SPI_UPDATE_UNMAPPED_SYN | SYNARRAY_RDATA[(i<<2)+3])),
                .SYN_BIST_REF(CTRL_BIST_REF),
                    // From neuron
                .V_UP(NEUR_V_UP_int[i]),
                .V_DOWN(NEUR_V_DOWN_int[i]),    
                    // From SRAM
                .WSYN_CURR(SYNARRAY_RDATA[(i<<2)+3:(i<<2)]),
                
                // Output
                .WSYN_NEW(SYNARRAY_WDATA_int[(i<<2)+3:(i<<2)])
		    );
        end
    endgenerate
    // Updated or configured weights to be written to the synaptic memory

    // generate
    //     for (i=0; i<4; i=i+1) begin
    //         assign synarray_wdata[(i<<3)+7:(i<<3)] = (i == CTRL_SPI_ADDR[14:13])
    //                                                ? ((CTRL_PROG_DATA[M-1:0] & ~CTRL_PROG_DATA[2*M-1:M]) | (SYNARRAY_RDATA[(i<<3)+7:(i<<3)] & CTRL_PROG_DATA[2*M-1:M]))
    //                                                : SYNARRAY_RDATA[(i<<3)+7:(i<<3)];
    //     end
    // endgenerate

    generate
        for (i=0; i<4; i=i+1) begin
            assign SYNARRAY_WDATA[(i<<3)+7:(i<<3)] = SPI_GATE_ACTIVITY_sync?
                                                   ((i == CTRL_SPI_ADDR)? 
                                                   CTRL_PROG_DATA : SYNARRAY_RDATA[(i<<3)+7:(i<<3)])
                                                   : SYNARRAY_WDATA_int[(i<<3)+7:(i<<3)];
        end
    endgenerate
    
    
    // Synaptic memory wrapper

//    SRAM_8192x32_wrapper synarray_0 (
        
//        // Global inputs
//        .CK         (CLK),
	
//		// Control and data inputs
//		.CS         (CTRL_SYNARRAY_CS),
//		.WE         (CTRL_SYNARRAY_WE),
//		.A			(CTRL_SYNARRAY_ADDR),
//		.D			(synarray_wdata),
		
//		// Data output
//		.Q			(SYNARRAY_RDATA)
//    );
    blk_mem_gen_0 SRAM_8192x32_wrapper(
    .clka  (CLK      ),  // input wire clka
    .ena   (CTRL_SYNARRAY_CS       ),  // input 片选使能信号
    .wea   (CTRL_SYNARRAY_WE       ),  // input 写使能信号
    .addra (CTRL_SYNARRAY_ADDR     ), 
    .dina  (SYNARRAY_WDATA  ),
    .douta (SYNARRAY_RDATA  )  
);

endmodule




module SRAM_8192x32_wrapper (

    // Global inputs
    input         CK,                       // Clock (synchronous read/write)

    // Control and data inputs
    input         CS,                       // Chip select
    input         WE,                       // Write enable
    input  [12:0] A,                        // Address bus 
    input  [31:0] D,                        // Data input bus (write)

    // Data output
    output [31:0] Q                         // Data output bus (read)   
);


    /*
     *  Simple behavioral code for simulation, to be replaced by a 8192-word 32-bit SRAM macro 
     *  or Block RAM (BRAM) memory with the same format for FPGA implementations.
     */      
        reg [31:0] SRAM[8191:0];
        reg [31:0] Qr;
        always @(posedge CK) begin
            Qr <= CS ? SRAM[A] : Qr;
            if (CS & WE) SRAM[A] <= D;
        end
        assign Q = Qr;
    
endmodule
