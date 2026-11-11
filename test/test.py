# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # After reset: hsync (uo[7]) and vsync (uo[3]) idle high, color black
    await ClockCycles(dut.clk, 1)
    assert dut.uo_out.value == 0x88

    # Over one full line (800 clocks), hsync must pulse low
    saw_hsync_low = False
    for _ in range(800):
        await ClockCycles(dut.clk, 1)
        if (int(dut.uo_out.value) & 0x80) == 0:
            saw_hsync_low = True
    assert saw_hsync_low, "hsync never went low"