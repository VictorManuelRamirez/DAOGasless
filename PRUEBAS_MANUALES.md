# Guía de pruebas manuales — DAO Gasless

Pasos para validar la aplicación en **local (Anvil + MetaMask + Next.js)**. Están alineados con el escenario E2E de [DAO_GaslessVoting_IA.md](./DAO_GaslessVoting_IA.md) (§7.2) y con [README.md](./README.md).


---

## 0. Requisitos previos

- Foundry (`anvil`, `forge`, `cast`), Node.js ≥ 18, npm.
- MetaMask instalado en el navegador.
- Tres terminales disponibles (nodo, deploy, frontend).

---

## 1. Preparar el entorno

### Terminal 1 — Anvil

```bash
anvil --chain-id 31337
```

Dejar esta terminal abierta.

### Terminal 2 — Contratos

```bash
cd sc
forge build
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

Anotar las direcciones de **MinimalForwarder** y **DAOVoting** que imprime el script.

### Terminal 3 — Web

```bash
cd web
cp -n .env.local.example .env.local   # o editar .env.local existente
```

En `web/.env.local` completar al menos:

| Variable | Valor típico (local) |
|----------|----------------------|
| `NEXT_PUBLIC_DAO_ADDRESS` | Dirección del deploy |
| `NEXT_PUBLIC_FORWARDER_ADDRESS` | Dirección del deploy |
| `NEXT_PUBLIC_CHAIN_ID` | `31337` |
| `NEXT_PUBLIC_RPC_URL` | `http://127.0.0.1:8545` |
| `RPC_URL` | `http://127.0.0.1:8545` |
| `RELAYER_PRIVATE_KEY` | Misma clave que el deploy (`0xac09…f80`) para que el relayer tenga ETH en Anvil |

Arrancar:

```bash
npm install
npm run dev
```

Abrir **http://localhost:3000**.

---

## 2. Configurar MetaMask (red local)

1. Red → **Añadir red** → datos manuales:
   - **RPC:** `http://127.0.0.1:8545`
   - **Chain ID:** `31337`
   - **Moneda:** ETH (símbolo arbitrario, p. ej. ETH)
2. Importar cuentas con claves privadas de Anvil (opción “Importar cuenta”):
   - **Cuenta #0 (Usuario A):** `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
   - **Cuenta #1 (Usuario B):** `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d`
   - **Cuenta #2 (Usuario C):** `0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a`

Anvil financia estas cuentas con ETH por defecto.

---

## 3. Escenario principal (flujo E2E)

Sigue el orden. En la UI, mantén activado **Gasless voting** en la sección Proposals si quieres votar sin gas del usuario.

| Paso | Acción manual | Qué comprobar |
|------|----------------|---------------|
| 1 | En MetaMask, seleccionar **Usuario A** (cuenta #0). | Saldo ETH visible. |
| 2 | En la app, **Conectar wallet**. | Dirección truncada y estado “Conectado” en el header; sin error de red incorrecta (debe ser chain `31337`). |
| 3 | Con Usuario A: en **Deposit ETH to DAO**, depositar **10** ETH y pulsar **Deposit to DAO**. | “Treasury Balance” y “Your Balance in DAO” coherentes (10 ETH en tesorería y tu parte). |
| 4 | Cambiar en MetaMask a **Usuario B** (cuenta #1). Conectar si hace falta. Depositar **5** ETH. | Tesorería total ≈ **15** ETH. |
| 5 | Volver a **Usuario A**. Crear propuesta: **Recipient** = una dirección de prueba (p. ej. cuenta que no sea el DAO), **Amount** = **1** ETH, **Voting Duration (days)** = **1** (el formulario usa días enteros; el `deadline` será ~ahora + 1 día). **Description** opcional. Activar **Use gasless transaction** si quieres probar relayer al crear, o desactivar para tx on-chain. | Aparece **Proposal #1** en la lista. |
| 6 | Cambiar a **Usuario B**. Intentar crear otra propuesta con datos válidos. | Debe fallar (balance B &lt; 10 % del total del DAO): mensaje coherente con *Insufficient balance to propose* o equivalente en la UI. |
| 7 | Con **Usuario A**, en la propuesta activa, votar **A FAVOR** con **Gasless voting** activado. | No debe aparecer el popup de **enviar transacción** con gas del usuario (solo firma EIP-712). Contador **FOR** sube (tras refresco/polling). |
| 8 | Con **Usuario B**, votar **EN CONTRA** (gasless). | Igual: sin gas del usuario; **AGAINST** sube. |
| 9 | Importar/seleccionar **Usuario C** (cuenta #2), depositar **20** ETH y votar **A FAVOR**. | **FOR** debe quedar por encima de **AGAINST** (p. ej. FOR 2, AGAINST 1). |
| 10 | Avanzar el tiempo de la blockchain **después** del `deadline` y del **periodo de seguridad** (1 h). Ejemplo genérico: `T=$(($(date +%s) + 172800))` (≈ +2 días respecto al reloj del sistema; ajusta si hace falta más margen), luego `cast rpc anvil_setNextBlockTimestamp $T` y `cast rpc anvil_mine` contra `http://127.0.0.1:8545`. | El bloque actual está **después** de `deadline + 3600s`. |
| 11 | Ejecutar el daemon (navegador o terminal): abrir **http://localhost:3000/api/daemon** o `curl -s http://localhost:3000/api/daemon`. | JSON con `executed: [1]` (o el id correspondiente) si la propuesta es ejecutable. |
| 12 | Recargar la página de la app. | La propuesta #1 muestra estado **Executed** (badge gris / ejecutada). |
| 13 | Comprobar el **recipient**: `cast balance <DIRECCION_RECIPIENT> --rpc-url http://127.0.0.1:8545`. | El saldo aumentó en **1 ETH** (menos gas si hubiera sido otra operación; aquí es transferencia del contrato). |

---

## 4. Comprobaciones rápidas adicionales

- **Relay:** si el voto gasless falla, revisa consola del servidor Next.js y [ERRORES.md](./ERRORES.md) (nonce del **forwarder**, dominio EIP-712 `MinimalForwarder` / versión `1`).
- **Red incorrecta:** cambia chain id en MetaMask a otra red; la app debe indicar red incorrecta y no operar hasta volver a **31337**.
- **Desconectar wallet:** **Desconectar** en el header y comprobar que no quedan datos sensibles en pantalla.
- **Barra “Blockchain Time”:** debe actualizarse periódicamente si `NEXT_PUBLIC_RPC_URL` apunta a Anvil.

---

## 5. Ideas de edge cases (opcional)

Puedes repetir escenarios de la tabla §7.3 del spec usando **cast** / consola del contrato o la UI donde aplique:

| Tema | Idea |
|------|------|
| Votar sin depósito | Cuenta nueva sin depositar → intentar votar → error. |
| Votar tras deadline | Sin mover tiempo, tras cerrar votación → no debe dejarte votar. |
| Ejecutar dos veces | Tras ejecutar, el botón o `executeProposal` no debe volver a ejecutar. |

---

## 6. Referencias

- Especificación: [DAO_GaslessVoting_IA.md](./DAO_GaslessVoting_IA.md)  
- Errores habituales: [ERRORES.md](./ERRORES.md)  
- Mock de pantalla: [DAO-Design-UX.png](./DAO-Design-UX.png)
