import ctypes
import ctypes.wintypes as wintypes

# Adjust the path to match your drive
physical_drive_path = r"\\.\PhysicalDrive10"

# Constants from Windows headers
GENERIC_READ  = 0x80000000
GENERIC_WRITE = 0x40000000
FILE_SHARE_READ  = 1
FILE_SHARE_WRITE = 2
OPEN_EXISTING = 3

IOCTL_SCSI_PASS_THROUGH = 0x4D004

SCSI_IOCTL_DATA_IN = 1
INQUIRY_CMD = 0x12
INQUIRY_CMDLEN = 6

# We request page 0x83 (Device Identification VPD)
VPD_PAGE = 0x83
EVPD_BIT = 0x01  # EVPD=1 to request VPD pages
ALLOCATION_LENGTH = 0xFF  # 255 bytes, adjust if needed

# Structures

class SCSI_PASS_THROUGH(ctypes.Structure):
    _fields_ = [
        ("Length", wintypes.USHORT),
        ("ScsiStatus", ctypes.c_ubyte),
        ("PathId", ctypes.c_ubyte),
        ("TargetId", ctypes.c_ubyte),
        ("Lun", ctypes.c_ubyte),
        ("CdbLength", ctypes.c_ubyte),
        ("SenseInfoLength", ctypes.c_ubyte),
        ("DataIn", ctypes.c_ubyte),
        ("DataTransferLength", wintypes.ULONG),
        ("TimeOutValue", wintypes.ULONG),
        ("DataBufferOffset", wintypes.ULONG),
        ("SenseInfoOffset", wintypes.ULONG),
    ]

kernel32 = ctypes.WinDLL('kernel32', use_last_error=True)

kernel32.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                 wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD,
                                 wintypes.HANDLE]
kernel32.CreateFileW.restype = wintypes.HANDLE

kernel32.DeviceIoControl.argtypes = [wintypes.HANDLE, wintypes.DWORD, wintypes.LPVOID,
                                     wintypes.DWORD, wintypes.LPVOID, wintypes.DWORD,
                                     ctypes.POINTER(wintypes.DWORD), wintypes.LPVOID]
kernel32.DeviceIoControl.restype = wintypes.BOOL

kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
kernel32.CloseHandle.restype = wintypes.BOOL

def open_handle(path):
    handle = kernel32.CreateFileW(path,
                                  GENERIC_READ | GENERIC_WRITE,
                                  FILE_SHARE_READ | FILE_SHARE_WRITE,
                                  None,
                                  OPEN_EXISTING,
                                  0,
                                  None)
    if handle == wintypes.HANDLE(-1).value:
        raise OSError(f"Failed to open handle to {path}, error: {ctypes.get_last_error()}")
    return handle

def get_vpd_data(physical_drive):
    handle = open_handle(physical_drive)
    try:
        # Prepare SCSI CDB for INQUIRY (EVPD=1, Page=0x83)
        cdb = (ctypes.c_ubyte * 16)()
        for i in range(16):
            cdb[i] = 0
        cdb[0] = INQUIRY_CMD
        cdb[1] = EVPD_BIT
        cdb[2] = VPD_PAGE
        cdb[3] = 0x0
        cdb[4] = ALLOCATION_LENGTH
        cdb[5] = 0x0

        spt = SCSI_PASS_THROUGH()
        spt.Length = ctypes.sizeof(SCSI_PASS_THROUGH)
        spt.CdbLength = INQUIRY_CMDLEN
        spt.DataIn = SCSI_IOCTL_DATA_IN
        spt.TimeOutValue = 2
        spt.DataTransferLength = ALLOCATION_LENGTH
        spt.DataBufferOffset = ctypes.sizeof(SCSI_PASS_THROUGH) + 16
        spt.SenseInfoOffset = 0

        buffer_size = ctypes.sizeof(SCSI_PASS_THROUGH) + 16 + ALLOCATION_LENGTH
        buffer = (ctypes.c_ubyte * buffer_size)()
        # Copy spt into buffer
        ctypes.memmove(ctypes.addressof(buffer), ctypes.addressof(spt), ctypes.sizeof(SCSI_PASS_THROUGH))
        # Copy cdb
        ctypes.memmove(ctypes.addressof(buffer) + ctypes.sizeof(SCSI_PASS_THROUGH), ctypes.addressof(cdb), 16)

        bytes_returned = wintypes.DWORD(0)
        if not kernel32.DeviceIoControl(handle,
                                        IOCTL_SCSI_PASS_THROUGH,
                                        buffer, buffer_size,
                                        buffer, buffer_size,
                                        ctypes.byref(bytes_returned),
                                        None):
            raise OSError(f"DeviceIoControl failed: {ctypes.get_last_error()}")

        data_offset = ctypes.sizeof(SCSI_PASS_THROUGH) + 16
        inquiry_data = bytes(buffer[data_offset:data_offset+ALLOCATION_LENGTH])
        return inquiry_data
    finally:
        kernel32.CloseHandle(handle)

def parse_vpd_page_83(inquiry_data):
    # According to SCSI SPC:
    # Byte0 = Page Code (should be 0x83)
    # Byte1 = Reserved
    # Byte2-3 = Page Length
    # Then "Page Length" bytes of descriptors
    if inquiry_data[0] != VPD_PAGE:
        raise ValueError("Not a VPD 0x83 page")
    page_length = (inquiry_data[2] << 8) | inquiry_data[3]
    descriptors = inquiry_data[4:4+page_length]

    # Each descriptor:
    # Byte0: [7:4 protocol id][3:0 code set]
    # Byte1: [7:PIV][6:4 reserved][3:2 Association][1:0 IdentifierType]
    # Byte2-3: reserved
    # Byte4: Identifier length
    # Byte5...: Identifier (ASCII if code set=1)

    idx = 0
    serial_candidates = []
    while idx < len(descriptors):
        if idx + 5 > len(descriptors):
            break
        byte0 = descriptors[idx]
        code_set = byte0 & 0x0F
        byte1 = descriptors[idx+1]
        association = (byte1 >> 4) & 0x3
        identifier_type = byte1 & 0x0F

        id_length = descriptors[idx+4]
        end_idx = idx + 5 + id_length
        if end_idx > len(descriptors):
            break

        identifier = descriptors[idx+5:end_idx]

        # If code_set=1 (ASCII), association=2 (target device), and identifier_type often 2 or 8 for serial
        # Let's just gather ASCII identifiers and see which fits best.
        if code_set == 1:  # ASCII
            text_id = identifier.decode('ascii', errors='ignore').strip()
            # If it looks like a serial (not empty and somewhat alphanumeric), consider it a candidate
            if text_id and association in (1,2):  
                # Association 2 usually means the device itself
                serial_candidates.append(text_id)

        idx = end_idx

    # Return the longest candidate or all candidates.
    # Usually the unit serial number is a clear ASCII string under association=2.
    # If multiple candidates, pick the first with association=2 if not filtered above.
    return serial_candidates

if __name__ == "__main__":
    data = get_vpd_data(physical_drive_path)
    serials = parse_vpd_page_83(data)
    if serials:
        print("Potential Serial Number(s):", serials)
    else:
        print("No ASCII serial candidates found in VPD page 0x83.")