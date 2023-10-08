import std.stdio;

import std.stdio : writeln;
import std.file : read;
import cpu;

void main(string[] args)
{
    string path;
    if (args.length != 2)
    {
        path = "test/add-addi.bin";
        // writeln("Usage: \n\trvemu <filename>");
        // return;
    }
    else {
        path = args[1];
    }

    auto file = cast(ubyte[])read(path);
    auto cpu = Cpu(file);

    while (cpu.pc < cpu.code.length)
    {
        auto inst = cpu.fetch();
        cpu.execute(inst);
        cpu.pc += 4;
    }
    cpu.dumpRegisters();
}
