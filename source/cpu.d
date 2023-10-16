module cpu;

import std.bitmanip : peek, write, Endian;
import std.stdio : writeln;
import std.conv : to;
import std.string : format;
import opcode;
import bus;
import csr;
import exception, interrupt;

const auto RVABI = [
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
    "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
    "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
    "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
];

enum Mode : ulong
{
    User = 0b00,
    Supervisor = 0b01,
    Machine = 0b11,
}

enum AccessType
{
    Instruction,
    Load,
    Store,
}

struct Cpu
{
    // 32 64-bit Registers
    ulong[32] regs;
    // 64-bit Program Counter
    ulong pc;
    // System Bus
    Bus bus;
    // Control Status Registers
    Csr csr;
    // Privilege Mode
    Mode mode;

    bool enablePaging;
    ulong pageTable;

    this(ubyte[] code, ubyte[] diskImage)
    in (code.length <= DRAM_SIZE)
    {
        regs[0] = 0;
        regs[2] = DRAM_END;
        pc = DRAM_BASE;
        this.bus = Bus(code, diskImage);
        mode = Mode.Machine;
    }

    Ret load(ulong addr, ulong size)
    {
        version (unittest)
        {
            return bus.load(addr + DRAM_BASE, size);
        }
        else
        {
            auto ret = translate(addr, AccessType.Load);
            return ret.ok ? this.bus.load(ret.value, size) : ret;
        }
    }

    Ret store(ulong addr, ulong size, ulong value)
    {
        version (unittest)
        {
            return bus.store(addr + DRAM_BASE, size, value);
        }
        else
        {
            auto ret = translate(addr, AccessType.Store);
            return ret.ok ? this.bus.store(ret.value, size, value) : ret;
        }
    }

    Ret translate(ulong addr, AccessType accessType)
    {
        if (!enablePaging)
            return Ret(addr);

        auto levels = 3;
        auto vpn = [
            (addr >> 12) & 0x1ff, // L0
            (addr >> 21) & 0x1ff, // L1
            (addr >> 30) & 0x1ff, // L2
        ];

        auto a = this.pageTable;
        long i = levels - 1;
        ulong pte;

        while (true)
        {
            pte = this.bus.load(a + vpn[i] << 3, 64).value;

            auto v = pte & 1;
            auto r = (pte >> 1) & 1;
            auto w = (pte >> 2) & 1;
            auto x = (pte >> 3) & 1;
            if (v == 0 || (r == 0 && w == 1))
            {
                final switch (accessType)
                {
                case AccessType.Instruction:
                    return Ret(CpuException(ExceptionCode.InstructionPageFault, addr));
                case AccessType.Load:
                    return Ret(CpuException(ExceptionCode.LoadPageFault, addr));
                case AccessType.Store:
                    return Ret(CpuException(ExceptionCode.StoreAMOPageFault, addr));
                }
            }

            if (r == 1 || x == 1)
                break;

            i -= 1;
            auto ppn = (pte >> 10) & 0x0fff_ffff_ffff;
            a = ppn * PAGE_SIZE;

            if (i < 0)
            {
                final switch (accessType)
                {
                case AccessType.Instruction:
                    return Ret(CpuException(ExceptionCode.InstructionPageFault, addr));
                case AccessType.Load:
                    return Ret(CpuException(ExceptionCode.LoadPageFault, addr));
                case AccessType.Store:
                    return Ret(CpuException(ExceptionCode.StoreAMOPageFault, addr));
                }
            }
        }

        auto ppn = [
            (pte >> 10) & 0x1ff,
            (pte >> 19) & 0x1ff,
            (pte >> 28) & 0x03ff_ffff,
        ];

        auto offset = addr & 0xfff;
        switch (i)
        {
        case 0:
            {
                auto _ppn = (pte >> 10) & 0x0fff_ffff_ffff;
                return Ret((_ppn << 12) | offset);
            }
        case 1:
            {
                return Ret((ppn[2] << 30) | (ppn[1] << 21) | (vpn[0] << 12) | offset);
            }
        case 2:
            {
                return Ret((ppn[2] << 30) | (vpn[1] << 21) | (vpn[0] << 12) | offset);
            }
        default:
            {
                final switch (accessType)
                {
                case AccessType.Instruction:
                    return Ret(CpuException(ExceptionCode.InstructionPageFault, addr));
                case AccessType.Load:
                    return Ret(CpuException(ExceptionCode.LoadPageFault, addr));
                case AccessType.Store:
                    return Ret(CpuException(ExceptionCode.StoreAMOPageFault, addr));
                }
            }
        }
    }

