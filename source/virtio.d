module virtio;

import exception;

const auto VIRTIO_BASE = 0x1000_1000;
const auto VIRTIO_SIZE = 0x1000;
const auto VIRTIO_END = VIRTIO_BASE + VIRTIO_SIZE - 1;
const auto VIRTIO_IRQ = 1;

const auto DESC_NUM = 8;

const auto VIRTIO_MAGIC = VIRTIO_BASE + 0x000;
const auto VIRTIO_VERSION = VIRTIO_BASE + 0x004;
const auto VIRTIO_DEVICE_ID = VIRTIO_BASE + 0x008;
const auto VIRTIO_VENDOR_ID = VIRTIO_BASE + 0x00c;
const auto VIRTIO_DEVICE_FEATURES = VIRTIO_BASE + 0x010;
const auto VIRTIO_DRIVER_FEATURES = VIRTIO_BASE + 0x020;
const auto VIRTIO_GUEST_PAGE_SIZE = VIRTIO_BASE + 0x028;
const auto VIRTIO_QUEUE_SEL = VIRTIO_BASE + 0x030;
const auto VIRTIO_QUEUE_NUM_MAX = VIRTIO_BASE + 0x034;
const auto VIRTIO_QUEUE_NUM = VIRTIO_BASE + 0x038;
const auto VIRTIO_QUEUE_PFN = VIRTIO_BASE + 0x040;
const auto VIRTIO_QUEUE_NOTIFY = VIRTIO_BASE + 0x050;
const auto VIRTIO_STATUS = VIRTIO_BASE + 0x070;


const auto PAGE_SIZE = 4096;
const auto SECTOR_SIZE = 512;

const auto VIRTIO_BLK_T_IN = 0;
const auto VIRTIO_BLK_T_OUT = 1;

const auto VIRTQ_DESC_F_NEXT = 1;
const auto VIRTQ_DESC_F_WRITE = 2;
const auto VIRTQ_DESC_F_INDIRECT = 4;

struct VirtqDesc
{
    ulong addr;
    uint len;
    ushort flags;
    ushort next;
}

struct VirtqAvail
{
    ushort flags;
    ushort idx;
    ushort[DESC_NUM] ring;
    ushort usedEvent;
}

struct VirtqUsed
{
    ushort flags;
    ushort idx;
    VirtqUsedElement[DESC_NUM] ring;
    ushort availEvent;
}

struct VirtqUsedElement
{
    uint id;
    uint len;
}

struct VirtioBlkRequest
{
    uint ioType;
    uint reserved;
    ulong sector;
}

const auto MAX_BLOCK_QUEUE = 1;

struct VirtioBlock
{
    ulong id;
    uint driverFeatures;
    uint pageSize;
    uint queueSel;
    uint queueNum;
    uint queuePfn;
    uint queueNotify;
    uint status;
    ubyte[] disk;

    this(ubyte[] diskImage)
    {
        this.disk ~= diskImage;
        queueNotify = MAX_BLOCK_QUEUE;
    }

    bool isInterrupting()
    {
        if (queueNotify < MAX_BLOCK_QUEUE)
        {
            queueNotify = MAX_BLOCK_QUEUE;
            return true;
        }
        return false;
    }

    Ret load(ulong addr, ulong size)
    {
        if (size == 32)
        {
            switch (addr)
            {
                case VIRTIO_MAGIC: return Ret(0x74726976);
                case VIRTIO_VERSION: return Ret(0x1);
                case VIRTIO_DEVICE_ID: return Ret(0x2);
                case VIRTIO_VENDOR_ID: return Ret(0x554d4551);
                case VIRTIO_DEVICE_FEATURES: return Ret(0);
                case VIRTIO_DRIVER_FEATURES: return Ret(this.driverFeatures);
                case VIRTIO_QUEUE_NUM_MAX: return Ret(8);
                case VIRTIO_QUEUE_PFN: return Ret(this.queuePfn);
                case VIRTIO_STATUS: return Ret(this.status);
                default: return Ret(0);
            }
        }
        else {
            return Ret(CpuException(ExceptionCode.LoadAccessFault, addr));
        }
    }

    Ret store(ulong addr, ulong size, ulong value)
    {
        if (size == 32)
        {
            auto val = cast(uint)value;
            switch (addr)
            {
                case VIRTIO_DEVICE_FEATURES: return Ret(this.driverFeatures = val);
                case VIRTIO_GUEST_PAGE_SIZE: return Ret(this.pageSize = val);
                case VIRTIO_QUEUE_SEL: return Ret(this.queueSel = val);
                case VIRTIO_QUEUE_NUM: return Ret(this.queueNum = val);
                case VIRTIO_QUEUE_PFN: return Ret(this.queuePfn = val);
                case VIRTIO_QUEUE_NOTIFY: return Ret(this.queueNotify = val);
                case VIRTIO_STATUS: return Ret(this.status = val);
                default: return Ret(0);
            }
        }
        else {
            return Ret(CpuException(ExceptionCode.StoreAMOAccessFault, addr));
        }
    }

    ulong getNewId()
    {
        this.id++;
        return this.id;
    }

    ulong descAddr()
    {
        return cast(ulong)queuePfn * cast(ulong)pageSize;
    }

    ulong readDisk(ulong addr)
    {
        return cast(ulong)disk[addr];
    }

    ulong writeDisk(ulong addr, ulong value)
    {
        return cast(ulong)(disk[addr] = cast(ubyte)value);
    }
}