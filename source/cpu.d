module cpu;

import std.bitmanip : peek, write, Endian;
import std.stdio : writeln;
import std.conv : to;
import opcode;
import bus;

const auto RVABI = [
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", 
    "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5", 
    "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7", 
    "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"];

struct Cpu
{
    // 32 64-bit Registers
    ulong[32] regs;
    // 64-bit Program Counter
    ulong pc;
    // System Bus
    Bus bus;

    this(ubyte[] code)
    in(code.length <= DRAM_SIZE)
    {
        regs[0] = 0;
        regs[2] = DRAM_SIZE - 1;
        pc = DRAM_BASE;
        this.bus = Bus(code);
    }

    ulong load(ulong addr, ulong size)
    {
        return bus.load(addr, size);
    }

    void store(ulong addr, ulong size, ulong value)
    {
        bus.store(addr, size, value);
    }

    uint fetch()
    {
        auto inst = cast(uint)bus.load(pc, 32);
        return inst;
    }

    bool execute(uint inst)
    {
        auto opcode = inst & 0x7f;
        auto rd = ((inst >> 7) & 0x1f);
        auto rs1 = ((inst >> 15) & 0x1f);
        auto rs2 = ((inst >> 20) & 0x1f);
        auto funct3 = ((inst >> 12) & 0x07);
        auto funct7 = ((inst >> 25) & 0x7f);

        with(Opcode)
        switch (opcode)
        {
            case load:
            {
                auto imm = cast(ulong)(cast(long)(inst) >> 20);
                auto addr = regs[rs1] + imm;
                with(Funct3)
                switch (funct3)
                {
                    case lb:
                        {
                            auto val = cast(byte)(this.load(addr, 8));
                            regs[rd] = cast(ulong)(cast(long)val);
                        }
                        break;
                    case lh:
                        {
                            auto val = cast(short)(this.load(addr, 16));
                            regs[rd] = cast(ulong)(cast(long)val);
                        }
                        break;
                    case lw:
                        {
                            auto val = cast(int)(this.load(addr, 32));
                            regs[rd] = cast(ulong)(cast(long)val);
                        }
                        break;
                    case ld:
                        {
                            auto val = cast(long)this.load(addr, 64);
                            regs[rd] = cast(ulong)val;
                        }
                        break;
                    case lbu:
                        {
                            auto val = this.load(addr, 8);
                            regs[rd] = val;
                        }
                        break;
                    case lhu:
                        {
                            auto val = this.load(addr, 16);
                            regs[rd] = val;
                        }
                        break;
                    case lwu:
                        {
                            auto val = this.load(addr, 32);
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
                auto imm = cast(ulong)(cast(long)(inst & 0xfe00_0000) >> 20) | cast(ulong)((inst >> 7) & 0x1f);
                auto addr = regs[rs1] + imm;

                with(Funct3)
                switch (funct3)
                {
                    case sb: this.store(addr, 8, regs[rs2]); break;
                    case sh: this.store(addr, 16, regs[rs2]); break;
                    case sw: this.store(addr, 32, regs[rs2]); break;
                    case sd: this.store(addr, 64, regs[rs2]); break;
                    default:
                        break;
                }
            }
            break;

            case addi:
            {
                auto imm = cast(ulong)(cast(long)(inst & 0xfff0_0000) >> 20);
                regs[rd] = regs[rs1] + imm;
            }
            break;
            case add:
            {
                regs[rd] = regs[rs1] + regs[rs2];
            } 
            break;
            default:
            {
                writeln("Not implemented (yet): Opcode %d", opcode);
                return false;
            }
        }

        return true;
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