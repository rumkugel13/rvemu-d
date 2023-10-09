module test;

import std.stdio : writeln;
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
        assert(cpu.regs[reg] == val);
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