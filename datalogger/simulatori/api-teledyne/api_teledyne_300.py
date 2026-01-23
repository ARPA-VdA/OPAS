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
DEFAULT_PORT = 3003
BUFFER_SIZE = 1024

# Standard Diagnostic Mapping: Command -> (Label, Unit, Min, Max)
DIAG_MAP = {
    b'T BENCHTEMP':  ('BENCH TEMP', 'C', 40, 55),
    b'T WHEELTEMP':  ('WHEEL TEMP', 'C', 40, 55),
    b'T BOXTEMP':    ('BOX TEMP', 'C', 40, 55),
    b'T MRRATIO':    ('MR RATIO', '', 40, 55),
    b'T COSLOPE':    ('SLOPE', '', 0.9, 1.1),
    b'T COOFFSET':   ('OFFSET', '', 10, 20),
    b'T SAMPFLOW':   ('SAMP FL', 'CC/M', 100, 199),
    b'T SAMPPRESS':  ('PRES', 'IN-HG-A', 40, 60),
    b'T SAMPTEMP':   ('SAMPLE TEMP', 'C', 90, 110),
    b'T PHOTOTEMP':  ('PHT DRIVE', 'MV', -5, 0),
}


def get_wlist():
    """Returns the string of active warnings."""
    warnings = [
        'W  128:00:04  0001  SYSTEM RESET',
        'W  128:00:04  0001  SAMPLE FLOW WARN'
    ]
    return '\n\r'.join(warnings) + '\n\r'


def main():
    # Handle port assignment
    port = DEFAULT_PORT
    if len(sys.argv) == 2:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print(f"Invalid port. Using default: {port}")

    # Socket Setup
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    try:
        sock.bind((DEFAULT_ADDRESS, port))
        sock.listen(5)
        print(f"CO Server started on {DEFAULT_ADDRESS} port {port}")
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

                    # Command sanitization
                    cmd = raw_data.strip(b'\x0D\x0A ')
                    if not cmd:
                        continue
                    
                    now = datetime.now().strftime("%m/%d/%Y, %H:%M:%S")
                    print(f"[{now}] Received: {cmd}")

                    # 1. Main Gas Value
                    if cmd == b'T CO':
                        v = random.uniform(0, 75)
                        conn.sendall(f"T CO={v:.2f}UGM".encode())

                    # 2. System Mode
                    elif cmd == b'V MODE':
                        conn.sendall(f"...{status}".encode())

                    # 3. Special Diagnostics (MV/CNT Unit Toggle)
                    elif cmd in [b'T COMEAS', b'T COREF']:
                        label = "CO MEAS" if cmd == b'T COMEAS' else "CO REF"
                        v = random.uniform(40, 55)
                        # Simulates MV/CNT alternation based on a 50/50 random choice
                        unit = random.choice(['MV', 'CNT'])
                        conn.sendall(f"T {label}={v:.1f} {unit}".encode())

                    # 4. Standard Diagnostics (Mapping)
                    elif cmd in DIAG_MAP:
                        label, unit, v_min, v_max = DIAG_MAP[cmd]
                        v = random.uniform(v_min, v_max)
                        fmt = ".4f" if "SLOPE" in label or "OFFSET" in label else ".1f"
                        resp = f"T {label}={v:{fmt}} {unit}".strip()
                        conn.sendall(resp.encode())

                    # 5. Calibration Commands
                    elif b'C ZERO' in cmd:
                        status = 'ZERO'
                        conn.sendall(b"...ST_SYSTEM_OK=ON")
                    elif b'C SPAN' in cmd:
                        status = 'SPAN'
                        conn.sendall(b"...ST_SYSTEM_OK=ON")
                    elif b'C EXIT' in cmd:
                        status = 'SAMPLE'
                        conn.sendall(b"...ST_SYSTEM_OK=ON")

                    # 6. Warning List
                    elif b'W LIST' in cmd:
                        conn.sendall(get_wlist().encode())
                    elif b'W CLEAR' in cmd:
                        print("Warnings cleared")

                    # 7. Fallback
                    else:
                        conn.sendall(raw_data)

            except Exception as e:
                print(f"Session error: {e}")
            finally:
                conn.close()

    except KeyboardInterrupt:
        print("\nShutting down server...")
    finally:
        sock.close()


if __name__ == '__main__':
    main()