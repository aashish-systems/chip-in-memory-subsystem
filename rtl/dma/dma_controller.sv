// DMA Controller Top Wrapper
// Instantiates the Register File (dma_regs) and the FSM (dma_fsm).

`timescale 1ns/1ps

module dma_controller (
    input  logic        clk,
    input  logic        rst_n,

    // Slave Configuration Interface
    input  logic [31:0] reg_addr,
    input  logic [31:0] reg_wdata,
    input  logic        reg_wr_en,
    input  logic        reg_rd_en,
    output logic [31:0] reg_rdata,

    // Master Memory Interface
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    output logic        mem_rd_en,
    output logic        mem_wr_en,
    input  logic [31:0] mem_rdata,
    input  logic        mem_ready,

    // Status & Interrupts
    output logic        dma_active,
    output logic        dma_irq
);

    // Internal signals
    logic [31:0] src_addr;
    logic [31:0] dst_addr;
    logic [31:0] size;
    logic        start;
    logic        fsm_busy;
    logic        fsm_done;
    logic        reg_done;

    // Reg Done Sticky Flag
    // Set when FSM asserts done, cleared when FSM starts a new transfer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_done <= 1'b0;
        end else if (start) begin
            reg_done <= 1'b0;
        end else if (fsm_done) begin
            reg_done <= 1'b1;
        end
    end

    // Register File instantiation
    dma_regs u_regs (
        .clk      (clk),
        .rst_n    (rst_n),
        .addr     (reg_addr),
        .wdata    (reg_wdata),
        .wr_en    (reg_wr_en),
        .rd_en    (reg_rd_en),
        .rdata    (reg_rdata),
        .src_addr (src_addr),
        .dst_addr (dst_addr),
        .size     (size),
        .start    (start),
        .busy     (fsm_busy),
        .done     (reg_done)
    );

    // FSM instantiation
    dma_fsm u_fsm (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .src_addr  (src_addr),
        .dst_addr  (dst_addr),
        .size      (size),
        .busy      (fsm_busy),
        .done      (fsm_done),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_rd_en (mem_rd_en),
        .mem_wr_en (mem_wr_en),
        .mem_rdata (mem_rdata),
        .mem_ready (mem_ready)
    );

    // Output assignments
    assign dma_active = fsm_busy;

    // Pulse interrupt for 1 cycle when transfer is complete
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_irq <= 1'b0;
        end else begin
            dma_irq <= fsm_done;
        end
    end

endmodule
