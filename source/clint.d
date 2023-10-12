module clint;

import exception;

const auto CLINT_BASE = 0x200_0000;
const auto CLINT_SIZE = 0x10000;
const auto CLINT_END = CLINT_BASE + CLINT_SIZE - 1;

const auto CLINT_MTIMECMP = CLINT_BASE + 0x4000;
const auto CLINT_MTIME = CLINT_BASE + 0xbff8;

// Core Local Interruptor
struct Clint
{
    ulong mtimecmp;
    ulong mtime;

    Ret load(ulong addr, ulong size)
    {
        if (size == 64)
        {
            switch (addr)
            {
                case CLINT_MTIMECMP: return Ret(mtimecmp);
                case CLINT_MTIME: return Ret(mtime);
                default: return Ret(0);
            }
        }
        else {
            return Ret(CpuException(ExceptionCode.LoadAccessFault, addr));
        }
    }

    Ret store(ulong addr, ulong size, ulong value)
    {
        if (size == 64)
        {
            switch (addr)
            {
                case CLINT_MTIMECMP: return Ret(mtimecmp = value);
                case CLINT_MTIME: return Ret(mtime = value);
                default: return Ret(0);
            }
        }
        else {
            return Ret(CpuException(ExceptionCode.StoreAMOAccessFault, addr));
        }
    }
}