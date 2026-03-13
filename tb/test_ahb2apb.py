import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


class ApbMemoryModel:
    def __init__(self, dut):
        self.dut = dut
        self.mem = {}

    async def run(self):
        while True:
            await RisingEdge(self.dut.Hclk)
            if int(self.dut.Pselx.value) != 0 and int(self.dut.Penable.value) == 1:
                addr = int(self.dut.Paddr.value)
                if int(self.dut.Pwrite.value):
                    self.mem[addr] = int(self.dut.Pwdata.value)
                else:
                    self.dut.Prdata.value = self.mem.get(addr, 0xDEADBEEF)


async def reset_dut(dut):
    dut.Hresetn.value = 0
    dut.Hwrite.value = 0
    dut.Hreadyin.value = 1
    dut.Htrans.value = 0
    dut.Hwdata.value = 0
    dut.Haddr.value = 0
    dut.Prdata.value = 0
    await Timer(20, units="ns")
    dut.Hresetn.value = 1
    await RisingEdge(dut.Hclk)


async def ahb_transfer(dut, *, addr: int, write: bool, data: int = 0):
    while int(dut.Hreadyout.value) == 0:
        await RisingEdge(dut.Hclk)

    dut.Haddr.value = addr
    dut.Hwrite.value = int(write)
    dut.Hwdata.value = data
    dut.Htrans.value = 2  # NONSEQ
    dut.Hreadyin.value = 1

    await RisingEdge(dut.Hclk)
    dut.Htrans.value = 0

    wait_cycles = 0
    while int(dut.Hreadyout.value) == 0:
        await RisingEdge(dut.Hclk)
        wait_cycles += 1

    return int(dut.Hresp.value), int(dut.Hrdata.value), wait_cycles


@cocotb.test()
async def test_basic_write_read(dut):
    cocotb.start_soon(Clock(dut.Hclk, 10, units="ns").start())
    model = ApbMemoryModel(dut)
    cocotb.start_soon(model.run())
    await reset_dut(dut)

    addr = 0x0000_0010
    data = 0x1234ABCD

    resp, _, wait_cycles = await ahb_transfer(dut, addr=addr, write=True, data=data)
    assert resp == 0, "write response must be OKAY"
    assert wait_cycles == 2, "bridge should insert 2 wait cycles for setup/access"

    resp, rdata, _ = await ahb_transfer(dut, addr=addr, write=False)
    assert resp == 0, "read response must be OKAY"
    assert rdata == data, f"readback mismatch got=0x{rdata:08x} exp=0x{data:08x}"


@cocotb.test()
async def test_invalid_address_error_response(dut):
    cocotb.start_soon(Clock(dut.Hclk, 10, units="ns").start())
    model = ApbMemoryModel(dut)
    cocotb.start_soon(model.run())
    await reset_dut(dut)

    resp, _, _ = await ahb_transfer(dut, addr=0xF000_0000, write=True, data=0x55AA55AA)
    assert resp == 1, f"expected ERROR response, got {resp}"
    assert int(dut.Pselx.value) == 0, "no APB slave should be selected on invalid decode"


@cocotb.test()
async def test_back_to_back_mixed_transactions(dut):
    cocotb.start_soon(Clock(dut.Hclk, 10, units="ns").start())
    model = ApbMemoryModel(dut)
    cocotb.start_soon(model.run())
    await reset_dut(dut)

    for i in range(16):
      addr = ((i % 4) << 12) | (i * 4)
      data = random.getrandbits(32)
      resp, _, _ = await ahb_transfer(dut, addr=addr, write=True, data=data)
      assert resp == 0
      resp, rdata, _ = await ahb_transfer(dut, addr=addr, write=False)
      assert resp == 0
      assert rdata == data


@cocotb.test()
async def test_hreadyin_stall_then_accept(dut):
    cocotb.start_soon(Clock(dut.Hclk, 10, units="ns").start())
    model = ApbMemoryModel(dut)
    cocotb.start_soon(model.run())
    await reset_dut(dut)

    dut.Hreadyin.value = 0
    dut.Haddr.value = 0x0000_0020
    dut.Hwrite.value = 1
    dut.Hwdata.value = 0xCAFEBABE
    dut.Htrans.value = 2

    for _ in range(3):
        await RisingEdge(dut.Hclk)
        assert int(dut.Pselx.value) == 0, "transaction must not start while Hreadyin is low"

    dut.Hreadyin.value = 1
    await RisingEdge(dut.Hclk)
    dut.Htrans.value = 0

    while int(dut.Hreadyout.value) == 0:
        await RisingEdge(dut.Hclk)

    resp, rdata, _ = await ahb_transfer(dut, addr=0x0000_0020, write=False)
    assert resp == 0
    assert rdata == 0xCAFEBABE
