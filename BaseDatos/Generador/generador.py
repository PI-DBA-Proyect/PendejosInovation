# =====================================================================
# PI BD BANCO | GENERADOR DE DATOS
# Uso:      python generador.py [carpeta_salida]
# Objetivo: generar los 9 archivos .txt que carga PI_BD_Banco.sql
# =====================================================================
import os
import sys
import random
from datetime import datetime, timedelta

# ==========================================
# CONFIGURACIÓN GENERAL Y PARÁMETROS DE VOLUMEN
# ==========================================
# Ruta de salida:
#   python generador.py              -> carpeta "Datos" junto a este script
#   python generador.py <carpeta>    -> la carpeta indicada (ej. Uploads de MySQL)
# Los archivos se escriben con saltos de linea LF para que LOAD DATA los lea bien.
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(SCRIPT_DIR, "Datos")

# Cantidad de registros por tabla (Modificable entre 200 y 200,000+)
TOTAL_SUCURSALES = 300
TOTAL_EMPLEADOS = 6000
TOTAL_CLIENTES = 90000
TOTAL_CUENTAS = 100000
TOTAL_TARJETAS = 120000
TOTAL_TRANSACCIONES = 2000000
TOTAL_PRESTAMOS = 20000
TOTAL_INVERSIONES = 10000
TOTAL_SEGUROS = 8000

# Listas de apoyo para datos realistas

NOMBRES = [
    "Carlos", "Ana", "Luis", "Maria", "Juan", "Sofia", "Pedro", "Lucia", "Jorge", "Elena",
    "Miguel", "Laura", "Diego", "Valeria", "Alejandro", "Gabriela", "Fernanda", "Daniela",
    "Ricardo", "Mariana", "Andres", "Paola", "Eduardo", "Camila", "Roberto", "Natalia",
    "Francisco", "Adriana", "Sergio", "Patricia", "Hector", "Veronica", "Ramon", "Isabel",
    "Manuel", "Diana", "Oscar", "Regina", "Alberto", "Claudia", "Martin", "Renata",
    "Fernando", "Itzayana",
]
APELLIDOS = [
    "Gomez", "Lopez", "Perez", "Hernandez", "Rodriguez", "Martinez", "Sanchez", "Diaz",
    "Garcia", "Torres", "Ramirez", "Flores", "Vazquez", "Castillo", "Romero", "Morales",
    "Ortiz", "Gutierrez", "Chavez", "Ramos", "Mendoza", "Ruiz", "Aguilar", "Moreno",
    "Jimenez", "Alvarez", "Munoz", "Rojas", "Navarro", "Dominguez", "Vega", "Silva",
    "Cruz", "Rivera", "Mendez", "Fuentes", "Carrillo", "Cabrera", "Soto", "Espinoza",
    "Esmeralda", "Rubi", "Jade", "Ambar", "Zafiro", "Diamante", "Perla", "Granate",
    "Topacio", "Onix", "Opalo", "Aguamarina",
]
CIUDADES = [
    "CDMX", "Guadalajara", "Monterrey", "Puebla", "Queretaro", "Merida", "Toluca", "Tijuana",
    "Leon", "Juarez", "Torreon", "San Luis Potosi", "Aguascalientes", "Mexicali", "Hermosillo",
    "Culiacan", "Cancun", "Morelia", "Veracruz", "Chihuahua", "Oaxaca", "Acapulco", "Tuxtla",
    "Villahermosa", "Durango",
]
PUESTOS = [
    "Cajero", "Ejecutivo", "Gerente", "Analista", "Asesor", "Subgerente", "Director",
    "Contador", "Auditor", "Supervisor", "Consultor", "Coordinador",
]
SALARIOS_BASE = {
    "Cajero": 12000,
    "Ejecutivo": 18000,
    "Gerente": 45000,
    "Analista": 22000,
    "Asesor": 17000,
    "Subgerente": 35000,
    "Director": 75000,
    "Contador": 28000,
    "Auditor": 30000,
    "Supervisor": 25000,
    "Consultor": 32000,
    "Coordinador": 27000,
}
TIPOS_CUENTA = ["Ahorro", "Corriente", "Nómina", "Inversion", "Empresarial"]
TIPOS_TARJETA = ["Débito", "Crédito", "Oro", "Platino"]
TIPOS_TRANSACCION = ["Depósito", "Retiro", "Transferencia", "Pago de servicio", "Compra", "Consulta"]
ESTATUS_PRESTAMO = ["Activo", "Pagado", "En mora", "Pendiente", "Cancelado"]
TIPOS_SEGURO = ["Vida", "Auto", "Gastos Médicos", "Hogar", "Viaje", "Empresarial", "Educativo", "Mascotas"]

