module test;

import std.stdio : writeln;
import std.string : format;

import cpu, dram;

static void run(string name, ubyte[] data, ulong[ubyte] regs, ulong pc = 0)
{
    writeln("Testing ", name);
    Cpu cpu = Cpu(data);

    while (true)
    {
        auto inst = cpu.fetch();
        
        // break on zero inst
        if (!inst)
            break;

        auto newpc = cpu.execute(inst);
        cpu.pc = newpc;
        if (newpc == pc) break;

        // avoid infinite loops / break on error
        if (cpu.pc == 0)
            break;
    }

    foreach (reg, val; regs)
    {
        assert(cpu.regs[reg] == val, format("Register x%d expected: 0x%x, actual: 0x%x", reg, val, cpu.regs[reg]));
    }
    
    if(pc)
        assert(pc == cpu.pc, format("Program counter expected: 0x%x, actual: 0x%x", pc, cpu.pc));
}

// test cases from https://github.com/d0iasm/rvemu/blob/main/tests/rv32i.rs

unittest
{
    ubyte[] data = [
        0x93, 0x0F, 0x40, 0x00, // addi x31, x0, 4
    ];

    ulong[ubyte] expected = [31: 4];

    run("addi", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0xb0, 0xff, // addi x16 x0, -5
        0x93, 0x28, 0xe8, 0xff, // slti x17, x16, -2
    ];

    ulong[ubyte] expected = [16: cast(ulong)-5L, 17: 1];

    run("slti", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x20, 0x00, // addi x16, x0, 2
        0x93, 0x38, 0x58, 0x00, // sltiu, x17, x16, 5
    ];

    ulong[ubyte] expected = [16: 2, 17: 1];

    run("sltiu", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x30, 0x00, // addi x16, x0, 3
        0x93, 0x48, 0x68, 0x00, // xori, x17, x16, 6
    ];

    ulong[ubyte] expected = [16: 3, 17: 5];

    run("xori", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x30, 0x00, // addi x16, x0, 3
        0x93, 0x68, 0x68, 0x00, // ori, x17, x16, 6
    ];

    ulong[ubyte] expected = [16: 3, 17: 7];

    run("ori", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x40, 0x00, // addi x16, x0, 4
        0x93, 0x78, 0x78, 0x00, // andi, x17, x16, 7
    ];

    ulong[ubyte] expected = [16: 4, 17: 4];

    run("andi", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x20, 0x00, // addi x16 x0, 2
        0x93, 0x18, 0x38, 0x00, // slli x17, x16, 3
    ];

    ulong[ubyte] expected = [16: 2, 17: 16];

    run("slli", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x80, 0x00, // addi x16, x0, 8
        0x93, 0x58, 0x28, 0x00, // srli x17, x16, 2
    ];

    ulong[ubyte] expected = [16: 8, 17: 2];

    run("srli", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x80, 0xff, // addi x16, x0, -8
        0x93, 0x58, 0x28, 0x40, // srai x17, x16, 2
    ];

    ulong[ubyte] expected = [16: cast(ulong)-8L, 17: cast(ulong)-2L];

    run("srai", data, expected);
}

unittest
{
    ubyte[] data = [
        0x93, 0x01, 0x50, 0x00, // addi x3, x0, 5
        0x13, 0x02, 0x60, 0x00, // addi x4, x0, 6
        0x33, 0x81, 0x41, 0x00, // add x2, x3, x4
    ];

    ulong[ubyte] expected = [2: 11, 3: 5, 4: 6];

    run("add", data, expected);
}

