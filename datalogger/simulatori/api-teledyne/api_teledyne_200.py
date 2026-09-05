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
    return response

# Create a TCP/IP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

# Bind the socket to the port
port = 3002
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
                now = datetime.now() # current date and time
                date_time = now.strftime("%m/%d/%Y, %H:%M:%S")
                print ('received @ {0} -> {1} '.format(date_time, data))
                if data:
                    # main
                    if data == b'T NOX':
                        print ('sending nox value')
                        v = random.uniform(0, 75)
                        connection.sendall('T NOX={}UGM'.format(v).encode())
                    elif data == b'T NO':
                        print ('sending no value')
                        v = random.uniform(0, 65)
                        connection.sendall('T NO={}UGM'.format(v).encode())
                    elif data == b'T NO2':
                        print ('sending no2 value')
                        v = random.uniform(0, 25)
                        connection.sendall('T NO2={}UGM'.format(v).encode())

                    # system
                    elif data == b'V MODE':
                        print ('sending SPAN|ZERO|FINISH|START|SAMPLE')
                        connection.sendall(('...{0}'.format(status)).encode())

                    # elif data == b'D ST_SYSTEM_OK':
                    #     print ('sending ST_SYSTEM_OK=(ON|OFF)')
                    #     connection.sendall('...ST_SYSTEM_OK=ON'.encode())

                    # diags
                    elif data == b'T SAMPFLOW':
                        print ('sending conv temp value')
                        v = random.uniform(100, 199)
                        connection.sendall('T SAMP FLW={0} CC/M'.format(v).encode())
                    elif data == b'T OZONEFLOW':
                        print ('sending cooler temp value')
                        v = random.uniform(-1, -10)
                        connection.sendall('T OZONE FL={0} CC/M'.format(v).encode())
                    elif data == b'T RCELLTEMP':
                        print ('sending flow value')
                        v = random.uniform(0.9, 1.1)
                        connection.sendall('T RCELL TEMP={0} C'.format(v).encode())
                    elif data == b'T BOXTEMP':
                        print ('sending internal temp value')
                        v = random.uniform(20, 35)
                        connection.sendall('T BOX TEMP={0} C'.format(v).encode())
                    elif data == b'T PMTTEMP':
                        print ('sending perm gas temp value')
                        v = random.uniform(90, 110)
                        connection.sendall('T PMT TEMP={0} C'.format(v).encode())
                    elif data == b'T CONVTEMP':
                        print ('sending pmt temp value')
                        v = random.uniform(-0, -5)
                        connection.sendall('T MOLY TEMP={0} C'.format(v).encode())
                    elif data == b'T RCELLPRESS':
                        print ('sending pmt voltage value')
                        v = random.uniform(-800, -880)
                        connection.sendall('T RCEL={0} IN-HG-A'.format(v).encode())
                    elif data == b'T SAMPPRESS':
                        print ('sending pres value')
                        v = random.uniform(40, 60)
                        connection.sendall('T SAMP={0} IN-HG-A'.format(v).encode())
                    elif data == b'T NOXSLOPE':
                        print ('sending react temp value')
                        v = random.uniform(40, 55)
                        connection.sendall('T NOX SLOPE={0}'.format(v).encode())
                    elif data == b'T NOXOFFSET':
                        print ('sending nox coef value')
                        v = random.uniform(40, 55)
                        connection.sendall('T NOX OFFS={0} MV'.format(v).encode())
                    elif data == b'T NOSLOPE':
                        print ('sending no coef value')
                        v = random.uniform(40, 55)
                        connection.sendall('T NO SLOPE={0}'.format(v).encode())
                    elif data == b'T NOOFFSET':
                        print ('sending no coef value')
                        v = random.uniform(40, 55)
                        connection.sendall('T NO OFFS={0} MV'.format(v).encode())
                    elif data == b'T AUTOZERO':
                        print ('sending no2 coef value')
                        v = random.uniform(40, 55)
                        connection.sendall('T AZERO={0} MV'.format(v).encode())
                    elif data == b'T HVPS':
                        print ('sending nox bkg value')
                        v = random.uniform(40, 55)
                        connection.sendall('T HVPS={0} V'.format(v).encode())


                    # calib
                    elif b'C ZERO' in data:
                        print ('---- sending zero status ----')
                        connection.sendall(b'...ST_SYSTEM_OK=ON')
                        status = 'ZERO'

                    elif b'C SPAN' in data:
                        print ('---- sending span status ----')
                        connection.sendall(b'...ST_SYSTEM_OK=ON')
                        status = 'SPAN'

                    elif b'C EXIT' in data:
                        print ('---- sending sample status ----')
                        connection.sendall('...ST_SYSTEM_OK=ON'.encode())
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