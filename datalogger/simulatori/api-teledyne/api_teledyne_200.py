#!/ user/bin/env python3
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
DEFAULT_PORT = 3002
BUFFER_SIZE = 1024

# Diagnostic Mapping: Command -> (Instrument Label, Unit, Min, Max)
DIAG_MAP = {
    b'T SAMPFLOW':   ('SAMP FLW', 'CC/M', 100, 199),
    b'T OZONEFLOW':  ('OZONE FL', 'CC/M', -10, -1),
    b'T RCELLTEMP':  ('RCELL TEMP', 'C', 0.9, 1.1),
    b'T BOXTEMP':    ('BOX TEMP', 'C', 20, 35),
    b'T PMTTEMP':    ('PMT TEMP', 'C', 90, 110),
    b'T CONVTEMP':   ('MOLY TEMP', 'C', -5, 0),
    b'T RCELLPRESS': ('RCEL', 'IN-HG-A', -880, -800),
    b'T SAMPPRESS':  ('SAMP', 'IN-HG-A', 40, 60),
    b'T NOXSLOPE':   ('NOX SLOPE', '', 40, 55),
    b'T NOXOFFSET':  ('NOX OFFS', 'MV', 40, 55),
    b'T NOSLOPE':    ('NO SLOPE', '', 40, 55),
    b'T NOOFFSET':   ('NO OFFS', 'MV', 40, 55),
    b'T AUTOZERO':   ('AZERO', 'MV', 40, 55),
    b'T HVPS':       ('HVPS', 'V', 40, 55),
}


def get_wlist():
    """Returns the formatted string of active warnings."""
    warnings = [
        'W  128:00:04  0001  SYSTEM RESET',
        'W  128:00:04  0001  SAMPLE FLOW WARN',
        'W  128:00:04  0001  OZONE FLOW WARNING',
        'W  128:00:04  0001  RCELL PRESS WARN',
        'W  128:00:04  0001  IZS TEMP WARNING'
    ]
    return '\n\r'.join(warnings) + '\n\r'


def main():
    # Determine port
    port = DEFAULT_PORT
    if len(sys.argv) == 2:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print(f"Invalid port. Using default: {port}")

    # Socket Initialization
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    try:
        sock.bind((DEFAULT_ADDRESS, port))
        sock.listen(5)
        print(f"NOx Server started on {DEFAULT_ADDRESS} port {port}")
    except Exception as e:
        print(f"Error starting server: {e}")
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

                    # Command cleanup (stripping \r, \n and spaces)
                    cmd = raw_data.strip(b'\x0D\x0A ')
                    
                    now = datetime.now().strftime("%m/%d/%Y, %H:%M:%S")
                    print(f"[{now}] Received: {cmd}")

                    if not cmd:
                        continue

                    # 1. Main Values (Gas)
                    if cmd == b'T NOX':
                        v = random.uniform(0, 75)
                        conn.sendall(f"T NOX={v:.2f}UGM".encode())

                    elif cmd == b'T NO':
                        v = random.uniform(0, 65)
                        conn.sendall(f"T NO={v:.2f}UGM".encode())

                    elif cmd == b'T NO2':
                        v = random.uniform(0, 25)
                        conn.sendall(f"T NO2={v:.2f}UGM".encode())

                    # 2. System Mode
                    elif cmd == b'V MODE':
                        conn.sendall(f"...{status}".encode())

                    # 3. Diagnostics (Using Mapping)
                    elif cmd in DIAG_MAP:
                        label, unit, v_min, v_max = DIAG_MAP[cmd]
                        v = random.uniform(v_min, v_max)
                        # Formatting: 4 decimal places for slope, 1 for others
                        fmt = ".4f" if "SLOPE" in label else ".1f"
                        response = f"T {label}={v:{fmt}} {unit}".strip()
                        conn.sendall(response.encode())

                    # 4. Calibration Commands
                    elif b'C ZERO' in cmd:
                        status = 'ZERO'
                        conn.sendall(b"...ST_SYSTEM_OK=ON")

                    elif b'C SPAN' in cmd:
                        status = 'SPAN'
                        conn.sendall(b"...ST_SYSTEM_OK=ON")

                    elif b'C EXIT' in cmd:
                        status = 'SAMPLE'
                        conn.sendall(b"...ST_SYSTEM_OK=ON")

                    # 5. Warning List
                    elif b'W LIST' in cmd:
                        conn.sendall(get_wlist().encode())

                    elif b'W CLEAR' in cmd:
                        print("Warnings cleared")

                    # 6. Fallback (Echo)
                    else:
                        conn.sendall(raw_data)

            except Exception as e:
                print(f"Error during session: {e}")
            finally:
                conn.close()
                print(f"Connection with {addr} closed.")

    except KeyboardInterrupt:
        print("\nShutting down server...")
    finally:
        sock.close()


if __name__ == '__main__':
    main()