// =====================================================================
// PI BD BANCO | SIMULACION DRP
// Objetivo: reproducir por fases el simulacro DRP (scripts 02 a 12)
// Cada fase es una lista de eventos [retardo_ms, funcion(estado)].
// Ir a una fase = reconstruir el estado aplicando al instante todas las
// fases anteriores y animar solo los eventos de la fase destino.
// =====================================================================
(() => {
  'use strict';

  const dinero = new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' });
  const entero = new Intl.NumberFormat('es-MX');
  const BASE = DATOS.sumaSaldos;
  const DEP = DATOS.deposito;
  const TOTAL = DATOS.totalCuentas;
  const INICIO = new Date(2026, 10, 8, 12, 0, 0);

  // Segundos simulados de cada hito (MTTD = deteccion - fallo)
  const T = {
    respaldo: 0, lineaBase: 10, deposito: 20, fallo: 60, deteccion: 88, atencion: 110,
    bloqueo: 130, forense: 200, restInicio: 330, restFin: 420, binlog: 450,
    validado: 500, reapertura: 520, fin: 540,
  };

  // Suma de saldos en el tiempo simulado (serie de la grafica)
  function sumaEn(t) {
    if (t < T.deposito) return BASE;
    if (t < T.fallo) return BASE + DEP;
    if (t < T.restInicio) return 0;
    if (t < T.restFin) return BASE * (t - T.restInicio) / (T.restFin - T.restInicio);
    if (t < T.binlog) return BASE;
    return BASE + DEP;
  }

  // ------------------------------------------------------------------
  // Estado
  // ------------------------------------------------------------------
  function estadoInicial() {
    return {
      t: 0,
      estado: 'operativo',
      estadoTexto: 'OPERATIVO',
      cuentas: DATOS.cuentas.map(c => ({ ...c, original: c.saldo, etiqueta: null, destello: null })),
      suma: BASE,
      ceros: 0,
      readOnly: false,
      incidentes: [],
      registro: [],
      progreso: null,
      bloqueo: false,
      bloqueoError: '',
      metricas: { mttd: null, mttr: null, rec: null, rpo: null },
    };
  }

  function log(s, tipo, msg) { s.registro.unshift({ t: s.t, tipo, msg }); }

  // ------------------------------------------------------------------
  // Fases
  // ------------------------------------------------------------------
  const FASES = [
    {
      titulo: 'Operación normal', sub: 'Scripts 02 – 04', usuario: 'root · app_banco', app: false,
      sql: '-- 02 Respaldo completo con la posición del binlog\n' +
           'mysqldump --databases banco_db --single-transaction --flush-logs --source-data=2\n' +
           '-- 04 Operación legítima posterior al respaldo\n' +
           'UPDATE cuentas SET saldo = saldo + 15000 WHERE id_cuenta = 1;',
      texto: 'La base atiende con normalidad. Se genera el respaldo y después un cliente recibe un depósito legítimo que el DRP debe conservar.',
      eventos: [
        [0, s => {
          s.t = T.respaldo;
          log(s, 'ok', 'Respaldo completo generado: respaldo_banco_db_ULTIMO.sql');
        }],
        [900, s => {
          s.t = T.lineaBase;
          log(s, 'info', `Línea base capturada: ${entero.format(TOTAL)} cuentas · ${dinero.format(BASE)}`);
        }],
        [1100, s => {
          s.t = T.deposito;
          const c = s.cuentas[0];
          c.saldo += DEP;
          c.etiqueta = { txt: '+ $15,000.00 depósito', mala: false };
          c.destello = 'ok';
          s.suma = BASE + DEP;
          log(s, 'ok', `app_banco: depósito de ${dinero.format(DEP)} en ${c.numero}`);
        }],
        [1200, s => { s.t = 40; }],
      ],
    },
    {
      titulo: 'Fallo', sub: 'Script 05', usuario: 'app_banco', app: true,
      sql: 'SET SQL_SAFE_UPDATES = 0;\nUPDATE cuentas SET saldo = 0;   -- falta el WHERE',
      texto: 'Un operador ejecuta un ajuste de saldos sin WHERE: las 100,000 cuentas quedan en $0.00 y el cliente ve desaparecer su dinero.',
      eventos: [
        [0, s => {
          s.t = T.fallo;
          s.estado = 'incidente';
          s.estadoTexto = 'INCIDENTE';
          s.cuentas[0].etiqueta = null;
          log(s, 'mal', `app_banco: UPDATE cuentas SET saldo = 0 → ${entero.format(TOTAL)} filas afectadas`);
        }],
        ...DATOS.cuentas.map((_, i) => [i === 0 ? 500 : 140, s => {
          const c = s.cuentas[i];
          c.saldo = 0;
          c.destello = 'mal';
          c.etiqueta = { txt: 'saldo en $0.00', mala: true };
        }]),
        [400, s => {
          s.t = 75;
          s.suma = 0;
          s.ceros = TOTAL;
          log(s, 'warn', `trg_auditoria_saldo: ${entero.format(TOTAL)} cambios registrados con su saldo anterior`);
        }],
      ],
    },
    {
      titulo: 'Detección y bloqueo', sub: 'Scripts 06 – 07', usuario: 'root', app: false,
      sql: '-- 06 Declarar la contingencia\n' +
           "UPDATE bitacora_incidentes SET estatus = 'EN_ATENCION' WHERE estatus = 'ABIERTO';\n" +
           '-- 07 Bloquear las escrituras de la aplicación\n' +
           'SET GLOBAL read_only = ON;',
      texto: 'El monitor detecta la anomalía en su siguiente ciclo. Se declara la contingencia y la base pasa a solo lectura: el daño deja de crecer.',
      eventos: [
        [0, s => {
          s.t = T.deteccion;
          s.cuentas.forEach(c => { c.destello = null; });
          s.incidentes.unshift(
            { tipo: 'CAIDA_SALDOS', estatus: 'ABIERTO' },
            { tipo: 'MODIFICACION_MASIVA', estatus: 'ABIERTO' },
          );
          s.metricas.mttd = `${T.deteccion - T.fallo} s`;
          log(s, 'mal', `ev_vigila_saldos: MODIFICACION_MASIVA (${entero.format(TOTAL)} cambios/min)`);
          log(s, 'mal', 'ev_vigila_saldos: CAIDA_SALDOS (suma de saldos en $0.00)');
        }],
        [1400, s => {
          s.t = T.atencion;
          s.incidentes.forEach(i => { i.estatus = 'EN_ATENCION'; });
          log(s, 'warn', 'Contingencia declarada: incidentes EN_ATENCION');
        }],
        [1300, s => {
          s.t = T.bloqueo;
          s.estado = 'contencion';
          s.estadoTexto = 'CONTENCIÓN';
          s.readOnly = true;
          s.bloqueo = true;
          log(s, 'warn', 'read_only = ON · sesiones de app_banco terminadas (KILL)');
        }],
        [1500, s => {
          s.t = 140;
          s.bloqueoError = 'ERROR 1290 (HY000): The MySQL server is\nrunning with the --read-only option';
          log(s, 'mal', 'app_banco: intento de UPDATE rechazado → ERROR 1290');
        }],
      ],
    },
    {
      titulo: 'Restauración', sub: 'Scripts 08 – 09', usuario: 'root', app: false,
      sql: "-- 08 Ubicar el UPDATE dañino en el binlog\n" +
           "SHOW BINLOG EVENTS IN 'binlog.000004' FROM 157 LIMIT 50;\n" +
           '-- 09 Restaurar el respaldo y reaplicar solo lo legítimo\n' +
           'mysql < respaldo_banco_db_ULTIMO.sql\n' +
           'mysqlbinlog --skip-gtids --database=banco_db --start-position=157 --stop-position=48211 binlog.000004 | mysql',
      texto: 'Con la base bloqueada se localiza el error en el binlog. Se restaura el respaldo y se reaplican los cambios legítimos posteriores, hasta justo antes del UPDATE.',
      eventos: [
        [0, s => {
          s.t = T.forense;
          s.estado = 'recuperando';
          s.estadoTexto = 'RECUPERANDO';
          s.bloqueoError = '';
          log(s, 'info', 'Forense: UPDATE dañino en binlog.000004 · STOP POSITION 48211');
        }],
        [1200, s => {
          s.t = T.restInicio;
          s.progreso = { v: 0, txt: 'Restaurando respaldo' };
          log(s, 'info', '[1/3] Restaurando el respaldo completo');
        }],
        ...Array.from({ length: 10 }, (_, k) => [220, s => {
          const v = (k + 1) * 10;
          s.progreso = { v, txt: 'Restaurando respaldo' };
          s.t = T.restInicio + (T.restFin - T.restInicio) * v / 100;
          s.suma = sumaEn(s.t);
          const hasta = Math.round(s.cuentas.length * v / 100);
          s.cuentas.forEach((c, i) => {
            if (i < hasta && c.saldo === 0) {
              c.saldo = c.original;
              c.etiqueta = { txt: 'restaurada del respaldo', mala: false };
              c.destello = 'ok';
            }
          });
          s.ceros = Math.round(TOTAL * (1 - v / 100));
        }]),
        [500, s => {
          s.t = T.restFin;
          s.cuentas.forEach(c => { c.destello = null; });
          log(s, 'ok', `Respaldo restaurado: ${entero.format(TOTAL)} cuentas (estado del script 02)`);
          log(s, 'info', '[2/3] Extrayendo cambios legítimos del binlog hasta la posición 48211');
          s.progreso = { v: 100, txt: 'Reaplicando binlog' };
        }],
        [1300, s => {
          s.t = T.binlog;
          const c = s.cuentas[0];
          c.saldo = c.original + DEP;
          c.etiqueta = { txt: '+ $15,000.00 reaplicado', mala: false };
          c.destello = 'ok';
          s.suma = BASE + DEP;
          log(s, 'ok', `[3/3] Depósito de ${dinero.format(DEP)} reaplicado desde el binlog`);
        }],
        [800, s => { s.t = 460; s.cuentas[0].destello = null; }],
      ],
    },
    {
      titulo: 'Validación y cierre', sub: 'Scripts 11 – 12', usuario: 'root', app: false,
      sql: '-- 11 Validación contra la auditoría y la línea base\n' +
           'SELECT COUNT(*) AS cuentas_sin_recuperar FROM ...;   -- 0\n' +
           '-- 12 Reabrir el servicio y cerrar el incidente\n' +
           'SET GLOBAL read_only = OFF;\n' +
           "UPDATE bitacora_incidentes SET estatus = 'RESUELTO' WHERE ...;",
      texto: 'Las validaciones confirman la recuperación total, incluido el depósito posterior al respaldo. Se reabre el servicio y se cierra el incidente.',
      eventos: [
        [0, s => {
          s.t = T.validado;
          s.progreso = null;
          log(s, 'ok', `Cuentas sin recuperar: 0 de ${entero.format(TOTAL)}`);
        }],
        [700, s => { log(s, 'ok', `Diferencia vs. línea base: ${dinero.format(DEP)} (el depósito)`); }],
        [700, s => { log(s, 'ok', 'Depósito posterior al respaldo conservado (RPO = 0)'); }],
        [1100, s => {
          s.t = T.reapertura;
          s.estado = 'operativo';
          s.estadoTexto = 'OPERATIVO · RESTABLECIDO';
          s.readOnly = false;
          s.bloqueo = false;
          s.incidentes.forEach(i => { i.estatus = 'RESUELTO'; });
          s.cuentas.forEach((c, i) => {
            c.etiqueta = i === 0 ? { txt: '+ $15,000.00 conservado', mala: false } : null;
          });
          const mttr = T.reapertura - T.fallo;
          s.metricas.mttr = `${Math.floor(mttr / 60)} min ${mttr % 60} s`;
          s.metricas.rec = `${entero.format(TOTAL)} / ${entero.format(TOTAL)}`;
          s.metricas.rpo = '0';
          log(s, 'ok', 'read_only = OFF · servicio reabierto · incidentes RESUELTOS');
        }],
        [600, s => { s.t = T.fin; }],
      ],
    },
  ];

  // ------------------------------------------------------------------
  // Utilidades de interfaz
  // ------------------------------------------------------------------
  const $ = id => document.getElementById(id);
  const esc = txt => txt.replace(/[&<>]/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[ch]));

  function hora(t) {
    const d = new Date(INICIO.getTime() + t * 1000);
    return d.toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false });
  }

  function resaltarSql(sql) {
    const kw = /\b(UPDATE|SET|WHERE|SELECT|FROM|SHOW|BINLOG|EVENTS|IN|LIMIT|GLOBAL|AS|COUNT|ON|OFF)\b/g;
    return sql.split('\n').map(linea => {
      if (linea.trim().startsWith('--')) return `<span class="cm">${esc(linea)}</span>`;
      const [codigo, ...resto] = linea.split('   --');
      const comentario = resto.length ? `<span class="cm">   --${esc(resto.join('   --'))}</span>` : '';
      return esc(codigo).replace(kw, '<span class="kw">$1</span>') + comentario;
    }).join('\n');
  }

  // Interpolacion de numeros para que los cambios se lean como movimiento
  function ponerNumero(el, valor, formato, animar) {
    const desde = el._v ?? valor;
    el._v = valor;
    cancelAnimationFrame(el._raf);
    if (!animar || desde === valor) { el.textContent = formato(valor); return; }
    const t0 = performance.now(), dur = 650;
    const paso = ahora => {
      const p = Math.min(1, (ahora - t0) / dur);
      const e = 1 - Math.pow(1 - p, 3);
      el.textContent = formato(desde + (valor - desde) * e);
      if (p < 1) el._raf = requestAnimationFrame(paso);
    };
    el._raf = requestAnimationFrame(paso);
  }

  // ------------------------------------------------------------------
  // Construccion inicial
  // ------------------------------------------------------------------
  function construir() {
    $('fases').innerHTML = FASES.map((f, i) => `
      <li class="fase" data-i="${i}" tabindex="0" role="button" aria-label="Fase ${i + 1}: ${f.titulo}">
        <span class="fase-num">${i + 1}</span>
        <span class="fase-txt"><strong>${f.titulo}</strong><small>${f.sub}</small></span>
      </li>`).join('');

    $('cuentas').innerHTML = DATOS.cuentas.map((c, i) => {
      const ini = c.cliente.split(' ').slice(0, 2).map(p => p[0]).join('');
      return `
      <li class="cuenta" id="cuenta-${i}">
        <span class="avatar" aria-hidden="true">${ini}</span>
        <span class="cuenta-info">
          <strong>${esc(c.cliente)}</strong>
          <small>${c.tipo} · •••• ${c.numero.slice(-4)}</small>
        </span>
        <span class="cuenta-saldo">
          <strong class="monto" id="saldo-${i}"></strong>
          <span class="etiqueta" id="etq-${i}" hidden></span>
        </span>
      </li>`;
    }).join('');
    $('kpi-total').textContent = entero.format(TOTAL);
  }

  // ------------------------------------------------------------------
  // Pintado
  // ------------------------------------------------------------------
  function pintarEscena() {
    const f = FASES[fase];
    $('escena-script').textContent = f.sub;
    const u = $('escena-usuario');
    u.textContent = f.usuario;
    u.classList.toggle('app', f.app);
    $('escena-sql').innerHTML = resaltarSql(f.sql);
    $('escena-texto').textContent = f.texto;
    document.querySelectorAll('.fase').forEach((li, i) => {
      li.classList.toggle('activa', i === fase);
      li.classList.toggle('hecha', i < fase);
      li.setAttribute('aria-current', i === fase ? 'step' : 'false');
    });
    $('btn-ant').disabled = fase === 0;
    $('btn-sig').disabled = fase === FASES.length - 1;
  }

  function pintar(animar) {
    const s = estado;
    document.body.dataset.estado = s.estado;
    $('estado-texto').textContent = s.estadoTexto;
    $('estado-icono').textContent = { operativo: '●', incidente: '✕', contencion: '▲', recuperando: '↻' }[s.estado];
    $('reloj').textContent = hora(s.t);

    // Vista del cliente
    s.cuentas.forEach((c, i) => {
      const fila = $(`cuenta-${i}`);
      fila.classList.toggle('cero', c.saldo === 0);
      fila.classList.toggle('destello-ok', c.destello === 'ok');
      fila.classList.toggle('destello-mal', c.destello === 'mal');
      ponerNumero($(`saldo-${i}`), c.saldo, v => dinero.format(v), animar);
      const etq = $(`etq-${i}`);
      etq.hidden = !c.etiqueta;
      if (c.etiqueta) {
        etq.textContent = c.etiqueta.txt;
        etq.classList.toggle('mala', c.etiqueta.mala);
      }
    });
    $('bloqueo').hidden = !s.bloqueo;
    $('bloqueo-error').textContent = s.bloqueoError;

    // KPIs
    ponerNumero($('kpi-suma'), s.suma, v => dinero.format(v), animar);
    ponerNumero($('kpi-ceros'), s.ceros, v => entero.format(Math.round(v)), animar);
    $('kpi-ceros').classList.toggle('mal', s.ceros > 0);
    $('kpi-ro').textContent = s.readOnly ? 'ON' : 'OFF';
    $('kpi-ro').classList.toggle('alerta', s.readOnly);
    const abiertos = s.incidentes.filter(i => i.estatus !== 'RESUELTO').length;
    $('kpi-inc').textContent = abiertos;
    $('kpi-inc').classList.toggle('mal', abiertos > 0);

    // Bitacora
    const claseEst = { ABIERTO: 'abierto', EN_ATENCION: 'atencion', RESUELTO: 'resuelto' };
    $('bitacora').innerHTML = s.incidentes.length
      ? s.incidentes.map(i => `
          <li class="incidente">
            <span class="sev">CRÍTICA</span>
            <span class="tipo">${i.tipo}</span>
            <span class="est ${claseEst[i.estatus]}">${i.estatus}</span>
          </li>`).join('')
      : '<li class="vacio">Sin incidentes registrados.</li>';

    // Registro
    const icono = { ok: '✓', mal: '✕', warn: '▲', info: '•' };
    $('registro').innerHTML = s.registro.map(r => `
      <li class="${r.tipo}"><span class="t">${hora(r.t)}</span><span class="i">${icono[r.tipo]}</span><span>${esc(r.msg)}</span></li>`).join('');

    // Progreso de la restauracion
    $('progreso').hidden = !s.progreso;
    if (s.progreso) {
      $('progreso-relleno').style.width = `${s.progreso.v}%`;
      $('progreso-texto').textContent = `${s.progreso.v}%`;
    }

    // Metricas
    const m = s.metricas;
    $('m-mttd').textContent = m.mttd ?? '—';
    $('m-mttr').textContent = m.mttr ?? '—';
    $('m-rec').textContent = m.rec ?? '—';
    $('m-rpo').textContent = m.rpo ?? '—';
    $('m-rec').classList.toggle('ok', !!m.rec);
    $('m-rpo').classList.toggle('ok', !!m.rpo);

    dibujarGrafica();
  }

  // ------------------------------------------------------------------
  // Grafica SVG: una sola serie (sin leyenda), linea de 2px, crosshair
  // ------------------------------------------------------------------
  const NS = 'http://www.w3.org/2000/svg';
  const M = { izq: 74, der: 16, arr: 22, aba: 26 };
  const Y_MAX = Math.ceil(BASE * 1.12 / 1e10) * 1e10;
  let escalas = null;

  function etiquetaY(v) {
    if (v === 0) return '$0';
    return `$${entero.format(v / 1e9)} mil M`;
  }

  function dibujarGrafica() {
    const svg = $('grafica');
    const ancho = svg.clientWidth || 600;
    const alto = svg.clientHeight || 210;
    svg.setAttribute('viewBox', `0 0 ${ancho} ${alto}`);
    const x = t => M.izq + (t / T.fin) * (ancho - M.izq - M.der);
    const y = v => alto - M.aba - (v / Y_MAX) * (alto - M.arr - M.aba);
    escalas = { x, y, ancho, alto };
    const hasta = estado.t;

    let h = '';
    // Rejilla y eje Y
    for (let v = 0; v <= Y_MAX; v += Y_MAX / 3) {
      const yy = y(v);
      h += `<line x1="${M.izq}" x2="${ancho - M.der}" y1="${yy}" y2="${yy}" stroke="var(--${v === 0 ? 'eje' : 'grid'})" stroke-width="1"/>`;
      h += `<text x="${M.izq - 8}" y="${yy + 4}" text-anchor="end" font-size="11" fill="var(--muted)">${etiquetaY(v)}</text>`;
    }
    // Eje X (minutos)
    for (let t = 0; t <= T.fin; t += 60) {
      h += `<text x="${x(t)}" y="${alto - 8}" text-anchor="middle" font-size="11" fill="var(--muted)">${hora(t).slice(0, 5)}</text>`;
    }
    // Hitos alcanzados
    [[T.fallo, 'Fallo'], [T.bloqueo, 'Bloqueo'], [T.reapertura, 'Reapertura']].forEach(([t, txt]) => {
      if (hasta < t) return;
      h += `<line x1="${x(t)}" x2="${x(t)}" y1="${M.arr - 6}" y2="${alto - M.aba}" stroke="var(--eje)" stroke-dasharray="3 3"/>`;
      const alFinal = x(t) > ancho - 90;   // cerca del borde derecho: etiqueta a la izquierda
      h += `<text x="${x(t) + (alFinal ? -4 : 4)}" y="${M.arr - 8}" text-anchor="${alFinal ? 'end' : 'start'}" font-size="11" fill="var(--tinta-2)">${txt}</text>`;
    });
    // Serie hasta el instante actual
    const puntos = [];
    for (let t = 0; t <= hasta; t += 2) puntos.push([t, sumaEn(t)]);
    if (puntos.length && puntos[puntos.length - 1][0] !== hasta) puntos.push([hasta, sumaEn(hasta)]);
    // Escalones verticales exactos en el fallo
    const ruta = puntos.map(([t, v], i) => `${i ? 'L' : 'M'}${x(t).toFixed(1)},${y(v).toFixed(1)}`).join('');
    if (puntos.length > 1) {
      const area = `${ruta}L${x(hasta).toFixed(1)},${y(0)}L${x(0)},${y(0)}Z`;
      h += `<path d="${area}" fill="var(--serie)" opacity=".08"/>`;
      h += `<path d="${ruta}" fill="none" stroke="var(--serie)" stroke-width="2" stroke-linejoin="round"/>`;
    }
    const [ut, uv] = [hasta, sumaEn(hasta)];
    h += `<circle cx="${x(ut)}" cy="${y(uv)}" r="5" fill="var(--serie)" stroke="var(--superficie)" stroke-width="2"/>`;
    // Capa de hover
    h += `<g id="hover" style="display:none"><line id="hover-linea" y1="${M.arr}" y2="${alto - M.aba}" stroke="var(--tinta-2)" stroke-width="1"/>` +
         `<circle id="hover-punto" r="5" fill="var(--serie)" stroke="var(--superficie)" stroke-width="2"/></g>`;
    h += `<rect id="hover-area" x="${M.izq}" y="0" width="${ancho - M.izq - M.der}" height="${alto}" fill="transparent"/>`;
    svg.innerHTML = h;
  }

  function hoverGrafica(ev) {
    if (!escalas) return;
    const svg = $('grafica');
    const r = svg.getBoundingClientRect();
    const px = ev.clientX - r.left;
    const { x, y, ancho } = escalas;
    let t = ((px - M.izq) / (ancho - M.izq - M.der)) * T.fin;
    t = Math.max(0, Math.min(estado.t, Math.round(t)));
    const v = sumaEn(t);
    const g = svg.querySelector('#hover');
    g.style.display = '';
    svg.querySelector('#hover-linea').setAttribute('x1', x(t));
    svg.querySelector('#hover-linea').setAttribute('x2', x(t));
    svg.querySelector('#hover-punto').setAttribute('cx', x(t));
    svg.querySelector('#hover-punto').setAttribute('cy', y(v));
    const tip = $('tooltip');
    tip.hidden = false;
    tip.innerHTML = `<small>${hora(t)}</small><b>${dinero.format(v)}</b>`;
    tip.style.left = `${x(t)}px`;
    tip.style.top = `${y(v)}px`;
  }

  function salirGrafica() {
    const g = $('grafica').querySelector('#hover');
    if (g) g.style.display = 'none';
    $('tooltip').hidden = true;
  }

  // ------------------------------------------------------------------
  // Motor de fases y controles
  // ------------------------------------------------------------------
  let fase = 0;
  let estado = estadoInicial();
  let temporizadores = [];
  let reproduciendo = false;

  function cancelar() { temporizadores.forEach(clearTimeout); temporizadores = []; }

  function irA(n, animar) {
    cancelar();
    fase = Math.max(0, Math.min(FASES.length - 1, n));
    estado = estadoInicial();
    for (let p = 0; p < fase; p++) FASES[p].eventos.forEach(([, fn]) => fn(estado));
    estado.cuentas.forEach(c => { c.destello = null; });
    pintarEscena();

    const eventos = FASES[fase].eventos;
    if (!animar) {
      eventos.forEach(([, fn]) => fn(estado));
      estado.cuentas.forEach(c => { c.destello = null; });
      pintar(false);
      return;
    }
    pintar(false);
    let acumulado = 0;
    eventos.forEach(([retardo, fn], i) => {
      acumulado += retardo;
      temporizadores.push(setTimeout(() => {
        fn(estado);
        pintar(true);
        if (i === eventos.length - 1) alTerminarFase();
      }, acumulado));
    });
  }

  function alTerminarFase() {
    if (!reproduciendo) return;
    if (fase < FASES.length - 1) {
      temporizadores.push(setTimeout(() => irA(fase + 1, true), 2600));
    } else {
      ponerReproduccion(false);
    }
  }

  function ponerReproduccion(activo) {
    reproduciendo = activo;
    $('btn-play').textContent = activo ? '❚❚ Pausar' : '▶ Reproducir';
  }

  function alternarReproduccion() {
    if (reproduciendo) { ponerReproduccion(false); return; }
    ponerReproduccion(true);
    irA(fase === FASES.length - 1 ? 0 : fase + 1, true);
  }

  function siguiente() { ponerReproduccion(false); irA(fase + 1, true); }
  function anterior() { ponerReproduccion(false); irA(fase - 1, false); }

  construir();
  $('btn-sig').addEventListener('click', siguiente);
  $('btn-ant').addEventListener('click', anterior);
  $('btn-play').addEventListener('click', alternarReproduccion);
  $('btn-reset').addEventListener('click', () => { ponerReproduccion(false); irA(0, false); });
  $('fases').addEventListener('click', ev => {
    const li = ev.target.closest('.fase');
    if (li) { ponerReproduccion(false); irA(Number(li.dataset.i), true); }
  });
  $('fases').addEventListener('keydown', ev => {
    const li = ev.target.closest('.fase');
    if (li && (ev.key === 'Enter' || ev.key === ' ')) { ev.preventDefault(); ev.stopPropagation(); li.click(); }
  });
  // Atajos globales aunque el foco quede en un boton; el espacio se anula
  // para que no active ademas el boton enfocado.
  document.addEventListener('keydown', ev => {
    if (ev.key === 'ArrowRight') siguiente();
    else if (ev.key === 'ArrowLeft') anterior();
    else if (ev.key === ' ') { ev.preventDefault(); alternarReproduccion(); }
  });
  $('grafica-caja').addEventListener('mousemove', hoverGrafica);
  $('grafica-caja').addEventListener('mouseleave', salirGrafica);
  new ResizeObserver(() => dibujarGrafica()).observe($('grafica-caja'));

  // index.html#3 abre directamente en la fase 3
  const inicial = parseInt(location.hash.slice(1), 10);
  irA(Number.isInteger(inicial) ? inicial - 1 : 0, false);
})();
