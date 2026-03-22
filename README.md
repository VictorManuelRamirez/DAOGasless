# DAO Gasless — Votación sin gas (EIP-2771)

Monorepo con **smart contracts** (Foundry) y **frontend + relayer** (Next.js 16, TypeScript, ethers v6). Los usuarios firman meta-transacciones EIP-712; el **relayer** ejecuta `MinimalForwarder.execute` y paga el gas.

## Documentación

| Recurso | Descripción |
|---------|-------------|
| [DAO_GaslessVoting_IA.md](./DAO_GaslessVoting_IA.md) | Especificación técnica completa |
| [DAO-Design-UX.png](./DAO-Design-UX.png) | Referencia visual de la interfaz |
| [PLAN_IMPLEMENTACION.md](./PLAN_IMPLEMENTACION.md) / [LISTADO_TAREAS.md](./LISTADO_TAREAS.md) | Plan y checklist |
| [ERRORES.md](./ERRORES.md) | Errores frecuentes (EIP-712, nonce, relayer) |

## Estructura

```
DAOGasless/
├── sc/                    # Foundry — MinimalForwarder, DAOVoting
├── web/                   # Next.js — UI, /api/relay, /api/daemon
├── DAO_GaslessVoting_IA.md
├── DAO-Design-UX.png
└── README.md
```

## Requisitos

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`, `anvil`, `cast`)
- Node.js ≥ 18 y npm

## 1. Contratos (local)

Terminal 1 — nodo Anvil (chain id 31337):

```bash
anvil --chain-id 31337
```

Terminal 2 — compilar, test y desplegar:

```bash
cd sc
forge build
forge test
forge coverage --report summary
```

Desplegar en Anvil (cuenta #0 por defecto):

```bash
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

Copiar las direcciones impresas de `MinimalForwarder` y `DAOVoting`.

## 2. Frontend y relayer

```bash
cd web
cp .env.local.example .env.local
```

Editar `web/.env.local`:

- `NEXT_PUBLIC_DAO_ADDRESS` y `NEXT_PUBLIC_FORWARDER_ADDRESS` — salida del script de deploy.
- `NEXT_PUBLIC_CHAIN_ID=31337`
- `NEXT_PUBLIC_RPC_URL=http://127.0.0.1:8545`
- `RPC_URL` — misma URL RPC (uso servidor).
- `RELAYER_PRIVATE_KEY` — clave con ETH en Anvil para pagar gas (p. ej. la misma `0xac09…` de la cuenta #0).
- `RELAYER_ADDRESS` — opcional, solo referencia.

Arrancar la app:

```bash
npm install
npm run dev
```

Abrir [http://localhost:3000](http://localhost:3000). Importar en MetaMask la clave de una cuenta con ETH de Anvil; añadir red local (RPC `http://127.0.0.1:8545`, chain id `31337`).

## 3. Flujo de prueba (resumen)

1. Conectar wallet en la red 31337.
2. Depositar ETH al DAO (**Deposit to DAO**).
3. Crear propuesta (on-chain o con **Create Proposal (Gasless)** si el relayer está configurado).
4. Votar con **Gasless voting** activado: firma EIP-712 sin popup de gas del usuario.
5. Tras `deadline + 1h` (periodo de seguridad), ejecutar propuestas aprobadas con **Ejecutar** o llamar `GET /api/daemon` (o esperar al scheduler en desarrollo).

Avanzar tiempo en Anvil (opcional):

```bash
cast rpc anvil_setNextBlockTimestamp <unix_timestamp>
cast rpc anvil_mine
```

## API

| Ruta | Descripción |
|------|-------------|
| `POST /api/relay` | Cuerpo `{ request, signature }` — ejecuta meta-tx en el forwarder (solo destino = DAO). |
| `GET /api/daemon` | Intenta `executeProposal` en propuestas elegibles (relayer). |

En **desarrollo**, `web/instrumentation.ts` programa una comprobación periódica del daemon en el servidor (cada 30 s).

## Verificación de build

```bash
cd sc && forge test && forge build
cd ../web && npm run lint && npm run build
```

## Seguridad

- No commitear claves reales. `web/.gitignore` ignora `.env*` salvo `.env.local.example`.
- `RELAYER_PRIVATE_KEY` solo en servidor; nunca prefijo `NEXT_PUBLIC_` en secretos.

## Licencia

MIT (alineado a los contratos y dependencias OpenZeppelin).
