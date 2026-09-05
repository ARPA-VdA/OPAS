@echo off
setlocal enabledelayedexpansion

:: Vai nella cartella dello script, qualunque sia la directory di lavoro (cwd)
cd /d "%~dp0"

:: --- rileva python ---
:: Su Windows di solito è 'python', raramente 'python3' (a meno di alias specifici)
where python >nul 2>nul
if %ERRORLEVEL% equ 0 (
    set PYTHON=python
) else (
    where py >nul 2>nul
    if %ERRORLEVEL% equ 0 (
        set PYTHON=py
    ) else (
        echo ERRORE: python non trovato nel PATH.
        pause
        exit /b 1
    )
)

:: --- venv ---
if not exist venv (
    echo Creo il virtual environment...
    %PYTHON% -m venv venv
    if %ERRORLEVEL% neq 0 (
        echo Errore durante la creazione del venv.
        pause
        exit /b 1
    )
)

:: --- dipendenze ---
if exist requirements.txt (
    echo Installo le dipendenze...
    :: Su Windows il percorso è venv\Scripts\pip
    venv\Scripts\pip install --quiet -r requirements.txt
) else (
    echo ATTENZIONE: requirements.txt non trovato, salto l'installazione.
)

:: --- avvio ---
echo Avvio il servizio...
:: Uso venv\Scripts\python per eseguire lo script
venv\Scripts\python src\core\service_master.py

:: Se lo script Python termina improvvisamente, tieni aperta la finestra per leggere l'errore
if %ERRORLEVEL% neq 0 (
    echo Il servizio si e interrotto con errore %ERRORLEVEL%.
    pause
)