module neuron_core #(
    parameter N = 784,
    parameter M = 8
)(
    input wire  AER_EVENT,
    // Global inputs ------------------------------------------
    input  wire CLK,
    input  wire RST_N,
    // Synaptic inputs ----------------------------------------
    input  wire [         31:0] SYNARRAY_RDATA,
    // Controller inputs ----------------------------------------
    input wire [9:0] CTRL_PRE_NEURON_ADDRESS,
    input wire [9:0] CTRL_POST_NEURON_ADDRESS,
    
    input wire  CTRL_NEUR_EVENT,
    input wire  CTRL_TSTEP_EVENT,
    input wire  CTRL_TREF_EVENT,

    input wire  CTRL_PRE_NEUR_CS,
    input wire  CTRL_PRE_NEUR_WE,
    input wire  CTRL_POST_NEUR_CS,
    input wire  CTRL_POST_NEUR_WE,
    // SPI inputs
    input wire  SPI_GATE_ACTIVITY_sync,
    input wire  [9:0] SPI_POST_NEUR_ADDR,
    input wire  [31:0] SPI_POST_NEUR_DATA,
    // Outputs
    output wire [3:0] NEUR_EVENT_OUT,
    output wire [7:0] PRE_NEUR_S_CNT,
    output wire [6:0] POST_NEUR_S_CNT_0,
    output wire [6:0] POST_NEUR_S_CNT_1,
    output wire [6:0] POST_NEUR_S_CNT_2,
    output wire [6:0] POST_NEUR_S_CNT_3
);
    localparam  neuron_thresold= 12'hAAA;
    // Internal regs and wires definitions
    wire [7:0] pre_neuron_sram_out;
    wire [7:0] pre_neuron_sram_in;

    wire [127:0] post_neuron_sram_out;
    wire [127:0] post_neuron_sram_in;
    wire [7:0]  post_neuron_sram_addr;
    wire [1:0]  post_neuron_byte_addr;
    wire [3:0]  IF_neuron_event_out;
    wire [11:0] IF_neuron_next_mem [3:0];
    wire [6:0]  IF_neuron_next_spike_cnt[3:0];
    wire [6:0]  POST_NEUR_S_CNT[3:0];

    // assign NEUR_STATE = (post_neuron_sram_out >> ({5'b0,post_neuron_byte_addr} << 5))[31:0]; //右移post_neuron_byte_address * 32
    assign post_neuron_sram_addr = CTRL_POST_NEURON_ADDRESS[9:2];
    assign post_neuron_byte_addr = CTRL_POST_NEURON_ADDRESS[1:0];
    assign PRE_NEUR_S_CNT = pre_neuron_sram_out;
    assign POST_NEUR_S_CNT_0 = POST_NEUR_S_CNT[0];
    assign POST_NEUR_S_CNT_1 = POST_NEUR_S_CNT[1];
    assign POST_NEUR_S_CNT_2 = POST_NEUR_S_CNT[2];
    assign POST_NEUR_S_CNT_3 = POST_NEUR_S_CNT[3];

    reg neur_event_d;
    always @(posedge CLK or negedge RST_N)           
        begin                                        
            if(!RST_N)                               
                neur_event_d <= 0;                             
            else                                    
                neur_event_d <= CTRL_NEUR_EVENT; 
        end                                          

    pre_neuron pre_neuron_0( 
    .pre_spike_cnt(pre_neuron_sram_out),          // 突触前神经元发放脉冲数量 from SRAM
    .neuron_event(CTRL_NEUR_EVENT),               // synaptic event trigger
    .neuron_event_pulse(!neur_event_d && neur_event),
    .time_ref_event(CTRL_TREF_EVENT),                // time reference event trigger
    .pre_spike_cnt_next(pre_neuron_sram_in)          // 突触前神经元发放脉冲数量 to SRAM
);

    genvar i;
    // 神经元状态更新模块 + SPI初始化
    generate
        for (i=0; i<4; i=i+1) begin
            // 神经元状态信息更新：SPI 配置？（SPI指定地址？掩码后的编入数据：保持）：膜电位更新
            // 突触后神经元发放脉冲更新
            assign post_neuron_sram_in[30+(i*32):24+(i*32)] = SPI_GATE_ACTIVITY_sync ? SPI_POST_NEUR_DATA[30:24] : IF_neuron_next_spike_cnt[i];
            // 突触后神经元阈值更新
            assign post_neuron_sram_in[23+(i*32):12+(i*32)] = SPI_GATE_ACTIVITY_sync ? SPI_POST_NEUR_DATA[23:12] : neuron_thresold;
            // 突触后神经元膜电位更新
            assign post_neuron_sram_in[11+(i*32): 0+(i*32)] = SPI_GATE_ACTIVITY_sync ? SPI_POST_NEUR_DATA[11:0]: IF_neuron_next_mem[i]; 
            // 突触后神经元使能信号更新                 
            assign post_neuron_sram_in[31+(i*32)] = SPI_GATE_ACTIVITY_sync ? SPI_POST_NEUR_DATA[31] : post_neuron_sram_out[31+(i*32)];                            

            if_neuron if_neuron_gen( 
            .post_spike_cnt(post_neuron_sram_out [30+(i*32):24+(i*32)]),          // 突触后神经元发放脉冲数量 from SRAM
            .post_spike_cnt_next(IF_neuron_next_spike_cnt[i]),          // 突触后神经元发放脉冲数量 to SRAM
            .param_thr(post_neuron_sram_out [23+(i*32):12+(i*32)]),               // neuron firing threshold parameter 
            .state_core(post_neuron_sram_out [11+(i*32): 0+(i*32)]),              // core neuron state from SRAM 
            .state_core_next(IF_neuron_next_mem[i]),         // next core neuron state to SRAM
            .syn_weight(SYNARRAY_RDATA [7+(i*8):0+(i*8)]),              // synaptic weight
            .neuron_event(CTRL_NEUR_EVENT),                  // synaptic event trigger
            .time_step_event(CTRL_TSTEP_EVENT),
            .time_ref_event(CTRL_TREF_EVENT),                // time reference event trigger
            .spike_out(IF_neuron_event_out[i])                // neuron spike event output  
            );
        assign NEUR_EVENT_OUT[i] = post_neuron_sram_out[31+(i*32)] ? 1'b0 : ((CTRL_POST_NEUR_CS && CTRL_POST_NEUR_WE) ? IF_neuron_event_out[i] : 1'b0);
        assign POST_NEUR_S_CNT[i] = post_neuron_sram_out [30+(i*32):24+(i*32)];
        end
    endgenerate
    // 突触前神经元SRAM 读优先时序
    SRAM_1024x8_wrapper neurarray_pre (       
        
        // Global inputs
        .CK         (CLK),
    
        // Control and data inputs
        .CS         (CTRL_PRE_NEUR_CS),
        .WE         (CTRL_PRE_NEUR_WE),
        .A          (CTRL_PRE_NEURON_ADDRESS),
        .D          (pre_neuron_sram_in),
        // Data output
        .Q          (pre_neuron_sram_out)
    );

    // 突触后神经元SRAM 读优先时序
    SRAM_256x128_wrapper neurarray_post (       
        
        // Global inputs
        .CK         (CLK),
    
        // Control and data inputs
        .CS         (CTRL_POST_NEUR_CS),
        .WE         (CTRL_POST_NEUR_WE),
        .A          (post_neuron_sram_addr),
        .D          (post_neuron_sram_in),
        // Data output
        .Q          (post_neuron_sram_out)
    );

