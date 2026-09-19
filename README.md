# UVM UART Verification Guide

Aprende a verificar un UART 8N1 con un testbench UVM de dos agentes, paso a paso y sin magia.

## Qué aprenderás

- Cómo funciona un UART 8N1 por dentro: bit de inicio, 8 bits de datos LSB primero, bit de stop y el parámetro `CLKS_PER_BIT`.
- Cómo modelar el DUT con una interfaz SystemVerilog (`uart_if.sv`) y conectarla al testbench.
- Cómo construir dos agentes UVM independientes: uno para el camino de TX y otro para el camino de RX.
- Cómo escribir drivers que "bit-banguean" la línea serie y monitores que decodifican tramas a nivel de bit.
- Cómo comparar lo enviado contra lo recibido con un scoreboard (bytes de host vs. tramas de línea, y tramas inyectadas vs. salidas del DUT).
- Cómo detectar errores reales: bit de stop malo, glitches en la línea y bugs inyectados en el RTL.
- Cómo medir cobertura funcional y por qué muestrear en el medio del bit.

## Estructura del repositorio

```
uvm-uart-verification-guide/
├── rtl/
│   └── uart_core.sv          # DUT: núcleo UART 8N1 con parámetro CLKS_PER_BIT
├── tb/
│   ├── uart_if.sv            # Interfaz SystemVerilog con las señales del UART
│   ├── uart_tx_item.sv       # Transacción de bytes a transmitir (camino TX)
│   ├── uart_rx_item.sv       # Transacción de tramas a inyectar (camino RX)
│   ├── uart_sequences.sv     # Secuencias UVM para estimular ambos caminos
│   ├── uart_tx_driver.sv     # Driver que entrega bytes al DUT cuando tx_ready está alto
│   ├── uart_tx_monitor.sv    # Monitor TX: host_ap (bytes aceptados) y line_ap (tramas decodificadas de txd)
│   ├── uart_rx_driver.sv     # Driver RX: bit-banguea rxd, con opciones bad_stop y glitch
│   ├── uart_rx_monitor.sv    # Monitor RX: in_ap (decodificado de rxd) y out_ap (rx_valid / rx_frame_err)
│   ├── uart_agents.sv        # Define uart_tx_agent y uart_rx_agent
│   ├── uart_scoreboard.sv    # Compara camino TX (host vs. línea) y camino RX (inyectado vs. salidas)
│   ├── uart_coverage.sv      # Cobertura funcional del testbench
│   ├── uart_env.sv           # Entorno UVM que arma agentes, scoreboard y cobertura
│   ├── uart_tests.sv         # Tests: uart_tx_test, uart_rx_test, uart_error_test, uart_glitch_test, uart_full_duplex_test
│   ├── uart_pkg.sv           # Paquete UVM que agrupa todas las clases
│   ├── tb_top.sv             # Top-level: instancia DUT, interfaz y arranca UVM
│   ├── selfcheck_tb.sv       # Testbench SystemVerilog plano con decodificador y generador de tramas independientes (incluye tramas con baudrate desviado)
│   └── baud_sweep_tb.sv      # Barrido de tolerancia de baudrate del receptor (de -12 % a +12 %, paso 0,5 %)
├── sim/
│   ├── run_selfcheck.sh      # Corre el self-check con Verilator 5
│   ├── run_baud_sweep.sh     # Corre el barrido de tolerancia de baudrate con Verilator 5
│   └── run_questa.sh         # Corre un test UVM con Questa
├── docs/
│   └── index.html            # Guía web didáctica e interactiva (ábrela en tu navegador)
└── README.md
```

## Cómo ejecutarlo

**Opción A — Self-check con Verilator (necesitas Verilator 5):**

```bash
bash sim/run_selfcheck.sh
```

**Opción B — UVM con Questa:**

```bash
bash sim/run_questa.sh uart_full_duplex_test
```

**Opción C — Otros simuladores comerciales (VCS / Xcelium):**

Usa la misma lista de archivos:

```
rtl/uart_core.sv tb/uart_if.sv tb/uart_pkg.sv tb/tb_top.sv
```

con `+incdir+tb` y `+UVM_TESTNAME=<test>`.

## Estado de verificación

> **Importante — esto es lo que se verificó y lo que no, sin adornos.**

