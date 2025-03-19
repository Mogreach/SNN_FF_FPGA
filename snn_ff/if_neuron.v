
module if_neuron ( 
    input  wire  [          6:0] post_spike_cnt,          // 突触后神经元发放脉冲数量 from SRAM
    output  wire [          6:0] post_spike_cnt_next,          // 突触后神经元发放脉冲数量 to SRAM

    input  wire signed [         11:0] param_thr,               // neuron firing threshold parameter 
    
    input  wire signed [         11:0] state_core,              // core neuron state from SRAM 
    output wire signed [         11:0] state_core_next,         // next core neuron state to SRAM
    
    input  wire signed [          7:0] syn_weight,              // synaptic weight
    input  wire                 neuron_event,               // synaptic event trigger
    input  wire                 time_step_event,
    input  wire                 time_ref_event,                // time reference event trigger
    
    output wire                 spike_out                // neuron spike event output  
);
    localparam MEMBRANE_WIDTH = 12;
    localparam max_value = (1 << (MEMBRANE_WIDTH-1)) - 1;
    localparam min_value = -(1 << (MEMBRANE_WIDTH-1));
    //time_step_event：单时间步事件，待处理完一个时间步所有的神经元事件后发起，判断脉冲发放、膜电位复位、脉冲计数+1
    //time_ref_event: 一定时间步后拉高，重置脉冲计数以及更新权重（需要增加一个重置计数的信号）
    //neuron_event：神经元事件，只更新累加膜电位，以及输入神经元的脉冲数
    //core是膜电位数值，符号数，11位为符号位
    reg  [6:0] post_spike_cnt_next_i;
    reg  signed [MEMBRANE_WIDTH-1:0] state_core_next_i;
    wire signed [MEMBRANE_WIDTH-1:0] syn_weight_ext;
    wire signed [MEMBRANE_WIDTH-1:0] state_syn;

    // assign spike_out       = ~state_core_next_i[11] & (state_core_next_i >= param_thr) & time_step_event;
    assign spike_out       = (state_core_next_i >= param_thr) & time_step_event;
    assign state_core_next =  spike_out ? 8'd0 : state_core_next_i;

    assign post_spike_cnt_next = post_spike_cnt_next_i;
    // 权重S2.5对齐膜电位S5.6
    assign syn_weight_ext  = syn_weight[7] ? {4'hF,syn_weight[6:5],syn_weight[4:0],1'b0} : {4'h0,syn_weight[6:5],syn_weight[4:0],1'b0};
    assign state_syn = state_core + syn_weight_ext;
    // if_neur_mem_adder u_if_neur_mem_adder (
    // .A(state_core),  // input wire [11 : 0] A
    // .B(syn_weight_ext),  // input wire [11 : 0] B
    // .S(state_syn)  // output wire [11 : 0] S
    // );
    assign overflow = (state_core[MEMBRANE_WIDTH-1]==syn_weight_ext[MEMBRANE_WIDTH-1]) && (state_syn[MEMBRANE_WIDTH-1]!=state_core[MEMBRANE_WIDTH-1]);

    always @(*) begin 
        if (neuron_event) begin
            state_core_next_i = (overflow) ? 
            (state_syn[MEMBRANE_WIDTH-1])? max_value : min_value
                                                             : state_syn; //防止在一个时间步前，膜电位数值溢出变为负数，导致单个时间步内脉冲发放不了
            post_spike_cnt_next_i = post_spike_cnt;
        end
        else if (time_step_event) begin
            state_core_next_i = state_core;
            post_spike_cnt_next_i = (spike_out)? post_spike_cnt + 1: post_spike_cnt;
        end
        else if (time_ref_event)begin 
            state_core_next_i = 'd0;
            post_spike_cnt_next_i = 'd0;
        end
        else begin 
            state_core_next_i = state_core;
            post_spike_cnt_next_i = post_spike_cnt;
        end
    end
endmodule
