/*
 * SSDT-PEPD-STA: make the firmware's Power Engine device visible to macOS.
 *
 * \_SB.PEPD (_HID INT33A1, _CID PNP0D80) reports itself present only when OSYS >= 0x07DF
 * (the OS answered _OSI "Windows 2015") or (OSYS >= 0x07DC and S0ID == 1). macOS answers
 * neither, so S0ixStandby (which matches PNP0D80) never sees it. An OpenCore ACPI patch
 * renames the original method to XSTA; this table adds a new _STA that reports the device
 * present for Darwin and otherwise calls the original.
 *
 * Needs the matching ACPI > Patch entry (see README.md). Without it this table does nothing
 * useful, so keep the two together.
 */
DefinitionBlock ("", "SSDT", 2, "S0IX", "PEPDSTA", 0x00001000)
{
    External (\_SB.PEPD, DeviceObj)
    External (\_SB.PEPD.XSTA, MethodObj)

    Scope (\_SB.PEPD)
    {
        Method (_STA, 0, NotSerialized)
        {
            If (_OSI ("Darwin"))
            {
                Return (0x0F)
            }

            Return (XSTA ())
        }
    }
}