def random_string(length):
    chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    return "".join(random.choices(chars, k=length))

def random_digits(length):
    return "".join(random.choices("0123456789", k=length))

def valores_unicos(cantidad, generar):
    """Genera 'cantidad' valores distintos llamando a generar() hasta completarlos."""
    vistos = set()
    while len(vistos) < cantidad:
        vistos.add(generar())
    return list(vistos)

def numeros_unicos(cantidad, digitos):
    """Numeros aleatorios SIN repetir de 'digitos' cifras (random.sample no materializa el rango)."""
    return [f"{n:0{digitos}d}" for n in random.sample(range(10 ** digitos), cantidad)]

def random_date(start_year=2008, end_year=2026):
    start = datetime(start_year, 1, 1)
    end = datetime(end_year, 12, 31)
    return start + timedelta(seconds=random.randint(0, int((end - start).total_seconds())))

# ==========================================
# GENERACIÓN DE ARCHIVOS
# ==========================================
os.makedirs(OUTPUT_DIR, exist_ok=True)

# 1. Sucursales
if (True):    
    with open(os.path.join(OUTPUT_DIR, "sucursales.txt"), "w", encoding="utf-8", newline="\n") as f:
        for i in range(1, TOTAL_SUCURSALES + 1):
            nombre = f"Sucursal {random.choice(CIUDADES)} {i}"
            direccion = f"Av. {random.choice(APELLIDOS)} #{random.randint(100, 9999)}"
            telefono = f"55{random_digits(8)}"
            registro = f"{i}|{nombre}|{direccion}|{telefono}\n"
            f.write(registro)

# 2. Empleados
if (True):
    with open(os.path.join(OUTPUT_DIR, "empleados.txt"), "w", encoding="utf-8", newline="\n") as f:
        for i in range(1, TOTAL_EMPLEADOS + 1):
            fk_sucursal = random.randint(1, TOTAL_SUCURSALES)
            nombre = f"{random.choice(NOMBRES)} {random.choice(APELLIDOS)} {random.choice(APELLIDOS)}"
            puesto = random.choice(PUESTOS)
            salario_base = SALARIOS_BASE[puesto]
            variacion_salario = random.uniform(-500, 500)
            salario = round(salario_base + variacion_salario, 2)
            salario_texto = f"{salario:.2f}"
            registro = f"{i}|{fk_sucursal}|{nombre}|{puesto}|{salario_texto}\n"
            f.write(registro)

# 3. Clientes
if (True):
    # RFC unico (columna UNIQUE en la BD); el email ya es unico porque incluye el id
    rfcs = valores_unicos(TOTAL_CLIENTES, lambda: f"{random_string(4)}{random_digits(6)}{random_string(3)}")
    with open(os.path.join(OUTPUT_DIR, "clientes.txt"), "w", encoding="utf-8", newline="\n") as f:
        for i in range(1, TOTAL_CLIENTES + 1):
            apellido1 = random.choice(APELLIDOS)
            apellido2 = random.choice(APELLIDOS)
            nombre = f"{random.choice(NOMBRES)} {apellido1} {apellido2}"
            rfc = rfcs[i - 1]
            email = f"{apellido1.lower()}{apellido2.lower()}{i}@mail.com"
            telefono = f"55{random_digits(8)}"
            direccion = f"Calle {random.choice(APELLIDOS)} #{random.randint(10, 999)} {random.choice(CIUDADES)}"
            registro = f"{i}|{nombre}|{rfc}|{telefono}|{email}|{direccion}\n"
            f.write(registro)

# 4. Cuentas
if (True):
    # Numero de cuenta unico (columna UNIQUE en la BD)
    numeros_cuenta = numeros_unicos(TOTAL_CUENTAS, 10)
    with open(os.path.join(OUTPUT_DIR, "cuentas.txt"), "w", encoding="utf-8", newline="\n") as f:
        for i in range(1, TOTAL_CUENTAS + 1):
            fk_cliente = random.randint(1, TOTAL_CLIENTES)
            fk_sucursal = random.randint(1, TOTAL_SUCURSALES)
            saldo = round(random.uniform(100, 1000000), 2)
            fecha = random_date(2010, 2026).strftime("%Y-%m-%d")
            numero_cuenta = f"CT{numeros_cuenta[i - 1]}"
            tipo_cuenta = random.choice(TIPOS_CUENTA)
            saldo_texto = f"{saldo:.2f}"
            registro = f"{i}|{fk_cliente}|{fk_sucursal}|{numero_cuenta}|{tipo_cuenta}|{saldo_texto}|{fecha}\n"
            f.write(registro)

