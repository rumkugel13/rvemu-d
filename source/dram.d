module dram;

import std.conv : to;
import std.bitmanip : peek, write, Endian;

// 128 MiB
const auto DRAM_SIZE = 1024 * 1024 * 128;
const auto DRAM_BASE = 0x8000_0000;
const auto DRAM_END = DRAM_SIZE + DRAM_BASE - 1;

struct Dram
{
    ubyte[] dram;

    this(ubyte[] code)
    {
        dram.length = DRAM_SIZE;
        dram[0..code.length] = code[0..$];
    }

    ulong load(ulong addr, ulong size)
    {
        switch (size)
        {
            case 8:  return cast(ulong)dram.peek!(ubyte, Endian.littleEndian)(addr - DRAM_BASE);
            case 16: return cast(ulong)dram.peek!(ushort, Endian.littleEndian)(addr - DRAM_BASE);
            case 32: return cast(ulong)dram.peek!(uint, Endian.littleEndian)(addr - DRAM_BASE);
            case 64: return dram.peek!(ulong, Endian.littleEndian)(addr - DRAM_BASE);
            default: assert(0, "Unkwnon size " ~ size.to!string);
        }
    }

    void store(ulong addr, ulong size, ulong value)
    {
        switch (size)
        {
            case 8:  dram.write!(ubyte, Endian.littleEndian)(cast(ubyte)value, addr - DRAM_BASE); break;
            case 16: dram.write!(ushort, Endian.littleEndian)(cast(ushort)value, addr - DRAM_BASE); break;
            case 32: dram.write!(uint, Endian.littleEndian)(cast(uint)value, addr - DRAM_BASE); break;
            case 64: dram.write!(ulong, Endian.littleEndian)(value, addr - DRAM_BASE); break;
            default: assert(0, "Unkwnon size " ~ size.to!string);
        }
    }
}