    void updatePaging(ulong csrAddr)
    {
        if (csrAddr != CsrName.SATP)
            return;

        auto satp = this.csr.load(CsrName.SATP);
        this.pageTable = (satp & CsrMask.MASK_PPN) * PAGE_SIZE;

        auto mode = satp >> 60;
        this.enablePaging = mode == 8; //Sv39
    }

    Ret fetch()
    {
        auto tret = translate(pc, AccessType.Instruction);
        auto ret = this.bus.load(tret.value, 32);
        if (tret.ok)
            return ret.ok ? ret : Ret(CpuException(ExceptionCode.InstructionAccessFault, tret.value));
        else
            return tret;
    }

    // returns updated program counter
    Ret execute(uint inst)
    {
        regs[0] = 0;
        uint opcode = inst & 0x7f;
        uint rd = ((inst >> 7) & 0x1f);
        uint rs1 = ((inst >> 15) & 0x1f);
        uint rs2 = ((inst >> 20) & 0x1f);
        uint funct3 = ((inst >> 12) & 0x07);
        uint funct7 = ((inst >> 25) & 0x7f);

        with (Opcode) switch (opcode)
        {
        case load:
            {
                auto imm = cast(ulong) cast(long)(cast(int)(inst) >> 20);
                auto addr = regs[rs1] + imm;
                with (Funct3) switch (funct3)
                {
                case lb:
                    {
                        auto val = this.load(addr, 8);
                        if (val.ok)
                            regs[rd] = cast(long) cast(byte) val.value;
                        else
                            return val;
                    }
                    break;
                case lh:
                    {
                        auto val = this.load(addr, 16);
                        if (val.ok)
                            regs[rd] = cast(long) cast(short) val.value;
                        else
                            return val;
                    }
                    break;
                case lw:
                    {
                        auto val = this.load(addr, 32);
                        if (val.ok)
                            regs[rd] = cast(long) cast(int) val.value;
                        else
                            return val;
                    }
                    break;
                case ld:
                    {
                        auto val = this.load(addr, 64);
                        if (val.ok)
                            regs[rd] = cast(long) cast(long) val.value;
                        else
                            return val;
                    }
                    break;
                case lbu:
                    {
                        auto val = this.load(addr, 8);
                        if (val.ok)
                            regs[rd] = val.value;
                        else
                            return val;
                    }
                    break;
                case lhu:
                    {
                        auto val = this.load(addr, 16);
                        if (val.ok)
                            regs[rd] = val.value;
                        else
                            return val;
                    }
                    break;
                case lwu:
                    {
                        auto val = this.load(addr, 32);
                        if (val.ok)
                            regs[rd] = val.value;
                        else
                            return val;
                    }
                    break;
                default:
                    return Ret(CpuException(ExceptionCode.IllegalInstruction, inst));
                }
            }
            break;
        case store:
            {
                auto imm = cast(ulong)(cast(long)(cast(int)(inst & 0xfe00_0000)) >> 20) | (
                    (inst >> 7) & 0x1f);
                auto addr = regs[rs1] + imm;

                with (Funct3) switch (funct3)
                {
                case sb:
                    this.store(addr, 8, regs[rs2]);
                    break;
                case sh:
                    this.store(addr, 16, regs[rs2]);
                    break;
                case sw:
                    this.store(addr, 32, regs[rs2]);
                    break;
                case sd:
                    this.store(addr, 64, regs[rs2]);
                    break;
                default:
                    return Ret(CpuException(ExceptionCode.IllegalInstruction, inst));
                }
            }
            break;

        case opimm:
            {
                auto imm = cast(ulong)(cast(long)(cast(int)(inst & 0xfff0_0000)) >> 20);
                uint shamt = imm & 0x3f; // note: in 64-bit mode the lower 6 bits are used, not 5

                with (Funct3) switch (funct3)
                {
                case addi:
                    regs[rd] = regs[rs1] + imm;
                    break;
                case slti:
                    regs[rd] = cast(long) regs[rs1] < cast(long) imm ? 1 : 0;
                    break;
                case sltiu:
                    regs[rd] = cast(ulong) regs[rs1] < cast(ulong) imm ? 1 : 0;
                    break;
                case xori:
                    regs[rd] = regs[rs1] ^ imm;
                    break;
                case ori:
                    regs[rd] = regs[rs1] | imm;
                    break;
                case andi:
                    regs[rd] = regs[rs1] & imm;
                    break;
                case slli:
                    regs[rd] = regs[rs1] << shamt;
                    break;
                case srli | srai:
                    if (funct7)
                        regs[rd] = cast(long) regs[rs1] >> shamt;
                    else
                        regs[rd] = regs[rs1] >>> shamt;
                    break;
                default:
                    return Ret(CpuException(ExceptionCode.IllegalInstruction, inst));
                }
            }
            break;
        case op:
            {
                uint shamt = regs[rs2] & 0x1f;

                with (Funct3) switch (funct3)
                {
                case add | sub | mul:
                    if (funct7 == Funct7.add)
                        regs[rd] = regs[rs1] + regs[rs2];
                    else if (funct7 == Funct7.sub)
                        regs[rd] = regs[rs1] - regs[rs2];
                    else if (funct7 == Funct7.muldiv)
                        regs[rd] = regs[rs1] * regs[rs2];
                    break;
                case sll:
                    regs[rd] = regs[rs1] << shamt;
                    break;
                case slt:
                    regs[rd] = cast(long) regs[rs1] < cast(long) regs[rs2] ? 1 : 0;
                    break;
                case sltu:
                    regs[rd] = cast(ulong) regs[rs1] < cast(ulong) regs[rs2] ? 1 : 0;
                    break;
                case xor | div:
                    if (funct7 == Funct7.muldiv)
                        regs[rd] = regs[rs2] ? cast(long) regs[rs1] / cast(long) regs[rs2] : -1L;
                    else
                        regs[rd] = regs[rs1] ^ regs[rs2];
                    break;
                case srl | sra | divu:
                    if (funct7 == Funct7.sra)
                        regs[rd] = cast(long) regs[rs1] >> shamt;
                    else if (funct7 == Funct7.srl)
                        regs[rd] = regs[rs1] >>> shamt;
                    else if (funct7 == Funct7.muldiv)
                        regs[rd] = regs[rs2] ? cast(ulong) regs[rs1] / cast(ulong) regs[rs2]
                            : 0xffffffff_ffffffff;
                    break;
                case or | rem:
                    if (funct7 == Funct7.muldiv)
                        regs[rd] = regs[rs2] ? cast(long) regs[rs1] % cast(long) regs[rs2]
                            : regs[rs1];
                    else
                        regs[rd] = regs[rs1] | regs[rs2];
                    break;
                case and | remu:
                    if (funct7 == Funct7.muldiv)
                        regs[rd] = regs[rs2] ? cast(ulong) regs[rs1] % cast(ulong) regs[rs2]
                            : regs[rs1];
                    else
                        regs[rd] = regs[rs1] & regs[rs2];
                    break;
                default:
                    return Ret(CpuException(ExceptionCode.IllegalInstruction, inst));
                }
            }
            break;

        case op32:
            {
                uint shamt = regs[rs2] & 0x1f;

                with (Funct3) switch (funct3)
                {
                case addw | subw | mulw:
                    if (funct7 == Funct7.sub)
                        regs[rd] = cast(long)(cast(int) regs[rs1] - cast(int) regs[rs2]);
                    else if (funct7 == Funct7.add)
                        regs[rd] = cast(long)(cast(int) regs[rs1] + cast(int) regs[rs2]);
                    else if (funct7 == Funct7.muldiv)
                        regs[rd] = cast(long)(cast(int) regs[rs1] * cast(int) regs[rs2]);
                    break;
                case sllw:
                    regs[rd] = cast(long)(cast(int) regs[rs1] << shamt);
                    break;
                case divw:
                    regs[rd] = regs[rs2] ? cast(long)(cast(int) regs[rs1] / cast(int) regs[rs2]) : -1L;
                    break;
                case srlw | sraw | divuw:
                    if (funct7 == Funct7.sra)
                        regs[rd] = cast(long)(cast(int) regs[rs1] >> cast(int) shamt);
                    else if (funct7 == Funct7.srl)
                        regs[rd] = cast(long)(cast(uint) regs[rs1] >>> shamt);
                    else if (funct7 == Funct7.muldiv)
                        regs[rd] = regs[rs2] ? cast(long) cast(int)(
                            cast(uint) regs[rs1] / cast(uint) regs[rs2]) : cast(long) 0xffff_ffff;
                    break;
                case remw:
                    regs[rd] = regs[rs2] ? cast(long)(cast(int) regs[rs1] % cast(int) regs[rs2]) : cast(
                        long) cast(int) regs[rs1];
                    break;
                case remuw:
                    regs[rd] = regs[rs2] ? cast(long) cast(int)(
                        cast(uint) regs[rs1] % cast(uint) regs[rs2]) : cast(long) cast(int) regs[rs1];
                    break;
                default:
                    return Ret(CpuException(ExceptionCode.IllegalInstruction, inst));
                }
            }
            break;

        case opimm32:
            {
                ulong imm = cast(ulong)(cast(long)(cast(int) inst) >> 20);
                uint shamt = (imm & 0x1f);

                with (Funct3) switch (funct3)
                {
                case addiw:
                    regs[rd] = cast(long) cast(int)(regs[rs1] + imm);
                    break;
                case slliw:
                    regs[rd] = cast(long) cast(int)(regs[rs1] << shamt);
                    break;
                case srliw | sraiw:
                    if (funct7)
                        regs[rd] = cast(long) cast(int)(regs[rs1] >> shamt);
                    else
                        regs[rd] = cast(long) cast(int)(regs[rs1] >>> shamt);
                    break;
                default:
                    return Ret(CpuException(ExceptionCode.IllegalInstruction, inst));
                }
            }
            break;

        case lui:
            {
                auto imm = cast(long)(cast(int)(inst & 0xffff_f000));
                regs[rd] = imm;
            }
            break;
        case auipc:
            {
                auto imm = cast(long)(cast(int)(inst & 0xffff_f000));
                regs[rd] = pc + imm;
            }
            break;
        case jal:
            {
                regs[rd] = pc + 4;
                auto imm = cast(long) cast(int)(
                    (cast(int)(inst & 0x8000_0000) >> 11) |
                        (
                            inst & 0xff000) |
                        ((inst >> 9) & 0x800) |
                        ((inst >> 20) & 0x7fe));
                return Ret(pc + imm);
            }
        case jalr:
            {
                auto imm = cast(long)(cast(int)(inst & 0xfff0_0000) >> 20);
                auto newpc = (imm + regs[rs1]) & ~0x1L;
                regs[rd] = pc + 4;
                return Ret(newpc);
            }

        case branch:
            {
                auto imm = cast(long) cast(int)(
                    (cast(int)(
                        inst & 0x8000_0000) >> 19) |
                        ((inst >> 20) & 0x7e0) |
                        ((inst >> 7) & 0x1e) |
                        ((inst & 0x80) << 4));

                with (Funct3) switch (funct3)
                {
                case beq:
                    if (regs[rs1] == regs[rs2])
                        return Ret(pc + imm);
                    break;
                case bne:
                    if (regs[rs1] != regs[rs2])
                        return Ret(pc + imm);
                    break;
                case blt:
                    if (cast(long) regs[rs1] < cast(long) regs[rs2])
                        return Ret(pc + imm);
                    break;
                case bge:
                    if (cast(long) regs[rs1] >= cast(long) regs[rs2])
                        return Ret(pc + imm);
                    break;
                case bltu:
                    if (cast(ulong) regs[rs1] < cast(ulong) regs[rs2])
                        return Ret(pc + imm);
                    break;
                case bgeu:
                    if (cast(ulong) regs[rs1] >= cast(ulong) regs[rs2])
                        return Ret(pc + imm);
                    break;

                default:
                    return Ret(CpuException(ExceptionCode.IllegalInstruction, inst));
                }
                return Ret(pc + 4);
            }

        case fence:
            {
                // Not implemented, no out-of-order execution
            }
            break;

        case system:
            {
                auto csr = (inst >> 20);
                auto uimm = (inst >> 15) & 0x1f;

                with (Funct3) switch (funct3)
                {
                case ecall | ebreak | sfence_vma | sret | mret:
                    {
                        // treat as nop
                        switch (funct7)
                        {
                        case Funct7.ecall:
                            switch (mode)
                            {
                            case Mode.User:
                                return Ret(CpuException(ExceptionCode.EnvironmentCallFromUMode, pc));
                            case Mode.Supervisor:
                                return Ret(CpuException(ExceptionCode.EnvironmentCallFromSMode, pc));
                            case Mode.Machine:
                                return Ret(CpuException(ExceptionCode.EnvironmentCallFromMMode, pc));
                            default:
                                return Ret(CpuException(ExceptionCode.IllegalInstruction, inst));
                            }
                        case Funct7.ebreak:
                            return Ret(CpuException(ExceptionCode.Breakpoint, pc));
                        case Funct7.sfence_vma:
                            {
                                // Not implemented, no out-of-order execution
                            }
                            break;
                        default:
                            return Ret(CpuException(ExceptionCode.IllegalInstruction, inst));
                        case Funct7.sret:
                            with (CsrName) with (CsrMask)
                                if (rs2 == 0x2)
                                {
                                    auto sstatus = this.csr.load(SSTATUS);
                                    this.mode = cast(Mode)((sstatus & MASK_SPP) >> 8);
                                    auto spie = (sstatus & MASK_SPIE) >> 5;
                                    sstatus = (sstatus & ~MASK_SIE) | (spie << 1);
                                    sstatus |= MASK_SPIE;
                                    sstatus &= ~MASK_SPP;
                                    this.csr.store(SSTATUS, sstatus);
                                    auto newpc = this.csr.load(SEPC) & ~0b11;
                                    return Ret(newpc);
                                }
                            return Ret(CpuException(ExceptionCode.IllegalInstruction, inst));
                        case Funct7.mret:
                            with (CsrName) with (CsrMask)
                                if (rs2 == 0x2)
                                {
                                    auto mstatus = this.csr.load(MSTATUS);
                                    this.mode = cast(Mode)((mstatus & MASK_MPP) >> 11);
                                    auto mpie = (mstatus & MASK_MPIE) >> 7;
                                    mstatus = (mstatus & ~MASK_MIE) | (mpie << 3);
                                    mstatus |= MASK_MPIE;
                                    mstatus &= ~MASK_MPP;
                                    mstatus &= ~MASK_MPRV;
                                    this.csr.store(MSTATUS, mstatus);
                                    auto newpc = this.csr.load(MEPC) & ~0b11;
                                    return Ret(newpc);
                                }
                            return Ret(CpuException(ExceptionCode.IllegalInstruction, inst));
                        }
                    }
                    break;

                case csrrw:
                    {
                        auto t = this.csr.load(csr);
                        this.csr.store(csr, regs[rs1]);
                        regs[rd] = t;
                        updatePaging(csr);
                    }
                    break;
                case csrrs:
                    {
                        auto t = this.csr.load(csr);
                        this.csr.store(csr, t | regs[rs1]);
                        regs[rd] = t;
                        updatePaging(csr);
                    }
                    break;
                case csrrc:
                    {
                        auto t = this.csr.load(csr);
                        this.csr.store(csr, t & ~regs[rs1]);
                        regs[rd] = t;
                        updatePaging(csr);
                    }
                    break;
                case csrrwi:
                    {
                        regs[rd] = this.csr.load(csr);
                        this.csr.store(csr, uimm);
                        updatePaging(csr);
                    }
                    break;
                case csrrsi:
                    {
                        auto t = this.csr.load(csr);
                        this.csr.store(csr, t | uimm);
                        regs[rd] = t;
                        updatePaging(csr);
                    }
                    break;
                case csrrci:
                    {
                        auto t = this.csr.load(csr);
                        this.csr.store(csr, t & ~uimm);
                        regs[rd] = t;
                        updatePaging(csr);
                    }
                    break;

                default:
                    return Ret(CpuException(ExceptionCode.IllegalInstruction, inst));
                }
            }
            break;
        case amo:
            {
                // note: not really atomic, but that doesn't matter on single threaded execution
                auto funct5 = (funct7 & 0b1111100) >> 2;
                auto aq = (funct7 & 0b10) >> 1;
                auto rl = (funct7 & 0b1);

                with (Funct5) switch (funct5)
                {
                case amoadd:
                    {
                        if (funct3 == Funct3.amo32)
                        {
                            auto t = this.load(regs[rs1], 32);
                            if (t.ok)
                            {
                                this.store(regs[rs1], 32, t.value + regs[rs2]);
                                regs[rd] = cast(long) cast(int) t.value;
                            }
                            else
                                return t;
                        }
                        else if (funct3 == Funct3.amo64)
                        {
                            auto t = this.load(regs[rs1], 64);
                            if (t.ok)
                            {
                                this.store(regs[rs1], 64, t.value + regs[rs2]);
                                regs[rd] = t.value;
                            }
                            else
                                return t;
                        }
                        else
                            return Ret(CpuException(ExceptionCode.IllegalInstruction, inst));
                    }
                    break;
                case amoswap:
                    {
                        if (funct3 == Funct3.amo32)
                        {
                            auto t = this.load(regs[rs1], 32);
                            if (t.ok)
                            {
                                this.store(regs[rs1], 32, regs[rs2]);
                                regs[rd] = cast(long) cast(int) t.value;
                            }
                            else
                                return t;
                        }
                        else if (funct3 == Funct3.amo64)
                        {
                            auto t = this.load(regs[rs1], 64);
                            if (t.ok)
                            {
                                this.store(regs[rs1], 64, regs[rs2]);
                                regs[rd] = t.value;
                            }
                            else
                                return t;
                        }
                        else
                            return Ret(CpuException(ExceptionCode.IllegalInstruction, inst));
                    }
                    break;
                default:
                    return Ret(CpuException(ExceptionCode.IllegalInstruction, inst));
                }
            }
            break;

        default:
            return Ret(CpuException(ExceptionCode.IllegalInstruction, inst));
        }

        return Ret(pc + 4);
    }

