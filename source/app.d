import std.stdio;

import std.stdio : writeln;
import std.file : read;
import cpu;
import exception, interrupt;

void main(string[] args)
{
    string path;
    if (args.length != 2 && args.length != 3)
    {
        path = "test/add-addi.bin";
        path = "test/fib.bin";
        path = "test/helloworld.bin";
        // path = "test/echoback.bin";
        // writeln("Usage: \n\trvemu <filename> <(option) image>");
        // return;
    }
    else
    {
        path = args[1];
    }

    auto file = cast(ubyte[]) read(path);
    ubyte[] diskImage;

    if (args.length == 3)
    {
        diskImage ~= cast(ubyte[]) read(args[2]);
    }

    auto cpu = Cpu(file, diskImage);

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

        auto e = cpu.execute(inst);
        if (e.ok)
            cpu.pc = e.value;
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

        auto pending = cpu.checkPendingInterrupt();
        if (pending)
        {
            cpu.handleInterrupt(cast(InterruptCode)pending);
        }

        // avoid infinite loops / break on error
        if (cpu.pc == 0)
            break;
    }

    if (path == "test/fib.bin")
        assert(cpu.regs[15] == 0x37);
    cpu.dumpRegisters();
}
