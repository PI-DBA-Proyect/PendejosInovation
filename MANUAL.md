# Manual de ejecución

## Requisitos

- MySQL Server 8.0 con binlog activo en formato ROW (valor por defecto)
- Python 3.8 o superior (Windows o WSL)

## 1. Generar los datos

Desde la carpeta `base`:

```bat
:: Windows
python BaseDatos\Generador\generador.py [carpeta_salida]
```
```bash
# WSL
python3 BaseDatos/Generador/generador.py [carpeta_salida]
```

- Sin `carpeta_salida`: los archivos se crean en `BaseDatos/Generador/Datos/`.
- Con `carpeta_salida`: se crean en esa carpeta.

## 2. Copiar los datos a la carpeta de carga de MySQL

1. Consulta la carpeta de carga:
   ```sql
   SHOW VARIABLES LIKE 'secure_file_priv';
   ```
   Por defecto: `C:\ProgramData\MySQL\MySQL Server 8.0\Uploads\`
2. Coloca ahí los 9 archivos `.txt` con una de estas opciones (consola **como administrador**):
   - **A. Generar directamente en esa carpeta:**
     ```bat
     python BaseDatos\Generador\generador.py "C:\ProgramData\MySQL\MySQL Server 8.0\Uploads"
     ```
   - **B. Copiar los ya generados:**
     ```bat
     copy /Y BaseDatos\Generador\Datos\*.txt "C:\ProgramData\MySQL\MySQL Server 8.0\Uploads\"
     ```
3. Si tu carpeta de carga es otra, cambia las rutas de `LOAD DATA` en `BaseDatos/PI_BD_Banco.sql`.

## 3. Instalar las bases de datos

1. En Workbench: *Edit → Preferences → SQL Editor → DBMS connection read timeout* = `600`.
2. Abre `BaseDatos/PI_BD_Banco.sql` como `root` y ejecútalo completo.
   - Alternativa por consola: `mysql -u root -p < BaseDatos\PI_BD_Banco.sql`
3. Revisa los resultados de la sección 7:
   - Las filas de cada tabla coinciden con las líneas de su `.txt`.
   - Aparecen el trigger `trg_auditoria_saldo` y las 4 tablas de `drp_monitor`.
4. Ejecuta `DRP/scripts/01_setup_monitoreo.sql` como `root`.

**Reinstalar:** repite los pasos 2 a 4 de esta sección. Se borran todos los datos, la bitácora y el evento monitor.

## 4. Simulacro DRP

Ejecuta los scripts de `DRP/scripts/` en orden con el usuario indicado.
Los scripts marcados con `(app_banco)` en el nombre se ejecutan conectado como `app_banco`;
el resto, como `root`.

1. Abre una conexión de Workbench como `root` y otra como `app_banco`.
   La de `app_banco` se abre **después** de ejecutar el 01.
2. Ejecuta los scripts:

| Script | Rol | Usuario | Indicaciones |
|---|---|---|---|
| `00_reiniciar_ensayo.sql` | DBA | root | Solo entre ensayos, con `banco_db` sana. Después continúa en el 02. |
| `01_setup_monitoreo.sql` | DBA | root | Una vez después de instalar o reinstalar. |
| `02_respaldo_diario.bat` | DBA | root | Anota el archivo binlog y `SOURCE_LOG_POS` que muestra. |
| `03_estado_normal.sql` | Monitoreo / QA | root | — |
| `04_(app_banco)_operacion_legitima.sql` | Aplicación | **app_banco** | Anota el saldo resultante. |
| `05_(app_banco)_provocar_error.sql` | Operador | **app_banco** | — |
| `06_deteccion.sql` | Monitoreo | root | Espera hasta 30 s después del 05. |
| `07_contencion.sql` | DBA | root | Ejecuta las sentencias `KILL` que genera. |
| `08_analisis_forense.sql` | Analista de seguridad | root | Edita y ejecuta la plantilla del paso 4; obtén la posición final (Pos del `Anonymous_Gtid` del UPDATE). |
| `09_recuperacion_pitr.bat` | DBA | root | Requiere el 07 aplicado. Si avisa de un binlog posterior, usa el 10. |
| `10_recuperacion_rapida.sql` | DBA | root | Solo si falla el 09. Nunca ejecutes ambos. |
| `11_validacion.sql` | QA | root | Todo debe cumplirse antes del 12. |
| `12_cierre_incidente.sql` | Líder DRP | root | — |

- Contraseña de `app_banco`: definida en `01_setup_monitoreo.sql`.
- Por consola, pon entre comillas los nombres con paréntesis:
  `mysql -u app_banco -p < "05_(app_banco)_provocar_error.sql"`
- El 09 recupera desde **un solo** binlog: no reinicies el servicio entre el 02 y el 09.

### Opcional: no repetir la contraseña de root en los `.bat`

1. Una sola vez:
   ```bat
   "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql_config_editor.exe" set --login-path=drp -u root -p
   ```
2. En `02_respaldo_diario.bat` y `09_recuperacion_pitr.bat` cambia la línea
   `set "CONEXION=-u root -p"` por `set "CONEXION=--login-path=drp"`.

## 5. Demostración visual

1. Abre `Web/index.html` con doble clic. No necesita internet ni MySQL.
2. Controles:

| Acción | Botón | Tecla |
|---|---|---|
| Siguiente fase (animada) | Siguiente ▶ | → |
| Fase anterior | ◀ Anterior | ← |
| Reproducir / pausar todo | ▶ Reproducir | Espacio |
| Volver al inicio | ↺ | — |
| Saltar a una fase | Clic en la fase | — |

- Para abrir directamente en una fase: `index.html#3` (fases 1 a 5).
- Pasa el cursor sobre la gráfica para ver la suma de saldos en cada instante.
