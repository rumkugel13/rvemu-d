module test;

import std.stdio : writeln;
import std.string : format;

import cpu;

static void run(string name, ubyte[] data, ulong[ubyte] expected)
{
    writeln("Testing ", name);
    Cpu cpu = Cpu(data);

    while (true)
    {
        auto inst = cpu.fetch();
        
        // break on zero inst
        if (!inst)
            break;

        cpu.pc += 4;

        // break on unknown instruction/error
        if (!cpu.execute(inst))
            break;

        // avoid infinite loops
        if (cpu.pc == 0)
            break;
    }

    foreach (reg, val; expected)
    {
        assert(cpu.regs[reg] == val, format("Register x%d expected: 0x%x, actual: 0x%x", reg, val, cpu.regs[reg]));
    }
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