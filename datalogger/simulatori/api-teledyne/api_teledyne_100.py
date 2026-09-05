#!/usr/bin/env python3
# ----------------------------------------------------------------------
#  Copyright (c) 1995-2026, Ecometer s.n.c.
#  Author: Paolo Saudin.
#  Date  : 2026-07-31
# ----------------------------------------------------------------------
import sys
import random
import socket
from datetime import datetime

# get port
arg1 = None
if len(sys.argv) == 2:
    arg1 = sys.argv[1]

# warnings record
def get_wlist():
    # W  128:00:04  0001  SYSTEM RESET<CR><LF>
    # W  128:00:04  0001  SAMPLE FLOW WARN<CR><LF>
    # W  128:00:04  0001  OZONE FLOW WARNING<CR><LF>
    # W  128:00:04  0001  RCELL PRESS WARN<CR><LF>
    # W  128:00:04  0001  IZS TEMP WARNING<CR><LF>
    response = ('{0}\n\r{1}\n\r{2}\n\r{3}\n\r{4}\n\r'.format(
    'W  128:00:04  0001  SYSTEM RESET',
    'W  128:00:04  0001  SAMPLE FLOW WARN',
    'W  128:00:04  0001  OZONE FLOW WARNING',
    'W  128:00:04  0001  RCELL PRESS WARN',
    'W  128:00:04  0001  IZS TEMP WARNING'
    ))

    response = ('{0}\n\r'.format(
    'W  128:00:04  0001  SYSTEM RESET'
    ))
    return response

# Create a TCP/IP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

# Bind the socket to the port
port = 3001
address = '192.168.168.47'
if arg1:
    port = arg1
server_address = (address, int(port))
print ('starting up on {0} port {1}'.format(*server_address))
sock.bind(server_address)

# Listen for incoming connections
sock.listen()

while True:
    # Wait for a connection
    print ('waiting for a connection')
    connection, client_address = sock.accept()
    status = 'SAMPLE'

    try:
        print ('connection from {0}'.format(client_address))

        # Receive the data in small chunks and retransmit it
        while True:
            try:
                data = connection.recv(1024)
                if not data:
                    print('client disconnected gracefully')
                    break

                data = data.replace(b'\x0D', b'') # \r
                data = data.replace(b'\x0A', b'') # \n
                data = data.replace(b'\x0D\x0A', b'') # \r\n
                #data = data[:-2]
                res_calib='SAMPLE'
                now = datetime.now() # current date and time
                date_time = now.strftime("%m/%d/%Y, %H:%M:%S")
                print ('received @ {0} -> {1} '.format(date_time, data))
                if data:
                    # main
                    if data == b'T SO2':
                        print ('sending so2 value')
                        v = random.uniform(0, 75)
                        connection.sendall('T SO2={}UGM'.format(v).encode())

                    # system
                    elif data == b'V MODE':
                        print ('sending SPAN|ZERO|FINISH|START|SAMPLE')
                        connection.sendall(('...{0}'.format(status)).encode())

                    # elif data == b'D ST_SYSTEM_OK':
                    #     print ('sending ST_SYSTEM_OK=(ON|OFF)')
                    #     connection.sendall('...ST_SYSTEM_OK=ON'.encode())

                    # diags
                    elif data == b'T SAMPPRESS':
                        print ('sending pres value')
                        v = random.uniform(40, 60)
                        connection.sendall('T PRES={0} IN-HG-A'.format(v).encode())
                    elif data == b'T SAMPFLOW':
                        print ('sending samp flow value')
                        v = random.uniform(100, 199)
                        connection.sendall('T FL={0} CC/M'.format(v).encode())
                    elif data == b'T PMTDET':
                        print ('sending pmt det value')
                        v = random.uniform(40, 55)
                        connection.sendall('T PMT={0} MV'.format(v).encode())
                    elif data == b'T UVDET':
                        print ('sending uv det value')
                        v = random.uniform(40, 55)
                        connection.sendall('T LAMP={0} MV'.format(v).encode())
                    elif data == b'T SLOPE':
                        print ('sending so2 slope value')
                        v = random.uniform(40, 55)
                        connection.sendall('T SLOPE={0}'.format(v).encode())
                    elif data == b'T OFFSET':
                        print ('sending so2 offset value')
                        v = random.uniform(40, 55)
                        connection.sendall('T OFFSET={0} MV'.format(v).encode())
                    elif data == b'T DCPS':
                        print ('sending dcps value')
                        v = random.uniform(40, 55)
                        connection.sendall('T DCPS={0} MV'.format(v).encode())
                    elif data == b'T RCELLTEMP':
                        print ('sending rcell tmp value')
                        v = random.uniform(40, 55)
                        connection.sendall('T RCELL TEMP={0} C'.format(v).encode())
                    elif data == b'T BOXTEMP':
                        print ('sending box tmp value')
                        v = random.uniform(40, 55)
                        connection.sendall('T BOX TEMP={0} C'.format(v).encode())
                    elif data == b'T PMTTEMP':
                        print ('sending pmt temp value')
                        v = random.uniform(90, 110)
                        connection.sendall('T PMT TEMP={0} C'.format(v).encode())
                    elif data == b'T HVPS':
                        print ('sending pmt temp value')
                        v = random.uniform(1000, 1500)
                        connection.sendall('T HVPS={0} VOLTS'.format(v).encode())

                    # calib
                    elif b'C ZERO' in data:
                        print ('---- sending zero status ----')
                        connection.sendall(b'...ZERO')
                        status = 'ZERO'

                    elif b'C SPAN' in data:
                        print ('---- sending span status ----')
                        connection.sendall(b'...SPAN')
                        status = 'SPAN'

                    elif b'C EXIT' in data:
                        print ('---- sending sample status ----')
                        connection.sendall('...SAMPLE'.encode())
                        status = 'SAMPLE'

                    # elif data == b'ST_ZERO_CAL':
                    #     print ('sending ST_ZERO_CAL=OFF')
                    #     connection.sendall('...ST_ZERO_CAL=ON'.encode())

                    # elif data == b'ST_SPAN_CAL':
                    #     print ('sending ST_SPAN_CAL=ON')
                    #     connection.sendall('...ST_SPAN_CAL=ON'.encode())

                    # warnings
                    elif b'W LIST' in data:
                        print ('---- sending warning list ----')
                        w_list = get_wlist()
                        print (w_list)
                        connection.sendall(w_list.encode())

                    elif b'W CLEAR' in data:
                        print ('---- clearing warning ----')
                        #connection.sendall(b'OK')

                    else:
                        connection.sendall(data)
                else:
                    print ('no more data from {0}'.format(client_address))
                    break

            except (ConnectionResetError, BrokenPipeError, socket.error) as e:
                print('Communication error: {0}'.format(e))
                break
    finally:
        # Clean up the connection
        connection.close()