    void handleException(CpuException e)
    {
        with (CsrName) with (CsrMask)
        {
            auto pc = this.pc;
            auto mode = this.mode;
            auto cause = e.exception;
            auto trapInSMode = mode <= Mode.Supervisor && this.csr.isMeDelegated(cause);

            if (trapInSMode)
                this.mode = Mode.Supervisor;
            else
                this.mode = Mode.Machine;

            import std.typecons : tuple;

            auto result = trapInSMode
                ? tuple(SSTATUS, STVEC, SCAUSE, STVAL, SEPC, MASK_SPIE, 5, MASK_SIE, 1, MASK_SPP, 8) 
                : tuple(MSTATUS, MTVEC, MCAUSE, MTVAL, MEPC, MASK_MPIE, 7, MASK_MIE, 3, MASK_MPP, 11);

            auto STATUS = result[0];
            auto TVEC = result[1];
            auto CAUSE = result[2];
            auto TVAL = result[3];
            auto EPC = result[4];
            auto MASK_PIE = result[5];
            auto pie_i = result[6];
            auto MASK_IE = result[7];
            auto ie_i = result[8];
            auto MASK_PP = result[9];
            auto pp_i = result[10];

            this.pc = this.csr.load(TVEC) & ~0b11;
            this.csr.store(EPC, pc);
            this.csr.store(CAUSE, cause);
            this.csr.store(TVAL, e.value);

            auto status = this.csr.load(STATUS);
            auto ie = (status & MASK_IE) >> ie_i;
            status = (status & ~MASK_PIE) | (ie << pie_i);
            status &= ~MASK_IE;
            status = (status & ~MASK_PP) | (mode << pp_i);
            this.csr.store(STATUS, status);
        }
    }

