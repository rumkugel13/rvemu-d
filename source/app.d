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

    while (true)
    {
        auto inst = cpu.fetch();

        auto newpc = cpu.execute(inst);
        cpu.pc = newpc;

        // avoid infinite loops / break on error
        if (cpu.pc == 0)
            break;
    }

    cpu.dumpRegisters();
}
