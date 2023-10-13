import std.stdio;

import std.stdio : writeln;
import std.file : read;
import cpu;
import exception;

void main(string[] args)
{
    string path;
    if (args.length != 2)
    {
        path = "test/add-addi.bin";
        path = "test/fib.bin";
        path = "test/helloworld.bin";
        // path = "test/echoback.bin";
        // writeln("Usage: \n\trvemu <filename>");
        // return;
    }
    else
    {
        path = args[1];
    }

    auto file = cast(ubyte[]) read(path);
    auto cpu = Cpu(file);

    while (true)
    {
        uint inst;
        auto f = cpu.fetch();
        if (f.ok)
            inst = cast(uint) f.value;
        else
        {
            auto exception = f.exception;
            cpu.handleException(exception);
            if (exception.isFatal())
            {
                writeln(exception);
                break;
            }
            continue;
        }

        ulong newpc;
        auto e = cpu.execute(inst);
        if (e.ok)
            newpc = e.value;
        else
        {
            auto exception = e.exception;
            cpu.handleException(exception);
            if (exception.isFatal())
            {
                writeln(exception);
                break;
            }
        }

        cpu.pc = newpc;

        // avoid infinite loops / break on error
        if (cpu.pc == 0)
            break;
    }

    if (path == "test/fib.bin")
        assert(cpu.regs[15] == 0x37);
    cpu.dumpRegisters();
}