**RTL: VERIFICADO ✅**

- Verificado con **Verilator 5.052** usando `tb/selfcheck_tb.sv` (SystemVerilog plano, con un decodificador a nivel de bit y un generador de tramas independientes).
- Resultado: **PASS** con **324 bytes TX**, **366 tramas RX** (**70 con baudrate desviado entre −4,0 % y +5,5 %**, **18 con bit de stop malo → error de trama**, **8 con glitches rechazados**), incluyendo una fase full-duplex.
- **Mutation check:** se inyectaron 4 bugs deliberados en el RTL (bits de datos TX más cortos, orden de bits RX invertido, RX que no revisa el bit de stop, `tx_ready` siempre alto) y **los 4 fueron detectados (FAIL)**. Además, un quinto mutante (el receptor muestrea cada bit 4 ciclos más tarde, probado en una copia temporal) **pasaba el self-check antiguo** pero **da FAIL (22 errores)** con el bloque de baudrate desviado.

**Tolerancia de baudrate medida (Verilator 5.052, `bash sim/run_baud_sweep.sh`, 8 bytes por punto, paso de 0,5 %):** el receptor acepta un emisor con el periodo de bit desviado entre **−4,5 % y +6,0 %**; falla en −5,0 % (datos corruptos sin error de trama) y en +6,5 % (`rx_frame_err` en 4 de las 8 tramas). Es una medida del RTL con estos patrones, no una garantía general.

**Testbench UVM: NO EJECUTADO HASTA EL FINAL ⚠️**

- **Verilator 5.052 aborta dentro del arranque de fases de la propia librería UVM** (`UVM_FATAL OBJTN_ZERO` en tiempo 0), incluso con un test UVM mínimo de "hello". Es una limitación del simulador, no del testbench.
- Correrlo en **Questa / VCS / Xcelium** (o EDA Playground) queda **pendiente**.
- El testbench UVM del UART **ni siquiera se elaboró** bajo Verilator en esta sesión; solo se elaboró el de FIFO.

## Ruta de aprendizaje

1. **Entiende el DUT.** Lee `rtl/uart_core.sv` y responde: ¿cuántos clocks dura una trama con `CLKS_PER_BIT=16`? ¿Cuándo se pone alto `tx_ready`?
2. **Mira la línea, no el código.** Abre `tb/uart_tx_monitor.sv` y `tb/uart_rx_monitor.sv` y sigue cómo se decodifica una trama bit a bit desde `txd` y `rxd`.
3. **Sigue una transacción completa.** Desde `uart_sequences.sv` → driver → DUT → monitor → scoreboard. Dibuja el flujo en papel.
4. **Rompe cosas a propósito.** Usa `bad_stop` y `glitch` en `uart_rx_driver.sv` y observa cómo reaccionan `rx_valid` y `rx_frame_err`.
5. **Corre los tests UVM en un simulador comercial.** Empieza por `uart_full_duplex_test` y luego prueba `uart_error_test` y `uart_glitch_test`.

## Guía web didáctica

Hay una guía interactiva en **`docs/index.html`**. Ábrela directamente en tu navegador (doble clic o `file://`), no necesita servidor. Incluye un simulador visual del frame UART, la **Clase 1 — Tolerancia de baudrate** (`#clase-1`, con laboratorio interactivo), ejercicios guiados (1–6) y un registro de cambios.

## Curso: de electricidad básica a nivel profesional

`docs/curso.html` es un curso interactivo en 8 niveles (el último es preparación de entrevistas) (electricidad → lógica → secuencial → UART 8N1 → UVM → cobertura y aserciones → prácticas de empresa) con calculadoras, un simulador del simulador de trama UART (con desviación de baudrate, stop malo y glitch), quizzes y un diagrama UVM clicable. Ábrelo directamente en el navegador.

## Ejercicios

<a id="ejercicios"></a>

### Ejercicio 1 — ¿Cuántos clocks dura una trama?

Con `CLKS_PER_BIT=16`, calcula la duración total en ciclos de clock de una trama 8N1 completa (bit de inicio + 8 datos + stop).

<details>
<summary>Pista</summary>

Cuenta los bits de la trama y multiplica por `CLKS_PER_BIT`. No olvides el bit de inicio ni el de stop.

</details>

<details>
<summary>Solución</summary>

