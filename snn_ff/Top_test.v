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
// Last modified Date:     2025/02/26 16:10:53
// Last Version:           V1.0
// Descriptions:           
//----------------------------------------------------------------------------------------
// Created by:             Sephiroth
// Created date:           2025/02/26 16:10:53
// mail      :             1245598043@qq.com
// Version:                V1.0
// TEXT NAME:              Top_test.v
// PATH:                   D:\MyProject\FPGA_prj\SNN_FFSTBP\rtl\snn_ff\Top_test.v
// Descriptions:           
//                         
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module Top_test(
    input                               CLK                        ,
    input                               RST_N                       
);
    parameter                           M                          = 12    ;
    parameter                           N                          = 784   ;
    reg                                 RST                         ;
    reg                                 IS_POS                      ;
    reg                                 IS_TRAIN                    ;
    reg                                 SCK                         ;
    reg                                 MOSI                        ;
    wire                                MISO                        ;
    reg                [ M+1: 0]        AERIN_ADDR                  ;
    reg                                 AERIN_REQ                   ;
    wire                                AERIN_ACK                   ;
    wire               [ M-1: 0]        AEROUT_ADDR                 ;
    wire                                AEROUT_REQ                  ;
    reg                                 AEROUT_ACK                  ;
    wire                                SCHED_FULL                  ;

ODIN_ffstdp#(
    .N                                  (784                       ),
    .M                                  (10                        ) 
)
 u_ODIN_ffstdp(
// Global input     -------------------------------
    .CLK                                (CLK                       ),
    .RST                                (RST                       ),
    .IS_POS                             (IS_POS                    ),// 0: negative, 1: positive
    .IS_TRAIN                           (IS_TRAIN                  ),// 0: inference, 1: training
// SPI slave        -------------------------------
    .SCK                                (SCK                       ),
    .MOSI                               (MOSI                      ),
    .MISO                               (MISO                      ),
// Input 12-bit AER -------------------------------
    .AERIN_ADDR                         (AERIN_ADDR                ),
    .AERIN_REQ                          (AERIN_REQ                 ),
    .AERIN_ACK                          (AERIN_ACK                 ),
// Output 10-bit AER -------------------------------
    .AEROUT_ADDR                        (AEROUT_ADDR               ),
    .AEROUT_REQ                         (AEROUT_REQ                ),
    .AEROUT_ACK                         (AEROUT_ACK                ),
// Debug ------------------------------------------
    .SCHED_FULL                         (SCHED_FULL                ) 
);

                                                                   
endmodule