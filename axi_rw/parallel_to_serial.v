`timescale 1ns / 1ps
//****************************************VSCODE PLUG-IN**********************************//
//----------------------------------------------------------------------------------------
// IDE :                   VSCODE     
// VSCODE plug-in version: Verilog-Hdl-Format-3.5.20250220
// VSCODE plug-in author : Jiang Percy
//----------------------------------------------------------------------------------------
//****************************************Copyright (c)***********************************//
// Copyright(C)            Personal
// All rights reserved     
// File name:              
// Last modified Date:     2025/02/28 23:41:28
// Last Version:           V1.0
// Descriptions:           
//----------------------------------------------------------------------------------------
// Created by:             Sephiroth
// Created date:           2025/02/28 23:41:28
// mail      :             1245598043@qq.com
// Version:                V1.0
// TEXT NAME:              parallel_to_serial.v
// PATH:                   D:\BaiduSyncdisk\SNN_FFSTBP\rtl\axi_rw\parallel_to_serial.v
// Descriptions:           
//                         
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module parallel_to_serial #(
    parameter DATA_WIDTH = 8,
    parameter CNT_WIDTH = 4 // log2(DATA_WIDTH) + 1
)
(
	input clk,
	input rst_n,
	input [DATA_WIDTH-1:0] din_parallel,
	input din_valid,
    input shift_en,
	output reg dout_serial,
	output reg dout_valid,
    output reg finish
);

	reg[DATA_WIDTH-1:0]din_parallel_tmp;
	reg [CNT_WIDTH-1:0]cnt;
	
	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)
			cnt <= 0;
		else if(din_valid && shift_en)
			cnt <= cnt + 1'b1;
		else
			cnt <= 0;		
	end
	
	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			din_parallel_tmp <= 'd0;	
			dout_serial <= 1'b0;
			dout_valid <= 1'b0;
		end
		else if(din_valid && cnt == 0)begin
			din_parallel_tmp <= din_parallel;
		end
		else if((cnt >= 4'd1) && (cnt <= DATA_WIDTH) && shift_en)begin
			dout_serial <= din_parallel_tmp[DATA_WIDTH-1];
			din_parallel_tmp <= din_parallel_tmp << 1;
			dout_valid <= 1'b1;
		end
		else begin
			dout_serial <= 1'b0;
			dout_valid <= 1'b0;
		end
	end
	
endmodule
