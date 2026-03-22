# Listado de tareas — DAO gasless

Lista de trabajo derivada de [`DAO_GaslessVoting_IA.md`](./DAO_GaslessVoting_IA.md) (sección 8), ampliada con tareas de **diseño** según **[`DAO-Design-UX.png`](./DAO-Design-UX.png)** (raíz del repo). Marca `[ ]` → `[x]` conforme avances.

**Orden:** respetar el orden de fases salvo dependencias obvias (p. ej. ABIs tras `forge build`).

---

## Convenciones

- Cada tarea incluye **verificación** cuando el spec la indica.
- No commitear claves reales; usar `.env.local.example`.

---

## Fase 0 — Repositorio y diseño

Referencia visual: **[`DAO-Design-UX.png`](./DAO-Design-UX.png)** (raíz del proyecto).

| Estado | ID | Tarea | Verificación |
|--------|-----|-------|--------------|
| [ ] | 0.1 | Mencionar en **`README.md`** la ruta del mock (`./DAO-Design-UX.png`) como referencia de UI | README actualizado |
| [ ] | 0.2 | Checklist visual frente al PNG (marcar ítem por ítem) | Todos revisados |
| [ ] | 0.3 | Configurar tema Tailwind: fondo gris claro, tarjetas blancas ~8px radius, acentos **azul** (tesorería/depósito), **verde** (CTA secundario y métricas), **morado** (balance usuario DAO) | Comparación con PNG |

**Checklist detallado `DAO-Design-UX.png` (tarea 0.2):**

- [ ] Header: título **«DAO Voting Platform»** a la izquierda.
- [ ] Header derecha: dirección truncada, balance ETH de la wallet, **punto verde** conectado.
- [ ] Columna izquierda: tarjeta **Treasury Balance** (énfasis azul); **Total Proposals** (énfasis verde); **Your Balance in DAO** (tarjeta morada + **% del total**).
- [ ] Bloque depósito: etiqueta «Deposit ETH to DAO», input, botón azul «Deposit to DAO», texto de ayuda bajo el botón.
- [ ] Columna derecha: recipient, amount ETH, **duración en días**, **textarea descripción**, checkbox gasless para crear, botón verde «Create Proposal (Gasless)», nota del 10 %.
- [ ] Sección inferior ancho completo: título **Proposals**, checkbox **Gasless voting**, barra **Blockchain Time** (fondo azul claro, fecha + Unix).
- [ ] Tarjetas de propuesta: `#N`, badge (p. ej. Active), «X ETH to 0x…», descripción; integrar botones de voto del spec donde el mock no los detalla.

---

## Fase 1 — Smart contracts (Foundry)

| Estado | ID | Tarea | Verificación |
|--------|-----|-------|--------------|
| [ ] | 1.1 | `forge init sc`, `forge install OpenZeppelin/openzeppelin-contracts` | `forge build` sin errores |
| [ ] | 1.2 | Configurar `foundry.toml` con remappings OZ | `forge remappings` correcto |
| [ ] | 1.3 | Implementar `sc/src/MinimalForwarder.sol` (EIP712, `ForwardRequest`, `verify`, `execute`, evento; `getDigest` si se usa en tests) | `forge build` |
| [ ] | 1.4 | Implementar `sc/src/DAOVoting.sol` (ERC2771Context, ReentrancyGuard, overrides, reglas de negocio, `receive`) | `forge build` sin warnings críticos |
| [ ] | 1.5 | Escribir `sc/test/MinimalForwarder.t.sol` (verify, execute, replay) | `forge test --match-contract MinimalForwarderTest` |
| [ ] | 1.6 | Escribir `sc/test/DAOVoting.t.sol` con todos los casos de la tabla del spec | `forge test --match-contract DAOVotingTest` |
| [ ] | 1.7 | Test `test_GaslessVote` (meta-tx con `vm.sign` + `forwarder.execute`) | `forge test --match-test test_GaslessVote` |
| [ ] | 1.8 | Test `test_GaslessVote_ReplayAttack` | `forge test --match-test test_GaslessVote_ReplayAttack` |
| [ ] | 1.9 | Tests adicionales del spec: firma inválida, etc. | Tests verdes |
| [ ] | 1.10 | `forge coverage` ≥ 80 % líneas/ramas (objetivo spec) | Comando coverage |
| [ ] | 1.11 | `sc/script/Deploy.s.sol` (y opcional `DeployTestnet.s.sol`) | `forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545` |

---

## Fase 2 — Frontend base (Next.js 15)

