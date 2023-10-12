module bus;

import std.string : format;
import exception;
public import dram;

struct Bus
{
    Dram dram;

    this(ubyte[] code)
    {
        dram = Dram(code);
    }

    Ret load(ulong addr, ulong size)
    {
        if (DRAM_BASE <= addr)
        {
            return dram.load(addr, size);
        }
        return Ret(CpuException(ExceptionCode.LoadAccessFault, addr));
    }

    Ret store(ulong addr, ulong size, ulong value)
    {
        if (DRAM_BASE <= addr)
        {
            dram.store(addr, size, value);
            return Ret(0);
        }
        return Ret(CpuException(ExceptionCode.StoreAMOAccessFault, addr));
    }
}
