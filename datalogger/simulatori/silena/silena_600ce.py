#!/usr/bin/env python3
# ----------------------------------------------------------------------
#  Copyright (c) 1995-2026, Ecometer s.n.c.
#  Author: Paolo Saudin.
#  Date  : 2026-07-31
# ----------------------------------------------------------------------
import serial
import time
import datetime
import random

# Configurazione seriale (600, 7, E, 1)
ser = serial.Serial(
    port="/dev/ttySC0",
    baudrate=600,
    bytesize=serial.SEVENBITS,
    parity=serial.PARITY_EVEN,
    stopbits=serial.STOPBITS_ONE,
    timeout=1
)

def calculate_checksum(data_string):
    """XOR dei caratteri per il checksum"""
    crc = 0
    for char in data_string:
        crc ^= ord(char)
    return hex(crc)[2:].upper().zfill(2)

def calculate_checksum2(data):
    """
    Calcola il checksum come somma dei byte modulo 256.
    Ritorna la rappresentazione esadecimale in maiuscolo.
    """
    s = sum(ord(c) for c in data)
    return f"{s & 0xFF:02X}"

def handle_step_1_2():
    """Risponde ai messaggi A@30 e CI3B. Richiede ACK in posizione 7."""
    stx = chr(0x02)
    ack = chr(0x06)
    etx = chr(0x03)
    # Costruiamo: STX (1) + "7001A" (5) + ACK (1) + "00" (2) + CRC (2) + ETX (1) = 12 chars
    body = f"7001A{ack}00"
    crc = calculate_checksum(body)
    return f"{stx}{body}{crc}{etx}"

def handle_step_3():
    """Risponde al messaggio F<ACK>71. Richiede 'I' pos 7 e 'M' pos 19."""
    stx = chr(0x02) # Pos 1
    etx = chr(0x03)
    cr = "\r"
    lf = "\n"

    # 1. Prefisso (6 caratteri): 7027GI -> 'I' finisce in posizione 7 (1+6)
    prefix = "7027GI"

    # 2. Valore random tra 0.12 e 0.21
    # :07.2f significa: totale 7 caratteri, 2 decimali, riempimento con zeri
    valore_random = random.uniform(0.12, 0.21)
    valore_str = f"{valore_random:07.2f}" # Esempio: "0000.17"

    # 3. Spazi e 'M'
    # Posizioni:
    # [1] STX
    # [2-7] 7027GI
    # [8-9] Due spazi
    # [10-16] 0000.17 (7 caratteri)
    # [17-18] Due spazi
    # [19] M
    padding_valore = "  "
    padding_m = "  M"

    # 4. Timestamp (spazio + 11 caratteri)
    ora_corrente = datetime.datetime.now().strftime(" %m/%d %H:%M")

    # Costruzione del corpo per il calcolo checksum (dal carattere dopo STX fino a LF)
    body = f"{prefix}{padding_valore}{valore_str}{padding_m}{ora_corrente}{cr}{lf}"

    # Calcolo CRC (es. "44")
    crc = calculate_checksum(body)

    # Risultato finale
    return f"{stx}{body}{crc}{etx}"

def main():
    print("--- Simulatore Silena 600CE (Protocollo Step-by-Step) ---")
    print(f"In ascolto su {ser.port} a 600 7E1...")

    try:
        while True:
            if ser.in_waiting > 0:
                # Leggiamo il comando (termina con CR LF)
                raw_data = ser.read_until(b'\n')
                try:
                    incoming = raw_data.decode('latin-1')
                except:
                    incoming = str(raw_data)

                if not incoming.strip(): continue

                print(f"<- Ricevuto: {repr(incoming)}")

                response = ""

                # Logica di risposta basata sui messaggi definiti in VB.NET
                if "7001A@30" in incoming or "7001CI3B" in incoming:
                    # Step 1 e 2
                    response = handle_step_1_2()

                elif "7001F" in incoming:
                    # Step 3 (Richiesta Dati Gamma)
                    response = handle_step_3()

                elif "7001H" in incoming:
                    # Step 4 (Chiusura)
                    # VB.NET non controlla la risposta qui, mandiamo un ACK generico
                    response = chr(0x06)

                if response:
                    print(f"-> Risposta: {repr(response)}")
                    ser.write(response.encode('latin-1'))

            time.sleep(0.05)

    except KeyboardInterrupt:
        print("\nChiusura...")
    finally:
        ser.close()

if __name__ == '__main__':
    main()