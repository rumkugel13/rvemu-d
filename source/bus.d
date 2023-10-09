module bus;

public import dram;

struct Bus
{
    Dram dram;

    this(ubyte[] code)
    {
        dram = Dram(code);
    }

    ulong load(ulong addr, ulong size)
    {
        if (DRAM_BASE <= addr)
        {
            return dram.load(addr, size);
        }
        assert(0, "Not implemented");
    }

    void store(ulong addr, ulong size, ulong value)
    {
        if (DRAM_BASE <= addr)
        {
            dram.store(addr, size, value);
            return;
        }
        assert(0, "Not implemented");
    }
}