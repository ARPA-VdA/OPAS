#!/usr/bin/env python3
# ----------------------------------------------------------------------
#  Copyright (c) 1995-2026, Ecometer s.n.c.
#  Author: Paolo Saudin.
#  Date  : 2026-07-31
# ----------------------------------------------------------------------
import sys
import random
import socket
import re
from datetime import datetime

# --- Configuration ---
DEFAULT_ADDRESS = '192.168.168.47'
DEFAULT_PORT = 53700
BUFFER_SIZE = 1024

# Protocol constants
SOH = chr(0x01)
STX = chr(0x02)
ETX = chr(0x03)


def get_bcc(data):
    """Calculate BCC (Block Check Character) - XOR of all bytes"""
    if isinstance(data, str):
        data = data.encode()
    result = 0
    for byte in data:
        result ^= byte
    return chr(result)


def create_response(co_value, operating_status, caution_status, error_status):
    """
    Create HORIBA APNA370 response frame.
    Frame format: SOH + SendID + RecvID + FrmID + CmdStr + STX + ResponseData + FCS + ETX
    Response is comma-separated with 6 elements:
    [0] CO value string (matches regex "01R\d\d\s+((-|\+)?\d*(\.\d+)?)")
    [1-2] Extra fields
    [3] Operating status (16 digits binary as decimal)
    [4] Caution status (32 digits binary as decimal)
    [5] Error status (32 digits binary as decimal)
    """
    # Response format: CO value with regex-compatible format
    # "01R" + 2 digits + space + CO value with sign
    co_str = f"01R{int(co_value):02d} {co_value:+.2f}"

    # Build response string with comma-separated values (6 elements total)
    response_str = f"{co_str},field1,field2,{operating_status},{caution_status},{error_status}"

    # Construct full frame
    send_id = "F9"
    recv_id = "FF"
    frm_id = "01"
    cmd_str = "R001"
    prm_str = ""

    # Calculate checksum on: SOH + SendID + RecvID + FrmID + CmdStr + STX + PrmStr
    checksum_data = SOH + send_id + recv_id + frm_id + cmd_str + STX + prm_str
    fcs = get_bcc(checksum_data)

    # Build complete frame with response data
    frame = SOH + send_id + recv_id + frm_id + cmd_str + STX + response_str + fcs + ETX

    return frame


def main():
    # Handle port assignment
    port = DEFAULT_PORT
    if len(sys.argv) == 2:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print(f"Invalid port. Using default: {port}")

    # UDP Socket Setup
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    try:
        sock.bind((DEFAULT_ADDRESS, port))
        print(f"HORIBA APNA370 Server started on {DEFAULT_ADDRESS} port {port}")
    except Exception as e:
        print(f"Critical error starting server: {e}")
        return

    try:
        while True:
            print("\nWaiting for data...")
            try:
                raw_data, addr = sock.recvfrom(BUFFER_SIZE)

                now = datetime.now().strftime("%m/%d/%Y, %H:%M:%S")
                print(f"[{now}] Received from {addr}: {repr(raw_data)}")

                # Parse incoming command
                # Expected format: SOH + F9 + FF + 01 + R001 + STX + [PrmStr] + FCS + ETX
                if len(raw_data) >= 10:
                    # Check for SOH and ETX markers
                    if raw_data[0:1] == SOH.encode() and raw_data[-1:] == ETX.encode():
                        # Extract command string (should be R001 for data acquisition)
                        cmd_str = raw_data[7:11].decode('latin1', errors='ignore')

                        if cmd_str == "R001":
                            # Generate random CO value (0-75 ppm typical range)
                            co_value = random.uniform(5.0, 50.0)

                            # Generate status codes
                            # Operating status: 16-bit binary as decimal
                            operating_status = str(random.randint(0, 65535))
                            # Caution status: 32-bit binary as decimal
                            caution_status = str(random.randint(0, 4294967295))
                            # Error status: 32-bit binary as decimal
                            error_status = str(random.randint(0, 4294967295))

                            # Create response
                            response = create_response(co_value, operating_status, caution_status, error_status)

                            print(f"[{now}] Sending response: {repr(response.encode('latin1'))}")
                            sock.sendto(response.encode('latin1'), addr)
                        else:
                            print(f"Unknown command: {cmd_str}")
                    else:
                        print("Invalid frame format (missing SOH or ETX)")
                else:
                    print("Received data too short")

            except Exception as e:
                print(f"Error processing request: {e}")
                continue

    except KeyboardInterrupt:
        print("\nShutting down server...")
    finally:
        sock.close()


if __name__ == '__main__':
    main()
