#!/usr/bin/env python3
# ----------------------------------------------------------------------
#  Copyright (c) 1995-2026, Ecometer s.n.c.
#  Author: Paolo Saudin.
#  Date  : 2026-07-31
# ----------------------------------------------------------------------
import serial
import time
import random
import schedule
from datetime import datetime

# Configurazione seriale
ser = serial.Serial("/dev/ttySC0", 9600, timeout=1)

# Costanti
CR = "\r"
LF = "\n"
STX = chr(0x02) # Spesso richiesto dagli analizzatori Horiba, se non serve si può rimuovere

response_data = ""

def get_data_horiba_format():
    """
    Genera la stringa a tre parametri richiesta:
    MD03 051 +9000-04 00 00 001 000000 012 +5900-03 00 00 001 000000 013 +6800-03 00 00 001 000000 <CR><LF>
    """
    instrument_id = "03"

    # Parametro 1 (Uso 051 per matchare la Regex VB.NET: Reg += "051\s...")
    # Se in VB.NET cambi la regex in "011\s", allora cambia 051 in 011 qui sotto.
    p1_code = "011"
    p1_val = f"{random.randrange(1000, 9000):+05d}"
    p1_exp = "-04"
    p1_status = "00 00 001 000000"

    # Parametro 2
    p2_code = "012"
    p2_val = f"{random.randrange(1000, 9000):+05d}"
    p2_exp = "-03"
    p2_status = "00 00 001 000000"

    # Parametro 3
    p3_code = "013"
    p3_val = f"{random.randrange(1000, 9000):+05d}"
    p3_exp = "-03"
    p3_status = "00 00 001 000000"

    # Costruzione stringa finale
    # MD03 051 +9000-04 00 00 001 000000 012 +5900-03 00 00 001 000000 013 +6800-03 00 00 001 000000
    msg = (f"MD{instrument_id} "
           f"{p1_code} {p1_val}{p1_exp} {p1_status} "
           f"{p2_code} {p2_val}{p2_exp} {p2_status} "
           f"{p3_code} {p3_val}{p3_exp} {p3_status}")

    # Aggiungiamo CR LF come richiesto.
    # Se il software VB.NET non risponde, prova ad aggiungere STX all'inizio: return STX + msg + CR + LF
    return msg + CR + LF

def generate_data():
    global response_data
    response_data = get_data_horiba_format()
    print(f"[*] Dati pronti: {repr(response_data)}")

def main():
    global response_data
    print("--- Simulatore Horiba APNA-370 (3 Parametri) ---")

    generate_data()
    schedule.every().minute.at(":00").do(generate_data)

    try:
        while True:
            schedule.run_pending()

            if ser.in_waiting > 0:
                # Legge il comando (VB invia ChrW(2) + "DA" + ChrW(13))
                line = ser.read_until(CR.encode()).decode(errors='ignore')

                if "DA" in line:
                    timestamp = datetime.now().strftime('%H:%M:%S')
                    print(f"<- [{timestamp}] Richiesta DA ricevuta")

                    # Invia la risposta
                    ser.write(response_data.encode())
                    print(f"-> [{timestamp}] Risposta inviata")

            time.sleep(0.05)
    except KeyboardInterrupt:
        print("\nChiusura...")
    finally:
        ser.close()

if __name__ == '__main__':
    main()