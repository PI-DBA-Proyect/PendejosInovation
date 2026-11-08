# PI DBA — Base de datos bancaria + Plan de Recuperación ante Desastres (DRP)

Proyecto de administración de bases de datos en **MySQL 8.0 (Windows)**: base `banco_db`
con datos sintéticos, tablespaces y particionamiento, más un simulacro de DRP
(incidente → detección → contención → recuperación PITR → validación → cierre).

- **Ejecución:** ver [MANUAL.md](MANUAL.md).
- **Este documento:** estructura, convenciones y registro de cambios, para quienes mantienen el proyecto.

## Estructura

```
base/
├── README.md                    Documentación del proyecto (este archivo)
├── MANUAL.md                    Manual de ejecución
├── .gitignore
├── BaseDatos/
│   ├── Generador/
│   │   ├── generador.py         Datos sintéticos (.txt separados por '|', UTF-8, LF)
│   │   └── requirements.txt     Sin dependencias externas
│   └── PI_BD_Banco.sql          Instalación de banco_db y drp_monitor
├── DRP/scripts/                 Simulacro DRP (00 a 12); "(app_banco)" en el nombre = se ejecuta como app_banco
└── Web/                         Simulación visual del DRP (estática, sin servidor)
    ├── index.html
    ├── styles.css
    ├── app.js                   Motor de fases, animaciones y gráfica SVG
    └── datos.js                 Instantánea real de banco_db (8 cuentas, totales)
```

### Componentes

| Componente | Contenido |
|---|---|
| `banco_db` | 9 tablas; 8 en tablespaces generales `ts_*`; `transacciones` particionada por año (5 particiones) |
| `drp_monitor` | `bitacora_incidentes`, `auditoria_saldos`, `parametros`, `linea_base_cuentas` |
| Trigger `banco_db.trg_auditoria_saldo` | Registra cada cambio de saldo en `auditoria_saldos` |
| Evento `drp_monitor.ev_vigila_saldos` | Cada 30 s; alerta por cambios masivos o caída de saldos (creado en DRP 01) |
| Usuario `app_banco` | Simula la aplicación; solo DML sobre `banco_db` (creado en DRP 01) |
| Simulación web | 5 fases (operación, fallo, bloqueo, restauración, validación) con los SQL reales de cada script; no se conecta a MySQL |

### Simulación web

- `datos.js` se extrae a mano de `BaseDatos/Datos/` (primeras 8 cuentas, `COUNT` y `SUM(saldo)`).
  Si se regeneran los datos, actualizarlo para que coincida con la base.
- Tiempos simulados en `app.js` (objeto `T`): MTTD 28 s, MTTR 7 min 40 s. Son ilustrativos.
- Cada fase es una lista de eventos `[retardo_ms, función(estado)]`; ir a una fase reconstruye
  el estado aplicando al instante las anteriores.
- Diseño: se ajusta al alto de la ventana a partir de 1101×640 px; tema claro y oscuro según el sistema.

### Datos

- No se versionan: `transacciones.txt` (~105 MB) supera el límite de 100 MB de GitHub.
- Columnas únicas que el generador garantiza: `cuentas.numero_cuenta`, `tarjetas.numero_tarjeta`,
  `clientes.rfc_curp`, `clientes.email`.
- Volúmenes: constantes `TOTAL_*` en `generador.py`.

## Estándar de comentarios

Aplica a `.sql`, `.bat` y `.py`.

**Encabezado** (solo estos campos):
```sql
-- =====================================================================
-- <PROYECTO> | SCRIPT NN: <TITULO>
-- Usuario:  <root | app_banco>
-- Objetivo: <una linea>
-- =====================================================================
```

**Secciones:** `-- ####` con etiqueta y número, p. ej. `[INSTALACION] 3. CARGA DE DATOS`.

| Sí | No |
|---|---|
| Instrucciones en imperativo junto a la sentencia (`Anotar este saldo`) | Orden entre archivos (`después ejecutar 02`) → MANUAL |
| Resultado esperado (`Resultado esperado: 0 filas`) | Cuándo o quién ejecuta (roles) → MANUAL |
| Explicación técnica de por qué se hace algo, junto a la sentencia | Justificaciones en el encabezado o texto de relleno |
| Restricciones del motor (`InnoDB no admite FK en tablas particionadas`) | Requisitos previos de entorno (timeout, rutas) → MANUAL |

**Documentación:** `README.md` = estructura, decisiones y cambios. `MANUAL.md` = solo pasos de ejecución.

**Nombres de scripts DRP:** `NN_<descripcion>`; si se ejecutan como `app_banco`, `NN_(app_banco)_<descripcion>`.

