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
DEFAULT_PORT = 3004
BUFFER_SIZE = 1024
CRLF = "\x0D\x0A"

# Diagnostic Mapping: Command -> (Instrument Label, Unit, Min, Max)
DIAG_MAP = {
    b'T PHOTOMEAS':   ('MEAS', 'MV', 40, 55),
    b'T PHOTOREF':    ('REF', 'MV', 40, 55),
    b'T O3GENREF':    ('GEN', 'MV', 40, 55),
    b'T O3GENDRIVE':  ('DRIVE', 'MV', 40, 55),
    b'T SAMPPRESS':   ('PRES', 'IN-HG-A', 40, 60),
    b'T SAMPFLOW':    ('SAMP FL', 'CC/M', 100, 199),
    b'T SAMPTEMP':    ('SAMPLE TEMP', 'C', 90, 110),
    b'T PHOTOLTEMP':  ('PHOTO LAMP', 'C', -5, 0),
    b'T O3GENTEMP':   ('O3 GEN TMP', 'C', 40, 55),
    b'T BOXTEMP':     ('BOX TEMP', 'C', 40, 55),
    b'T SLOPE':       ('SLOPE', '', 0.9, 1.1),
    b'T OFFSET':      ('OFFSET', 'PPB', 10, 20),
}


def get_wlist():
    """Returns the formatted list of system warnings."""
    warnings = [
        'W  128:00:04  0001  SYSTEM RESET',
        'W  128:00:04  0001  SAMPLE FLOW WARN',
        'W  128:00:04  0001  OZONE FLOW WARNING',
        'W  128:00:04  0001  RCELL PRESS WARN',
        'W  128:00:04  0001  IZS TEMP WARNING'
    ]
    return '\n\r'.join(warnings) + '\n\r'


def main():
    # Handle port assignment
    port = DEFAULT_PORT
    if len(sys.argv) == 2:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print(f"Invalid port, using default: {port}")

    # Socket Initialization
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    try:
        sock.bind((DEFAULT_ADDRESS, port))
        sock.listen(5)
        print(f"O3 Server started on {DEFAULT_ADDRESS} port {port}")
    except Exception as e:
        print(f"Critical error starting server: {e}")
        return

    try:
        while True:
            print("\nWaiting for connection...")
            conn, addr = sock.accept()
            status = 'SAMPLE'

            try:
                print(f"Connected to {addr}")
                while True:
                    raw_data = conn.recv(BUFFER_SIZE)
                    if not raw_data:
                        break

                    # Received command sanitization
                    cmd = raw_data.strip(b'\x0D\x0A ')
                    if not cmd:
                        continue

                    now = datetime.now().strftime("%m/%d/%Y, %H:%M:%S")
                    print(f"[{now}] Received: {cmd}")

                    # 1. Main Ozone value
                    if cmd == b'T O3':
                        v = random.uniform(0, 75)
                        conn.sendall(f"T O3={v:.2f}UGM".encode())

                    # 2. System Mode
                    elif cmd == b'V MODE':
                        conn.sendall(f"...{status}".encode())

                    # 3. Diagnostics (from Mapping)
                    elif cmd in DIAG_MAP:
                        label, unit, v_min, v_max = DIAG_MAP[cmd]
                        v = random.uniform(v_min, v_max)
                        fmt = ".4f" if label == "SLOPE" else ".1f"
                        # Build response with CRLF terminator as per original specification
                        resp = f"T {label}={v:{fmt}} {unit}".strip() + CRLF
                        conn.sendall(resp.encode())

                    # 4. Calibration
                    elif b'C ZERO' in cmd:
                        status = 'ZERO'
                        conn.sendall(b"...ST_SYSTEM_OK=ON")
                    elif b'C SPAN' in cmd:
                        status = 'SPAN'
                        conn.sendall(b"...ST_SYSTEM_OK=ON")
                    elif b'C EXIT' in cmd:
                        status = 'SAMPLE'
                        conn.sendall(b"...ST_SYSTEM_OK=ON")

                    # 5. Warnings
                    elif b'W LIST' in cmd:
                        conn.sendall(get_wlist().encode())
                    elif b'W CLEAR' in cmd:
                        print("Warnings cleared")

                    # 6. Fallback (Echo)
                    else:
                        conn.sendall(raw_data)

            except Exception as e:
                print(f"Session error: {e}")
            finally:
                conn.close()

    except KeyboardInterrupt:
        print("\nShutting down O3 server...")
    finally:
        sock.close()


if __name__ == '__main__':
    main()