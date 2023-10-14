module interrupt;

const auto MASK_INTERRUPT_BIT = 1uL << 63;

enum InterruptCode : ulong
{
    SupervisorSoftwareInterrupt = 1 | MASK_INTERRUPT_BIT,
    MachineSoftwareInterrupt = 3 | MASK_INTERRUPT_BIT,
    SupervisorTimerInterrupt = 5 | MASK_INTERRUPT_BIT,
    MachineTimerInterrupt = 7 | MASK_INTERRUPT_BIT,
    SupervisorExternalInterrupt = 9 | MASK_INTERRUPT_BIT,
    MachineExternalInterrupt = 11 | MASK_INTERRUPT_BIT,
}