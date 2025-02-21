module synaptic_core #(
    parameter N = 784,
    parameter M = 8
)(
    
    // Global inputs ------------------------------------------
    input  wire           CLK,

    // Inputs from SPI configuration registers ----------------
    input  wire           SPI_GATE_ACTIVITY_sync,

    // Inputs from controller ---------------------------------
    input wire CTRL_SYNARRAY_CS,
    input wire CTRL_SYNARRAY_WE,
    input wire [9:0] CTRL_PRE_NEURON_ADDRESS,
    input wire [9:0] CTRL_POST_NEURON_ADDRESS,

    input wire CTRL_SYNA_WR_EVENT,
    input wire CTRL_SYNA_RD_EVENT,
    input wire[7:0] CTRL_SYNA_PROG_DATA,
    
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
    output wire [   31:0] synarray_rdata
);

    // Internal regs and wires definitions
    wire [15:0]    synarray_addr;
    wire [1:0]     post_neuron_byte_addr;

    wire [   31:0] synarray_wdata;
    wire [   31:0] synarray_wdata_int;
    wire [  N-1:0] NEUR_V_UP_int, NEUR_V_DOWN_int;
    wire [  N-2:0] syn_sign_dummy;
    wire [6:0]  POST_NEUR_S_CNT[3:0];

    assign synarray_addr[15:6] = CTRL_PRE_NEURON_ADDRESS;
    assign synarray_addr[5:0] = CTRL_POST_NEURON_ADDRESS[7:2];
    assign post_neuron_byte_addr = CTRL_POST_NEURON_ADDRESS[1:0];

    assign POST_NEUR_S_CNT[0] = POST_NEUR_S_CNT_0;
    assign POST_NEUR_S_CNT[1] = POST_NEUR_S_CNT_1;
    assign POST_NEUR_S_CNT[2] = POST_NEUR_S_CNT_2;
    assign POST_NEUR_S_CNT[3] = POST_NEUR_S_CNT_3;

    genvar i;
    // SDSP update logic
    generate
        for (i=0; i<4; i=i+1) begin
        
    ffstdp_update ffstdp_update_0(
        // Inputs
        // General
        .CTRL_TREF_EVENT(CTRL_TREF_EVENT),
        // From neuron
        .IS_POS(),    
        .POST_SPIKE_CNT(POST_NEUR_S_CNT[i]),
        .PRE_SPIKE_CNT(PRE_NEUR_S_CNT), 
        // From SRAM
        .WSYN_CURR(synarray_rdata[(i*8)+7:(i*8)]),
        // Output
        .WSYN_NEW(synarray_wdata_int[(i*8)+7:(i*8)])
    );
        end
    endgenerate
    // Updated or configured weights to be written to the synaptic memory
    generate
        for (i=0; i<4; i=i+1) begin
            assign synarray_wdata[(i*8)+7:(i*8)] = SPI_GATE_ACTIVITY_sync? (i==post_neuron_byte_addr && CTRL_SYNA_WR_EVENT)? CTRL_SYNA_PROG_DATA : synarray_rdata[(i*8)+7:(i*8)]
                                                 : synarray_wdata_int[(i*8)+7:(i*8)];
        end
    endgenerate
    
    
    // Synaptic memory wrapper
    SRAM_65536x32_wrapper SRAM_65536x32_wrapper_0(
    .clka  (CLK      ),  // input wire clka
    .ena   (CTRL_SYNARRAY_CS       ),  // input 片选使能信号
    .wea   (CTRL_SYNARRAY_WE       ),  // input 写使能信号
    .addra (synarray_addr    ), 
    .dina  (synarray_wdata  ),
    .douta (synarray_rdata  )  
);
endmodule




// module SRAM_8192x32_wrapper (

//     // Global inputs
//     input         CK,                       // Clock (synchronous read/write)

//     // Control and data inputs
//     input         CS,                       // Chip select
//     input         WE,                       // Write enable
//     input  [12:0] A,                        // Address bus 
//     input  [31:0] D,                        // Data input bus (write)

//     // Data output
//     output [31:0] Q                         // Data output bus (read)   
// );


//     /*
//      *  Simple behavioral code for simulation, to be replaced by a 8192-word 32-bit SRAM macro 
//      *  or Block RAM (BRAM) memory with the same format for FPGA implementations.
//      */      
//         reg [31:0] SRAM[8191:0];
//         reg [31:0] Qr;
//         always @(posedge CK) begin
//             Qr <= CS ? SRAM[A] : Qr;
//             if (CS & WE) SRAM[A] <= D;
//         end
//         assign Q = Qr;
    
// endmodule
