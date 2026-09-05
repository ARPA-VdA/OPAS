#!/usr/bin/env python3
# ----------------------------------------------------------------------
#  Copyright (c) 1995-2026, Ecometer s.n.c.
#  Author: Paolo Saudin.
#  Date  : 2026-07-31
# ----------------------------------------------------------------------
import sys
import random
import serial
import time
import os
from datetime import datetime

# --- Configuration ---
DEFAULT_PORT = "/dev/ttySC0"  # Windows: COM1-COM9, Linux: /dev/ttySC0, etc.
DEFAULT_BAUDRATE = 19200
DEFAULT_TIMEOUT = 1
DEVICE_ADDRESS = "0"

# Variabili globali per mantenere lo stato del timer
last_rain_time = 0
next_wait_time = random.randint(120, 240)  # Primo intervallo tra 2 e 4 minuti (120-240s)

def generate_wind_data():
    """
    Generate wind data for R1 command.
    Format: 0R1,Dn=XXX D,Dm=XXX D,Dx=XXX D,Sn=X.X M,Sm=X.X M,Sx=X.X M
    Dn/Dm/Dx: Wind direction (0-360°)
    Sn/Sm/Sx: Wind speed (m/s)
    """
    dn = random.randint(0, 360)              # min direction (degrees)
    dm = random.randint(0, 360)              # avg direction
    dx = random.randint(0, 360)              # max direction
    sn = round(random.uniform(0.0, 2.0), 1)  # min speed (m/s)
    sm = round(random.uniform(0.1, 5.0), 1)  # avg speed
    sx = round(random.uniform(0.2, 8.0), 1)  # max speed
    return f"{DEVICE_ADDRESS}R1,Dn={dn:03d}D,Dm={dm:03d}D,Dx={dx:03d}D,Sn={sn}M,Sm={sm}M,Sx={sx}M"


def generate_air_data():
    """
    Generate air data for R2 command.
    Format: 0R2,Ta=XX.X C,Ua=XX.X P,Pa=XXXX.X H
    Ta: Air temperature (°C)
    Ua: Relative humidity (%)
    Pa: Air pressure (hPa)
    """
    ta = round(random.uniform(-10.0, 45.0), 1)    # temperature (°C)
    ua = round(random.uniform(15.0, 95.0), 1)     # humidity (%)
    pa = round(random.uniform(850.0, 1050.0), 1)  # pressure (hPa)
    return f"{DEVICE_ADDRESS}R2,Ta={ta}C,Ua={ua}P,Pa={pa}H"


def generate_rain_data_old():
    """
    Generate rain/hail data for R3 command.
    Format: 0R3,Rc=X.XX M,Rd=XXXX s,Ri=X.X M,Hc=X.X M,Hd=XXXX s,Hi=X.X M
    Rc/Ri: Rain accumulation/intensity (mm)
    Rd: Rain duration (s)
    Hc/Hi: Hail accumulation/intensity (mm)
    Hd: Hail duration (s)
    """
    rc = round(random.uniform(0.0, 10.0), 2)  # rain accumulation (mm)
    rd = random.randint(0, 3600)              # rain duration (seconds)
    ri = round(random.uniform(0.0, 5.0), 1)   # rain intensity (mm/h)
    hc = round(random.uniform(0.0, 5.0), 1)   # hail accumulation (mm)
    hd = random.randint(0, 1800)              # hail duration (seconds)
    hi = round(random.uniform(0.0, 3.0), 1)   # hail intensity (mm/h)
    return f"{DEVICE_ADDRESS}R3,Rc={rc}M,Rd={rd}s,Ri={ri}M,Hc={hc}M,Hd={hd}s,Hi={hi}M"

def generate_rain_data():
    """
    Genera dati pioggia: ogni 2-4 minuti produce un valore tra 0.2 e 2.0 mm.
    Altrimenti restituisce zero.
    """
    global last_rain_time, next_wait_time

    current_time = time.time()

    # Inizializziamo i valori a zero (assenza di pioggia)
    rc = 0.0
    rd = 0
    ri = 0.0

    # Controlliamo se è passato il tempo necessario per il prossimo evento di pioggia
    if current_time - last_rain_time >= next_wait_time:
        # --- EVENTO PIOGGIA ATTIVO ---
        rc = round(random.uniform(0.2, 2.0), 2)  # Accumulo tra 0.2 e 2.0 mm

        # La durata (rd) deve essere coerente:
        # se cadono 2mm di colpo è un acquazzone, se cade 0.2mm è una pioggerella.
        # Simuliamo una durata tra 30 e 120 secondi per l'evento registrato.
        rd = random.randint(30, 120)

        # L'intensità (ri) è solitamente mm/h. Formula: (mm / secondi) * 3600
        ri = round((rc / rd) * 3600, 1)

        # Reset del timer e calcolo del prossimo intervallo (2-4 minuti)
        last_rain_time = current_time
        next_wait_time = random.randint(120, 240)

    # Per semplicità lasciamo la grandine (hail) a zero o gestita in modo simile
    hc = 0.0
    hd = 0
    hi = 0.0

    return f"{DEVICE_ADDRESS}R3,Rc={rc:.2f}M,Rd={rd}s,Ri={ri:.1f}M,Hc={hc:.1f}M,Hd={hd}s,Hi={hi:.1f}M"

