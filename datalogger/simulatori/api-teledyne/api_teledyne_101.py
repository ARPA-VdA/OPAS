#!/usr/bin/env python3
# ----------------------------------------------------------------------
#  Copyright (c) 1995-2025, Ecometer s.n.c.
#  Author: Paolo Saudin.
#  Date  : 2025-12-31
# ----------------------------------------------------------------------

import sys
import random
import socket
from datetime import datetime

# --- Configuration ---
DEFAULT_ADDRESS = '192.168.168.47'
DEFAULT_PORT = 3005
BUFFER_SIZE = 1024

# Diagnostic commands mapping: Command -> (Label, Unit, Min_Range, Max_Range)
DIAG_MAP = {
    b'T SAMPPRESS':   ('PRES', 'IN-HG-A', 40, 60),
    b'T SAMPFLOW':    ('SAMP FL', 'CC/M', 100, 199),
    b'T PMTDET':      ('PMT', 'MV', 40, 55),
    b'T NORMPMTDET':  ('NORM PMT', 'MV', 40, 55),
    b'T UVDET':       ('UV LAMP', 'MV', 2200, 2400),
    b'T LAMPRATIO':   ('LAMP RATIO', '%', 40, 60),
    b'T STRAYLIGHT':  ('STR. LGT', 'PPB', 5, 15),
    b'T DARKPMT':     ('DRK PMT', 'MV', 10, 30),
    b'T DARKLAMP':    ('DRK LMP', 'MV', 1, 5),
    b'T SO2SLOPE':    ('SO2 SLOPE', '', 0.9, 1.1),
    b'T SO2OFFSET':   ('SO2 OFFS', 'MV', 10, 20),
    b'T H2SSLOPE':    ('H2S SLOPE', '', 0.9, 1.1),
    b'T H2SOFFSET':   ('H2S OFFS', 'MV', 10, 20),
    b'T HVPS':        ('HVPS', 'VOLTS', 500, 1500),
    b'T RCELLTEMP':   ('RCELL TEMP', 'C', 45, 55),
    b'T BOXTEMP':     ('BOX TEMP', 'C', 30, 40),
    b'T PMTTEMP':     ('PMT TEMP', 'C', 5, 15),
    b'T IZSTEMP':     ('IZS TEMP', 'C', 45, 55),
    b'T STABILITY':   ('H2S STB', 'PPB', 0, 1),
}


def get_wlist():
    """Returns the list of system warnings."""
    warnings = [
        'W  128:00:04  0001  SYSTEM RESET',
        'W  128:00:04  0001  SAMPLE FLOW WARN',
        'W  128:00:04  0001  OZONE FLOW WARNING',
        'W  128:00:04  0001  RCELL PRESS WARN',
        'W  128:00:04  0001  IZS TEMP WARNING'
    ]
    return '\n\r'.join(warnings) + '\n\r'


def main():
    # Handle port from command-line arguments
    port = DEFAULT_PORT
    if len(sys.argv) == 2:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print(f"Invalid port, using default: {port}")

    # Socket Setup
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        sock.bind((DEFAULT_ADDRESS, port))
        sock.listen(5)
        print(f"Starting up on {DEFAULT_ADDRESS} port {port}")
    except Exception as e:
        print(f"Failed to start server: {e}")
        return

    try:
        while True:
            print("\nWaiting for a connection...")
            connection, client_address = sock.accept()
            status = 'SAMPLE'

            try:
                print(f"Connected by {client_address}")
                while True:
                    raw_data = connection.recv(BUFFER_SIZE)
                    if not raw_data:
                        break

                    # Command sanitization
                    cmd = raw_data.strip(b'\x0D\x0A\x20')
                    
                    now = datetime.now().strftime("%m/%d/%Y, %H:%M:%S")
                    print(f"[{now}] Recv: {cmd}")

                    if not cmd:
                        continue

                    # --- Response Logic ---
                    
                    # 1. Main Gas values
                    if cmd == b'T SO2':
                        v = random.uniform(0, 75)
                        connection.sendall(f"T SO2={v:.2f}UGM".encode())

                    elif cmd == b'T H2S':
                        v = random.uniform(0, 75)
                        connection.sendall(f"T H2S={v:.2f}UGM".encode())

                    # 2. System Mode
                    elif cmd == b'V MODE':
                        connection.sendall(f"...{status}".encode())

                    # 3. Diagnostics (Automatic Mapping)
                    elif cmd in DIAG_MAP:
                        label, unit, v_min, v_max = DIAG_MAP[cmd]
                        v = random.uniform(v_min, v_max)
                        # Formatting: 1 decimal place for temperature/voltage, 
                        # 4 decimal places for slope, otherwise 1.
                        fmt = ".4f" if "SLOPE" in label else ".1f"
                        resp = f"T {label}={v:{fmt}} {unit}".strip()
                        connection.sendall(resp.encode())

                    # 4. Calibration
                    elif b'C ZERO' in cmd:
                        status = 'ZERO'
                        connection.sendall(b"...ZERO")
                    elif b'C SPAN' in cmd:
                        status = 'SPAN'
                        connection.sendall(b"...SPAN")
                    elif b'C EXIT' in cmd:
                        status = 'SAMPLE'
                        connection.sendall(b"...SAMPLE")

                    # 5. Warnings
                    elif b'W LIST' in cmd:
                        connection.sendall(get_wlist().encode())
                    elif b'W CLEAR' in cmd:
                        print("Warnings cleared (simulated)")

                    # 6. Fallback (Echo)
                    else:
                        connection.sendall(raw_data)

            except Exception as e:
                print(f"Session error: {e}")
            finally:
                connection.close()
                print(f"Connection with {client_address} closed.")

    except KeyboardInterrupt:
        print("\nServer shutting down...")
    finally:
        sock.close()


if __name__ == '__main__':
    main()