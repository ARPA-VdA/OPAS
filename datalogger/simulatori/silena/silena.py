#!/usr/bin/env python3
# ----------------------------------------------------------------------
#  Copyright (c) 1995-2026, Ecometer s.n.c.
#  Author: Paolo Saudin.
#  Date  : 2026-07-31
# ----------------------------------------------------------------------
import serial, time, random, schedule
from datetime import datetime, timedelta

# open serial connection
ser = serial.Serial("/dev/ttySC1", 9600, timeout = 1)

# data
stx = chr(0x02)
etx = chr(0x03)
len = chr(0x06)
cr  = chr(0x0D)
lf  = chr(0x0A)
response = ''

# data record
def get_data():

    # CSV Type Reports<CR><LF>
    # <CR><LF>
    # <CR><LF>
    # 2 - Display All Data<CR><LF>
    # 3 - Display New Data<CR><LF>
    # 4 - Display Last Data<CR><LF>
    # <CR><LF>
    # 5 - Display All Flow Stats<CR><LF>
    # 6 - Display New Flow Stats<CR><LF>
    # <CR><LF>
    # 7 - Display All 5-Min Flow<CR><LF>
    # 8 - Display New 5-Min Flow<CR><LF>
    # <CR><LF>
    # 9 - Display Error Log<CR><LF>
    # <CR><LF>

    # 29/09/2025 09:48:43.692 [TX] - 4
    # 29/09/2025 09:48:43.706 [RX] - 4 Display CSV Data<CR><LF>
    # Station, 1<CR><LF>
    # Time, Conc (mg/m3), Qtot (m3), no (V), WS (MPS), no (V), RH (%), no (V), AT (C), Stab(ug), Ref (ug),E,U,M,I,L,R,N, F,P,D,C,T,<CR><LF>
    # 09/29/25 10:00, 0.012, 0.701, 0.002, 0.0, 0.001, 850.4,0,0,0,0,0,0,0,0,0,0,0,0,<CR><LF>

    # \d\d\/\d\d\/\d\d\s\d\d:\d\d,\s*((-|\+)?\d*(\.\d+)?),\s*((-|\+)?\d*(\.\d+)?),\s*((-|\+)?\d*(\.\d+)?),\s*((-|\+)?\d*(\.\d+)?),\s*((-|\+)?\d*(\.\d+)?),\s*((-|\+)?\d*(\.\d+)?),\d,\d,\d,\d,\d,\d,\d,\d,\d,\d,\d,\d,

    now = datetime.now()
    return "{0}{1}{2}{3}, {4}, {5}, {6}, {7}, {8}, {9},{10}".format(
        f'4 Display CSV Data{cr}{lf}', # 0
        f'Station, 1{cr}{lf}',         # 1
        f'Time, Conc (mg/m3), Qtot (m3), no (V), WS (MPS), no (V), RH (%), no (V), AT (C), Stab(ug), Ref (ug),E,U,M,I,L,R,N, F,P,D,C,T,{cr}{lf}', # 2
        str((now + timedelta(days=-1)).strftime("%d/%m/%y %H:00")), # 3
        f'{random.uniform(0, 1):.3f}',                              # 4
        f'{random.uniform(0, 1):.3f}',                              # 5
        f'{random.uniform(0, 1):.3f}',                              # 6
        f'{random.uniform(0, 1):.3f}',                              # 7
        f'{random.uniform(0, 1):.3f}',                              # 8
        f'{random.uniform(850, 860):.1f}',                          # 9
        f'0,0,0,0,0,0,0,0,0,0,0,0,{cr}{lf}'
    )

def generate_data():
    global response
    print("* get values")
    response = get_data()
    print("new response: {}".format(response))

def main():

    global response

    print("--- enter main ---")

    generate_data()

    # schedule job
    schedule.every().minute.at(":00").do(generate_data) # ogni minuto ai secondi :00

    try:

        while True:
            schedule.run_pending()

            # read data
            buffer_data = ser.readline() # readline() # read(1024)

            # data check
            if buffer_data:

                # decode
                #print(type(buffer_data))
                res = buffer_data.decode()
                print("<- arrivato comando [{0}] @ {1}".format(
                    res.rstrip(),
                    datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3])
                )

                # check command
                if res == f'{cr}{lf}':
                    response = '*'
                    print("-> invio: {}".format(str(response)))
                    ser.write(str(response).encode())

                elif "6" in res:
                    response = f'{response}{cr}{lf}',
                    print("-> invio: {}".format(str(response)))
                    ser.write(str(response).encode())

                elif "4" in res:
                    response = get_data()
                    print("-> invio: {}".format(str(response)))
                    ser.write(str(response).encode())

    except KeyboardInterrupt:
        pass

if __name__ == '__main__':
     main()
