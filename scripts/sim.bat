@echo off
setlocal enabledelayedexpansion

:: Initialize OSS CAD Suite environment
call C:\oss-cad-suite\environment.bat

set IVERILOG=iverilog.exe
set VVP=vvp.exe

echo ==============================================
echo Running Memory Subsystem Verification Suite
echo ==============================================

:: Create a temp directory inside the workspace for build artifacts
if not exist temp mkdir temp

set ALL_PASSED=1

:: 1. Address Decoder Simulation
echo.
echo [1/4] Running Address Decoder Simulation...
"%IVERILOG%" -g2012 -o temp\sim_decoder.vvp rtl\decoder\address_decoder.sv tb\tb_address_decoder.sv
if %errorlevel% neq 0 (
    echo [ERROR] Address Decoder compilation failed!
    set ALL_PASSED=0
) else (
    "%VVP%" temp\sim_decoder.vvp
    if %errorlevel% neq 0 (
        echo [FAIL] Address Decoder test bench failed!
        set ALL_PASSED=0
    ) else (
        echo [PASS] Address Decoder test bench passed.
    )
)

:: 2. SRAM Controller Simulation
echo.
echo [2/4] Running SRAM Controller Simulation...
"%IVERILOG%" -g2012 -o temp\sim_sram.vvp rtl\memory\sram_controller.sv tb\tb_sram_controller.sv
if %errorlevel% neq 0 (
    echo [ERROR] SRAM Controller compilation failed!
    set ALL_PASSED=0
) else (
    "%VVP%" temp\sim_sram.vvp
    if %errorlevel% neq 0 (
        echo [FAIL] SRAM Controller test bench failed!
        set ALL_PASSED=0
    ) else (
        echo [PASS] SRAM Controller test bench passed.
    )
)

:: 3. DMA Controller Simulation
echo.
echo [3/4] Running DMA Controller Simulation...
"%IVERILOG%" -g2012 -o temp\sim_dma.vvp rtl\dma\dma_pkg.sv rtl\dma\dma_regs.sv rtl\dma\dma_fsm.sv rtl\dma\dma_controller.sv tb\tb_dma_controller.sv
if %errorlevel% neq 0 (
    echo [ERROR] DMA Controller compilation failed!
    set ALL_PASSED=0
) else (
    "%VVP%" temp\sim_dma.vvp
    if %errorlevel% neq 0 (
        echo [FAIL] DMA Controller test bench failed!
        set ALL_PASSED=0
    ) else (
        echo [PASS] DMA Controller test bench passed.
    )
)

:: 4. Memory Subsystem Integration Simulation
echo.
echo [4/4] Running Memory Subsystem Integration Simulation...
"%IVERILOG%" -g2012 -o temp\sim_subsystem.vvp rtl\dma\dma_pkg.sv rtl\decoder\address_decoder.sv rtl\memory\sram_controller.sv rtl\memory\memory_arbiter.sv rtl\dma\dma_regs.sv rtl\dma\dma_fsm.sv rtl\dma\dma_controller.sv rtl\top\memory_subsystem_top.sv tb\tb_memory_subsystem.sv
if %errorlevel% neq 0 (
    echo [ERROR] Memory Subsystem Integration compilation failed!
    set ALL_PASSED=0
) else (
    "%VVP%" temp\sim_subsystem.vvp
    if %errorlevel% neq 0 (
        echo [FAIL] Memory Subsystem Integration test bench failed!
        set ALL_PASSED=0
    ) else (
        echo [PASS] Memory Subsystem Integration test bench passed.
    )
)

echo.
echo ==============================================
if !ALL_PASSED! equ 1 (
    echo ALL SIMULATIONS PASSED SUCCESSFULLY!
    exit /b 0
) else (
    echo SOME SIMULATIONS FAILED. CHECK LOGS ABOVE.
    exit /b 1
)
==============================================
