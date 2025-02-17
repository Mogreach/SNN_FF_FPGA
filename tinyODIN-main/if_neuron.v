// Copyright (C) 2019-2022, Université catholique de Louvain (UCLouvain, Belgium), University of Zürich (UZH, Switzerland),
//         Katholieke Universiteit Leuven (KU Leuven, Belgium), and Delft University of Technology (TU Delft, Netherlands).
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file except in compliance
// with the License, or, at your option, the Apache License version 2.0. You may obtain a copy of the License at
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the License is distributed on
// an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
//------------------------------------------------------------------------------
//
// "lif_neuron.v" - File containing the 12-bit leaky integrate-and-fire (LIF) neuron update logic, all SDSP-related states
//                  and parameters from ODIN were removed
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


module if_neuron ( 
    input  wire [          2:0] pre_spike_cnt,           // 突触前神经元发放脉冲数量 from SRAM
    input  wire [          2:0] post_spike_cnt,          // 突触后神经元发放脉冲数量 from SRAM

    output  wire [          2:0] pre_spike_cnt_next,           // 突触前神经元发放脉冲数量 to SRAM
    output  wire [          2:0] post_spike_cnt_next,          // 突触后神经元发放脉冲数量 to SRAM

    input  wire [         11:0] param_thr,               // neuron firing threshold parameter 
    
    input  wire [         11:0] state_core,              // core neuron state from SRAM 
    output wire [         11:0] state_core_next,         // next core neuron state to SRAM
    
    input  wire [          3:0] syn_weight,              // synaptic weight
    input  wire                 syn_event,               // synaptic event trigger
    input  wire                 time_ref,                // time reference event trigger
    
    output wire                 spike_out                // neuron spike event output  
);
    //core是膜电位数值，符号数，11位为符号位
    reg  [11:0] state_core_next_i;
    reg  [2:0] pre_spike_cnt_next_i;
    reg  [2:0] post_spike_cnt_next_i;
    reg  [2:0] event_syn_cnt;
    wire [11:0] syn_weight_ext;
    wire [11:0] state_syn;
    wire        event_syn;
    //time_ref时间步
    // 先输入event_syn后，再event_tref
    //POP_NEUR时才有even_syn事件，即当没有外部AER事件时，才执行累加动作，此时不算执行时间步中
    assign event_syn  =  syn_event  & ~time_ref; 
    //执行时间步，此时应该更新脉冲累加数
    assign event_ref =  syn_event  &  time_ref;

    assign spike_out       = ~state_core_next_i[11] & (state_core_next_i >= param_thr) & event_ref;
    assign state_core_next =  spike_out ? 8'd0 : state_core_next_i;

    assign post_spike_cnt_next = post_spike_cnt_next_i;

    assign syn_weight_ext  = syn_weight[3] ? {8'hFF,syn_weight} : {8'h00,syn_weight};
    assign state_syn = state_core + syn_weight_ext;

    always @(*) begin 
        if (event_ref)begin
            state_core_next_i = state_core;
            post_spike_cnt_next_i = (spike_out)? post_spike_cnt + 3'b1: post_spike_cnt;
        end else if(event_syn) begin
            state_core_next_i =  (state_syn>=12'd2048) ? 12'd2047 : state_syn;
            post_spike_cnt_next_i = post_spike_cnt;

        end else begin 
            state_core_next_i = state_core;
            post_spike_cnt_next_i = post_spike_cnt;
        end
    end
    


endmodule
