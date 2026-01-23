#!/usr/bin/env python3
# ----------------------------------------------------------------------
#  Copyright (c) 1995-2025, Ecometer s.n.c.
#  Author: Paolo Saudin.
#  Date  : 2025-12-31
# ----------------------------------------------------------------------

"""
Main template script for packet generation and BCC calculation.
"""

import os
import sys
import time

# ----------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------
CR = "\r"
LF = "\n"
CRLF = "\r\n"
TAB = "\t"
STX = chr(2)
ETX = chr(3)
EOT = chr(4)
ENQ = chr(5)
ACK = chr(6)
EOB = chr(3)
SOH = chr(14)
NAK = chr(21)
SYN = chr(22)
ETB = chr(23)


def get_bcc(data: str) -> int:
    """
    Calculate the BCC (Block Check Character) using XOR logic.
    """
    bcc = 0
    for char in data:
        bcc = bcc ^ ord(char)
    return bcc


def main():
    """
    Main entry point of the script.
    """
    # Protocol format: <STX><text><ETX><bcc1><bcc2>
    req = STX + 'DA044' + ETX
    print(f'req: {req}')

    # Get command checksum
    checksum = get_bcc(req)
    crc = f"{checksum:02X}"
    print(f'crc: {crc}')

    # Construct final command
    cmd = req + crc
    print(f'cmd: {cmd}')

    # Write to file
    try:
        with open("packet.dat", "a", encoding="utf-8") as f:
            f.write(cmd)
    except IOError as e:
        print(f"Error writing to file: {e}")


if __name__ == '__main__':
    main()