unittest
{
    ubyte[] data = [
        0x93, 0x01, 0x50, 0x00, // addi x3, x0, 5
        0x13, 0x02, 0x60, 0x00, // addi x4, x0, 6
        0x33, 0x81, 0x41, 0x40, // sub x2, x3, x4
    ];

    ulong[ubyte] expected = [2: cast(ulong)-1L, 3: 5, 4: 6];

    run("sub", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x80, 0x00, // addi x16, x0, 8
        0x93, 0x08, 0x20, 0x00, // addi x17, x0, 2
        0x33, 0x19, 0x18, 0x01, // sll x18, x16, x17
    ];

    ulong[ubyte] expected = [16: 8, 17: 2, 18: 32];

    run("sll", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x80, 0xff, // addi x16, x0, -8
        0x93, 0x08, 0x20, 0x00, // addi x17, x0, 2
        0x33, 0x29, 0x18, 0x01, // slt x18, x16, x17
    ];

    ulong[ubyte] expected = [16: cast(ulong)-8L, 17: 2, 18: 1];

    run("slt", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x80, 0x00, // addi x16, x0, 8
        0x93, 0x08, 0x20, 0x00, // addi x17, x0, 2
        0x33, 0xb9, 0x08, 0x01, // slt x18, x17, x16
    ];

    ulong[ubyte] expected = [16: 8, 17: 2, 18: 1];

    run("sltu", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x30, 0x00, // addi x16, x0, 3
        0x93, 0x08, 0x60, 0x00, // addi x17, x0, 6
        0x33, 0x49, 0x18, 0x01, // xor x18, x16, x17
    ];

    ulong[ubyte] expected = [16: 3, 17: 6, 18: 5];

    run("xor", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x00, 0x01, // addi x16, x0, 16
        0x93, 0x08, 0x20, 0x00, // addi x17, x0, 2
        0x33, 0x59, 0x18, 0x01, // srl x18, x16, x17
    ];

    ulong[ubyte] expected = [16: 16, 17: 2, 18: 4];

    run("srl", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x00, 0xff, // addi x16, x0, -16
        0x93, 0x08, 0x20, 0x00, // addi x17, x0, 2
        0x33, 0x59, 0x18, 0x41, // sra x18, x16, x17
    ];

    ulong[ubyte] expected = [16: cast(ulong)-16L, 17: 2, 18: cast(ulong)-4L];

    run("sra", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x30, 0x00, // addi x16, x0, 3
        0x93, 0x08, 0x50, 0x00, // addi x17, x0, 5
        0x33, 0x69, 0x18, 0x01, // or x18, x16, x17
    ];

    ulong[ubyte] expected = [16: 3, 17: 5, 18: 7];

    run("or", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x30, 0x00, // addi x16, x0, 3
        0x93, 0x08, 0x50, 0x00, // addi x17, x0, 5
        0x33, 0x79, 0x18, 0x01, // and x18, x16, x17
    ];

    ulong[ubyte] expected = [16: 3, 17: 5, 18: 1];

    run("and", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x50, 0x00, // addi x16, x0, 5
        0x93, 0x08, 0x30, 0x00, // addi x17, x0, 3
        0x03, 0x09, 0x40, 0x00, // lb x18, 4(x0)
    ];

    ulong[ubyte] expected = [16: 5, 17: 3, 18: cast(ulong)-109L];

    run("lb", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x50, 0x00, // addi x16, x0, 5
        0x93, 0x08, 0x30, 0x00, // addi x17, x0, 3
        0x03, 0x19, 0x40, 0x00, // lh x18, 4(x0)
    ];

    ulong[ubyte] expected = [16: 5, 17: 3, 18: 0x0893];

    run("lh", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x50, 0x00, // addi x16, x0, 5
        0x93, 0x08, 0x30, 0x00, // addi x17, x0, 3
        0x03, 0x29, 0x40, 0x00, // lw x18, 4(x0)
    ];

    ulong[ubyte] expected = [16: 5, 17: 3, 18: 0x300893];

    run("lw", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x50, 0x00, // addi x16, x0, 5
        0x93, 0x08, 0x30, 0x00, // addi x17, x0, 3
        0x03, 0x39, 0x40, 0x00, // ld x18, 4(x0)
    ];

    ulong[ubyte] expected = [16: 5, 17: 3, 18: 0x40390300300893];

    run("ld", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x50, 0x00, // addi x16, x0, 5
        0x93, 0x08, 0x30, 0x00, // addi x17, x0, 3
        0x03, 0x49, 0x40, 0x00, // lbu x18, 4(x0)
    ];

    ulong[ubyte] expected = [16: 5, 17: 3, 18: 0x93];

    run("lbu", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x50, 0x00, // addi x16, x0, 5
        0x93, 0x08, 0x30, 0x00, // addi x17, x0, 3
        0x03, 0x59, 0x40, 0x00, // lbu x18, 4(x0)
    ];

    ulong[ubyte] expected = [16: 5, 17: 3, 18: 0x0893];

    run("lhu", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x50, 0x00, // addi x16, x0, 5
        0x93, 0x08, 0x30, 0x00, // addi x17, x0, 3
        0x03, 0x69, 0x40, 0x00, // lbu x18, 4(x0)
    ];

    ulong[ubyte] expected = [16: 5, 17: 3, 18: 0x300893];

    run("lwu", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0xb0, 0xff, // addi x16, x0, -5
        0x93, 0x08, 0x30, 0x00, // addi x17, x0, 3
        0x23, 0x02, 0x00, 0x01, // sb x16, 4(x0)
        0x03, 0x09, 0x40, 0x00, // lb x18, 4(x0)
    ];

    ulong[ubyte] expected = [16: cast(ulong)(-5L), 17: 3, 18: cast(ulong)-5L];

    run("sb", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x00, 0xc0, // addi x16, x0, -1024
        0x93, 0x08, 0x30, 0x00, // addi x17, x0, 3
        0x23, 0x12, 0x00, 0x01, // sh x16, 4(x0)
        0x03, 0x19, 0x40, 0x00, // lh x18, 4(x0)
    ];

    ulong[ubyte] expected = [16: cast(ulong)-1024L, 17: 3, 18: cast(ulong)-1024L];

    run("sh", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x00, 0x80, // addi x16, x0, -2048
        0x93, 0x08, 0x30, 0x00, // addi x17, x0, 3
        0x23, 0x22, 0x00, 0x01, // sw x16, 4(x0)
        0x03, 0x29, 0x40, 0x00, // lw x18, 4(x0)
    ];

    ulong[ubyte] expected = [16: cast(ulong)-2048L, 17: 3, 18: cast(ulong)-2048L];

    run("sw", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x00, 0x80, // addi x16, x0, -2048
        0x93, 0x08, 0x30, 0x00, // addi x17, x0, 3
        0x23, 0x32, 0x00, 0x01, // sd x16, 4(x0)
        0x03, 0x39, 0x40, 0x00, // ld x18, 4(x0)
    ];

    ulong[ubyte] expected = [16: cast(ulong)-2048L, 17: 3, 18: cast(ulong)-2048L];

    run("sd", data, expected);
}