def handle_command(command):
    """Process incoming command and return appropriate response."""
    command = command.strip()

    if not command:
        return None

    # Remove device address prefix if present
    if command.startswith(DEVICE_ADDRESS):
        cmd = command[1:]
    else:
        cmd = command

    # Handle different commands
    if cmd == "?":
        # Address check - respond with device address
        return DEVICE_ADDRESS
    elif cmd == "R1":
        # Wind data request
        return generate_wind_data()
    elif cmd == "R2":
        # Air data request
        return generate_air_data()
    elif cmd == "R3":
        # Rain data request
        return generate_rain_data()
    elif cmd == "XZM":
        # Measurement reset
        return f"{DEVICE_ADDRESS}TX,Measurement reset"
    elif cmd == "XZRU":
        # Rain reset
        return f"{DEVICE_ADDRESS}TX,Rain reset"
    else:
        # Unknown command
        return f"{DEVICE_ADDRESS}TX,Unknown command: {cmd}"


def main():
    """Main server loop."""
    port = DEFAULT_PORT
    baudrate = DEFAULT_BAUDRATE

    # Parse command-line arguments
    if len(sys.argv) > 1:
        if sys.argv[1] in ['-h', '--help']:
            print("Usage: wxt536.py [PORT] [BAUDRATE]")
            print("Examples:")
            print("  wxt536.py                    # Use default COM3 at 19200 baud")
            print("  wxt536.py COM1               # Use COM1 at 19200 baud")
            print("  wxt536.py /dev/ttyUSB0       # Use /dev/ttyUSB0 on Linux")
            print("  wxt536.py COM1 9600          # Use COM1 at 9600 baud")
            return
        else:
            port = sys.argv[1]

    if len(sys.argv) > 2:
        try:
            baudrate = int(sys.argv[2])
        except ValueError:
            print(f"Invalid baudrate: {sys.argv[2]}")
            return

    # Try to open serial port
    try:
        ser = serial.Serial(port, baudrate, timeout=DEFAULT_TIMEOUT)
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{now}] Vaisala WXT536 simulator started")
        print(f"[{now}] Port: {port}, Baudrate: {baudrate}")
    except serial.SerialException as e:
        print(f"Error opening serial port {port}: {e}")
        print("\nTroubleshooting:")
        print("- On Windows: Install com0com or another virtual COM port software")
        print("- On Linux: Create virtual ports with: socat -d -d pty,raw,echo=0 pty,raw,echo=0")
        print("- Check if the port exists and is accessible")
        return
    except Exception as e:
        print(f"Unexpected error: {e}")
        return

    try:
        while True:
            # Check if there's data to read
            if ser.in_waiting > 0:
                try:
                    # Read a line (terminated by CR+LF)
                    raw_line = ser.readline()
                    command = raw_line.decode('utf-8', errors='ignore').strip()

                    if not command:
                        continue

                    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    print(f"[{now}] RX: {command}")

                    # Process command and get response
                    response = handle_command(command)

                    if response is not None:
                        # Send response with CRLF terminator
                        response_line = response + "\r\n"
                        ser.write(response_line.encode('utf-8'))
                        print(f"[{now}] TX: {response}")

                except UnicodeDecodeError:
                    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    print(f"[{now}] Error decoding received data")
                except Exception as e:
                    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    print(f"[{now}] Error processing command: {e}")
            else:
                # Small delay to avoid busy-waiting
                time.sleep(0.01)

    except KeyboardInterrupt:
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"\n[{now}] Shutting down...")
    except Exception as e:
        print(f"Runtime error: {e}")
    finally:
        if ser.is_open:
            ser.close()
            now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            print(f"[{now}] Serial port closed")


if __name__ == '__main__':
    main()
