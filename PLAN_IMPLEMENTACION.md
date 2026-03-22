# Plan de implementación — DAO con votación gasless (EIP-2771)

Este documento describe **cómo** implementar la aplicación definida en [`DAO_GaslessVoting_IA.md`](./DAO_GaslessVoting_IA.md), con la interfaz alineada al mock **[`DAO-Design-UX.png`](./DAO-Design-UX.png)** (presente en la raíz del repositorio).

---

## 1. Objetivo y alcance

**Objetivo:** Entregar una DAO en la que los usuarios depositan ETH, obtienen poder de voto proporcional, crean propuestas (si tienen ≥ 10 % del balance total), votan **sin gas** mediante meta-transacciones (MinimalForwarder + ERC2771Context) y ejecutan transferencias aprobadas tras el periodo de seguridad (manual vía relayer o daemon).

**Fuera de alcance inicial (salvo que se amplíe el spec):** governanza adicional (tokens ERC-20 externos), multisig, capas L2 específicas distintas a la red configurada por `CHAIN_ID`.

---

## 2. Arquitectura resumida

| Capa | Rol |
|------|-----|
| **Contratos** (`sc/`) | `MinimalForwarder` (EIP-712, nonce anti-replay), `DAOVoting` (lógica DAO, siempre `_msgSender()`). |
| **Frontend** (`web/`) | Next.js 15 App Router, Tailwind, ethers v6: wallet, lectura de estado, formularios, votación gasless (firma + POST). |
| **Relayer** (`web/app/api/relay`) | Valida destino = DAO, `verify`, `execute` con clave del relayer (gas pagado por servidor). |
| **Daemon** (`lib/daemon.ts` + `/api/daemon`) | Recorre propuestas; ejecuta si aplica la lógica de la sección 2.3 del spec (cron o intervalo en dev). |

Flujo crítico: el forwarder concatena `req.data` con `from` en el `call` para que OpenZeppelin `ERC2771Context` resuelva al votante real.

---

## 3. Estructura de repositorio (objetivo)

Alineada al spec (sección 1.3):

```
dao-gasless/
├── DAO-Design-UX.png   # Mock UI (referencia visual)
├── sc/                 # Foundry
├── web/                # Next.js 15
└── README.md
```

Documentación auxiliar existente: [`ERRORES.md`](./ERRORES.md) (patrones de fallo EIP-712, nonce, relayer).

---

## 4. Fases de implementación

### Fase A — Smart contracts (Foundry)

1. Inicializar `sc/`, instalar OpenZeppelin, `foundry.toml` con remappings.
2. Implementar `MinimalForwarder.sol` según spec (incl. `getDigest` para tests si se añade).
3. Implementar `DAOVoting.sol`: overrides `_msgSender`/`_msgData`, `fundDAO`, `receive`, `createProposal`, `vote`, `executeProposal`, vistas y eventos.
4. Tests: `MinimalForwarder.t.sol` y `test/DAOVoting.t.sol` con la tabla del spec (incl. gasless y replay).
5. Cobertura ≥ 80 % y `script/Deploy.s.sol` (y opcional `DeployTestnet.s.sol`).

**Verificación:** `forge build`, `forge test`, `forge coverage`, script dry-run contra Anvil.

### Fase B — Frontend base (Next.js)

1. Crear app con TypeScript, Tailwind, App Router; instalar `ethers@6`.
2. Tipos (`types/index.ts`), ABIs (`lib/contracts.ts` desde `sc/out` tras build), EIP-712 (`lib/eip712.ts`).
3. `WalletContext`, `useWallet`, `useDAO` (polling ~10 s).
4. Componentes alineados al mock y al spec: cabecera, panel de tesorería, depósito, formulario de propuesta, lista de propuestas (ver §5).
5. `app/page.tsx`: layout según **`DAO-Design-UX.png`** (no el boceto textual del spec que ponía depósito+crear a la izquierda y lista a la derecha):
   - **Cabecera:** título «DAO Voting Platform» a la izquierda; a la derecha wallet truncada, balance en ETH de la cuenta externa y estado conectado (punto verde).
   - **Fila superior (~1/3 + ~2/3):** columna **izquierda** — resumen de tesorería (tarjetas) + bloque de depósito; columna **derecha** — formulario «Create Proposal».
   - **Fila inferior ancho completo:** sección «Proposals» con barra de tiempo de cadena y listado de tarjetas.

**Verificación:** `npm run lint`, `npm run dev`, flujos on-chain; comparación visual con [`DAO-Design-UX.png`](./DAO-Design-UX.png).

**Nota respecto al spec:** el contrato expone `createProposal(..., deadline)`; el mock usa **duración en días** — calcular `deadline = tiempo_actual + días × 86400` (usando timestamp de bloque vía provider). El mock incluye **campo Descripción**; el `Proposal` del spec no guarda texto — implementar como UX (y opcionalmente off-chain) o documentar ampliación del contrato si se requiere persistencia on-chain.

### Fase C — Relayer y votación gasless

1. `app/api/relay/route.ts`: validación de body, whitelist `to === DAO`, parseo de bigints, `verify` + `execute`.
2. `useGaslessVote` e integración en `VoteButtons` (sin popup de gas del usuario para el `vote`).
3. Si el mock exige **«Create Proposal (Gasless)»** con el toggle activado: extender el flujo EIP-712 + relay para el selector `createProposal` (misma whitelist de contrato, distinto calldata), además del flujo de `vote`.
4. Manejo de errores y mensajes legibles (red incorrecta, firma rechazada, 400/500 del relayer).

**Verificación:** E2E local: firma → relay → voto registrado; opcionalmente creación de propuesta gasless si se implementa el punto 3.