    void handleInterrupt(InterruptCode code)
    {
        with (CsrName) with (CsrMask)
        {
            auto pc = this.pc;
            auto mode = this.mode;
            auto cause = code;

            auto trapInSMode = mode <= Mode.Supervisor && this.csr.isMiDelegated(cause);

            import std.typecons : tuple;

            auto result = trapInSMode
                ? tuple(SSTATUS, STVEC, SCAUSE, STVAL, SEPC, MASK_SPIE, 5, MASK_SIE, 1, MASK_SPP, 8) 
                : tuple(MSTATUS, MTVEC, MCAUSE, MTVAL, MEPC, MASK_MPIE, 7, MASK_MIE, 3, MASK_MPP, 11);

            auto STATUS = result[0];
            auto TVEC = result[1];
            auto CAUSE = result[2];
            auto TVAL = result[3];
            auto EPC = result[4];
            auto MASK_PIE = result[5];
            auto pie_i = result[6];
            auto MASK_IE = result[7];
            auto ie_i = result[8];
            auto MASK_PP = result[9];
            auto pp_i = result[10];

            auto tvec = this.csr.load(TVEC);
            auto tvecMode = tvec & 0b11;
            auto tvecBase = tvec & ~0b11;

            switch (tvecMode)
            {
            case 0:
                this.pc = tvecBase;
                break;
            case 1:
                this.pc = tvecBase + cause << 2;
                break;
            default:
                assert(0, "Unreachable");
            }

            this.csr.store(EPC, pc);
            this.csr.store(CAUSE, cause);
            this.csr.store(TVAL, 0);

            auto status = this.csr.load(STATUS);
            auto ie = (STATUS & MASK_IE) >> ie_i;
            status = (status & ~MASK_PIE) | (ie << pie_i);
            status &= ~MASK_IE;
            status = (status & ~MASK_PP) | (mode << pp_i);
            this.csr.store(STATUS, status);
        }
    }