# 5. Tarjetas
if (True):
    # Numero de tarjeta unico (columna UNIQUE en la BD)
    numeros_tarjeta = numeros_unicos(TOTAL_TARJETAS, 12)
    with open(os.path.join(OUTPUT_DIR, "tarjetas.txt"), "w", encoding="utf-8", newline="\n") as f:
        for i in range(1, TOTAL_TARJETAS + 1):
            fk_cuenta = random.randint(1, TOTAL_CUENTAS)
            exp = random_date(2026, 2030).strftime("%Y-%m-%d")
            numero_tarjeta = f"4152{numeros_tarjeta[i - 1]}"
            tipo_tarjeta = random.choice(TIPOS_TARJETA)
            cvv = random_digits(3)
            registro = f"{i}|{fk_cuenta}|{numero_tarjeta}|{tipo_tarjeta}|{exp}|{cvv}\n"
            f.write(registro)

# 6. Transacciones (Fechas amplias para llenar las 5 particiones)
if (True):
    with open(os.path.join(OUTPUT_DIR, "transacciones.txt"), "w", encoding="utf-8", newline="\n") as f:
        for i in range(1, TOTAL_TRANSACCIONES + 1):
            fk_cuenta = random.randint(1, TOTAL_CUENTAS)
            monto = round(random.uniform(10, 25000), 2)
            fecha_hora = random_date(2008, 2026).strftime("%Y-%m-%d %H:%M:%S")
            tipo_transaccion = random.choice(TIPOS_TRANSACCION)
            monto_texto = f"{monto:.2f}"
            registro = f"{i}|{fk_cuenta}|{tipo_transaccion}|{monto_texto}|{fecha_hora}\n"
            f.write(registro)

# 7. Préstamos
if (True):
    with open(os.path.join(OUTPUT_DIR, "prestamos.txt"), "w", encoding="utf-8", newline="\n") as f:
        for i in range(1, TOTAL_PRESTAMOS + 1):
            fk_cliente = random.randint(1, TOTAL_CLIENTES)
            fk_empleado = random.randint(1, TOTAL_EMPLEADOS)
            monto = round(random.uniform(5000, 500000), 2)
            tasa = round(random.uniform(8.5, 35.0), 2)
            plazo = random.choice([6, 12, 24, 36, 48])
            estatus = random.choice(ESTATUS_PRESTAMO)
            monto_texto = f"{monto:.2f}"
            tasa_texto = f"{tasa:.2f}"
            registro = f"{i}|{fk_cliente}|{fk_empleado}|{monto_texto}|{tasa_texto}|{plazo}|{estatus}\n"
            f.write(registro)

# 8. Inversiones
if (True):
    with open(os.path.join(OUTPUT_DIR, "inversiones.txt"), "w", encoding="utf-8", newline="\n") as f:
        for i in range(1, TOTAL_INVERSIONES + 1):
            fk_cliente = random.randint(1, TOTAL_CLIENTES)
            monto = round(random.uniform(10000, 5000000), 2)
            tasa = round(random.uniform(4.0, 14.0), 2)
            fecha = random_date(2020, 2026).strftime("%Y-%m-%d")
            plazo = random.choice([30, 90, 180, 360])
            monto_texto = f"{monto:.2f}"
            tasa_texto = f"{tasa:.2f}"
            registro = f"{i}|{fk_cliente}|{monto_texto}|{tasa_texto}|{plazo}|{fecha}\n"
            f.write(registro)

# 9. Seguros
if (True):
    with open(os.path.join(OUTPUT_DIR, "seguros.txt"), "w", encoding="utf-8", newline="\n") as f:
        for i in range(1, TOTAL_SEGUROS + 1):
            fk_cliente = random.randint(1, TOTAL_CLIENTES)
            prima = round(random.uniform(200, 3000), 2)
            cobertura = round(random.uniform(50000, 2000000), 2)
            tipo_seguro = random.choice(TIPOS_SEGURO)
            prima_texto = f"{prima:.2f}"
            cobertura_texto = f"{cobertura:.2f}"
            registro = f"{i}|{fk_cliente}|{tipo_seguro}|{prima_texto}|{cobertura_texto}\n"
            f.write(registro)

print(f"Archivos creados exitosamente en: {OUTPUT_DIR}")
print("Siguiente paso: copiarlos a la carpeta de secure_file_priv (Uploads) si no se generaron ahi.")