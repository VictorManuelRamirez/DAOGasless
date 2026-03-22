# DAO con Votación Gasless — Especificación Técnica para IA

> **Stack:** Solidity 0.8.x · Foundry · OpenZeppelin · Next.js 15 · TypeScript · ethers.js v6 · EIP-2771 · EIP-712

---

## Índice

1. [Resumen del Proyecto](#1-resumen-del-proyecto)
2. [Arquitectura del Sistema](#2-arquitectura-del-sistema)
3. [Instrucciones Generales para IA](#3-instrucciones-generales-para-IA)
4. [Parte 1 — Smart Contracts (Foundry)](#4-parte-1--smart-contracts-foundry)
5. [Parte 2 — Frontend (Next.js 15)](#5-parte-2--frontend-nextjs-15)
6. [Parte 3 — Relayer API y Daemon](#6-parte-3--relayer-api-y-daemon)
7. [Parte 4 — Integración y Testing](#7-parte-4--integración-y-testing)
8. [Plan de Tareas para IA](#8-plan-de-tareas-para-IA)
9. [Variables de Entorno](#9-variables-de-entorno)
10. [Criterios de Aceptación](#10-criterios-de-aceptación)

---

## 1. Resumen del Proyecto

Aplicación completa de una **DAO (Organización Autónoma Descentralizada)** donde los usuarios pueden votar propuestas **sin pagar gas**, usando meta-transacciones bajo el estándar **EIP-2771**.

El usuario firma el voto off-chain con MetaMask (sin costo), un servidor **Relayer** recibe esa firma y ejecuta la transacción on-chain pagando el gas con su propia cuenta.

### 1.1 Objetivos Funcionales

- Los usuarios depositan ETH en el DAO y obtienen poder de voto proporcional.
- Usuarios con ≥ 10% del balance total pueden crear propuestas de transferencia de fondos.
- Cualquier usuario con balance > 0 puede votar (A FAVOR / EN CONTRA / ABSTENCIÓN) sin pagar gas.
- Los votos son cambiables antes del deadline de la propuesta.
- Un daemon ejecuta automáticamente las propuestas aprobadas tras el período de seguridad.

### 1.2 Stack Tecnológico

| Capa | Tecnologías |
|------|-------------|
| Smart Contracts | Solidity 0.8.x, Foundry, OpenZeppelin Contracts v5 |
| Meta-Transacciones | EIP-2771, EIP-712, ECDSA |
| Frontend | Next.js 15 (App Router), TypeScript, TailwindCSS |
| Web3 Client | ethers.js v6 |
| Relayer | Next.js API Routes (server-side) |
| Testing Contratos | Forge tests (Solidity) |
| Dev Environment | Anvil (nodo local) |

### 1.3 Estructura del Repositorio

```
dao-gasless/
├── sc/                               # Smart Contracts
│   ├── src/
│   │   ├── MinimalForwarder.sol
│   │   └── DAOVoting.sol
│   ├── test/
│   │   ├── MinimalForwarder.t.sol
│   │   └── DAOVoting.t.sol
│   ├── script/
│   │   ├── Deploy.s.sol              # Deploy en Anvil
│   │   └── DeployTestnet.s.sol       # Deploy en testnet
│   └── foundry.toml
├── web/                              # Frontend
│   ├── app/
│   │   ├── page.tsx
│   │   ├── layout.tsx
│   │   └── api/
│   │       ├── relay/route.ts
│   │       └── daemon/route.ts
│   ├── components/
│   │   ├── ConnectWallet.tsx
│   │   ├── FundingPanel.tsx
│   │   ├── CreateProposal.tsx
│   │   ├── ProposalList.tsx
│   │   ├── ProposalCard.tsx
│   │   └── VoteButtons.tsx
│   ├── hooks/
│   │   ├── useWallet.ts
│   │   ├── useDAO.ts
│   │   └── useGaslessVote.ts
│   ├── lib/
│   │   ├── contracts.ts
│   │   ├── eip712.ts
│   │   └── daemon.ts
│   ├── context/
│   │   └── WalletContext.tsx
│   ├── types/
│   │   └── index.ts
│   ├── .env.local
│   └── .env.local.example
└── README.md
```

---

## 2. Arquitectura del Sistema

### 2.1 Flujo de Meta-Transacción (EIP-2771)

```
┌─────────────┐     firma EIP-712      ┌──────────────────┐
│   USUARIO   │ ──────(off-chain)────▶ │    FRONTEND      │
│  (MetaMask) │ ◀── sin popup de gas─  │  (Next.js 15)    │
└─────────────┘                        └────────┬─────────┘
                                                │ POST { request, signature }
                                                ▼
                                       ┌──────────────────┐
                                       │     RELAYER      │
                                       │  /api/relay      │
                                       │  (paga el gas)   │
                                       └────────┬─────────┘
                                                │ forwarder.execute()
                                                ▼
                                       ┌──────────────────┐
                                       │ MinimalForwarder  │
                                       │  Verifica firma  │
                                       │  Verifica nonce  │
                                       └────────┬─────────┘
                                                │ dao.vote(_msgSender = usuario)
                                                ▼
                                       ┌──────────────────┐
                                       │   DAOVoting      │
                                       │ ERC2771Context   │
                                       │ Registra voto    │
                                       └──────────────────┘
```

### 2.2 Cómo funciona ERC2771Context

En transacciones normales: `msg.sender` = quien llama la función.
En meta-transacciones: `msg.sender` = MinimalForwarder (no el usuario real).

`ERC2771Context` resuelve esto sobreescribiendo `_msgSender()`:
- Si `msg.sender` es el forwarder de confianza: extrae los últimos 20 bytes del calldata (que el forwarder añadió con `abi.encodePacked(data, from)`).
- Si no: devuelve `msg.sender` normalmente.

**Regla crítica:** Todo el código del DAO debe usar `_msgSender()` en lugar de `msg.sender`.

### 2.3 Flujo del Daemon

```
cada 30 segundos:
  para cada proposal (1..proposalCount):
    si executed == true → skip
    si block.timestamp <= deadline + SAFETY_PERIOD → skip
    si votesFor <= votesAgainst → skip
    si balance < amount → skip
    → executeProposal(id) con relayer signer
```

---

## 3. Instrucciones Generales para IA

> Leer completamente antes de escribir cualquier línea de código.

### 3.1 Reglas de Implementación

1. **Seguir el Plan de Tareas** (Sección 8) en orden estricto. No saltar tareas.
2. **Verificar cada tarea** con el comando indicado antes de continuar.
3. **Correr tests** después de implementar cada contrato.
4. **No usar `msg.sender` directamente** en DAOVoting — siempre `_msgSender()`.
5. **Seguridad primero**: validar todos los inputs, usar `nonReentrant` donde aplique.
6. **TypeScript estricto**: sin `any` implícito, tipar todas las funciones.
7. **Manejo de errores**: cubrir firma rechazada, red incorrecta, tx fallida.

### 3.2 Prerequisitos del Entorno

```bash
# Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
forge --version   # Debe mostrar versión instalada

# Node.js
node --version    # >= 18.x requerido
npm --version     # >= 9.x requerido
```

### 3.3 Comandos de Referencia Rápida

```bash
# Contratos
forge build                                    # Compilar
forge test                                     # Correr todos los tests
forge test -vvv                                # Con logs detallados
forge coverage                                 # Reporte de cobertura
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

# Nodo local
anvil --chain-id 31337                         # Iniciar nodo Anvil

# Frontend
npm run dev                                    # Servidor de desarrollo
npm run build                                  # Build de producción
npm run lint                                   # Verificar TypeScript
```

---

## 4. Parte 1 — Smart Contracts (Foundry)

### 4.1 Setup del Proyecto

```bash
forge init sc
cd sc
forge install OpenZeppelin/openzeppelin-contracts
```

Verificar que `foundry.toml` contenga:

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
remappings = [
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/"
]

[profile.default.fuzz]
runs = 256
```

---

### 4.2 Contrato: `MinimalForwarder.sol`

**Ubicación:** `sc/src/MinimalForwarder.sol`

#### Imports y herencia

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract MinimalForwarder is EIP712 {
    // Constructor: EIP712("MinimalForwarder", "1")
}
```

#### Struct `ForwardRequest`

```solidity
struct ForwardRequest {
    address from;       // Usuario firmante (owner real del voto)
    address to;         // Contrato destino = DAOVoting
    uint256 value;      // ETH a enviar (0 para votos)
    uint256 gas;        // Gas limit de la llamada interna
    uint256 nonce;      // Nonce del usuario (anti-replay)
    bytes   data;       // Calldata de la función a invocar
}
```

#### Type Hash (constante)

```solidity
bytes32 private constant _TYPEHASH = keccak256(
    "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data)"
);
```

#### Variables de Estado

```solidity
mapping(address => uint256) private _nonces;
```

#### Métodos Requeridos

| Método | Visibilidad | Descripción |
|--------|-------------|-------------|
| `getNonce(address from)` | `external view returns (uint256)` | Devuelve `_nonces[from]` |
| `verify(ForwardRequest calldata req, bytes calldata signature)` | `public view returns (bool)` | Verifica firma EIP-712 y nonce |
| `execute(ForwardRequest calldata req, bytes calldata signature)` | `public payable returns (bool, bytes memory)` | Ejecuta meta-transacción |

#### Lógica de `verify()`

```
1. Computar structHash = keccak256(abi.encode(_TYPEHASH, req.from, req.to, req.value, req.gas, req.nonce, keccak256(req.data)))
2. Computar digest = _hashTypedDataV4(structHash)
3. Recuperar signer = ECDSA.recover(digest, signature)
4. Retornar: _nonces[req.from] == req.nonce && signer == req.from
```

#### Lógica de `execute()`

```
1. require(verify(req, signature), "MinimalForwarder: invalid signature or nonce")
2. _nonces[req.from]++
3. (bool success, bytes memory returndata) = req.to.call{
       value: req.value,
       gas: req.gas
   }(abi.encodePacked(req.data, req.from))
   // ↑ CRÍTICO: se añade req.from al final para ERC2771Context
4. emit MetaTransactionExecuted(req.from, req.to, req.data)
5. return (success, returndata)
```

#### Evento

```solidity
event MetaTransactionExecuted(address indexed from, address indexed to, bytes data);
```

> **Nota de seguridad:** El forwarder NO valida que `req.to` sea el DAO. Esa whitelist se hace en el relayer (server-side). El contrato es intencionalmente genérico.

---

### 4.3 Contrato: `DAOVoting.sol`

**Ubicación:** `sc/src/DAOVoting.sol`

#### Imports y herencia

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC2771Context } from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

contract DAOVoting is ERC2771Context, ReentrancyGuard {
    constructor(address trustedForwarder) ERC2771Context(trustedForwarder) {}

    // Resolver conflicto de herencia múltiple
    function _msgSender() internal view override(ERC2771Context, Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }
}
```

#### Enum y Structs

```solidity
enum VoteType { FOR, AGAINST, ABSTAIN }

struct Proposal {
    uint256 id;
    address recipient;      // Beneficiario de los fondos
    uint256 amount;         // Cantidad en wei
    uint256 deadline;       // Timestamp Unix fin de votación
    uint256 votesFor;
    uint256 votesAgainst;
    uint256 votesAbstain;
    bool executed;
    bool exists;            // Para validar existencia con mapping
}
```

#### Variables de Estado

```solidity
uint256 public proposalCount;
uint256 public totalDAOBalance;
uint256 public constant SAFETY_PERIOD = 1 hours;    // 3600 segundos
uint256 public constant MIN_BALANCE_PCT = 10;        // 10% mínimo para crear propuesta

mapping(uint256 => Proposal) public proposals;
mapping(address => uint256) public userBalances;
mapping(uint256 => mapping(address => bool))     public hasVoted;
mapping(uint256 => mapping(address => VoteType)) public userVotes;
```

#### Eventos

```solidity
event FundsDeposited(address indexed user, uint256 amount);
event ProposalCreated(uint256 indexed proposalId, address recipient, uint256 amount, uint256 deadline);
event VoteCast(uint256 indexed proposalId, address indexed voter, VoteType voteType);
event VoteChanged(uint256 indexed proposalId, address indexed voter, VoteType oldVote, VoteType newVote);
event ProposalExecuted(uint256 indexed proposalId, address recipient, uint256 amount);
```

#### Modificadores

```solidity
modifier proposalExists(uint256 id) {
    require(proposals[id].exists, "Proposal does not exist");
    _;
}

modifier proposalNotExecuted(uint256 id) {
    require(!proposals[id].executed, "Proposal already executed");
    _;
}

modifier proposalActive(uint256 id) {
    require(block.timestamp <= proposals[id].deadline, "Voting period ended");
    _;
}
```

#### Funciones — Lógica Detallada

**`fundDAO() external payable`**
```
1. require(msg.value > 0, "Must send ETH")
2. userBalances[_msgSender()] += msg.value
3. totalDAOBalance += msg.value
4. emit FundsDeposited(_msgSender(), msg.value)
```

**`createProposal(address recipient, uint256 amount, uint256 deadline) external`**
```
1. require(userBalances[_msgSender()] * 100 >= totalDAOBalance * MIN_BALANCE_PCT, "Insufficient balance to propose")
2. require(recipient != address(0), "Invalid recipient")
3. require(amount > 0 && amount <= address(this).balance, "Invalid amount")
4. require(deadline > block.timestamp, "Deadline must be in the future")
5. proposalCount++
6. proposals[proposalCount] = Proposal({
       id: proposalCount,
       recipient: recipient,
       amount: amount,
       deadline: deadline,
       votesFor: 0, votesAgainst: 0, votesAbstain: 0,
       executed: false,
       exists: true
   })
7. emit ProposalCreated(proposalCount, recipient, amount, deadline)
```

**`vote(uint256 proposalId, VoteType voteType) external proposalExists(proposalId) proposalActive(proposalId)`**
```
1. require(userBalances[_msgSender()] > 0, "No balance to vote")
2. address voter = _msgSender()
3. Si hasVoted[proposalId][voter] == true:
     a. VoteType oldVote = userVotes[proposalId][voter]
     b. Decrementar contador del oldVote
     c. emit VoteChanged(proposalId, voter, oldVote, voteType)
   Si no:
     a. hasVoted[proposalId][voter] = true
     b. emit VoteCast(proposalId, voter, voteType)
4. Incrementar contador del nuevo voteType
5. userVotes[proposalId][voter] = voteType
```

**`executeProposal(uint256 proposalId) external nonReentrant proposalExists(proposalId) proposalNotExecuted(proposalId)`**
```
1. Proposal storage p = proposals[proposalId]
2. require(block.timestamp > p.deadline + SAFETY_PERIOD, "Safety period not elapsed")
3. require(p.votesFor > p.votesAgainst, "Proposal not approved")
4. require(address(this).balance >= p.amount, "Insufficient DAO balance")
5. p.executed = true
6. totalDAOBalance -= p.amount   // actualizar tracking
7. (bool success,) = p.recipient.call{value: p.amount}("")
8. require(success, "Transfer failed")
9. emit ProposalExecuted(proposalId, p.recipient, p.amount)
```

**`getProposal(uint256 proposalId) external view proposalExists(proposalId) returns (Proposal memory)`**
```
return proposals[proposalId]
```

**`getUserBalance(address user) external view returns (uint256)`**
```
return userBalances[user]
```

**`receive() external payable`**
```
Llamar internamente la lógica de fundDAO() para registrar el depósito
```

---

### 4.4 Tests Requeridos

**Ubicación:** `sc/test/DAOVoting.t.sol`  
**Coverage objetivo:** > 80% en líneas y ramas

#### Setup base

```solidity
contract DAOVotingTest is Test {
    MinimalForwarder forwarder;
    DAOVoting dao;
    
    address alice   = vm.addr(1);   // Creará propuestas
    address bob     = vm.addr(2);   // Votará en contra
    address carol   = vm.addr(3);   // Votará a favor
    address relayer = vm.addr(99);  // Simulará el relayer
    
    function setUp() public {
        forwarder = new MinimalForwarder();
        dao = new DAOVoting(address(forwarder));
        vm.deal(alice, 20 ether);
        vm.deal(bob, 10 ether);
        vm.deal(carol, 30 ether);
        vm.deal(relayer, 5 ether);
    }
}
```

#### Lista completa de tests

| Test | Descripción |
|------|-------------|
| `test_FundDAO` | Alice deposita 10 ETH, verificar `userBalances` y `totalDAOBalance` |
| `test_FundDAO_ZeroReverts` | Revert con `msg.value == 0` |
| `test_CreateProposal` | Alice deposita 10 ETH, crea propuesta. Verificar struct creado. |
| `test_CreateProposal_InsufficientBalance` | Bob deposita 1 ETH de 15 total → revert |
| `test_CreateProposal_PastDeadline` | `deadline = block.timestamp` → revert |
| `test_CreateProposal_ZeroRecipient` | `recipient = address(0)` → revert |
| `test_Vote_For` | Alice vota FOR. Verificar `votesFor++`, `hasVoted`, `userVotes`. |
| `test_Vote_Against` | Bob vota AGAINST. |
| `test_Vote_Abstain` | Carol vota ABSTAIN. |
| `test_Vote_ChangeVote` | Alice vota FOR, luego AGAINST. Verificar contadores actualizados. |
| `test_Vote_AfterDeadline` | Votar con `vm.warp(deadline + 1)` → revert |
| `test_Vote_NoBalance` | Votar sin haber depositado → revert |
| `test_Vote_NonexistentProposal` | `proposalId = 999` → revert |
| `test_ExecuteProposal` | Setup completo, warp, `votesFor > votesAgainst`, verificar transferencia |
| `test_Execute_BeforeSafetyPeriod` | Ejecutar antes de `deadline + SAFETY_PERIOD` → revert |
| `test_Execute_AlreadyExecuted` | Ejecutar dos veces → revert |
| `test_Execute_NotApproved` | `votesAgainst >= votesFor` → revert |
| `test_GaslessVote` | Simular meta-tx completa con `vm.sign()` + `forwarder.execute()`. Verificar voto registrado con `alice` como voter. |
| `test_GaslessVote_InvalidSignature` | Firma de dirección incorrecta → revert |
| `test_GaslessVote_ReplayAttack` | Reutilizar misma firma dos veces → revert en segundo intento |

#### Ejemplo: `test_GaslessVote`

```solidity
function test_GaslessVote() public {
    // Setup: Alice deposita y se crea propuesta
    vm.prank(alice);
    dao.fundDAO{value: 10 ether}();
    vm.prank(alice);
    dao.createProposal(bob, 1 ether, block.timestamp + 1 days);

    // Encodear calldata del voto
    bytes memory callData = abi.encodeWithSelector(
        dao.vote.selector, 1, DAOVoting.VoteType.FOR
    );

    // Construir ForwardRequest
    MinimalForwarder.ForwardRequest memory req = MinimalForwarder.ForwardRequest({
        from: alice,
        to: address(dao),
        value: 0,
        gas: 300_000,
        nonce: forwarder.getNonce(alice),
        data: callData
    });

    // Firmar con clave privada de alice (vm.addr(1) corresponde a key 1)
    bytes32 digest = forwarder.getDigest(req); // helper view function
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    // Relayer ejecuta la meta-transacción
    vm.prank(relayer);
    (bool success,) = forwarder.execute(req, signature);
    assertTrue(success);

    // Verificar que el voto fue registrado para alice
    assertTrue(dao.hasVoted(1, alice));
    assertEq(uint(dao.userVotes(1, alice)), uint(DAOVoting.VoteType.FOR));
    assertEq(dao.getProposal(1).votesFor, 1);
}
```

> **Nota:** Agregar función `getDigest(ForwardRequest)` como `public view` en `MinimalForwarder` para facilitar los tests. No afecta seguridad.

---

### 4.5 Scripts de Deployment

**`sc/script/Deploy.s.sol`**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { MinimalForwarder } from "../src/MinimalForwarder.sol";
import { DAOVoting } from "../src/DAOVoting.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        MinimalForwarder forwarder = new MinimalForwarder();
        DAOVoting dao = new DAOVoting(address(forwarder));

        vm.stopBroadcast();

        console.log("MinimalForwarder deployed at:", address(forwarder));
        console.log("DAOVoting deployed at:", address(dao));
        console.log("");
        console.log("Add to .env.local:");
        console.log("NEXT_PUBLIC_FORWARDER_ADDRESS=", address(forwarder));
        console.log("NEXT_PUBLIC_DAO_ADDRESS=", address(dao));
    }
}
```

**Comando de ejecución:**

```bash
# Con Anvil corriendo en otra terminal
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

---

## 5. Parte 2 — Frontend (Next.js 15)

### 5.1 Setup

```bash
npx create-next-app@latest web --typescript --tailwind --app --no-src-dir
cd web
npm install ethers@6
```

### 5.2 Tipos Compartidos: `types/index.ts`

```typescript
export interface Proposal {
  id: number;
  recipient: string;
  amount: bigint;
  deadline: number;          // timestamp Unix
  votesFor: bigint;
  votesAgainst: bigint;
  votesAbstain: bigint;
  executed: boolean;
  exists: boolean;
}

export enum VoteType {
  FOR = 0,
  AGAINST = 1,
  ABSTAIN = 2,
}

export type ProposalStatus = "active" | "pending_execution" | "rejected" | "executed";

export interface ForwardRequest {
  from: string;
  to: string;
  value: bigint;
  gas: bigint;
  nonce: bigint;
  data: string;
}

export interface RelayRequest {
  request: ForwardRequest;
  signature: string;
}

export interface WalletState {
  address: string | null;
  chainId: number | null;
  isConnected: boolean;
  provider: ethers.BrowserProvider | null;
  signer: ethers.JsonRpcSigner | null;
}
```

### 5.3 Contratos ABI: `lib/contracts.ts`

```typescript
// Copiar ABIs desde sc/out/ después de forge build
export const DAO_ADDRESS    = process.env.NEXT_PUBLIC_DAO_ADDRESS!;
export const FORWARDER_ADDRESS = process.env.NEXT_PUBLIC_FORWARDER_ADDRESS!;
export const CHAIN_ID       = parseInt(process.env.NEXT_PUBLIC_CHAIN_ID ?? "31337");

export const DAO_ABI = [
  // fundDAO
  "function fundDAO() external payable",
  // createProposal
  "function createProposal(address recipient, uint256 amount, uint256 deadline) external",
  // vote
  "function vote(uint256 proposalId, uint8 voteType) external",
  // executeProposal
  "function executeProposal(uint256 proposalId) external",
  // views
  "function getProposal(uint256 proposalId) external view returns (tuple(uint256 id, address recipient, uint256 amount, uint256 deadline, uint256 votesFor, uint256 votesAgainst, uint256 votesAbstain, bool executed, bool exists))",
  "function getUserBalance(address user) external view returns (uint256)",
  "function proposalCount() external view returns (uint256)",
  "function totalDAOBalance() external view returns (uint256)",
  "function hasVoted(uint256 proposalId, address user) external view returns (bool)",
  "function userVotes(uint256 proposalId, address user) external view returns (uint8)",
  // eventos
  "event FundsDeposited(address indexed user, uint256 amount)",
  "event ProposalCreated(uint256 indexed proposalId, address recipient, uint256 amount, uint256 deadline)",
  "event VoteCast(uint256 indexed proposalId, address indexed voter, uint8 voteType)",
  "event ProposalExecuted(uint256 indexed proposalId, address recipient, uint256 amount)",
] as const;

export const FORWARDER_ABI = [
  "function getNonce(address from) external view returns (uint256)",
  "function verify(tuple(address from, address to, uint256 value, uint256 gas, uint256 nonce, bytes data) req, bytes signature) external view returns (bool)",
  "function execute(tuple(address from, address to, uint256 value, uint256 gas, uint256 nonce, bytes data) req, bytes signature) external payable returns (bool, bytes)",
] as const;
```

### 5.4 Firma EIP-712: `lib/eip712.ts`

```typescript
import { ethers } from "ethers";
import { ForwardRequest } from "@/types";

const EIP712_DOMAIN_TYPE = [
  { name: "name",              type: "string"  },
  { name: "version",           type: "string"  },
  { name: "chainId",           type: "uint256" },
  { name: "verifyingContract", type: "address" },
];

const FORWARD_REQUEST_TYPE = {
  ForwardRequest: [
    { name: "from",  type: "address" },
    { name: "to",    type: "address" },
    { name: "value", type: "uint256" },
    { name: "gas",   type: "uint256" },
    { name: "nonce", type: "uint256" },
    { name: "data",  type: "bytes"   },
  ],
};

export async function signMetaTransaction(
  signer: ethers.JsonRpcSigner,
  forwarderAddress: string,
  daoAddress: string,
  callData: string,
  nonce: bigint,
  chainId: number
): Promise<{ request: ForwardRequest; signature: string }> {
  const domain = {
    name: "MinimalForwarder",
    version: "1",
    chainId,
    verifyingContract: forwarderAddress,
  };

  const request: ForwardRequest = {
    from:  await signer.getAddress(),
    to:    daoAddress,
    value: 0n,
    gas:   300_000n,
    nonce,
    data:  callData,
  };

  // ethers.js v6: signTypedData hace el hashing EIP-712 internamente
  const signature = await signer.signTypedData(
    domain,
    FORWARD_REQUEST_TYPE,
    request
  );

  return { request, signature };
}
```

### 5.5 Hook: `hooks/useWallet.ts`

**Responsabilidades:**
- Estado: `address`, `chainId`, `isConnected`, `provider`, `signer`
- `connectWallet()`: llama `window.ethereum.request({ method: "eth_requestAccounts" })`
- `disconnectWallet()`: limpia el estado local
- Escuchar `accountsChanged` y `chainChanged` con cleanup en `useEffect`
- Detectar si MetaMask está instalado (`typeof window.ethereum !== "undefined"`)
- Validar que `chainId === CHAIN_ID` del env y mostrar error si no coincide

```typescript
// Interfaz de retorno
interface UseWalletReturn extends WalletState {
  connectWallet:    () => Promise<void>;
  disconnectWallet: () => void;
  isCorrectNetwork: boolean;
  isMetaMaskInstalled: boolean;
}
```

### 5.6 Hook: `hooks/useDAO.ts`

**Responsabilidades:**
- Leer `proposalCount` y hacer `getProposal()` para cada ID → array `Proposal[]`
- Leer `userBalance` y `totalDAOBalance`
- Funciones de escritura: `fundDAO(amount)`, `createProposal(...)`, `executeProposal(id)`
- Estado: `proposals`, `userBalance`, `totalDAOBalance`, `loading`, `error`
- `refreshProposals()`: función pública para refrescar desde fuera
- Polling automático cada 10 segundos cuando el hook está montado

```typescript
interface UseDAOReturn {
  proposals:        Proposal[];
  userBalance:      bigint;
  totalDAOBalance:  bigint;
  loading:          boolean;
  error:            string | null;
  fundDAO:          (amountEth: string) => Promise<void>;
  createProposal:   (recipient: string, amountEth: string, deadlineTs: number) => Promise<void>;
  executeProposal:  (proposalId: number) => Promise<void>;
  refreshProposals: () => Promise<void>;
}
```

### 5.7 Hook: `hooks/useGaslessVote.ts`

**Flujo interno paso a paso:**

```
1. Obtener nonce: forwarderContract.getNonce(userAddress)
2. Encodear calldata:
     daoInterface.encodeFunctionData("vote", [proposalId, voteType])
3. Llamar signMetaTransaction() → { request, signature }
4. POST /api/relay con body: JSON.stringify({ request, signature })
   - Convertir bigint a string para serialización JSON
5. Si response.ok → return txHash
6. Si no → throw Error con mensaje del servidor
```

```typescript
interface UseGaslessVoteReturn {
  gaslessVote: (proposalId: number, voteType: VoteType) => Promise<string>;
  voting:      boolean;   // loading state
  error:       string | null;
}
```

### 5.8 Componentes UI

#### `components/ConnectWallet.tsx`

- Botón "Conectar Wallet" / "Desconectar"
- Mostrar dirección truncada: `0x1234...5678`
- Badge verde si red correcta, rojo con mensaje si incorrecta
- Disabled si MetaMask no está instalado (mostrar link de instalación)

#### `components/FundingPanel.tsx`

- Input numérico para cantidad de ETH (validar > 0)
- Botón "Depositar al DAO"
- Mostrar: "Tu balance en el DAO: X ETH"
- Mostrar: "Balance total del DAO: Y ETH"
- Loading state durante la transacción

#### `components/CreateProposal.tsx`

- Formulario con 3 campos:
  - `recipient`: dirección (validar formato con `ethers.isAddress()`)
  - `amount`: ETH a transferir (validar <= balance del DAO)
  - `deadline`: datetime-local picker
- Deshabilitar botón y mostrar tooltip si `userBalance < totalDAOBalance * 10 / 100`
- Mostrar error específico del contrato si la tx revierte

#### `components/ProposalList.tsx`

- Mostrar todos los proposals usando `useDAO`
- Empty state: "No hay propuestas aún"
- Loading skeleton mientras carga
- Ordenar por ID descendente (más recientes primero)

#### `components/ProposalCard.tsx`

- Mostrar: ID, recipient (truncado), amount en ETH, deadline formateado
- Barra de progreso visual para votos (FOR% vs AGAINST%)
- Badge de estado con colores:
  - **Activa** → verde (`timestamp <= deadline`)
  - **Pendiente de ejecución** → amarillo (`timestamp > deadline + SAFETY_PERIOD`, favor > contra, no ejecutada)
  - **Rechazada** → rojo (`timestamp > deadline`, contra >= favor)
  - **Ejecutada** → gris (`executed === true`)
- Botón "Ejecutar" visible solo si estado es "pendiente de ejecución"
- Renderizar `<VoteButtons>` si estado es "activa"

#### `components/VoteButtons.tsx`

- 3 botones: "✓ A FAVOR" / "✗ EN CONTRA" / "~ ABSTENCIÓN"
- Loading spinner en el botón clickeado durante la firma y relay
- Botón con borde resaltado si es el voto actual del usuario
- Deshabilitar todos durante `voting === true`
- Mostrar mensaje de éxito o error inline tras votar

### 5.9 Context: `context/WalletContext.tsx`

```typescript
// Wrappear el layout con WalletContext para compartir estado global
// Exponer: address, chainId, isConnected, signer, provider, connectWallet, disconnectWallet
```

### 5.10 Página Principal: `app/page.tsx`

```tsx
// Layout sugerido:
// <header>  → <ConnectWallet />
// <main>
//   <div grid 2 cols>
//     <div> → <FundingPanel /> + <CreateProposal /> </div>
//     <div> → <ProposalList /> </div>
//   </div>
// </main>
```

---

## 6. Parte 3 — Relayer API y Daemon

### 6.1 API Route: `app/api/relay/route.ts`

```typescript
import { NextRequest, NextResponse } from "next/server";
import { ethers } from "ethers";
import { FORWARDER_ABI, DAO_ADDRESS, FORWARDER_ADDRESS } from "@/lib/contracts";

export async function POST(req: NextRequest) {
  try {
    // 1. Parsear y validar body
    const body = await req.json();
    const { request, signature } = body;

    if (!request || !signature) {
      return NextResponse.json({ error: "Missing request or signature" }, { status: 400 });
    }

    // 2. Validar whitelist: solo permitir llamadas al DAO
    if (request.to.toLowerCase() !== DAO_ADDRESS.toLowerCase()) {
      return NextResponse.json({ error: "Invalid target contract" }, { status: 400 });
    }

    // 3. Conectar relayer
    const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
    const relayerWallet = new ethers.Wallet(process.env.RELAYER_PRIVATE_KEY!, provider);
    const forwarder = new ethers.Contract(FORWARDER_ADDRESS, FORWARDER_ABI, relayerWallet);

    // 4. Deserializar bigints (JSON no soporta bigint nativamente)
    const requestParsed = {
      from:  request.from,
      to:    request.to,
      value: BigInt(request.value),
      gas:   BigInt(request.gas),
      nonce: BigInt(request.nonce),
      data:  request.data,
    };

    // 5. Verificar firma antes de enviar
    const isValid = await forwarder.verify(requestParsed, signature);
    if (!isValid) {
      return NextResponse.json({ error: "Invalid signature or nonce" }, { status: 400 });
    }

    // 6. Ejecutar meta-transacción
    const tx = await forwarder.execute(requestParsed, signature);
    const receipt = await tx.wait();

    return NextResponse.json({ txHash: receipt.hash }, { status: 200 });

  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Unknown error";
    console.error("[relay] Error:", message);
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
```

### 6.2 Lógica del Daemon: `lib/daemon.ts`

```typescript
import { ethers } from "ethers";
import { DAO_ABI, DAO_ADDRESS } from "./contracts";

export async function checkAndExecuteProposals(): Promise<number[]> {
  const provider    = new ethers.JsonRpcProvider(process.env.RPC_URL);
  const relayer     = new ethers.Wallet(process.env.RELAYER_PRIVATE_KEY!, provider);
  const dao         = new ethers.Contract(DAO_ADDRESS, DAO_ABI, relayer);
  const executed: number[] = [];

  const count = await dao.proposalCount();
  const block = await provider.getBlock("latest");
  const now   = block!.timestamp;

  for (let id = 1; id <= Number(count); id++) {
    try {
      const p = await dao.getProposal(id);

      if (p.executed)                                              continue;
      if (now <= Number(p.deadline) + 3600 /* SAFETY_PERIOD */)   continue;
      if (p.votesFor <= p.votesAgainst)                            continue;

      const tx = await dao.executeProposal(id);
      await tx.wait();
      console.log(`[daemon] Executed proposal #${id} | tx: ${tx.hash}`);
      executed.push(id);

    } catch (err) {
      console.error(`[daemon] Failed to execute proposal #${id}:`, err);
    }
  }

  return executed;
}
```

### 6.3 API Route del Daemon: `app/api/daemon/route.ts`

```typescript
import { NextResponse } from "next/server";
import { checkAndExecuteProposals } from "@/lib/daemon";

// Trigger manual o via cron
export async function GET() {
  try {
    const executed = await checkAndExecuteProposals();
    return NextResponse.json({
      message: `Checked proposals. Executed: ${executed.length}`,
      executed
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
```

### 6.4 Trigger Periódico del Daemon

**Opción A — Singleton en módulo (development):**

```typescript
// lib/daemonScheduler.ts
// Importar en layout.tsx server-side para activar

let started = false;

export function startDaemon() {
  if (started || process.env.NODE_ENV !== "development") return;
  started = true;
  
  setInterval(async () => {
    const { checkAndExecuteProposals } = await import("./daemon");
    await checkAndExecuteProposals();
  }, 30_000); // cada 30 segundos
  
  console.log("[daemon] Scheduler started (30s interval)");
}
```

**Opción B — Vercel Cron (producción):**

```json
// vercel.json
{
  "crons": [{ "path": "/api/daemon", "schedule": "*/1 * * * *" }]
}
```

---

## 7. Parte 4 — Integración y Testing

### 7.1 Levantar el Entorno Local

```bash
# Terminal 1: Nodo Anvil
anvil --chain-id 31337

# Terminal 2: Deploy contratos
cd sc
forge build
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
# Copiar las addresses mostradas al .env.local

# Terminal 3: Frontend
cd web
# Editar .env.local con las addresses del paso anterior
npm run dev
```

### 7.2 Escenario de Prueba E2E

| Paso | Acción | Verificación |
|------|--------|--------------|
| 1 | Importar cuenta Anvil #0 en MetaMask (pk: `0xac09...`) | MetaMask muestra la cuenta |
| 2 | Conectar wallet en el frontend | Dirección visible en header |
| 3 | Usuario A deposita 10 ETH | Balance DAO: 10 ETH, balance A: 10 ETH |
| 4 | Cambiar a cuenta Anvil #1 (Usuario B), depositar 5 ETH | Balance DAO: 15 ETH |
| 5 | Con Usuario A: crear propuesta (recipient=cuentaExterna, 1 ETH, deadline=+1h) | Proposal #1 aparece en lista |
| 6 | Con Usuario B: intentar crear propuesta | Error: "Insufficient balance to propose" |
| 7 | Usuario A vota A FAVOR (gasless) | Sin popup de gas. Votos FOR: 1 |
| 8 | Usuario B vota EN CONTRA (gasless) | Sin popup de gas. Votos AGAINST: 1 |
| 9 | Importar cuenta Anvil #2 (Usuario C), depositar 20 ETH y votar A FAVOR | Votos FOR: 2 |
| 10 | Avanzar tiempo en Anvil: `cast rpc anvil_setNextBlockTimestamp <deadline+3700>` | — |
| 11 | Llamar `GET /api/daemon` | Response: `{ executed: [1] }` |
| 12 | Verificar que proposal #1 aparece como "Ejecutada" | Badge gris en ProposalCard |
| 13 | Verificar balance del recipient aumentó 1 ETH | `cast balance <recipient>` |

### 7.3 Edge Cases a Validar

| Caso | Acción | Resultado Esperado |
|------|--------|--------------------|
| Propuesta inexistente | `dao.vote(999, 0)` | Revert: "Proposal does not exist" |
| Votar sin balance | Votar antes de depositar | Revert: "No balance to vote" |
| Votar post-deadline | Votar con timestamp > deadline | Revert: "Voting period ended" |
| Crear sin balance suficiente | Balance < 10% del DAO | Revert: "Insufficient balance to propose" |
| Ejecutar antes de safety period | Ejecutar inmediatamente tras deadline | Revert: "Safety period not elapsed" |
| Ejecutar ya ejecutada | Llamar executeProposal dos veces | Revert: "Proposal already executed" |
| Ejecutar propuesta rechazada | AGAINST >= FOR | Revert: "Proposal not approved" |
| Replay attack | Reutilizar firma ya usada | Revert por nonce inválido |
| Firma de otro usuario | Firmar con key incorrecta | Revert: "invalid signature" |
| Cambiar voto | Votar FOR, luego AGAINST | Contadores actualizados: FOR-1, AGAINST+1 |

---

## 8. Plan de Tareas para IA

> **Seguir el orden estrictamente.** Verificar cada tarea antes de continuar.

### Fase 1: Smart Contracts

| # | Tarea | Comando de Verificación |
|---|-------|------------------------|
| 1.1 | `forge init sc && cd sc && forge install OpenZeppelin/openzeppelin-contracts` | `forge build` sin errores |
| 1.2 | Configurar `foundry.toml` con remappings | `forge remappings` muestra OZ path |
| 1.3 | Implementar `src/MinimalForwarder.sol` completo | `forge build src/MinimalForwarder.sol` |
| 1.4 | Implementar `src/DAOVoting.sol` completo | `forge build` sin warnings |
| 1.5 | Escribir `test/MinimalForwarder.t.sol` (verify, execute, replay) | `forge test --match-contract MinimalForwarderTest` ✓ |
| 1.6 | Escribir `test/DAOVoting.t.sol` (todos los casos) | `forge test --match-contract DAOVotingTest` ✓ |
| 1.7 | Implementar test de meta-transacción gasless | `forge test --match-test test_GaslessVote` ✓ |
| 1.8 | Implementar test de replay attack | `forge test --match-test test_GaslessVote_ReplayAttack` ✓ |
| 1.9 | Correr coverage | `forge coverage` muestra > 80% |
| 1.10 | Escribir `script/Deploy.s.sol` | `forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545` sin errores |

### Fase 2: Frontend Base

| # | Tarea | Comando de Verificación |
|---|-------|------------------------|
| 2.1 | `create-next-app` con TypeScript + Tailwind | `npm run dev` levanta en puerto 3000 |
| 2.2 | Crear `types/index.ts` con todas las interfaces | `npm run lint` sin errores de tipos |
| 2.3 | Implementar `lib/contracts.ts` con ABIs completos | Import sin errores |
| 2.4 | Implementar `lib/eip712.ts` | Función `signMetaTransaction` exportada y tipada |
| 2.5 | Implementar `context/WalletContext.tsx` | Provider wrappea `layout.tsx` |
| 2.6 | Implementar `hooks/useWallet.ts` | Conecta MetaMask, cambia estado |
| 2.7 | Implementar `hooks/useDAO.ts` | Lee proposals y balances del contrato |
| 2.8 | Implementar `components/ConnectWallet.tsx` | Visible en UI, conecta/desconecta |
| 2.9 | Implementar `components/FundingPanel.tsx` | Depósito funcional, UI actualiza |
| 2.10 | Implementar `components/CreateProposal.tsx` | Formulario valida balance y crea propuesta |
| 2.11 | Implementar `components/ProposalCard.tsx` | Muestra datos y badge de estado |
| 2.12 | Implementar `components/VoteButtons.tsx` | 3 botones con loading state |
| 2.13 | Implementar `components/ProposalList.tsx` | Lista proposals con polling |
| 2.14 | Componer `app/page.tsx` con todos los componentes | UI completa visible |

### Fase 3: Relayer y Gasless

| # | Tarea | Comando de Verificación |
|---|-------|------------------------|
| 3.1 | Implementar `app/api/relay/route.ts` | `curl -X POST /api/relay -d '{}' → 400` |
| 3.2 | Implementar `hooks/useGaslessVote.ts` | Hook exportado y tipado |
| 3.3 | Integrar `useGaslessVote` en `VoteButtons.tsx` | Voto sin popup de gas end-to-end |
| 3.4 | Implementar `lib/daemon.ts` | Función `checkAndExecuteProposals` exportada |
| 3.5 | Implementar `app/api/daemon/route.ts` | `curl GET /api/daemon → { executed: [] }` |
| 3.6 | Configurar trigger periódico del daemon | Logs cada 30s en consola del servidor |

### Fase 4: Integración y Cierre

| # | Tarea | Comando de Verificación |
|---|-------|------------------------|
| 4.1 | Ejecutar escenario completo E2E (Sección 7.2) | Todos los pasos sin errores |
| 4.2 | Validar todos los edge cases (Sección 7.3) | Mensajes de error correctos |
| 4.3 | Crear `.env.local.example` con keys vacías | Archivo presente, sin valores reales |
| 4.4 | `npm run build` sin errores | Build de producción exitoso |
| 4.5 | Escribir `README.md` con instrucciones completas | Instrucciones verificadas paso a paso |

---

## 9. Variables de Entorno

### `web/.env.local`

```env
# ─── Contratos (completar después del deployment) ───────────────────
NEXT_PUBLIC_DAO_ADDRESS=0x
NEXT_PUBLIC_FORWARDER_ADDRESS=0x

# ─── Red ─────────────────────────────────────────────────────────────
NEXT_PUBLIC_CHAIN_ID=31337
NEXT_PUBLIC_RPC_URL=http://127.0.0.1:8545

# ─── Relayer (server-side únicamente, NUNCA usar NEXT_PUBLIC_) ───────
# Usar una cuenta de Anvil — tiene ETH pre-cargado
RELAYER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
RELAYER_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
RPC_URL=http://127.0.0.1:8545
```

> ⚠️ **Seguridad:** `RELAYER_PRIVATE_KEY` y `RPC_URL` son server-only. Nunca usar prefijo `NEXT_PUBLIC_` para claves privadas.

### `web/.env.local.example`

```env
NEXT_PUBLIC_DAO_ADDRESS=
NEXT_PUBLIC_FORWARDER_ADDRESS=
NEXT_PUBLIC_CHAIN_ID=31337
NEXT_PUBLIC_RPC_URL=http://127.0.0.1:8545
RELAYER_PRIVATE_KEY=
RELAYER_ADDRESS=
RPC_URL=http://127.0.0.1:8545
```

### `sc/.env` (para deployment scripts)

```env
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

---

## 10. Criterios de Aceptación

### Smart Contracts

- [ ] `forge test` pasa al 100%
- [ ] `forge coverage` muestra ≥ 80% en líneas y ramas
- [ ] `forge build` sin warnings
- [ ] `MinimalForwarder` previene replay attacks (nonce incrementado)
- [ ] `DAOVoting` usa `_msgSender()` en **todas** las funciones públicas
- [ ] `executeProposal` tiene `nonReentrant`
- [ ] Todos los eventos emitidos correctamente
- [ ] Override de `_msgSender()` y `_msgData()` resuelve conflicto de herencia

### Frontend

- [ ] Conexión MetaMask funciona y detecta red incorrecta
- [ ] Depósito de ETH actualiza UI sin recargar página
- [ ] Creación de propuesta valida balance antes de enviar tx
- [ ] Votación gasless **no muestra popup de gas** en MetaMask
- [ ] UI refleja votos en tiempo real (polling o eventos)
- [ ] Errores del contrato se muestran de forma legible
- [ ] Estados de propuesta con colores correctos
- [ ] `npm run build` exitoso sin errores de TypeScript

### Relayer y Daemon

- [ ] POST `/api/relay` con firma válida devuelve `{ txHash }`
- [ ] POST `/api/relay` con firma inválida devuelve `400`
- [ ] POST `/api/relay` con `to` !== DAO devuelve `400` (whitelist)
- [ ] Daemon detecta propuestas elegibles correctamente
- [ ] Daemon ejecuta y transfiere fondos
- [ ] Daemon no re-ejecuta propuestas ya ejecutadas
- [ ] Logs de ejecución visibles en consola

### Documentación

- [ ] `README.md` con instalación paso a paso verificada
- [ ] Comandos de deployment documentados
- [ ] `.env.local.example` presente sin valores reales
- [ ] Funciones complejas documentadas con NatSpec / JSDoc

---

*Fin de la especificación técnica — DAO con Votación Gasless para IA*
