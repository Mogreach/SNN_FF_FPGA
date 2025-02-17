// Copyright (C) 2019-2022, Université catholique de Louvain (UCLouvain, Belgium), University of Zürich (UZH, Switzerland),
//         Katholieke Universiteit Leuven (KU Leuven, Belgium), and Delft University of Technology (TU Delft, Netherlands).
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License�??); you may not use this file except in compliance
// with the License, or, at your option, the Apache License version 2.0. You may obtain a copy of the License at
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the License is distributed on
// an “AS IS�?? BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
//------------------------------------------------------------------------------
//
// "synaptic_core.v" - File containing the time-multiplexed synaptic array based on 4-bit-weight fixed synapses
//                     (as opposed to ODIN, which had 3-bit-weight synapses with SDSP online learning)
// 
// Project: tinyODIN - A low-cost digital spiking neuromorphic processor adapted from ODIN.
//
// Author:  C. Frenkel, Delft University of Technology
//
// Cite/paper: C. Frenkel, M. Lefebvre, J.-D. Legat and D. Bol, "A 0.086-mm² 12.7-pJ/SOP 64k-Synapse 256-Neuron Online-Learning
//             Digital Spiking Neuromorphic Processor in 28-nm CMOS," IEEE Transactions on Biomedical Circuits and Systems,
//             vol. 13, no. 1, pp. 145-158, 2019.
//
//------------------------------------------------------------------------------


module synaptic_core #(
    parameter N = 256,
    parameter M = 8
)(
    
    // Global inputs ------------------------------------------
    input  wire           CLK,

    // Inputs from SPI configuration registers ----------------
    input  wire           SPI_GATE_ACTIVITY_sync,
    
    // Inputs from controller ---------------------------------
    input  wire [    7:0] CTRL_PRE_EN,
    input  wire           CTRL_SYNARRAY_WE,
    input  wire [   12:0] CTRL_SYNARRAY_ADDR,
    input  wire           CTRL_SYNARRAY_CS,
    input  wire [2*M-1:0] CTRL_PROG_DATA,
    input  wire [2*M-1:0] CTRL_SPI_ADDR,
    // Inputs from neurons ------------------------------------
    input  wire [  N-1:0] NEUR_V_UP,
    input  wire [  N-1:0] NEUR_V_DOWN,
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
    assign NEUR_V_UP_int   = NEUR_V_UP   >> ({3'b0,CTRL_SYNARRAY_ADDR[4:0]} << 3);
    assign NEUR_V_DOWN_int = NEUR_V_DOWN >> ({3'b0,CTRL_SYNARRAY_ADDR[4:0]} << 3);
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
            assign SYNARRAY_WDATA[(i<<3)+7:(i<<3)] = SPI_GATE_ACTIVITY_sync
                                                   ?
                                                       ((i == CTRL_SPI_ADDR[14:13])
                                                       ? ((CTRL_PROG_DATA[M-1:0] & ~CTRL_PROG_DATA[2*M-1:M]) | (SYNARRAY_RDATA[(i<<3)+7:(i<<3)] & CTRL_PROG_DATA[2*M-1:M]))
                                                       : SYNARRAY_RDATA[(i<<3)+7:(i<<3)])
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
    .ena   (CTRL_SYNARRAY_CS       ),  // input ʹ���ź� 
    .wea   (CTRL_SYNARRAY_WE       ),  // input ��д�źţ�0����1д
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
