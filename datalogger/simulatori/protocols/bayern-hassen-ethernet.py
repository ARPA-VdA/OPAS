#!/usr/bin/env python3
# ----------------------------------------------------------------------
#  Copyright (c) 1995-2025, Ecometer s.n.c.
#  Author: Paolo Saudin.
#  Date  : 2025-12-31
# ----------------------------------------------------------------------

"""
Main template script for TCP communication with Ecometer instruments.
"""

import os
import socket
import sys
import time

# ----------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------
CR = "\r"
LF = "\n"
CRLF = "\r\n"
TAB = "\t"
SEMICOLON = ";"
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

# Network Settings
TCP_IP = '192.168.168.47'
TCP_PORT = 32783
BUFFER_SIZE = 1024


def get_bcc(msg: str) -> str:
    """
    Calculate the BCC, split into nibbles, and return as hex string.
    """
    bcc_val = 0
    for char in msg:
        bcc_val ^= ord(char)

    print(f"BCC decimal: {bcc_val}")
    
    # Convert to hex string (2 characters, uppercase)
    # This replaces the manual nibble shifting for clarity
    bcc_hex = f"{bcc_val:02X}"
    
    print(f"BCC hex: {bcc_hex}")
    return bcc_hex


def main():
    """
    Main execution logic for instrument communication.
    """
    # Protocol: <STX><text><ETX><bcc1><bcc2>
    
    # Command: Byte(n=4) - R001 [Instantaneous value acquisition command]
    cmd_body = "DA044"
    
    # Calculate checksum on STX + Command + ETX
    fcs = get_bcc(STX + cmd_body + ETX)
    
    # Build full message
    message_str = STX + cmd_body + ETX + fcs
    message_bytes = message_str.encode('ascii')
    
    print(f"Sending message: {message_bytes}")

    # Socket communication
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(2.0)

    try:
        print(f"Connecting to {TCP_IP}:{TCP_PORT}...")
        s.connect((TCP_IP, TCP_PORT))

        print("Sending data...")
        s.sendall(message_bytes)
        
        # Brief pause to allow instrument processing
        time.sleep(0.5)

        print("Waiting for response...")
        data = s.recv(BUFFER_SIZE)
        
        if data:
            print(f"Received data (raw): {data}")
            # print(f"Received data (decoded): {data.decode(errors='ignore')}")
        else:
            print("No data received from instrument.")

    except socket.timeout:
        print("Timeout: The instrument did not respond.")
    except socket.error as e:
        print(f"Socket error: {e}")
    finally:
        print("Closing connection.")
        s.close()


if __name__ == '__main__':
    main()