    ulong checkPendingInterrupt()
    {
        with (CsrName) with (CsrMask)
        {
            if (this.mode == Mode.Machine && (this.csr.load(MSTATUS) & MASK_MIE) == 0)
                return 0;
            if (this.mode == Mode.Supervisor && (this.csr.load(SSTATUS) & MASK_SIE) == 0)
                return 0;

            if (this.bus.uart.isInterrupting())
            {
                this.bus.store(PLIC_SCLAIM, 32, UART_IRQ);
                this.csr.store(MIP, this.csr.load(MIP) | MASK_SEIP);
            }
            else if (this.bus.virtioBlock.isInterrupting())
            {
                this.diskAccess();
                this.bus.store(PLIC_SCLAIM, 32, VIRTIO_IRQ);
                this.csr.store(MIP, this.csr.load(MIP) | MASK_SEIP);
            }

            auto pending = this.csr.load(MIE) & this.csr.load(MIP);

            if ((pending & MASK_MEIP) != 0)
            {
                this.csr.store(MIP, this.csr.load(MIP) & ~MASK_MEIP);
                return InterruptCode.MachineExternalInterrupt;
            }
            if ((pending & MASK_MSIP) != 0)
            {
                this.csr.store(MIP, this.csr.load(MIP) & ~MASK_MSIP);
                return InterruptCode.MachineSoftwareInterrupt;
            }
            if ((pending & MASK_MTIP) != 0)
            {
                this.csr.store(MIP, this.csr.load(MIP) & ~MASK_MTIP);
                return InterruptCode.MachineTimerInterrupt;
            }
            if ((pending & MASK_SEIP) != 0)
            {
                this.csr.store(MIP, this.csr.load(MIP) & ~MASK_SEIP);
                return InterruptCode.SupervisorExternalInterrupt;
            }
            if ((pending & MASK_SSIP) != 0)
            {
                this.csr.store(MIP, this.csr.load(MIP) & ~MASK_SSIP);
                return InterruptCode.SupervisorSoftwareInterrupt;
            }
            if ((pending & MASK_STIP) != 0)
            {
                this.csr.store(MIP, this.csr.load(MIP) & ~MASK_STIP);
                return InterruptCode.SupervisorTimerInterrupt;
            }

            return 0;
        }
    }

