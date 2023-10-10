module opcode;

enum Opcode : uint
{
    opimm = 0x13,
    op = 0x33,
    op32 = 0x3b,
    opimm32 = 0x1b,
    load = 0x03,
    store = 0x23,
    lui = 0x37,
    auipc = 0x17,
    jal = 0x6f,
    jalr = 0x67,
    branch = 0x63,
    fence = 0xff,
    system = 0x73,
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

    beq = 0x0,
    bne = 0x1,
    blt = 0x4,
    bge = 0x5,
    bltu = 0x6,
    bgeu = 0x7,

    add = 0x0,
    sub = 0x0,
    sll = 0x1,
    slt = 0x2,
    sltu = 0x3,
    xor = 0x4,
    srl = 0x5,
    sra = 0x5,
    or = 0x6,
    and = 0x7,

    addi = 0x0,
    slti = 0x2,
    sltiu = 0x3,
    xori = 0x4,
    ori = 0x6,
    andi = 0x7,
    slli = 0x1,
    srli = 0x5,
    srai = 0x5,

    addw = add,
    subw = sub,
    sllw = sll,
    srlw = srl,
    sraw = sra,

    addiw = addi,
    slliw = slli,
    srliw = srli,
    sraiw = srai,
}

enum Funct7 : uint
{
    add = 0x0,
    sub = 0x20,
    srl = 0x0,
    sra = 0x20,

    slli = 0x0,
    srli = 0x0,
    srai = 0x20,
}