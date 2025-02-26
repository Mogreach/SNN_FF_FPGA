module ODIN_ffstdp #(
	parameter N = 784,
	parameter M = 10
)(
    // Global input     -------------------------------
    input  wire           CLK,
    input  wire           RST,
    input  wire           IS_POS,   // 0: negative, 1: positive
    input  wire           IS_TRAIN, // 0: inference, 1: training
    
    // SPI slave        -------------------------------
    input  wire           SCK,
    input  wire           MOSI,
    output wire           MISO,

	// Input 12-bit AER -------------------------------
	input  wire [  M+1:0] AERIN_ADDR,
	input  wire           AERIN_REQ,
	output wire 		  AERIN_ACK,

	// Output 10-bit AER -------------------------------
	output wire [  M-1:0] AEROUT_ADDR,
	output wire 	      AEROUT_REQ,
	input  wire 	      AEROUT_ACK,

    // Debug ------------------------------------------
    output wire           SCHED_FULL
);

    //----------------------------------------------------------------------------------
	//	Internal regs and wires
	//----------------------------------------------------------------------------------

    // Reset
    reg                  RST_sync_int, RST_sync;
    wire                 RSTN_sync;

    // AER output
    wire                 AEROUT_CTRL_BUSY;
    wire                 AEROUT_CTRL_FINISH;
    
    // SPI + parameter bank
    wire                 SPI_GATE_ACTIVITY, SPI_GATE_ACTIVITY_sync;
    wire                 SPI_OPEN_LOOP;
    wire                 SPI_AER_SRC_CTRL_nNEUR;
    wire [        M-1:0] SPI_MAX_NEUR;
    
    // Controller
    wire                 CTRL_READBACK_EVENT;
    wire                 CTRL_PROG_EVENT;
    wire [      2*M-1:0] CTRL_SPI_ADDR;
    wire [          1:0] CTRL_OP_CODE;
    wire [      2*M-1:0] CTRL_PROG_DATA;
    wire [          7:0] CTRL_PRE_EN;
    wire                 CTRL_NEURMEM_WE;
    wire [15:0]          CTRL_SYNARRAY_ADDR;   // 控制信号: 突触数组地址
    wire                 CTRL_SYNARRAY_CS;     // 控制信号: 突触数组选择
    wire                 CTRL_SYNARRAY_WE;     // 控制信号: 突触数组写使能
    wire [        M-1:0] CTRL_NEURMEM_ADDR;
    wire                 CTRL_NEURMEM_CS;
    wire                 CTRL_NEUR_TREF;  
    wire [          3:0] CTRL_NEUR_VIRTS;
    wire                 CTRL_SCHED_POP_N;
    wire [        M-1:0] CTRL_SCHED_ADDR;
    wire                 CTRL_SCHED_EVENT_IN;
    wire [          3:0] CTRL_SCHED_VIRTS;
    wire                 CTRL_AEROUT_POP_NEUR;
    wire CTRL_SYNA_WR_EVENT;          // 突触写事件
    wire CTRL_SYNA_RD_EVENT;          // 突触读事件
    wire [7:0] CTRL_SYNA_PROG_DATA;   // 突触编程数据
    wire CTRL_NEUR_EVENT;             // 神经元事件
    wire CTRL_TSTEP_EVENT;            // 时间步事件
    wire CTRL_TREF_EVENT;            // 时间参考事件
    wire CTRL_WR_NEUR_EVENT;         // 写神经元事件
    wire CTRL_RD_NEUR_EVENT;         // 读神经元事件
    wire [31:0] CTRL_POST_NEUR_PROG_DATA; // 神经元编程数据
    wire [9:0] CTRL_PRE_NEURON_ADDRESS;  // 预神经元地址
    wire [9:0] CTRL_POST_NEURON_ADDRESS; // 后神经元地址
    wire   CTRL_PRE_NEUR_CS;
    wire   CTRL_PRE_NEUR_WE;
    wire   CTRL_POST_NEUR_CS;
    wire   CTRL_POST_NEUR_WE;
    wire   CTRL_PRE_CNT_EN;             // 预神经元计数使能信号
    wire   CTRL_AEROUT_POP_TSTEP;
    wire   CTRL_AEROUT_PUSH_NEUR;
    // Synaptic core
    wire [         31:0] SYNARRAY_RDATA;
    wire [31:0] synarray_rdata;         // 突触数组读数据
    
    // Scheduler
    wire                 SCHED_EMPTY;
    wire [         11:0] SCHED_DATA_OUT;
    
    // Neuron core
    wire [         31:0] NEUR_STATE;
    wire [        N-1:0] NEUR_V_UP;
    wire [        N-1:0] NEUR_V_DOWN;
    wire [3:0]  NEUR_EVENT_OUT;         // 神经元输出事件
    wire [7:0]  PRE_NEUR_S_CNT;         // 预神经元脉冲计数
    wire [6:0]  POST_NEUR_S_CNT_0;      // 后神经元0脉冲计数
    wire [6:0]  POST_NEUR_S_CNT_1;      // 后神经元1脉冲计数
    wire [6:0]  POST_NEUR_S_CNT_2;      // 后神经元2脉冲计数
    wire [6:0]  POST_NEUR_S_CNT_3;      // 后神经元3脉冲计数

    //----------------------------------------------------------------------------------
	//	Reset (with double sync barrier)
	//----------------------------------------------------------------------------------
    
    always @(posedge CLK) begin
        RST_sync_int <= RST;
		RST_sync     <= RST_sync_int;
	end
    
    assign RSTN_sync = ~RST_sync;


    //----------------------------------------------------------------------------------
	//	AER OUT
	//----------------------------------------------------------------------------------
    aer_out #(
        .N(256),
        .M(10)
    ) aer_out_inst (
        .CLK(CLK),
        .RST(RST_sync),
        .SPI_GATE_ACTIVITY_sync(SPI_GATE_ACTIVITY_sync),
        .SPI_AER_SRC_CTRL_nNEUR(SPI_AER_SRC_CTRL_nNEUR),
        .NEUR_EVENT_OUT(NEUR_EVENT_OUT),
        .SCHED_DATA_OUT(SCHED_DATA_OUT),
        .CTRL_AEROUT_PUSH_NEUR(CTRL_AEROUT_PUSH_NEUR),
        .CTRL_AEROUT_POP_NEUR(CTRL_AEROUT_POP_NEUR),
        .CTRL_AEROUT_POP_TSTEP(CTRL_AEROUT_POP_TSTEP),
        .CTRL_POST_NEURON_ADDRESS(CTRL_POST_NEURON_ADDRESS),
        .AEROUT_CTRL_FINISH(AEROUT_CTRL_FINISH),
        .AEROUT_ADDR(AEROUT_ADDR),
        .AEROUT_REQ(AEROUT_REQ),
        .AEROUT_ACK(AEROUT_ACK)
    );
    
    //----------------------------------------------------------------------------------
	//	SPI + parameter bank
	//----------------------------------------------------------------------------------
    spi_slave #(
        .N(256),
        .M(8)
    ) spi_slave_inst (
        .RST_async(RST),
        .SCK(SCK),
        .MISO(MISO),
        .MOSI(MOSI),
        .CTRL_READBACK_EVENT(CTRL_READBACK_EVENT),
        .CTRL_PROG_EVENT(CTRL_PROG_EVENT),
        .CTRL_SPI_ADDR(CTRL_SPI_ADDR),
        .CTRL_OP_CODE(CTRL_OP_CODE),
        .CTRL_PROG_DATA(CTRL_PROG_DATA),
        .SYNARRAY_RDATA(SYNARRAY_RDATA),
        .NEUR_STATE(NEUR_STATE),
        .SPI_GATE_ACTIVITY(SPI_GATE_ACTIVITY),
        .SPI_OPEN_LOOP(SPI_OPEN_LOOP),
        .SPI_AER_SRC_CTRL_nNEUR(SPI_AER_SRC_CTRL_nNEUR),
        .SPI_MAX_NEUR(SPI_MAX_NEUR)
    );        
    
    //----------------------------------------------------------------------------------
	//	Controller
	//----------------------------------------------------------------------------------
    controller #(
        .N(256),
        .M(10)
    ) controller_inst (
        // Global Inputs ------------------------------------------
        .CLK(CLK),                                        // 时钟信号
        .RST(RST_sync),                                   // 复位信号

        // Inputs from AER ----------------------------------------
        .AERIN_ADDR(AERIN_ADDR),                         // AER 输入地址
        .AERIN_REQ(AERIN_REQ),                           // AER 输入请求信号
        .AERIN_ACK(AERIN_ACK),                           // AER 输入应答信号

        // Control Interface for Readback -------------------------
        .CTRL_READBACK_EVENT(CTRL_READBACK_EVENT),       // 读取回传事件
        .CTRL_PROG_EVENT(CTRL_PROG_EVENT),               // 编程事件
        .CTRL_SPI_ADDR(CTRL_SPI_ADDR),                   // SPI 地址
        .CTRL_OP_CODE(CTRL_OP_CODE),                     // 操作码

        // Inputs from SPI Configuration Registers ----------------
        .SPI_GATE_ACTIVITY(SPI_GATE_ACTIVITY),           // SPI 激活控制信号
        .SPI_GATE_ACTIVITY_sync(SPI_GATE_ACTIVITY_sync), // SPI 激活同步信号
        .SPI_MAX_NEUR(SPI_MAX_NEUR),                     // 最大神经元数目

        // Inputs from Scheduler ----------------------------------
        .SCHED_EMPTY(SCHED_EMPTY),                       // 调度器是否为空
        .SCHED_FULL(SCHED_FULL),                         // 调度器是否满
        .SCHED_DATA_OUT(SCHED_DATA_OUT),                 // 调度器输出数据

        // Inputs from AER Output ---------------------------------
        .AEROUT_CTRL_BUSY(AEROUT_CTRL_BUSY),             // AER 输出控制是否忙
        .AEROUT_CTRL_FINISH(AEROUT_CTRL_FINISH),         // AER 输出控制是否完成

        // Outputs to Synaptic Core -------------------------------
        .CTRL_SYNARRAY_ADDR(CTRL_SYNARRAY_ADDR),         // 突触数组地址
        .CTRL_SYNARRAY_CS(CTRL_SYNARRAY_CS),             // 突触数组选择信号
        .CTRL_SYNARRAY_WE(CTRL_SYNARRAY_WE),             // 突触数组写使能信号

        .CTRL_NEURMEM_CS(CTRL_NEURMEM_CS),               // 神经元内存选择信号 (由 CTRL_POST/PRE 取代)
        .CTRL_NEURMEM_WE(CTRL_NEURMEM_WE),               // 神经元内存写使能信号

        .CTRL_SYNA_WR_EVENT(CTRL_SYNA_WR_EVENT),         // 突触写事件
        .CTRL_SYNA_RD_EVENT(CTRL_SYNA_RD_EVENT),         // 突触读事件
        .CTRL_SYNA_PROG_DATA(CTRL_SYNA_PROG_DATA),       // 突触编程数据

        // Outputs to Neurons -------------------------------------
        .CTRL_WR_NEUR_EVENT(CTRL_WR_NEUR_EVENT),         // 写神经元事件
        .CTRL_RD_NEUR_EVENT(CTRL_RD_NEUR_EVENT),         // 读神经元事件
        .CTRL_POST_NEUR_PROG_DATA(CTRL_POST_NEUR_PROG_DATA), // 神经元编程数据
        .CTRL_PRE_NEURON_ADDRESS(CTRL_PRE_NEURON_ADDRESS),   // 预神经元地址
        .CTRL_POST_NEURON_ADDRESS(CTRL_POST_NEURON_ADDRESS), // 后神经元地址
        .CTRL_PRE_NEUR_CS(CTRL_PRE_NEUR_CS),             // 预神经元选择信号
        .CTRL_PRE_NEUR_WE(CTRL_PRE_NEUR_WE),             // 预神经元写使能信号
        .CTRL_POST_NEUR_CS(CTRL_POST_NEUR_CS),           // 后神经元选择信号
        .CTRL_POST_NEUR_WE(CTRL_POST_NEUR_WE),           // 后神经元写使能信号
        .CTRL_PRE_CNT_EN(CTRL_PRE_CNT_EN),               // 预计数使能信号

        // Training and Inference Events --------------------------
        .CTRL_NEUR_EVENT(CTRL_NEUR_EVENT),               // 神经元事件
        .CTRL_TSTEP_EVENT(CTRL_TSTEP_EVENT),             // 时间步事件
        .CTRL_TREF_EVENT(CTRL_TREF_EVENT),               // 时间参考事件

        // Outputs to Scheduler -----------------------------------
        .CTRL_SCHED_POP_N(CTRL_SCHED_POP_N),             // 调度器弹出神经元事件
        .CTRL_SCHED_ADDR(CTRL_SCHED_ADDR),               // 调度器地址
        .CTRL_SCHED_EVENT_IN(CTRL_SCHED_EVENT_IN),       // 调度器输入事件
        .CTRL_SCHED_VIRTS(CTRL_SCHED_VIRTS),             // 虚拟事件权重值

        // Outputs to AER Output -----------------------------------
        .CTRL_AEROUT_POP_NEUR(CTRL_AEROUT_POP_NEUR),     // AER 输出弹出神经元事件
        .CTRL_AEROUT_PUSH_NEUR(CTRL_AEROUT_PUSH_NEUR),   // AER 输出推送神经元事件
        .CTRL_AEROUT_POP_TSTEP(CTRL_AEROUT_POP_TSTEP)    // AER 输出弹出时间步事件
    );

    //----------------------------------------------------------------------------------
	//	Scheduler
	//----------------------------------------------------------------------------------
    // 实例化 scheduler 模块
    scheduler #(
        .N(256),
        .M(10)
    ) scheduler_inst (
        .CLK(CLK),
        .RSTN(RSTN_sync),
        .CTRL_SCHED_POP_N(CTRL_SCHED_POP_N),
        .CTRL_SCHED_VIRTS(CTRL_SCHED_VIRTS),
        .CTRL_SCHED_ADDR(CTRL_SCHED_ADDR),
        .CTRL_SCHED_EVENT_IN(CTRL_SCHED_EVENT_IN),
        .SPI_OPEN_LOOP(SPI_OPEN_LOOP),
        .SCHED_EMPTY(SCHED_EMPTY),
        .SCHED_FULL(SCHED_FULL),
        .SCHED_DATA_OUT(SCHED_DATA_OUT)
    );    

    //----------------------------------------------------------------------------------
	//	Synaptic core
	//----------------------------------------------------------------------------------
    synaptic_core #(
        .N(784),
        .M(8)
    ) synaptic_core_inst (
        .IS_POS(IS_POS),
        .CLK(CLK),
        .SPI_GATE_ACTIVITY_sync(SPI_GATE_ACTIVITY_sync),
        .CTRL_SYNARRAY_CS(CTRL_SYNARRAY_CS),
        .CTRL_SYNARRAY_WE(CTRL_SYNARRAY_WE),
        .CTRL_SYNARRAY_ADDR(CTRL_SYNARRAY_ADDR),
        .CTRL_POST_NEURON_ADDRESS(CTRL_POST_NEURON_ADDRESS),
        .CTRL_SYNA_WR_EVENT(CTRL_SYNA_WR_EVENT),
        .CTRL_SYNA_RD_EVENT(CTRL_SYNA_RD_EVENT),
        .CTRL_SYNA_PROG_DATA(CTRL_SYNA_PROG_DATA),
        .CTRL_NEUR_EVENT(CTRL_NEUR_EVENT),
        .CTRL_TSTEP_EVENT(CTRL_TSTEP_EVENT),
        .CTRL_TREF_EVENT(CTRL_TREF_EVENT),
        .PRE_NEUR_S_CNT(PRE_NEUR_S_CNT),
        .POST_NEUR_S_CNT_0(POST_NEUR_S_CNT_0),
        .POST_NEUR_S_CNT_1(POST_NEUR_S_CNT_1),
        .POST_NEUR_S_CNT_2(POST_NEUR_S_CNT_2),
        .POST_NEUR_S_CNT_3(POST_NEUR_S_CNT_3),
        .synarray_rdata(synarray_rdata)
    );

    
    //----------------------------------------------------------------------------------
	//	Neuron core
	//----------------------------------------------------------------------------------
    neuron_core #(
        .N(784),  // 输入神经元数量（784个）
        .M(8)     // 输出神经元数量（8个）
    ) neuron_core_inst (
        // Global inputs ------------------------------------------
        .CLK(CLK),  // 时钟信号
        .RST_N(RST),  // 复位信号

        // Synaptic inputs ----------------------------------------
        .SYNARRAY_RDATA(synarray_rdata),  // 从突触数组读取的输入数据

        // Controller inputs ----------------------------------------
        .CTRL_POST_NEUR_PROG_DATA(CTRL_POST_NEUR_PROG_DATA),  // 神经元编程数据
        .CTRL_PRE_NEURON_ADDRESS(CTRL_PRE_NEURON_ADDRESS),  // 预神经元地址
        .CTRL_POST_NEURON_ADDRESS(CTRL_POST_NEURON_ADDRESS),  // 后神经元地址
        .CTRL_WR_NEUR_EVENT(CTRL_WR_NEUR_EVENT),  // 写神经元事件
        .CTRL_RD_NEUR_EVENT(CTRL_RD_NEUR_EVENT),  // 读神经元事件
        .CTRL_NEUR_EVENT(CTRL_NEUR_EVENT),  // 神经元事件
        .CTRL_TSTEP_EVENT(CTRL_TSTEP_EVENT),  // 时间步事件
        .CTRL_TREF_EVENT(CTRL_TREF_EVENT),  // 时间参考事件
        .CTRL_PRE_NEUR_CS(CTRL_PRE_NEUR_CS),  // 预神经元选择信号
        .CTRL_PRE_NEUR_WE(CTRL_PRE_NEUR_WE),  // 预神经元写使能信号
        .CTRL_POST_NEUR_CS(CTRL_POST_NEUR_CS),  // 后神经元选择信号
        .CTRL_POST_NEUR_WE(CTRL_POST_NEUR_WE),  // 后神经元写使能信号
        .CTRL_PRE_CNT_EN(CTRL_PRE_CNT_EN),  // 预计数器使能信号

        // SPI inputs ----------------------------------------
        .SPI_GATE_ACTIVITY_sync(SPI_GATE_ACTIVITY_sync),  // SPI激活同步信号
        .SPI_POST_NEUR_ADDR(SPI_POST_NEUR_ADDR),  // SPI后神经元地址

        // Outputs ----------------------------------------
        .NEUR_STATE(NEUR_STATE),  // 神经元状态
        .NEUR_EVENT_OUT(NEUR_EVENT_OUT),  // 神经元事件输出
        .PRE_NEUR_S_CNT(PRE_NEUR_S_CNT),  // 预神经元脉冲计数
        .POST_NEUR_S_CNT_0(POST_NEUR_S_CNT_0),  // 后神经元脉冲计数（通道 0）
        .POST_NEUR_S_CNT_1(POST_NEUR_S_CNT_1),  // 后神经元脉冲计数（通道 1）
        .POST_NEUR_S_CNT_2(POST_NEUR_S_CNT_2),  // 后神经元脉冲计数（通道 2）
        .POST_NEUR_S_CNT_3(POST_NEUR_S_CNT_3)   // 后神经元脉冲计数（通道 3）
    );



endmodule

