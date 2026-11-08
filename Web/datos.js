// =====================================================================
// PI BD BANCO | DATOS DE LA SIMULACION
// Objetivo: instantanea real de banco_db para la demostracion visual
// Origen:   BaseDatos/Datos/cuentas.txt y clientes.txt (primeras 8 cuentas,
//           total de cuentas y suma de saldos)
// =====================================================================
const DATOS = {
  totalCuentas: 100000,
  sumaSaldos: 50071395277.14,
  deposito: 15000.00,          // Script 04: operacion legitima posterior al respaldo
  cuentas: [
    { id: 1, cliente: "Luis Cruz Diaz",          numero: "CT9479624516", tipo: "Nómina",      saldo: 379348.99 },
    { id: 2, cliente: "Daniela Silva Romero",    numero: "CT0059617188", tipo: "Ahorro",      saldo: 852925.35 },
    { id: 3, cliente: "Ramon Martinez Espinoza", numero: "CT4310933394", tipo: "Inversion",   saldo: 294108.51 },
    { id: 4, cliente: "Diego Jimenez Jimenez",   numero: "CT4057562721", tipo: "Nómina",      saldo: 214727.69 },
    { id: 5, cliente: "Gabriela Silva Onix",     numero: "CT1205850712", tipo: "Empresarial", saldo: 574048.29 },
    { id: 6, cliente: "Diana Chavez Cabrera",    numero: "CT4938761192", tipo: "Nómina",      saldo: 796084.62 },
    { id: 7, cliente: "Pedro Torres Cabrera",    numero: "CT3025812756", tipo: "Inversion",   saldo: 480318.32 },
    { id: 8, cliente: "Diana Ruiz Alvarez",      numero: "CT3808964788", tipo: "Empresarial", saldo: 967304.18 },
  ],
};
