module opcode;

enum Opcode : uint
{
    addi = 0x13,
    add = 0x33,
    load = 0x03,
    store = 0x23,
}

enum Funct3 : uint
{
    lb = 0x0,
    lh = 0x1,
    lw = 0x2,
    ld = 0x3,
    lbu = 0x4,
    lhu = 0x5,
    lwu = 0x6,

    sb = 0x0,
    sh = 0x1,
    sw = 0x2,
    sd = 0x3,
}