//    Neuron_SRAM neurarray_0(
//    .clka  (CLK      ),  // input wire clka
//    .ena   (CTRL_NEURMEM_CS       ),  // input 片选使能信号
//    .wea   (CTRL_NEURMEM_WE       ),  // input 写使能信号
//    .addra (CTRL_NEURMEM_ADDR     ), 
//    .dina  (neuron_data  ),
//    .douta (NEUR_STATE  )  
//);

endmodule




module SRAM_256x32_wrapper (

    // Global inputs
    input          CK,                       // Clock (synchronous read/write)

    // Control and data inputs
    input          CS,                       // Chip select
    input          WE,                       // Write enable
    input  [  7:0] A,                        // Address bus 
    input  [ 31:0] D,                        // Data input bus (write)

    // Data output
    output [ 31:0] Q                         // Data output bus (read)   
);
    /*
     *  Simple behavioral code for simulation, to be replaced by a 256-word 32-bit SRAM macro 
     *  or Block RAM (BRAM) memory with the same format for FPGA implementations.
     */      
        reg [31:0] SRAM[255:0];
        reg [31:0] Qr;
        always @(posedge CK) begin
            Qr <= CS ? SRAM[A] : Qr;
            if (CS & WE) SRAM[A] <= D;
        end
        assign Q = Qr;


endmodule
