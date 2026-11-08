@echo off
REM =====================================================================
REM DRP BANCO | SCRIPT 09: RECUPERACION A UN PUNTO EN EL TIEMPO (RUTA FORMAL)
REM Usuario:  root
REM Objetivo:
REM   1) Restaurar el respaldo completo
REM   2) Reaplicar desde el binlog solo los cambios de banco_db posteriores
REM      al respaldo y anteriores al UPDATE danino
REM =====================================================================
setlocal
set "MYSQL_BIN=C:\Program Files\MySQL\MySQL Server 8.0\bin"
set "RUTA=C:\DRP\respaldos"
REM Credenciales. Con un login-path configurado: set "CONEXION=--login-path=drp"
set "CONEXION=-u root -p"

echo === DRP BANCO: RECUPERACION A UN PUNTO EN EL TIEMPO ===
echo.
echo Obteniendo la ruta real de los binlogs...
for /f "usebackq delims=" %%i in (`"%MYSQL_BIN%\mysql.exe" %CONEXION% -N -B -e "SELECT @@log_bin_basename"`) do set "BINBASE=%%i"
if "%BINBASE%"=="" goto error
set "BINBASE=%BINBASE:/=\%"
echo Binlogs en: %BINBASE%.xxxxxx
echo.

set /p "RESPALDO=Ruta del respaldo [Enter = %RUTA%\respaldo_banco_db_ULTIMO.sql]: "
if "%RESPALDO%"=="" set "RESPALDO=%RUTA%\respaldo_banco_db_ULTIMO.sql"
if not exist "%RESPALDO%" (
    echo ERROR: no existe el respaldo %RESPALDO%
    goto fin
)

echo.
echo Linea del respaldo con archivo y posicion inicial:
findstr /C:"SOURCE_LOG_FILE" /C:"MASTER_LOG_FILE" "%RESPALDO%"
echo.
set /p "NUMERO=Numero del binlog (solo la extension, ej. 000003): "
set "BINLOG=%BINBASE%.%NUMERO%"
if not exist "%BINLOG%" (
    echo ERROR: no existe %BINLOG%
    echo Revise SHOW BINARY LOGS; No se modifico ninguna base de datos.
    goto fin
)

REM Solo se reaplica un binlog: si existe uno posterior (reinicio o rotacion
REM despues del respaldo), los cambios legitimos que contenga se perderian.
REM "1%NUMERO%" evita que set /a interprete los ceros iniciales como octal.
set "CONTINUAR=S"
set /a SIGUIENTE=1%NUMERO%+1
set "SIGUIENTE=%SIGUIENTE:~1%"
if exist "%BINBASE%.%SIGUIENTE%" (
    echo AVISO: existe un binlog posterior: %BINBASE%.%SIGUIENTE%
    echo Los cambios legitimos registrados en el no se reaplicaran.
    set /p "CONTINUAR=Continuar de todos modos? (S/N) [N]: "
)
if /I not "%CONTINUAR%"=="S" goto fin

set /p "START_POS=Posicion inicial (SOURCE_LOG_POS del respaldo): "
set /p "STOP_POS=Posicion final (Pos del Anonymous_Gtid del UPDATE danino): "
set /p "RESTAURAR=Restaurar el respaldo completo antes de reaplicar? (S/N) [S]: "
if "%RESTAURAR%"=="" set "RESTAURAR=S"

echo.
if /I "%RESTAURAR%"=="S" (
    echo [1/3] Restaurando respaldo completo...
    "%MYSQL_BIN%\mysql.exe" %CONEXION% < "%RESPALDO%"
    if errorlevel 1 goto error
) else (
    echo [1/3] Restauracion omitida por el usuario.
)

echo [2/3] Extrayendo cambios legitimos del binlog...
REM --skip-gtids: con gtid_mode=ON el servidor omitiria en silencio las
REM transacciones cuyo GTID ya figura como aplicado y no se reaplicaria nada.
"%MYSQL_BIN%\mysqlbinlog.exe" --skip-gtids --database=banco_db --start-position=%START_POS% --stop-position=%STOP_POS% "%BINLOG%" > "%RUTA%\replay_binlog.sql"
if errorlevel 1 goto error

echo [3/3] Aplicando cambios legitimos...
"%MYSQL_BIN%\mysql.exe" %CONEXION% < "%RUTA%\replay_binlog.sql"
if errorlevel 1 goto error

echo.
echo RECUPERACION COMPLETADA.
goto fin

:error
echo.
echo ERROR durante la recuperacion. Revisar el mensaje anterior.

:fin
pause
endlocal
