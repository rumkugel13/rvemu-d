module csr;

enum CsrName : ulong
{
    MHARTID = 0xf14,
    MSTATUS = 0x300,
    MEDELEG = 0x302,
    MIDELEG = 0x303,
    MIE = 0x304,
    MTVEC = 0x305,
    MCOUNTEREN = 0x306,
    MSCRATCH = 0x340,
    MEPC = 0x341,
    MCAUSE = 0x342,
    MTVAL = 0x343,
    MIP = 0x344,
    SSTATUS = 0x100,
    SIE = 0x104,
    STVEC = 0x105,
    SSCRATCH = 0x140,
    SEPC = 0x141,
    SCAUSE = 0x142,
    STVAL = 0x143,
    SIP = 0x144,
    SATP = 0x180,
}

enum CsrMask : ulong
{
    MASK_SIE = 1 << 1, 
    MASK_MIE = 1 << 3,
    MASK_SPIE = 1 << 5, 
    MASK_UBE = 1 << 6, 
    MASK_MPIE = 1 << 7,
    MASK_SPP = 1 << 8, 
    MASK_VS = 0b11 << 9,
    MASK_MPP = 0b11 << 11,
    MASK_FS = 0b11 << 13, 
    MASK_XS = 0b11 << 15, 
    MASK_MPRV = 1 << 17,
    MASK_SUM = 1 << 18, 
    MASK_MXR = 1 << 19, 
    MASK_TVM = 1 << 20,
    MASK_TW = 1 << 21,
    MASK_TSR = 1 << 22,
    MASK_UXL = 0b11L << 32, 
    MASK_SXL = 0b11L << 34,
    MASK_SBE = 1L << 36,
    MASK_MBE = 1L << 37,
    MASK_SD = 1L << 63, 
    MASK_SSTATUS = MASK_SIE | MASK_SPIE | MASK_UBE | MASK_SPP | MASK_FS 
                | MASK_XS  | MASK_SUM  | MASK_MXR | MASK_UXL | MASK_SD,

    MASK_SSIP = 1 << 1,
    MASK_MSIP = 1 << 3,
    MASK_STIP = 1 << 5,
    MASK_MTIP = 1 << 7,
    MASK_SEIP = 1 << 9,
    MASK_MEIP = 1 << 11,
}

struct Csr
{
    ulong[4096] csrs;

    ulong load(ulong addr)
    {
        with(CsrName)
        switch (addr)
        {
            case SIE: return csrs[MIE] & csrs[MIDELEG];
            case SIP: return csrs[MIP] & csrs[MIDELEG];
            case SSTATUS: return csrs[MSTATUS] & CsrMask.MASK_SSTATUS;
            default: return csrs[addr];
        }
    }

    void store(ulong addr, ulong value)
    {
        with(CsrName)
        switch (addr)
        {
            case SIE: csrs[MIE] = (csrs[MIE] & !csrs[MIDELEG]) | (value & csrs[MIDELEG]); break;
            case SIP: csrs[MIP] = (csrs[MIP] & !csrs[MIDELEG]) | (value & csrs[MIDELEG]); break;
            case SSTATUS: csrs[MSTATUS] = (csrs[MSTATUS] & ~CsrMask.MASK_SSTATUS) | (value & CsrMask.MASK_SSTATUS); break;
            default: csrs[addr] = value; break;
        }
    }

    void dumpCsrs()
    {
        import std.stdio : writeln;
        import std.string : format;

        string output = format("%s\n%s", format(
            "mstatus=%#018x mtvec=%#018x mepc=%#018x mcause=%#018x",
            load(CsrName.MSTATUS),
            load(CsrName.MTVEC),
            load(CsrName.MEPC),
            load(CsrName.MCAUSE),
        ),
        format(
            "sstatus=%#018x stvec=%#018x sepc=%#018x scause=%#018x",
            load(CsrName.SSTATUS),
            load(CsrName.STVEC),
            load(CsrName.SEPC),
            load(CsrName.SCAUSE),
        ));

        writeln(output);
    }
}