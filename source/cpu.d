module cpu;

import std.bitmanip : peek, write, Endian;
import std.stdio : writeln;

// 128 MiB
const auto DRAM_SIZE = 1024 * 1024 * 128;

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
    // DRAM
    ubyte[] code;

    this(ubyte[] code)
    in(code.length <= DRAM_SIZE)
    {
        regs[0] = 0;
        regs[2] = DRAM_SIZE - 1;
        pc = 0;
        this.code = code;
    }

    uint fetch()
    {
        auto index = pc;
        auto inst = code.peek!(uint, Endian.littleEndian)(index);
        return inst;
    }

    void execute(uint inst)
    {
        auto opcode = inst & 0x7f;
        auto rd = ((inst >> 7) & 0x1f);
        auto rs1 = ((inst >> 15) & 0x1f);
        auto rs2 = ((inst >> 20) & 0x1f);
        auto funct3 = ((inst >> 12) & 0x07);
        auto funct7 = ((inst >> 25) & 0x7f);

        switch (opcode)
        {
            case 0x13:  // addi
            {
                auto imm = cast(ulong)(cast(long)(inst & 0xfff0_0000) >> 20);
                regs[rd] = regs[rs1] + imm;
            }
            break;
            case 0x33:  // add
            {
                regs[rd] = regs[rs1] + regs[rs2];
            } 
            break;
            default:
            {
                assert(0, "Not implemented (yet)");
            }
        }
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