@echo off
REM =====================================================================
REM DRP BANCO | SCRIPT 09: RECUPERACION A UN PUNTO EN EL TIEMPO (RUTA FORMAL)
REM Quien:  DBA
REM 1) Restaura el respaldo completo (estado al momento del script 02)
REM 2) Reaplica desde el binlog SOLO los cambios de banco_db ocurridos
REM    despues del respaldo y ANTES del UPDATE danino.
REM Requiere read_only = ON (script 07) para que nadie escriba mientras tanto.
REM =====================================================================
setlocal
set "MYSQL_BIN=C:\Program Files\MySQL\MySQL Server 8.0\bin"
set "DATADIR=C:\ProgramData\MySQL\MySQL Server 8.0\Data"
set "RUTA=C:\DRP\respaldos"

echo === DRP BANCO: RECUPERACION A UN PUNTO EN EL TIEMPO ===
echo.
set /p "RESPALDO=Ruta del respaldo [Enter = %RUTA%\respaldo_banco_db_ULTIMO.sql]: "
if "%RESPALDO%"=="" set "RESPALDO=%RUTA%\respaldo_banco_db_ULTIMO.sql"
set /p "BINLOG=Nombre del binlog (ej. MIPC-bin.000015): "
set /p "START_POS=Posicion inicial (SOURCE_LOG_POS del respaldo): "
set /p "STOP_POS=Posicion final (Pos del Anonymous_Gtid del UPDATE danino): "
set /p "RESTAURAR=Restaurar el respaldo completo antes de reaplicar? (S/N) [S]: "
if "%RESTAURAR%"=="" set "RESTAURAR=S"

echo.
if /I "%RESTAURAR%"=="S" (
    echo [1/3] Restaurando respaldo completo...
    "%MYSQL_BIN%\mysql.exe" -u root -p < "%RESPALDO%"
    if errorlevel 1 goto error
) else (
    echo [1/3] Restauracion omitida por el usuario.
)

echo [2/3] Extrayendo cambios legitimos del binlog...
"%MYSQL_BIN%\mysqlbinlog.exe" --database=banco_db --start-position=%START_POS% --stop-position=%STOP_POS% "%DATADIR%\%BINLOG%" > "%RUTA%\replay_binlog.sql"
if errorlevel 1 goto error

echo [3/3] Aplicando cambios legitimos...
"%MYSQL_BIN%\mysql.exe" -u root -p < "%RUTA%\replay_binlog.sql"
if errorlevel 1 goto error

echo.
echo RECUPERACION COMPLETADA. Ejecutar 11_validacion.sql
goto fin

:error
echo.
echo ERROR durante la recuperacion. Revisar el mensaje anterior.
echo Alternativa: ejecutar 10_recuperacion_rapida.sql (Plan B).

:fin
pause
endlocal
