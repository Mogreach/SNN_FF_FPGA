`include "if_neuron.v"
`timescale 1ns/1ps

module if_neuron_tb;

    // 输入信号
    wire  [2:0]  pre_spike_cnt;          // 突触前神经元发放脉冲数量
    wire  [2:0]  post_spike_cnt;         // 突触后神经元发放脉冲数量
    reg  [11:0] param_thr;              // 神经元发放阈值
    wire  [11:0] state_core;             // 当前膜电位状态
    reg  [3:0]  syn_weight;             // 突触权重
    reg         syn_event;              // 突触事件触发
    reg         time_ref;               // 时间参考事件触发

    // 输出信号
    wire [2:0]  pre_spike_cnt_next;     // 下一个突触前神经元发放脉冲数量
    wire [2:0]  post_spike_cnt_next;    // 下一个突触后神经元发放脉冲数量
    wire [11:0] state_core_next;        // 下一个膜电位状态
    wire        spike_out;              // 神经元发放脉冲输出

    reg [2:0]  r_pre_spike_cnt_next;     // 下一个突触前神经元发放脉冲数量
    reg [2:0]  r_post_spike_cnt_next;    // 下一个突触后神经元发放脉冲数量
    reg [11:0] r_state_core_next;        // 下一个膜电位状态
    reg        r_spike_out;              // 神经元发放脉冲输出

    // 实例化 if_neuron 模块
    if_neuron uut (
        .pre_spike_cnt(pre_spike_cnt),
        .post_spike_cnt(post_spike_cnt),
        .pre_spike_cnt_next(pre_spike_cnt_next),
        .post_spike_cnt_next(post_spike_cnt_next),
        .param_thr(param_thr),
        .state_core(state_core),
        .state_core_next(state_core_next),
        .syn_weight(syn_weight),
        .syn_event(syn_event),
        .time_ref(time_ref),
        .spike_out(spike_out)
    );

    // 时钟信号（如果需要）
    reg clk;
    always #5 clk = ~clk; // 10ns 周期时钟
    always @(posedge clk)           
    begin                                        
        r_post_spike_cnt_next <= post_spike_cnt_next;
        r_pre_spike_cnt_next <= pre_spike_cnt_next;
        r_state_core_next <= state_core_next;
    end  
    assign post_spike_cnt = r_post_spike_cnt_next;
    assign pre_spike_cnt = r_pre_spike_cnt_next;
    assign state_core = r_state_core_next;    
    // 测试流程
    initial begin
        // 初始化信号
        clk = 0;
        r_pre_spike_cnt_next = 3'b0;
        r_post_spike_cnt_next = 3'b0;
        param_thr = 12'd100; // 设置阈值为 100
        r_state_core_next = 12'd512;   // 初始膜电位为 0
        syn_weight = 4'b0111; // 突触权重为 5
        syn_event = 0;
        time_ref = 0;

        // 开始测试
        #10; // 等待 10ns

        //25个神经元脉冲输入
        syn_event = 1;
        time_ref = 0;
        #5000
        // 推理一次
        syn_event = 1;
        time_ref = 1;
        #5000


        // 结束测试
        $display("All tests completed.");
    end
  
                                  
endmodule