/*
 * SSDT-PL1: raise the package RAPL limits (PL1/PL2) at boot.
 *
 * The Latitude 5320 firmware leaves PL1 very low under macOS (powermetrics:
 * "CPU LIMIT PL1", ~6 W, ~550 MHz at full load). macOS has no DPTF driver,
 * so nothing raises it. The DSDT already maps the package RAPL registers at
 * MCHBAR+0x5000 (region \CPWR); this table writes PACKAGE_RAPL_LIMIT
 * (MCHBAR+0x59A0, mirror of MSR 0x610) once.
 *
 * Safe by construction: ACPI only (no kext, no MSR access from the kernel),
 * never lowers a limit, and does nothing if the lock bit (63) is set.
 * Rollback: remove SSDT-PL1.aml from config.plist.
 */
DefinitionBlock ("", "SSDT", 2, "CUSTOM", "PL1TUNE", 0x00000001)
{
    External (CPWR, OpRegionObj)

    Scope (\_SB)
    {
        Device (PL1T)
        {
            Name (_HID, "PL1T0000")
            Name (_UID, Zero)

            Name (PL1W, 18)      // target PL1, watts (Windows Ultra Performance sustains 18 W on this chassis)
            Name (PL2W, 28)      // target PL2, watts
            Name (DONE, Zero)

            Field (\CPWR, DWordAcc, NoLock, Preserve)
            {
                Offset (0x938),
                PWUN,   32,      // MSR_RAPL_POWER_UNIT low dword
                Offset (0x9A0),
                PL1V,   32,      // PACKAGE_RAPL_LIMIT bits 31:0  (PL1)
                PL2V,   32       // PACKAGE_RAPL_LIMIT bits 63:32 (PL2, lock = bit 31)
            }

            Method (APPL, 0, Serialized)
            {
                If (DONE)
                {
                    Return (Zero)
                }

                DONE = One
                Local0 = PL1V
                Local1 = PL2V
                If ((Local1 & 0x80000000))
                {
                    Return (Zero)             // locked by firmware
                }

                Local2 = (PWUN & 0x0F)
                If (((Local2 < 0x02) || (Local2 > 0x08)))
                {
                    Return (Zero)             // region not backed / implausible unit
                }

                If ((Local0 == Zero))
                {
                    Return (Zero)             // PL1 register reads empty: not real
                }

                Local2 = (One << Local2)          // RAPL units per watt
                Local3 = (Local2 * PL1W)
                Local4 = (Local2 * PL2W)
                If ((Local3 > 0x7FFF))
                {
                    Local3 = 0x7FFF
                }

                If ((Local4 > 0x7FFF))
                {
                    Local4 = 0x7FFF
                }

                If ((Local3 > (Local0 & 0x7FFF)))
                {
                    PL1V = ((Local0 & 0xFFFF8000) | Local3 | 0x18000)
                }

                If ((Local4 > (Local1 & 0x7FFF)))
                {
                    PL2V = ((Local1 & 0xFFFF8000) | Local4 | 0x18000)
                }

                Return (Zero)
            }

            Method (_INI, 0, NotSerialized)
            {
                APPL ()
            }

            Method (_STA, 0, NotSerialized)
            {
                APPL ()
                Return (0x0F)
            }
        }
    }
}
