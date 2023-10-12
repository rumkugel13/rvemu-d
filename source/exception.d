module exception;

enum ExceptionCode
{
    InstructionAddrMisaligned = 0,
    InstructionAccessFault = 1,
    IllegalInstruction = 2,
    Breakpoint = 3,
    LoadAccessMisaligned = 4,
    LoadAccessFault = 5,
    StoreAMOAddrMisaligned = 6,
    StoreAMOAccessFault = 7,
    EnvironmentCallFromUMode = 8,
    EnvironmentCallFromSMode = 9,
    EnvironmentCallFromMMode = 11,
    InstructionPageFault = 12,
    LoadPageFault = 13,
    StoreAMOPageFault = 15,
}

struct CpuException
{
    ulong value;
    ExceptionCode exception;

    this(ExceptionCode exception, ulong value)
    {
        this.exception = exception;
        this.value = value;
    }

    bool isFatal()
    {
        with (ExceptionCode) switch (exception)
        {
        case InstructionAddrMisaligned:
        case InstructionAccessFault:
        case LoadAccessFault:
        case StoreAMOAddrMisaligned:
        case StoreAMOAccessFault:
        case IllegalInstruction:
            return true;
        default:
            return false;
        }
    }
}

struct Ret
{
    bool ok;
    union
    {
        ulong value;
        CpuException exception;
    }

    this(ulong value)
    {
        this.ok = true;
        this.value = value;
    }

    this(CpuException exception)
    {
        this.ok = false;
        this.exception = exception;
    }
}