## Limitaciones conocidas

- `09_recuperacion_pitr.bat` reaplica un solo binlog; avisa si existe uno posterior.
- Contraseña de `app_banco` escrita en `01_setup_monitoreo.sql` (entorno académico).

## Pendientes

- Ninguno.

## Registro de cambios

| Fecha | Archivo | Cambio | Motivo |
|---|---|---|---|
| 2026-11-08 | generador.py | Salida en `Datos/` junto al script o en la carpeta pasada como argumento | Antes dependía de la carpeta de ejecución |
| 2026-11-08 | generador.py | `open(..., newline="\n")` | En Windows, CRLF dejaría `\r` en la última columna al cargar |
| 2026-11-08 | generador.py | `numero_cuenta`, `numero_tarjeta` y `rfc_curp` sin repetidos | Columnas `UNIQUE`; antes había duplicados |
| 2026-11-08 | requirements.txt | Nuevo | Documentar que no hay dependencias externas |
| 2026-11-08 | .gitignore | Nuevo | Excluir `**/Datos/*.txt` y archivos temporales |
| 2026-11-08 | PI_BD_Banco.sql | Ejecución de una pasada; sección 0 de reinstalación con `DROP TABLESPACE` protegido | El `DROP TABLESPACE` fallaba en una instalación limpia |
| 2026-11-08 | PI_BD_Banco.sql | Llave primaria en el `CREATE TABLE`; `UNIQUE`, llaves foráneas e índices después de la carga | Evita reconstruir las tablas |
| 2026-11-08 | PI_BD_Banco.sql | `idx_transacciones_cuenta`, particiones `p2008_2011`…, `NOT NULL`, `utf8mb4` explícito | Rendimiento, integridad y acentos |
| 2026-11-08 | PI_BD_Banco.sql | Incluye las tablas de `drp_monitor`, el trigger y la sección 7 de verificación | Instalación completa en un solo script |
| 2026-11-08 | 01_setup_monitoreo.sql | Solo activa el evento y crea `app_banco` | Tablas y trigger movidos a PI_BD_Banco.sql |
| 2026-11-08 | 04_operacion_legitima.sql | `'DEPOSITO'` → `'Depósito'` | Mismo catálogo que los datos |
| 2026-11-08 | Todos los scripts | Encabezados con el estándar de comentarios; orden, roles y requisitos movidos a MANUAL.md | Separar documentación de instrucciones |
| 2026-11-08 | README.md / MANUAL.md | Separación en documentación del proyecto y manual de ejecución | Público distinto |
| 2026-11-08 | DRP 04 y 05 | Renombrados a `NN_(app_banco)_...` | Identificar los scripts que ejecuta el usuario de aplicación |
| 2026-11-08 | 01_setup_monitoreo.sql | `SET PERSIST` para `event_scheduler` y `binlog_rows_query_log_events` | `SET GLOBAL` se perdía al reiniciar y el monitor dejaba de detectar |
| 2026-11-08 | 09_recuperacion_pitr.bat | `mysqlbinlog --skip-gtids` | Con `gtid_mode=ON` la reaplicación se omitía en silencio |
| 2026-11-08 | 09_recuperacion_pitr.bat | Aviso si existe un binlog posterior | Solo reaplica un archivo; podía perder cambios legítimos |
| 2026-11-08 | 02 y 09 (.bat) | Variable `CONEXION` (admite `--login-path`) | Evitar pedir la contraseña varias veces |
| 2026-11-08 | 08_analisis_forense.sql | `SHOW BINLOG EVENTS` como plantilla comentada con `FROM ... LIMIT` | Fallaba al ejecutarse tal cual y listaba miles de eventos |
| 2026-11-08 | 12_cierre_incidente.sql | `SET PERSIST sql_safe_updates`; texto de cierre neutro | Persistencia; el texto decía PITR aunque se usara el plan B |
| 2026-11-08 | 00_reiniciar_ensayo.sql | `RESET PERSIST sql_safe_updates` | Revertir la medida del 12 entre ensayos |
| 2026-11-08 | 03 / 10 | Quitado `SQL_SAFE_UPDATES` innecesario (03); aviso sobre `@drp_restauracion` (10) | Limpieza / evitar auditoría errónea |
| 2026-11-08 | PI_BD_Banco.sql | Comentario técnico en el trigger sobre `CURRENT_TIMESTAMP(3)` | Explica por qué se agrupa por `fecha` |
| 2026-11-08 | Web/ | Nueva simulación visual del DRP | Demostración para la presentación |
