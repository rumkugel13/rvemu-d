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
    fence = 0x0f,
    system = 0x73,
    amo = 0x2f,
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

    ecall = 0x0,
    ebreak = 0x0,
    sfence_vma = 0x0,
    sret = 0x0,
    mret = 0x0,
    csrrw = 0x1,
    csrrs = 0x2,
    csrrc = 0x3,
    csrrwi = 0x5,
    csrrsi = 0x6,
    csrrci = 0x7,

    mul = 0x0,
    div = 0x4,
    divu = 0x5,
    rem = 0x6,
    remu = 0x7,
    mulw = mul,
    divw = div,
    divuw = divu,
    remw = rem,
    remuw = remu,

    amo32 = 0x2,
    amo64 = 0x3,
}

enum Funct7 : uint
{
    add = 0x0,
    muldiv = 0x1,
    sub = 0x20,
    srl = 0x0,
    sra = 0x20,

    slli = 0x0,
    srli = 0x0,
    srai = 0x20,

    ecall = 0x0,
    ebreak = 0x1,
    sfence_vma = 0x9,
    sret = 0x8,
    mret = 0x18,
}

enum Funct5 : uint
{
    amoadd = 0x0,
    amoswap = 0x1,
    lr = 0x2,
    sc = 0x3,
    amoxor = 0x4,
    amoand = 0xc,
    amoor = 0x8,
    amomin = 0x10,
    amomax = 0x14,
    amominu = 0x18,
    amomaxu = 0x1c,
}