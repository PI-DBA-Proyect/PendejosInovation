@echo off
REM =====================================================================
REM DRP BANCO | SCRIPT 02: RESPALDO COMPLETO DIARIO
REM Usuario:  root
REM Objetivo: respaldo consistente con la posicion del binlog registrada
REM --flush-logs abre un binlog nuevo justo al momento del respaldo.
REM Si MySQL es menor a 8.0.26 cambiar --source-data=2 por --master-data=2
REM =====================================================================
setlocal
set "MYSQL_BIN=C:\Program Files\MySQL\MySQL Server 8.0\bin"
set "RUTA=C:\DRP\respaldos"
REM Credenciales. Con un login-path configurado: set "CONEXION=--login-path=drp"
set "CONEXION=-u root -p"
if not exist "%RUTA%" mkdir "%RUTA%"

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set FECHA=%%i
set "ARCHIVO=%RUTA%\respaldo_banco_db_%FECHA%.sql"

echo Generando respaldo en %ARCHIVO% ...
"%MYSQL_BIN%\mysqldump.exe" %CONEXION% --databases banco_db --single-transaction --routines --triggers --events --flush-logs --source-data=2 --result-file="%ARCHIVO%"
if errorlevel 1 (
    echo ERROR: el respaldo no se genero correctamente.
    pause
    exit /b 1
)

copy /Y "%ARCHIVO%" "%RUTA%\respaldo_banco_db_ULTIMO.sql" >nul

echo.
echo Respaldo terminado. Posicion del binlog al momento del respaldo:
echo (ANOTAR el nombre del archivo y SOURCE_LOG_POS, se usan en la recuperacion)
findstr /C:"CHANGE REPLICATION SOURCE" /C:"CHANGE MASTER" "%ARCHIVO%"
echo.
pause
endlocal
