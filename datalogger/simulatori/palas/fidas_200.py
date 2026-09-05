#!/usr/bin/env python3
# ----------------------------------------------------------------------
#  Copyright (c) 1995-2026, Ecometer s.n.c.
#  Author: Paolo Saudin.
#  Date  : 2026-07-31
# ----------------------------------------------------------------------
import logging
import random
import datetime
from twisted.internet.task import LoopingCall

# Modbus libraries
from pymodbus.server.asynchronous import StartSerialServer as ModbusServer
from pymodbus.datastore import ModbusSequentialDataBlock
from pymodbus.datastore import ModbusSlaveContext, ModbusServerContext
from pymodbus.transaction import ModbusRtuFramer
from pymodbus.constants import Endian
from pymodbus.payload import BinaryPayloadBuilder

# --- Configuration ---
SERIAL_PORT = '/dev/ttySC1'
BAUDRATE = 19200
SLAVE_ID = 0x00
UPDATE_INTERVAL = 60  # seconds

# Register addresses
HR_BLOCK = 3
IR_BLOCK = 4

# Logging configuration
logging.basicConfig(format='%(asctime)s - %(levelname)s - %(message)s')
log = logging.getLogger()
log.setLevel(logging.INFO)


def update_registers(a):
    """Callback function to update Modbus registers with simulated data."""
    context = a[0]
    slave_id = SLAVE_ID

    now = datetime.datetime.now()
    log.info(f"--- Updating values at {now.strftime('%Y-%m-%d %H:%M:%S')} ---")

    # 1. SET FIXED VALUES
    # Holding Registers
    context[slave_id].setValues(HR_BLOCK, 3, [2])
    context[slave_id].setValues(HR_BLOCK, 4, [5])

    # Input Registers (status/fixed)
    context[slave_id].setValues(IR_BLOCK, 12, [0])
    context[slave_id].setValues(IR_BLOCK, 13, [0])

    # 2. SET RANDOM INTEGERS (changing every minute)
    reg_36_val = random.randrange(1, 10)
    reg_67_val = random.randrange(1, 10)
    context[slave_id].setValues(IR_BLOCK, 36, [reg_36_val])
    context[slave_id].setValues(IR_BLOCK, 67, [reg_67_val])

    log.info(f"INT: Reg36={reg_36_val}, Reg67={reg_67_val}")

    # 3. SET 32-BIT FLOATS (Registers 14-34 and 37-65)
    # Range 1: 14 to 34 (step 2)
    for r in range(14, 35, 2):
        builder = BinaryPayloadBuilder(byteorder=Endian.Big, wordorder=Endian.Big)
        val = round(random.uniform(1, 25), 2)
        builder.add_32bit_float(val)
        payload = builder.to_registers()
        context[slave_id].setValues(IR_BLOCK, r, payload)
        log.debug(f"FLOAT: Reg{r}={val}")

    # Range 2: 37 to 65 (step 2)
    for r in range(37, 66, 2):
        builder = BinaryPayloadBuilder(byteorder=Endian.Big, wordorder=Endian.Big)
        val = round(random.uniform(1, 25), 2)
        builder.add_32bit_float(val)
        payload = builder.to_registers()
        context[slave_id].setValues(IR_BLOCK, r, payload)
        log.debug(f"FLOAT: Reg{r}={val}")

    log.info("Float registers updated successfully.")


def run_server():
    """Initializes the data store and starts the Modbus RTU server."""
    log.info(f"Starting Palas Simulator on {SERIAL_PORT} ({BAUDRATE} baud)")

    # Initialize data store with 10000 registers for each type
    store = ModbusSlaveContext(
        di=ModbusSequentialDataBlock(0, [0x0] * 10000),
        co=ModbusSequentialDataBlock(0, [0x0] * 10000),
        hr=ModbusSequentialDataBlock(0, [0x0] * 10000),
        ir=ModbusSequentialDataBlock(0, [0x0] * 10000)
    )
    context = ModbusServerContext(slaves=store, single=True)

    # Setup the update loop (LoopingCall from Twisted)
    loop = LoopingCall(f=update_registers, a=(context,))
    loop.start(UPDATE_INTERVAL, now=True)

    # Start the Serial Modbus RTU Server
    try:
        ModbusServer(
            context,
            framer=ModbusRtuFramer,
            port=SERIAL_PORT,
            baudrate=BAUDRATE
        )
    except Exception as e:
        log.error(f"Failed to start Modbus Server: {e}")


def main():
    """Entry point of the script."""
    try:
        run_server()
    except KeyboardInterrupt:
        log.info("\nServer shutting down...")
    except Exception as e:
        log.critical(f"Unexpected error: {e}")


if __name__ == "__main__":
    main()