Una trama 8N1 tiene **10 bits**: 1 de inicio + 8 de datos + 1 de stop.

`10 × 16 = 160 ciclos de clock` por trama.

</details>

### Ejercicio 2 — ¿Por qué muestrear en el medio del bit?

Explica por qué el receptor muestrea en el punto medio de cada bit y no en el borde.

<details>
<summary>Pista</summary>

Piensa en qué pasa si el transmisor y el receptor no tienen exactamente el mismo clock, o si la línea tiene ruido.

</details>

<details>
<summary>Solución</summary>

Muestrear en el medio da el **margen máximo** respecto a los bordes. Si hay una pequeña diferencia de frecuencia entre TX y RX, o ruido en la línea, el punto medio es el lugar donde el bit lleva más tiempo estable. Además, el DUT valida el bit de inicio en el medio del bit, así que **glitches más cortos que medio bit se rechazan** y no arrancan una recepción falsa.

</details>

### Ejercicio 3 — Enviar 0x55 back-to-back

Escribe (en pseudocódigo o SystemVerilog) una secuencia que envíe `0x55` varias veces seguidas sin pausa, y explica qué compara el scoreboard en ese caso.

<details>
<summary>Pista</summary>

`0x55` es `01010101` en binario. Fíjate en cómo el driver espera `tx_ready` antes de aceptar el siguiente byte.

</details>

<details>
<summary>Solución</summary>

```systemverilog
class seq_0x55 extends uvm_sequence #(uart_tx_item);
  `uvm_object_utils(seq_0x55)
  task body();
    uart_tx_item tr;
    repeat (8) begin
      tr = uart_tx_item::type_id::create("tr");
      start_item(tr);
      tr.data = 8'h55;
      finish_item(tr);
    end
  endtask
endclass
```

El driver solo entrega un byte cuando `tx_valid && tx_ready` (y `tx_ready` está alto solo en idle), así que las tramas salen **back-to-back** en la línea.

El scoreboard compara, en el camino TX, **los bytes que el host entregó** (por `host_ap`) contra **las tramas decodificadas de `txd`** (por `line_ap`): debe ver 8 tramas con dato `0x55`, sin errores de stop.

</details>

## Registro de cambios

### 2026-09-19 — Curso 0→experto y scripts robustos

- Nuevo `docs/curso.html` (8 niveles + entrevistas, simulador interactivo, quizzes, móvil).
- `docs/curso.html`: capa móvil (menú lateral tipo drawer, sin desborde horizontal a 375 px, controles táctiles de 44 px) y nuevo Nivel 7 de entrevista con flashcards filtrables, simulacro con temporizador, checklist de corner cases UART y ejercicios de pizarra; respuestas revisadas por verificación cruzada.
- `sim/run_selfcheck.sh`, `sim/run_questa.sh`, `sim/run_baud_sweep.sh` ahora devuelven código de salida distinto de 0 si falla la verificación; `run_questa.sh` acepta semilla.
- Nuevo `sim/run_regression.sh` (autoverificable + tests UVM × semillas).
- Corrige error de compilación: `uart_tests.sv` asignaba `.num_items` pero las secuencias declaran `n`.
- Nuevo `tb/uart_sva.sv` (forma de trama TX, rx_valid/rx_frame_err, cover; conectado con `bind`). El hueco del glitch en `uart_rx_driver.sv` ahora cubre el muestreo de mitad de bit, así el glitch se rechaza de verdad.

<a id="cambios"></a>

### 2026-09-19 — Clase 1: tolerancia de baudrate

- Nueva clase con laboratorio interactivo y ejercicios 4–6 en `docs/index.html`.
- `tb/selfcheck_tb.sv`: task `drive_frame_skew` y 70 tramas con baudrate desviado (PASS, 366 tramas RX).
- Nuevo `tb/baud_sweep_tb.sv` + `sim/run_baud_sweep.sh`: ventana medida −4,5 % … +6,0 %.
- El testbench UVM sigue sin ejecutarse en ningún simulador.

### 2026-09-19 — Versión inicial

- Publicación inicial del repositorio: RTL del UART 8N1, testbench UVM de dos agentes, self-check con Verilator, scripts de simulación y guía web didáctica.

## Licencia

MIT. Consulta el archivo `LICENSE` para más detalles.
