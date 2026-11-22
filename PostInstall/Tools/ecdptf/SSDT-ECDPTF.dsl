/*
 * SSDT-ECDPTF: tell the Dell embedded controller that a DPTF/DTT client is present.
 *
 * The firmware only does this itself when an OS evaluates Intel's Dynamic Tuning _OSC
 * (SSDT "DptfTabl": \_SB.PC00.LPCB.ECDV.DPST(1)); macOS never does, so EC register 0x32 stays 0.
 * With it at 0 the platform alternates the package between PL1 (18 W) and about 5.8 W / 400 MHz
 * every ~58 s under sustained load (measured: MSR 0x64F reports PL1 in both phases, nothing
 * thermal). With DPST(1) the same load holds 18 W / ratio 32-34 for the whole run.
 *
 * Idempotent: only writes when the register is not already 1. _STA/_INI are evaluated by the OS
 * during device enumeration; the write itself goes through ECW1, which works before the EC
 * region is up.
 */
DefinitionBlock ("", "SSDT", 2, "CUSTOM", "ECDPTF", 0x00000001)
{
    External (\_SB.PC00.LPCB.ECDV.DPST, MethodObj)
    External (\_SB.PC00.LPCB.ECDV.DPRT, MethodObj)

    Scope (\_SB)
    {
        Device (DPEC)
        {
            Name (_HID, "DPEC0000")  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (APPL, 0, Serialized)
            {
                If (CondRefOf (\_SB.PC00.LPCB.ECDV.DPRT))
                {
                    If (\_SB.PC00.LPCB.ECDV.DPRT () != One)
                    {
                        \_SB.PC00.LPCB.ECDV.DPST (One)
                    }
                }
            }

            Method (_INI, 0, NotSerialized)  // _INI: Initialize
            {
                APPL ()
            }

            Method (_STA, 0, NotSerialized)  // _STA: Status
            {
                APPL ()
                Return (0x0F)
            }
        }
    }
}