unittest
{
    ubyte[] data = [
        0x37, 0x28, 0x00, 0x00, // lui x16, 2
    ];

    ulong[ubyte] expected = [16: 8192];

    run("lui", data, expected);
}

unittest
{
    ubyte[] data = [
        0x17, 0x28, 0x00, 0x00, // auipc x16, 2
    ];

    ulong[ubyte] expected = [16: 0x2000 + DRAM_BASE];

    run("auipc", data, expected);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x30, 0x00, // addi x16, x0, 3
        0x93, 0x08, 0x50, 0x00, // addi x17, x0, 5
        0x6f, 0x09, 0xc0, 0x00, // jal x18, 12
    ];

    ulong[ubyte] expected = [16: 3, 17: 5, 18: 12 + DRAM_BASE];

    run("jal", data, expected, 12 + DRAM_BASE + 8);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x30, 0x00, // addi x16, x0, 3
        0x93, 0x08, 0x50, 0x00, // addi x17, x0, 5
        0x67, 0x09, 0xc0, 0x02, // jalr x18, x0, 44
    ];

    ulong[ubyte] expected = [16: 3, 17: 5, 18: 12 + DRAM_BASE];

    run("jalr", data, expected, 44);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x30, 0x00, // addi x16, x0, 3
        0x93, 0x08, 0x30, 0x00, // addi x17, x0, 3
        0x63, 0x06, 0x18, 0x01, // beq x16, x17, 12
    ];

    ulong[ubyte] expected = [16: 3, 17: 3];

    run("beq", data, expected, 12 + DRAM_BASE + 8);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x30, 0x00, // addi x16, x0, 3
        0x93, 0x08, 0x50, 0x00, // addi x17, x0, 5
        0x63, 0x16, 0x18, 0x01, // bne x16, x17, 12
    ];

    ulong[ubyte] expected = [16: 3, 17: 5];

    run("bne", data, expected, 12 + DRAM_BASE + 8);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0xd0, 0xff, // addi x16, x0, -3
        0x93, 0x08, 0x50, 0x00, // addi x17, x0, 5
        0x63, 0x46, 0x18, 0x01, // blt x16, x17, 12
    ];

    ulong[ubyte] expected = [16: cast(ulong)-3L, 17: 5];

    run("blt", data, expected, 12 + DRAM_BASE + 8);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0xd0, 0xff, // addi x16, x0, -3
        0x93, 0x08, 0xd0, 0xff, // addi x17, x0, -3
        0x63, 0x56, 0x18, 0x01, // bge x16, x17, 12
    ];

    ulong[ubyte] expected = [16: cast(ulong)-3L, 17: cast(ulong)-3L];

    run("bge", data, expected, 12 + DRAM_BASE + 8);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x30, 0x00, // addi x16, x0, 3
        0x93, 0x08, 0x50, 0x00, // addi x17, x0, 5
        0x63, 0x66, 0x18, 0x01, // bltu x16, x17, 12
    ];

    ulong[ubyte] expected = [16: 3, 17: 5];

    run("bltu", data, expected, 12 + DRAM_BASE + 8);
}

unittest
{
    ubyte[] data = [
        0x13, 0x08, 0x50, 0x00, // addi x16, x0, 5
        0x93, 0x08, 0x30, 0x00, // addi x17, x0, 3
        0x63, 0x76, 0x18, 0x01, // bgeu x16, x17, 12
    ];

    ulong[ubyte] expected = [16: 5, 17: 3];

    run("bgeu", data, expected, 12 + DRAM_BASE + 8);
}