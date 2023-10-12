module plic;

import exception;

const auto PLIC_BASE = 0xc00_0000;
const auto PLIC_SIZE = 0x400_0000;
const auto PLIC_END = PLIC_BASE + PLIC_SIZE - 1;

const auto PLIC_PENDING = PLIC_BASE + 0x1000;
const auto PLIC_SENABLE = PLIC_BASE + 0x2000;
const auto PLIC_SPRIORITY = PLIC_BASE + 0x20_1000;
const auto PLIC_SCLAIM = PLIC_BASE + 0x20_1004;

// Platform Level Interrupt Controller
struct Plic
{
    ulong pending;
    ulong senable;
    ulong spriority;
    ulong sclaim;

    Ret load(ulong addr, ulong size)
    {
        if (size == 32)
        {
            switch (addr)
            {
                case PLIC_PENDING: return Ret(pending);
                case PLIC_SENABLE: return Ret(senable);
                case PLIC_SPRIORITY: return Ret(spriority);
                case PLIC_SCLAIM: return Ret(sclaim);
                default: return Ret(0);
            }
        }
        else {
            return Ret(CpuException(ExceptionCode.LoadAccessFault, addr));
        }
    }

    Ret store(ulong addr, ulong size, ulong value)
    {
        if (size == 32)
        {
            switch (addr)
            {
                case PLIC_PENDING: return Ret(pending = value);
                case PLIC_SENABLE: return Ret(senable = value);
                case PLIC_SPRIORITY: return Ret(spriority = value);
                case PLIC_SCLAIM: return Ret(sclaim = value);
                default: return Ret(0);
            }
        }
        else {
            return Ret(CpuException(ExceptionCode.StoreAMOAccessFault, addr));
        }
    }
}