### Fase D — Daemon y cierre

1. `lib/daemon.ts` y `GET /api/daemon`; scheduler en dev (30 s) y/o `vercel.json` para cron en producción.
2. Escenario E2E sección 7.2 del spec; edge cases 7.3.
3. `.env.local.example`, `README.md`, `npm run build`.

**Verificación:** Lista de comprobación de la sección 10 del spec y build de producción.

---

## 5. Diseño UX ([`DAO-Design-UX.png`](./DAO-Design-UX.png))

La especificación técnica define la lógica on-chain; el PNG define **layout, jerarquía y estilo**. Implementar la UI para que coincida con el mock:

### 5.1 Estructura de página

| Zona | Contenido (según mock) |
|------|-------------------------|
| **Header** | Izquierda: título **«DAO Voting Platform»**. Derecha: dirección truncada (`0xf39f…2266`), balance de wallet en ETH (cuenta L1, no solo DAO), indicador **conectado** (punto verde). |
| **Columna izquierda (~1/3)** | Tres tarjetas de métricas: **Treasury Balance** (texto/números en tono azul), **Total Proposals** (verde), **Your Balance in DAO** (tarjeta morada con importe y **% del total**). Debajo: bloque **Deposit ETH to DAO** (input, botón azul «Deposit to DAO», texto de ayuda sobre participación). |
| **Columna derecha (~2/3)** | Formulario **Create Proposal**: Recipient, Amount (ETH), **Voting Duration (days)** (sustituye al `datetime-local` del spec; mapear a `deadline`), **Description** (textarea), checkbox **«Use gasless transaction (relayer pays gas)»**, botón verde principal **«Create Proposal (Gasless)»** (o variante on-chain si el toggle está off), nota sobre el **10 %** mínimo. |
| **Sección inferior (ancho completo)** | Título **Proposals**; a la derecha checkbox **«Gasless voting»**. Barra informativa tipo **Blockchain Time** (fondo azul claro: fecha/hora legible + timestamp Unix). Lista de tarjetas: **Proposal #N**, badge de estado (p. ej. **Active** en azul), línea con monto y destino (`X ETH to 0x…`), texto de descripción; aquí integrar votos (FOR / AGAINST / ABSTAIN) y acciones del spec donde el mock no detalle botones. |

### 5.2 Estilo

- **Fondo:** gris muy claro; **tarjetas:** blanco, **esquinas ~8px**, sombra o borde sutil.
- **Colores de acento:** azul (tesorería, depósito, estados «activos»), verde (propuestas totales, CTA crear), morado (balance del usuario en el DAO).
- **Responsive:** el mock es tipo desktop; en viewports estrechos, apilar columnas (tesorería → formulario → lista).

### 5.3 Coherencia spec ↔ mock

- **Votación gasless:** el mock enfatiza relayer en propuestas y lista; el spec detalla EIP-712 para `vote` — implementar votación gasless obligatoria según criterios §10; **crear propuesta gasless** si se desea paridad exacta con el botón del mock (ver Fase C).
- **Descripción de propuesta:** solo UI / off-chain salvo que se amplíe el contrato.

**Proceso recomendado:** tras funcionalidad mínima del spec, **paso de alineación visual** píxel a píxel con el PNG en desktop y revisión en móvil.

---

## 6. Variables de entorno y despliegue

- Contratos: `NEXT_PUBLIC_DAO_ADDRESS`, `NEXT_PUBLIC_FORWARDER_ADDRESS`, `NEXT_PUBLIC_CHAIN_ID`, `NEXT_PUBLIC_RPC_URL`.
- Servidor: `RPC_URL`, `RELAYER_PRIVATE_KEY` (nunca `NEXT_PUBLIC_`).
- Scripts Foundry: `PRIVATE_KEY` / `sc/.env` según spec sección 9.

Orden típico local: Anvil → `forge script ... --broadcast` → copiar addresses a `web/.env.local` → `npm run dev`.

---

## 7. Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Desalineación EIP-712 dominio vs contrato | Mismo `name`, `version`, `chainId`, `verifyingContract` que en `MinimalForwarder` constructor. |
| Nonce obsoleto | Siempre `forwarder.getNonce(user)` inmediatamente antes de firmar; evitar votos paralelos sin cola (ver `ERRORES.md`). |
| `msg.sender` en DAO | Code review: solo `_msgSender()` en lógica de usuario. |
| Relayer con `to` arbitrario | Whitelist estricta en `/api/relay`. |
| Daemon doble ejecución | Contrato ya marca `executed`; relayer idempotente en errores esperados. |

---

## 8. Criterios de salida

Coinciden con la **sección 10** de `DAO_GaslessVoting_IA.md`: tests Foundry, cobertura, build Next, flujos gasless y daemon, documentación y UI coherente con **`DAO-Design-UX.png`** además de los requisitos funcionales del spec.

---

## 9. Documentos relacionados

| Documento | Uso |
|-----------|-----|
| [`DAO_GaslessVoting_IA.md`](./DAO_GaslessVoting_IA.md) | Especificación normativa |
| [`LISTADO_TAREAS.md`](./LISTADO_TAREAS.md) | Checklist ejecutable por tarea |
| [`ERRORES.md`](./ERRORES.md) | Antipatrones y debugging |
| [`DAO-Design-UX.png`](./DAO-Design-UX.png) | Referencia visual en raíz del repo |

---

*Última actualización: revisión contra [`DAO-Design-UX.png`](./DAO-Design-UX.png) en repo (layout tres zonas, paleta, componentes); spec normativo en `DAO_GaslessVoting_IA.md`.*