    void diskAccess()
    {
        auto descSize = VirtqDesc.sizeof;
        auto descAddr = this.bus.virtioBlock.descAddr();
        auto availAddr = descAddr + cast(ulong) DESC_NUM * descSize;
        auto usedAddr = descAddr + PAGE_SIZE;

        auto virtqAvail = cast(VirtqAvail*) availAddr;
        auto virtqUsed = cast(VirtqUsed*) usedAddr;

        auto idx = this.bus.load(cast(ulong)(&virtqAvail.idx), 16).value;
        auto index = this.bus.load(cast(ulong)(&virtqAvail.ring[idx % DESC_NUM]), 16).value;

        auto descAddr0 = descAddr + descSize * index;
        auto virtqDesc0 = cast(VirtqDesc*) descAddr0;
        auto next0 = this.bus.load(cast(ulong)(&virtqDesc0.next), 16).value;

        auto reqAddr = this.bus.load(cast(ulong)(&virtqDesc0.addr), 64).value;
        auto virtqBlkReq = cast(VirtioBlkRequest*) reqAddr;
        auto blkSector = this.bus.load(cast(ulong)(&virtqBlkReq.sector), 64).value;
        auto ioType = this.bus.load(cast(ulong)(&virtqBlkReq.ioType), 64).value;

        auto descAddr1 = descAddr + descSize * next0;
        auto virtqDesc1 = cast(VirtqDesc*) descAddr1;
        auto addr1 = this.bus.load(cast(ulong)(&virtqDesc1.addr), 64).value;
        auto len1 = this.bus.load(cast(ulong)(&virtqDesc1.len), 32).value;

        switch (ioType)
        {
        case VIRTIO_BLK_T_OUT:
            {
                foreach (i; 0 .. len1)
                {
                    auto data = this.bus.load(addr1 + i, 8).value;
                    this.bus.virtioBlock.writeDisk(blkSector * SECTOR_SIZE + i, data);
                }
            }
            break;
        case VIRTIO_BLK_T_IN:
            {
                foreach (i; 0 .. len1)
                {
                    auto data = this.bus.virtioBlock.readDisk(blkSector * SECTOR_SIZE + i);
                    this.bus.store(addr1 + i, 8, data);
                }
            }
            break;
        default:
            assert(0, "Unreachable");
        }

        auto newId = this.bus.virtioBlock.getNewId();
        this.bus.store(cast(ulong)(&virtqUsed.idx), 16, newId % 8);
    }

    void dumpRegisters()
    {
        import std.string : format;

        string output;

        for (int i = 0; i < RVABI.length; i += 4)
        {
            output = format("%s\n%s", output, format(
                    "x%02d(%04s)=%#018x x%02d(%04s)=%#018x x%02d(%04s)=%#018x x%02d(%04s)=%#018x",
                    i,
                    RVABI[i],
                    regs[i],
                    i + 1,
                    RVABI[i + 1],
                    regs[i + 1],
                    i + 2,
                    RVABI[i + 2],
                    regs[i + 2],
                    i + 3,
                    RVABI[i + 3],
                    regs[i + 3],
            ));
        }

        writeln(output);
    }

    void dumpPc()
    {
        import std.string : format;

        writeln(format("Program Counter: %x", pc));
    }
}
