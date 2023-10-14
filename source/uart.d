module uart;

import core.sync.condition;
import core.sync.mutex;
import core.atomic;
import std.concurrency : spawn;
import std.conv : to;
import std.stdio;
import exception;

const auto UART_BASE = 0x1000_0000;
const auto UART_SIZE = 0x100;
const auto UART_END = UART_BASE + UART_SIZE - 1;

const auto UART_IRQ = 10;
const auto UART_RHR = 0;
const auto UART_THR = 0;
const auto UART_LCR = 3;
const auto UART_LSR = 5;

const auto MASK_UART_LSR_RX = 1;
const auto MASK_UART_LSR_TX = 1 << 5;

struct Uart
{
    shared ubyte[] uart;
    shared Mutex mut;
    shared Condition cond;
    shared bool interrupt;

    void create()
    {
        auto uart = new ubyte[UART_SIZE];
        uart[UART_LSR] |= MASK_UART_LSR_TX;
        this.uart = cast(shared)uart;
        this.mut = new shared Mutex();
        this.cond = new shared Condition(this.mut);
        this.interrupt = false;

        spawn(&run, this.uart, this.mut, this.cond, this.interrupt);
    }

    static void run(shared ubyte[] uart, shared Mutex mut, shared Condition cond, shared bool interrupt)
    {
        while(!stdin.eof)
        {
            char c;
            auto read = readf!"%c"(c);
            if (read > 0)
            {
                mut.lock();
                
                while ((uart[UART_LSR] & MASK_UART_LSR_RX) == 1)
                    cond.wait();

                uart[UART_RHR] = c;
                interrupt.atomicStore!(MemoryOrder.rel)(true);
                uart[UART_LSR].atomicOp!"|="(MASK_UART_LSR_RX);
                mut.unlock();
            }
            else
            {
                break;
            }
        }
    }

    Ret load(ulong addr, ulong size)
    {
        if (size == 8)
        {
            this.mut.lock();
            scope(exit) this.mut.unlock();

            auto index = addr - UART_BASE;
            switch (index)
            {
                case UART_RHR:
                {
                    this.cond.notify();
                    this.uart[UART_LSR].atomicOp!"&="(~MASK_UART_LSR_RX);
                    return Ret(this.uart[UART_RHR]);
                }
                default: return Ret(this.uart[index]);
            }
        }
        else {
            return Ret(CpuException(ExceptionCode.LoadAccessFault, addr));
        }
    }

    Ret store(ulong addr, ulong size, ulong value)
    {
        if (size == 8)
        {
            this.mut.lock();
            scope(exit) this.mut.unlock();

            auto index = addr - UART_BASE;
            switch (index)
            {
                case UART_THR:
                {
                    write(cast(char)cast(ubyte)value);
                    stdout.flush();
                    return Ret(0);
                }
                default:
                {
                    this.uart[index] = cast(ubyte)value;
                    return Ret(0);
                }
            }
        }
        else {
            return Ret(CpuException(ExceptionCode.StoreAMOAccessFault, addr));
        }
    }

    bool isInterrupting()
    {
        atomicExchange!(MemoryOrder.acq)(&this.interrupt, false);
        return this.interrupt;
    }
}