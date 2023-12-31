module bus;

import std.string : format;
import exception;
public import dram;
public import plic;
public import clint;
public import uart;
public import virtio;

struct Bus
{
    Dram dram;
    Plic plic;
    Clint clint;
    Uart uart;
    VirtioBlock virtioBlock;

    this(ubyte[] code, ubyte[] diskImage)
    {
        dram = Dram(code);
        uart.create();
        virtioBlock = VirtioBlock(diskImage);
    }

    Ret load(ulong addr, ulong size)
    {
        if (CLINT_BASE <= addr && addr <= CLINT_END)
            return clint.load(addr, size); 
        else if (PLIC_BASE <= addr && addr <= PLIC_END)
            return plic.load(addr, size);
        else if (UART_BASE <= addr && addr <= UART_END)
            return uart.load(addr, size);
        else if (VIRTIO_BASE <= addr && addr <= VIRTIO_END)
            return virtioBlock.load(addr, size);
        else if (DRAM_BASE <= addr && addr <= DRAM_END)
            return dram.load(addr, size);
        else
            return Ret(CpuException(ExceptionCode.LoadAccessFault, addr));
    }

    Ret store(ulong addr, ulong size, ulong value)
    {
        if (CLINT_BASE <= addr && addr <= CLINT_END)
            return clint.store(addr, size, value); 
        else if (PLIC_BASE <= addr && addr <= PLIC_END)
            return plic.store(addr, size, value);
        else if (UART_BASE <= addr && addr <= UART_END)
            return uart.store(addr, size, value);
        else if (VIRTIO_BASE <= addr && addr <= VIRTIO_END)
            return virtioBlock.store(addr, size, value);
        else if (DRAM_BASE <= addr && addr <= DRAM_END)
            return dram.store(addr, size, value);
        else
            return Ret(CpuException(ExceptionCode.StoreAMOAccessFault, addr));
    }
}
