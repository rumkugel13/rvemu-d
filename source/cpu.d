module cpu;

import std.bitmanip : peek, write, Endian;
import std.stdio : writeln;
import std.conv : to;
import std.string : format;
import opcode;
import bus;
import csr;

const auto RVABI = [
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
    "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
    "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
    "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
];

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

    this(ubyte[] code)
    in (code.length <= DRAM_SIZE)
    {
        regs[0] = 0;
        regs[2] = DRAM_END;
        pc = DRAM_BASE;
        this.bus = Bus(code);
    }

    ulong load(ulong addr, ulong size)
    {
        version (unittest)
        {
            return bus.load(addr + DRAM_BASE, size);
        }
        else
        {
            return bus.load(addr, size);
        }
    }

    void store(ulong addr, ulong size, ulong value)
    {
        version (unittest)
        {
            bus.store(addr + DRAM_BASE, size, value);
        }
        else
        {
            bus.store(addr, size, value);
        }
    }

    uint fetch()
    {
        auto inst = cast(uint) bus.load(pc, 32);
        return inst;
    }

    // returns updated program counter
    ulong execute(uint inst)
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
                        long val = cast(byte)(this.load(addr, 8));
                        regs[rd] = cast(ulong) val;
                    }
                    break;
                case lh:
                    {
                        long val = cast(short)(this.load(addr, 16));
                        regs[rd] = cast(ulong) val;
                    }
                    break;
                case lw:
                    {
                        long val = cast(int)(this.load(addr, 32));
                        regs[rd] = cast(ulong) val;
                    }
                    break;
                case ld:
                    {
                        long val = cast(long) this.load(addr, 64);
                        regs[rd] = cast(ulong) val;
                    }
                    break;
                case lbu:
                    {
                        ulong val = this.load(addr, 8);
                        regs[rd] = val;
                    }
                    break;
                case lhu:
                    {
                        ulong val = this.load(addr, 16);
                        regs[rd] = val;
                    }
                    break;
                case lwu:
                    {
                        ulong val = this.load(addr, 32);
                        regs[rd] = val;
                    }
                    break;
                default:
                    break;
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
                    break;
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
                    break;
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
                        regs[rd] = cast(long)regs[rs1] / cast(long)regs[rs2];
                    else
                        regs[rd] = regs[rs1] ^ regs[rs2];
                    break;
                case srl | sra | divu:
                    if (funct7 == Funct7.sra)
                        regs[rd] = cast(long) regs[rs1] >> shamt;
                    else if (funct7 == Funct7.srl)
                        regs[rd] = regs[rs1] >>> shamt;
                    else if (funct7 == Funct7.muldiv)
                        regs[rd] = cast(ulong)regs[rs1] / cast(ulong)regs[rs2];
                    break;
                case or | rem:
                    if (funct7 == Funct7.muldiv)
                        regs[rd] = cast(long)regs[rs1] % cast(long)regs[rs2];
                    else
                        regs[rd] = regs[rs1] | regs[rs2];
                    break;
                case and | remu:
                    if (funct7 == Funct7.muldiv)
                        regs[rd] = cast(ulong)regs[rs1] % cast(ulong)regs[rs2];
                    else
                        regs[rd] = regs[rs1] & regs[rs2];
                    break;
                default:
                    break;
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
                        regs[rd] = cast(long)(cast(int)regs[rs1] - cast(int)regs[rs2]);
                    else if (funct7 == Funct7.add)
                        regs[rd] = cast(long)(cast(int)regs[rs1] + cast(int)regs[rs2]);
                    else if (funct7 == Funct7.muldiv)
                        regs[rd] = cast(long)(cast(int)regs[rs1] * cast(int)regs[rs2]);
                    break;
                case sllw:
                    regs[rd] = cast(long) (cast(int)regs[rs1] << shamt);
                    break;
                case divw:
                    regs[rd] = cast(long)(cast(int)regs[rs1] / cast(int)regs[rs2]);
                    break;
                case srlw | sraw | divuw:
                    if (funct7 == Funct7.sra)
                        regs[rd] = cast(long)(cast(int) regs[rs1] >> cast(int) shamt);
                    else if (funct7 == Funct7.srl)
                        regs[rd] = cast(long)(cast(uint) regs[rs1] >>> shamt);
                    else if (funct7 == Funct7.muldiv)
                        regs[rd] = cast(long)cast(int)(cast(uint)regs[rs1] / cast(uint)regs[rs2]);
                    break;
                case remw:
                    regs[rd] = cast(long)(cast(int)regs[rs1] % cast(int)regs[rs2]);
                    break;
                case remuw:
                    regs[rd] = cast(long)cast(int)(cast(uint)regs[rs1] % cast(uint)regs[rs2]);
                    break;
                default:
                    break;
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
                    break;
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
                pc += imm;
                regs[rd] = pc;
                return pc;
            }

        case jal:
            {
                regs[rd] = pc + 4;
                auto imm = cast(long) cast(int)(
                    (cast(int)(inst & 0x8000_0000) >> 11) |
                        (
                            inst & 0xff000) |
                        ((inst >> 9) & 0x800) |
                        ((inst >> 20) & 0x7fe));
                return pc + imm;
            }
        case jalr:
            {
                regs[rd] = pc + 4;
                auto imm = cast(long)(cast(int)(inst & 0xfff0_0000) >> 20);
                auto newpc = (imm + regs[rs1]) & ~0x1L;
                return newpc;
            }

        case branch:
            {
                auto imm = cast(long) cast(int)(
                    (cast(int)(
                        inst & 0x8000_0000) >> 19) |
                        ((inst >> 20) & 0x7e0) |
                        (
                            (inst >> 7) & 0x1e) |
                        ((inst & 0x80) << 4));

                with (Funct3) switch (funct3)
                {
                case beq:
                    if (regs[rs1] == regs[rs2])
                        return pc + imm;
                    break;
                case bne:
                    if (regs[rs1] != regs[rs2])
                        return pc + imm;
                    break;
                case blt:
                    if (cast(long) regs[rs1] < cast(long) regs[rs2])
                        return pc + imm;
                    break;
                case bge:
                    if (cast(long) regs[rs1] >= cast(long) regs[rs2])
                        return pc + imm;
                    break;
                case bltu:
                    if (cast(ulong) regs[rs1] < cast(ulong) regs[rs2])
                        return pc + imm;
                    break;
                case bgeu:
                    if (cast(ulong) regs[rs1] >= cast(ulong) regs[rs2])
                        return pc + imm;
                    break;

                default:
                    break;
                }
                return pc + 4;
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
                case ecall | ebreak | sfence_vma:
                    {
                        // treat as nop
                        switch (funct7)
                        {
                            case Funct7.ecall:
                            case Funct7.ebreak:
                            case Funct7.sfence_vma:
                            default: break;
                        }
                    }
                    break;
                case csrrw:
                    {
                        auto t = this.csr.load(csr);
                        this.csr.store(csr, regs[rs1]);
                        regs[rd] = t;
                    }
                    break;
                case csrrs:
                    {
                        auto t = this.csr.load(csr);
                        this.csr.store(csr, t | regs[rs1]);
                        regs[rd] = t;
                    }
                    break;
                case csrrc:
                    {
                        auto t = this.csr.load(csr);
                        this.csr.store(csr, t & ~regs[rs1]);
                        regs[rd] = t;
                    }
                    break;
                case csrrwi:
                    {
                        regs[rd] = this.csr.load(csr);
                        this.csr.store(csr, uimm);
                    }
                    break;
                case csrrsi:
                    {
                        auto t = this.csr.load(csr);
                        this.csr.store(csr, t | uimm);
                        regs[rd] = t;
                    }
                    break;
                case csrrci:
                    {
                        auto t = this.csr.load(csr);
                        this.csr.store(csr, t & ~uimm);
                        regs[rd] = t;
                    }
                    break;

                default:
                    break;
                }
            }
            break;

        default:
            {
                writeln(format("Unknown Opcode: 0x%02x in Instruction 0x%08x at Address 0x%08x", opcode, inst, pc));
                return 0;
            }
        }

        return pc + 4;
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
}
