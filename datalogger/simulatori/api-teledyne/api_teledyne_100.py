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
DEFAULT_PORT = 3001
BUFFER_SIZE = 1024


def get_wlist():
    """Returns a formatted list of system warnings."""
    # Note: Maintained as a single-entry list for now, 
    # but structured for future expansion.
    warnings = [
        'W  128:00:04  0001  SYSTEM RESET'
    ]
    return "\n\r".join(warnings) + "\n\r"


def main():
    # Handle command-line port argument
    port = DEFAULT_PORT
    if len(sys.argv) == 2:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print(f"Invalid port: {sys.argv[1]}. Using default port {DEFAULT_PORT}")

    # Create a TCP/IP socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    try:
        server_address = (DEFAULT_ADDRESS, port)
        print(f"Starting up on {server_address[0]} port {server_address[1]}")
        sock.bind(server_address)
    except Exception as e:
        print(f"Error during bind: {e}")
        sys.exit(1)

    sock.listen(5)

    try:
        while True:
            print("\nWaiting for a connection...")
            connection, client_address = sock.accept()
            status = 'SAMPLE'

            try:
                print(f"Connection from {client_address}")

                while True:
                    raw_data = connection.recv(BUFFER_SIZE)
                    if not raw_data:
                        print(f"No more data from {client_address}")
                        break

                    # Command sanitization (strip CR/LF and leading/trailing whitespaces)
                    data = raw_data.strip(b'\r\n ')
                    
                    now = datetime.now()
                    date_time = now.strftime("%m/%d/%Y, %H:%M:%S")
                    print(f"Received @ {date_time} -> {data}")

                    # --- Response Logic ---
                    
                    # Main values
                    if data == b'T SO2':
                        v = random.uniform(0, 75)
                        connection.sendall(f"T SO2={v:.2f}UGM".encode())

                    # System status
                    elif data == b'V MODE':
                        print(f"Sending mode: {status}")
                        connection.sendall(f"...{status}".encode())

                    # Diagnostics (grouped by similarity)
                    elif data == b'T SAMPPRESS':
                        v = random.uniform(40, 60)
                        connection.sendall(f"T PRES={v:.2f} IN-HG-A".encode())

                    elif data == b'T SAMPFLOW':
                        v = random.uniform(100, 199)
                        connection.sendall(f"T FL={v:.2f} CC/M".encode())

                    elif data in [b'T PMTDET', b'T UVDET', b'T OFFSET', b'T DCPS']:
                        labels = {b'T PMTDET': 'PMT', b'T UVDET': 'LAMP', 
                                 b'T OFFSET': 'OFFSET', b'T DCPS': 'DCPS'}
                        v = random.uniform(40, 55)
                        connection.sendall(f"T {labels[data]}={v:.2f} MV".encode())

                    elif data == b'T SLOPE':
                        v = random.uniform(40, 55)
                        connection.sendall(f"T SLOPE={v:.4f}".encode())

                    elif data in [b'T RCELLTEMP', b'T BOXTEMP', b'T PMTTEMP']:
                        labels = {b'T RCELLTEMP': 'RCELL TEMP', 
                                 b'T BOXTEMP': 'BOX TEMP', 
                                 b'T PMTTEMP': 'PMT TEMP'}
                        v = random.uniform(40, 110)
                        connection.sendall(f"T {labels[data]}={v:.1f} C".encode())

                    elif data == b'T HVPS':
                        v = random.uniform(1000, 1500)
                        connection.sendall(f"T HVPS={v:.1f} VOLTS".encode())

                    # Calibration Commands
                    elif b'C ZERO' in data:
                        print("---- Setting status: ZERO ----")
                        status = 'ZERO'
                        connection.sendall(b"...ZERO")

                    elif b'C SPAN' in data:
                        print("---- Setting status: SPAN ----")
                        status = 'SPAN'
                        connection.sendall(b"...SPAN")

                    elif b'C EXIT' in data:
                        print("---- Setting status: SAMPLE ----")
                        status = 'SAMPLE'
                        connection.sendall(b"...SAMPLE")

                    # Warnings
                    elif b'W LIST' in data:
                        print("---- Sending warning list ----")
                        w_list = get_wlist()
                        connection.sendall(w_list.encode())

                    elif b'W CLEAR' in data:
                        print("---- Clearing warnings ----")
                        # connection.sendall(b'OK')

                    else:
                        # Fallback: echo for unrecognized commands
                        connection.sendall(raw_data)

            except Exception as e:
                print(f"Error during session with {client_address}: {e}")
            finally:
                connection.close()

    except KeyboardInterrupt:
        print("\nServer shutting down...")
    finally:
        sock.close()


if __name__ == '__main__':
    main()