| Estado | ID | Tarea | Verificación |
|--------|-----|-------|--------------|
| [ ] | 2.1 | Crear `web/` con `create-next-app` (TypeScript, Tailwind, App Router), instalar `ethers@6` | `npm run dev` en puerto 3000 |
| [ ] | 2.2 | `web/types/index.ts` (Proposal, VoteType, ForwardRequest, RelayRequest, WalletState, etc.) | `npm run lint` |
| [ ] | 2.3 | `web/lib/contracts.ts`: `DAO_ABI`, `FORWARDER_ABI`, constantes de env (tras `forge build`, sincronizar ABIs) | Imports OK |
| [ ] | 2.4 | `web/lib/eip712.ts` — `signMetaTransaction` | Tipado estricto, sin `any` |
| [ ] | 2.5 | `web/context/WalletContext.tsx` + envolver `app/layout.tsx` | Provider activo |
| [ ] | 2.6 | `web/hooks/useWallet.ts` (conectar, red, eventos, MetaMask) | Conexión y cambio de cuenta/red |
| [ ] | 2.7 | `web/hooks/useDAO.ts` (proposals, balances, polling ~10 s, escrituras on-chain) | Datos en UI |
| [ ] | 2.8 | `web/components/ConnectWallet.tsx` (o header compuesto) | Título app, dirección truncada, **balance ETH** en header, badge red incorrecta + **punto verde** si conectado (según PNG) |
| [ ] | 2.9 | `web/components/FundingPanel.tsx` / panel tesorería | Tres tarjetas (treasury, total propuestas, **tu balance + %** morado) + bloque depósito con botón azul y copy de ayuda, como el mock |
| [ ] | 2.10 | `web/components/CreateProposal.tsx` | Validación ≥ 10 %, `ethers.isAddress`, **duración en días → `deadline`**, campo **descripción** (UI u off-chain), checkbox **gasless create** (si on-chain: tx normal) |
| [ ] | 2.11 | `web/components/ProposalCard.tsx` | Badges (p. ej. Active azul), importe + destino truncado, descripción; barra FOR/AGAINST, ejecutar cuando aplique |
| [ ] | 2.12 | `web/components/VoteButtons.tsx` | Tres opciones; opcionalmente respetar toggle **Gasless voting** de la lista (fase 3) |
| [ ] | 2.13 | `web/components/ProposalList.tsx` + cabecera sección | Título **Proposals**, checkbox **Gasless voting**, barra **Blockchain Time** (timestamp bloque + fecha legible) |
| [ ] | 2.14 | `web/app/page.tsx` | Layout PNG: fila superior (≈1/3 tesorería + depósito, ≈2/3 crear propuesta); fila inferior lista propuestas a ancho completo (no el boceto 2-col del spec con lista a la derecha) |
| [ ] | 2.15 | Pulir responsive (stack en móvil), accesibilidad (focus, labels) | Revisión manual |

---

## Fase 3 — Relayer y votación gasless

| Estado | ID | Tarea | Verificación |
|--------|-----|-------|--------------|
| [ ] | 3.1 | `web/app/api/relay/route.ts` (parseo, whitelist DAO, verify, execute, errores) | `curl` POST vacío → 400 |
| [ ] | 3.2 | `web/hooks/useGaslessVote.ts` | POST con bigints serializados, manejo de respuesta |
| [ ] | 3.3 | Integrar gasless en `VoteButtons.tsx` | Voto sin popup de gas del usuario |
| [ ] | 3.4 | (Opcional paridad PNG) Meta-tx **`createProposal`** vía relay: mismo `ForwardRequest` + calldata `createProposal`, whitelist en `/api/relay` | Crear propuesta con toggle gasless sin gas usuario |
| [ ] | 3.5 | `web/lib/daemon.ts` — `checkAndExecuteProposals` | Logs / propuestas ejecutadas en prueba |
| [ ] | 3.6 | `web/app/api/daemon/route.ts` | `GET /api/daemon` devuelve JSON esperado |
| [ ] | 3.7 | Scheduler daemon (dev 30 s) y/o `vercel.json` cron | Comportamiento acordado |

---

## Fase 4 — Integración y cierre

| Estado | ID | Tarea | Verificación |
|--------|-----|-------|--------------|
| [ ] | 4.1 | Escenario E2E sección 7.2 del spec (Anvil + MetaMask + pasos 1–13) | Sin errores de flujo |
| [ ] | 4.2 | Edge cases sección 7.3 | Mensajes/reverts esperados |
| [ ] | 4.3 | `web/.env.local.example` sin secretos reales | Archivo en repo |
| [ ] | 4.4 | `npm run build` | Build producción OK |
| [ ] | 4.5 | `README.md` raíz: Anvil, deploy, env, dev, pruebas | Otro dev puede reproducir |
| [ ] | 4.6 | Revisión final UI frente a **`DAO-Design-UX.png`** | Checklist 0.2 completada |

---

## Checklist rápido — Criterios de aceptación (spec §10)

### Contratos
- [ ] `forge test` 100 %
- [ ] Cobertura ≥ 80 %
- [ ] `DAOVoting` usa `_msgSender()` en funciones públicas relevantes
- [ ] `executeProposal` con `nonReentrant`
- [ ] Replay protegido por nonce en forwarder

### Frontend
- [ ] MetaMask + red incorrecta detectada
- [ ] Depósito y propuestas con feedback
- [ ] Votación gasless sin popup de gas
- [ ] Estados de propuesta con colores según spec/mock
- [ ] `npm run build` limpio

### Relayer / daemon
- [ ] Relay: válido → `txHash`; inválido / destino incorrecto → 400
- [ ] Daemon no re-ejecuta ejecutadas

### Documentación
- [ ] README y `.env.local.example`
- [ ] NatSpec / JSDoc donde el spec lo pide en funciones complejas

---

*Total tareas numeradas: Fase 0 (3) + Fase 1 (11) + Fase 2 (15) + Fase 3 (7) + Fase 4 (6) = **42** tareas explícitas, más checklist final y sub-ítems de la tarea 0.2.*
