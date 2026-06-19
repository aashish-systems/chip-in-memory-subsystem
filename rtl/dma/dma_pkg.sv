// DMA Package
// Defines the states for the DMA Controller FSM.

`timescale 1ns/1ps

package dma_pkg;

    typedef enum logic [2:0] {
        DMA_IDLE       = 3'b000,
        DMA_READ_REQ   = 3'b001,
        DMA_READ_DATA  = 3'b010,
        DMA_WRITE_REQ  = 3'b011,
        DMA_WRITE_RESP = 3'b100,
        DMA_DONE       = 3'b101
    } dma_state_t;

endpackage
