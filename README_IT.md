# Balda Protocol — README Tecnico (Italiano)

> **Autore:** Deaf Italian · *Concept & Decisione esclusivamente di Deaf Italian. Realizzato con AI.*
> **Licenza:** MIT · **Solidity:** ^0.8.20 · **Dipendenze:** OpenZeppelin

---

## Indice

1. [Panoramica generale](#panoramica-generale)
2. [Token: Balda (BLD)](#1-baldasol--token-balda-bld)
3. [BaldaReserve](#2-baldareservesol--riserva-eterna)
4. [VaultCreator](#3-vaultcreatorsol--vesting-del-fondatore)
5. [BaldaAirdrop](#4-baldaairdropsol--airdrop-automatizzato)
6. [LiquidityVault](#5-liquidityvaultsol--blocco-della-liquidità)
7. [Riepilogo distribuzione supply](#riepilogo-distribuzione-supply)
8. [Ordine di deployment](#ordine-di-deployment)
9. [Proprietà di sicurezza](#proprietà-di-sicurezza)
10. [Rischi e osservazioni rilevanti](#rischi-e-osservazioni-rilevanti)

---

## Panoramica generale

**Balda Protocol** è un sistema token completamente autonomo e senza proprietario, costruito su Ethereum. È composto da cinque smart contract le cui interazioni sono determinate interamente al momento del deployment. Non esistono chiavi di amministrazione, percorsi di aggiornamento o ruoli privilegiati dopo la messa in produzione. Tutte le regole di distribuzione dei token sono imposte in modo immutabile on-chain.

Il sistema è progettato attorno a tre principi:
- **Immutabilità** — nessun contratto può essere modificato dopo il deployment.
- **Assenza di fiducia (trustlessness)** — nessun intervento umano è necessario per applicare le regole; i contratti le applicano autonomamente.
- **Trasparenza** — ogni regola, importo e costante temporale è hardcoded e pubblicamente verificabile.

---

## 1. `Balda.sol` — Token Balda (BLD)

### Sintesi

Un token ERC-20 puro e minimale con una **supply totale fissa di 91.000 BLD** (18 decimali). L'intera supply viene mintata in una singola operazione atomica all'interno del costruttore. Non esiste funzione di minting aggiuntiva, funzione di burn, proprietario, pausa, blacklist né tassa di trasferimento.

### Costanti di supply

| Costante          | Valore       | Destinatario           |
|-------------------|--------------|------------------------|
| `AIRDROP_AMOUNT`  | 70.000 BLD   | Contratto `BaldaAirdrop` |
| `VAULT_AMOUNT`    | 10.000 BLD   | Contratto `VaultCreator` |
| `RESERVE_AMOUNT`  |  6.000 BLD   | Contratto `BaldaReserve` |
| `DEPLOYER_AMOUNT` |  5.000 BLD   | Wallet del deployer      |
| **TOTAL_SUPPLY**  | **91.000 BLD** | —                      |

### Logica del costruttore

```
constructor(airdropContract, reserveContract, vaultContract)
```

- Verifica che tutti e tre gli indirizzi siano diversi da zero.
- Chiama `_mint()` quattro volte (una per destinatario).
- Include un controllo finale `assert(totalSupply() == TOTAL_SUPPLY)`: se l'aritmetica non corrisponde, l'intero deployment viene annullato (revert).

### Proprietà

- Nessun import di `Ownable` — il contratto è senza proprietario per design.
- ERC-20 standard: solo `transfer`, `approve`, `transferFrom`.
- Dopo il deployment, il contratto ha superficie amministrativa nulla.

---

## 2. `BaldaReserve.sol` — Riserva Eterna

### Sintesi

Il contratto più semplice del sistema. È un contratto **intenzionalmente vuoto**: nessuna variabile di stato, nessuna funzione, nessuna logica nel costruttore, nessun fallback, nessun hook `receive`.

Il suo unico scopo è fungere da **buco nero permanente** per 6.000 BLD. Al momento del deployment del token Balda, i token vengono mintati direttamente nell'indirizzo di questo contratto. Poiché il contratto non ha funzioni, quei token non possono mai essere spostati da nessuno, per nessun motivo.

### Perché questa scelta è rilevante

La riserva non è semplicemente "bloccata" — è **provabilmente inaccessibile**. Chiunque può ispezionare il codice sorgente on-chain e verificare in pochi secondi che non esiste nessun percorso di trasferimento. Questa è una garanzia più forte di un time lock o di un multisig.

---

## 3. `VaultCreator.sol` — Vesting del Fondatore

### Sintesi

Gestisce **10.000 BLD** allocati al fondatore del protocollo, suddivisi in due meccanismi indipendenti:

| Meccanismo     | Importo    | Regole |
|----------------|------------|--------|
| Vesting lineare | 5.000 BLD | Streaming continuo al secondo nell'arco di 11 anni gregoriani dal deploy |
| Tranche 1       | 2.500 BLD | Rivendicabile dopo 11 anni dal deploy |
| Tranche 2       | 1.250 BLD | Rivendicabile dopo 22 anni dal deploy |
| Tranche 3       | 1.250 BLD | Rivendicabile dopo 33 anni dal deploy |

### Costanti temporali

Tutte le durate usano l'anno gregoriano prolettivo (365,2425 × 86.400 secondi):

| Costante          | Secondi       | Durata umana |
|-------------------|---------------|--------------|
| `VESTING_DURATION`| 347.126.472   | 11 anni      |
| `TRANCHE_1_DELAY` | 347.126.472   | 11 anni      |
| `TRANCHE_2_DELAY` | 694.252.944   | 22 anni      |
| `TRANCHE_3_DELAY` | 1.041.379.416 | 33 anni      |

### A) Vesting Lineare

- Inizia al momento del deployment (`deployTime`).
- Si accumula in modo continuo, secondo per secondo.
- Nessun cliff, nessun importo minimo di prelievo.
- `withdrawVesting()` è richiamabile solo dall'indirizzo `founder` impostato al deploy.
- Il fondatore può prelevare importi parziali con la frequenza che preferisce.
- Dopo 11 anni, tutti i 5.000 BLD sono sbloccati.

**Funzioni principali:**
- `vestedAmount()` — vista: BLD cumulativi maturati fino ad ora.
- `availableVesting()` — vista: BLD attualmente prelevabili.
- `withdrawVesting()` — azione: trasferisce i BLD disponibili al fondatore.

### B) Tranche (Registrazione wallet protetta da password)

Il meccanismo delle tranche utilizza uno **schema commit-reveal** per proteggere l'indirizzo del wallet delle tranche:

1. Al momento del deploy, viene memorizzato solo `keccak256(abi.encodePacked(secretPassword))` — la password effettiva non è mai on-chain in chiaro.
2. Il fondatore chiama `registerTrancheWallet(password)` in qualsiasi momento. Il contratto verifica l'hash e registra permanentemente `msg.sender` come `trancheWallet`.
3. **Nota di sicurezza:** La password deve essere inviata tramite Flashbots o un bundle di transazioni private per evitare il front-running nel mempool pubblico.
4. Una volta registrato, `trancheWallet` è immutabile.
5. Le rivendicazioni delle tranche richiedono solo l'indirizzo `trancheWallet` — nessuna password è necessaria dopo la registrazione.

**Funzioni tranche:**
- `registerTrancheWallet(password)` — registrazione unica.
- `claimTranche1()` — richiamabile da `trancheWallet` dopo 11 anni.
- `claimTranche(2)` — richiamabile da `trancheWallet` dopo 22 anni.
- `claimTranche(3)` — richiamabile da `trancheWallet` dopo 33 anni.
- `trancheUnlockAt(id)` — vista: timestamp Unix in cui la tranche diventa rivendicabile (restituisce 0 se già sbloccata).

### Sicurezza

- Nessun proprietario dopo il deploy.
- Nessuna funzione amministrativa.
- Nessun percorso di aggiornamento.
- Nessuna funzione di recupero (rescue).
- `founder` e `passwordHash` sono impostati una volta, memorizzati come `immutable`, e non possono mai cambiare.

---

## 4. `BaldaAirdrop.sol` — Airdrop Automatizzato

Questo è il contratto più complesso del sistema. Distribuisce **70.000 BLD** in modo autonomo attraverso tre fasi sequenziali, senza proprietario, senza chiavi di amministrazione e senza percorsi di aggiornamento.

### Struttura di alto livello

| Fase          | BLD Base   | Periodi | Durata totale | Note |
|---------------|------------|---------|---------------|------|
| Ciclo 1       | 50.000 BLD | 8       | ~396 giorni   | Vesting lineare di 180 giorni per ogni claim |
| Ciclo 2       | 20.000 BLD | 5       | ~165 giorni   | Inizia 11 anni dopo il deploy; pagamento immediato completo |
| Fase Finale   | Avanzi     | 1       | Infinita      | Rete di sicurezza; pagamento immediato completo |

### Regole universali

**1. Un Wallet, Un Claim — Per Sempre**
Ogni indirizzo può effettuare un claim esattamente una volta nell'intera vita del contratto, indipendentemente dalla fase o dal periodo. La mappatura `hasClaimed` è permanente e globale.

**2. Vesting Lineare (solo Ciclo 1)**
Tutti e 8 i periodi del Ciclo 1 applicano un vesting lineare di 180 giorni. Il vesting inizia dall'*inizio del periodo*, non dal momento del claim.
- Al claim: la frazione già maturata `(elapsed / 180 giorni) × premio` viene trasferita immediatamente.
- Il resto è trattenuto nel contratto e rilasciato tramite `withdrawVesting()`.
- Nessun cliff, nessun importo minimo.
- Ciclo 2 e Fase Finale pagano l'intero premio senza vesting.

**3. Rollover degli Avanzi**
I token non rivendicati entro la fine di un periodo vengono trasferiti all'allocazione del periodo successivo. Tutti gli avanzi del Ciclo 1 si accumulano e vengono iniettati nel Ciclo 2 come mcap aggiuntivo all'avvio.

**4. Regola della Polvere / Dust Rule (solo C2-P5 e Fase Finale)**
- Periodi normali (C1-P1 fino a C2-P4): se l'allocazione rimanente del periodo è inferiore al premio, il claim **va in revert**. I token aspettano la scadenza naturale del periodo e si trasferiscono al successivo.
- C2-P5 e Fase Finale: se `mcapAvailable < premio`, si attiva la **Dust Rule** — il wallet richiedente riceve *tutti i token rimanenti* e il contratto si chiude definitivamente.

**5. Chiusura Automatica**
Il contratto si chiude (fase = 3) in questi casi:
- La Dust Rule si attiva nel C2-P5.
- Il C2-P5 termina senza avanzi.
- La Dust Rule si attiva nella Fase Finale.

La chiusura emette: `ContractClosed("Distribution complete. Thank you all.")`

---

### Ciclo 1 — Dettaglio Periodi

La durata dei periodi segue la formula `(indice + 1) × 11 giorni`. Solo il C1-P1 ha un cap sui wallet (massimo 91).

| Periodo | Durata   | Premio per Wallet | Allocazione Base  |
|---------|----------|-------------------|-------------------|
| C1-P1   | 11 giorni | 111 BLD          | 10.101 BLD        |
| C1-P2   | 22 giorni | 55,5 BLD         | 1.424,964… BLD    |
| C1-P3   | 33 giorni | 27,75 BLD        | 2.849,928… BLD    |
| C1-P4   | 44 giorni | 13,875 BLD       | 4.274,892… BLD    |
| C1-P5   | 55 giorni | 6,9375 BLD       | 5.699,857… BLD    |
| C1-P6   | 66 giorni | 3,46875 BLD      | 7.124,821… BLD    |
| C1-P7   | 77 giorni | 1,734375 BLD     | 8.549,785… BLD    |
| C1-P8   | 88 giorni | 0,8671875 BLD    | 9.974,750… BLD    |

**Totale base C1: 50.000 BLD** (somma verificata al wei nel contratto).

La serie di premi è geometrica con ragione 1/2 e base 111 BLD:
`premio[n] = 111 / 2^n` (n = 0 per P1)

---

### Ciclo 2 — Dettaglio Periodi

Il Ciclo 2 inizia esattamente **11 anni gregoriani** (347.126.472 secondi) dopo il deployment. Eredita tutti gli avanzi accumulati nel Ciclo 1.

| Periodo | Durata   | Premio per Wallet     | Allocazione Base      |
|---------|----------|-----------------------|-----------------------|
| C2-P1   | 11 giorni | ≈ 0,43359375 BLD     | ≈ 1.333,333… BLD      |
| C2-P2   | 22 giorni | ≈ 0,216796875 BLD    | ≈ 2.666,666… BLD      |
| C2-P3   | 33 giorni | ≈ 0,108398437 BLD    | 4.000 BLD (esatto)    |
| C2-P4   | 44 giorni | ≈ 0,054199218 BLD    | ≈ 5.333,333… BLD      |
| C2-P5   | 55 giorni | ≈ 0,027099609 BLD    | ≈ 6.666,666… BLD      |

**Totale base C2: 20.000 BLD** (somma verificata al wei nel contratto).

La serie dei premi continua la stessa progressione geometrica del Ciclo 1 (divisione per 2 ad ogni periodo).

---

### Fase Finale

Se il C2-P5 termina con token rimanenti, inizia la Fase Finale. Ha:
- **Durata infinita** (`type(uint256).max`).
- **Nessuna allocazione base** — solo gli avanzi sopravvissuti dal C2-P5.
- **Premio:** ≈ 0,013549804 BLD (111 / 2^13).
- **Dust Rule attiva** dal primo claim.

---

### Macchina a stati

```
Fase 0 (Ciclo 1)
  P0 → P1 → P2 → P3 → P4 → P5 → P6 → P7
  └─ Dopo P7 → Stato di attesa (periodIndex == 8)
       └─ Dopo 11 anni → Fase 1 (Ciclo 2)
            P0 → P1 → P2 → P3 → P4
            └─ P4 termina con avanzi → Fase 2 (Fase Finale)
            └─ P4 Dust Rule o 0 avanzi → Fase 3 (Chiuso)
Fase 2 (Fase Finale): Dust Rule → Fase 3 (Chiuso)
```

Il valore sentinella `currentPeriodIndex == 8` mentre `currentPhase == 0` rappresenta lo stato di attesa tra i cicli.

---

### Funzioni pubbliche

| Funzione | Accesso | Descrizione |
|----------|---------|-------------|
| `claim()` | chiunque (wallet non ancora richiedente) | Rivendica il premio del periodo corrente |
| `withdrawVesting()` | richiedenti del Ciclo 1 | Preleva i token di vesting maturati |
| `finalizePeriod()` | chiunque | Avanza lo stato se il periodo corrente è scaduto |
| `startCycle2()` | chiunque | Avvia manualmente il Ciclo 2 se i 11 anni sono trascorsi e si è in attesa |

### Funzioni di visualizzazione

| Funzione | Restituisce |
|----------|-------------|
| `currentPeriodInfo()` | Tupla completa dello stato del periodo |
| `timeLeftInPeriod()` | Secondi rimanenti nel periodo corrente |
| `cycle2StartTime()` | Timestamp Unix dell'avvio del Ciclo 2 (0 se già avviato) |
| `isWaitingForCycle2()` | True se in stato di attesa inter-ciclo |
| `availableVesting(wallet)` | Token di vesting attualmente prelevabili |
| `hasClaimed(wallet)` | Se il wallet ha già effettuato un claim |
| `vestingOf(wallet)` | Struct VestingInfo completo per il wallet |

---

## 5. `LiquidityVault.sol` — Blocco della Liquidità

### Sintesi

Un blocco permanente e unidirezionale per i token LP Uniswap V2 che rappresentano il pool BLD/ETH. Una volta depositati, i token LP non possono mai essere recuperati. Possono opzionalmente essere inviati all'indirizzo morto (`0x000...dEaD`) tramite `burnLP()`.

### Regole

1. **Deposita una volta, blocca per sempre.** `depositLP()` può essere chiamata solo una volta. L'indirizzo del token LP viene registrato alla prima chiamata ed è immutabile da quel momento.
2. **Nessun prelievo.** Nessuna funzione di withdraw, nessuna funzione rescue, nessun proprietario.
3. **Burn pubblico.** Chiunque può chiamare `burnLP()` in qualsiasi momento dopo il deposito. L'intero saldo LP viene inviato atomicamente a `0x000...dEaD`, rendendo il blocco della liquidità permanentemente e pubblicamente verificabile on-chain.

### Funzioni

| Funzione | Accesso | Descrizione |
|----------|---------|-------------|
| `depositLP(lpToken, amount)` | chiunque (una sola volta) | Deposita e blocca i token LP |
| `burnLP()` | chiunque | Invia tutti i token LP all'indirizzo morto |
| `lpBalance()` | vista | Saldo corrente dei token LP |
| `vaultStatus()` | vista | Stato completo: depositato, bruciato, indirizzo lp, importo, saldo |

### Flusso di deployment

1. Deploy di `LiquidityVault`.
2. Deploy del token `Balda` — il deployer riceve 5.000 BLD.
3. Aggiunta di BLD + ETH come liquidità su Uniswap V2 — si ricevono token LP.
4. Approvazione di `LiquidityVault` a spendere i token LP.
5. Chiamata a `depositLP(lpTokenAddress, amount)`.
6. Chiamata a `burnLP()` per inviare i token LP all'indirizzo morto in modo permanente.

### Sicurezza

- Nessun owner, nessun admin, nessun upgrade, nessun proxy, nessun rescue, nessun selfdestruct, nessun delegatecall.
- Tutti i trasferimenti di token usano `SafeERC20` di OpenZeppelin.
- Immutabile dopo il deployment.

---

## Riepilogo distribuzione supply

```
Supply Totale: 91.000 BLD
│
├── 70.000 BLD (76,9%) → BaldaAirdrop   — Distribuiti in ~11+ anni tramite fasi di claim
├── 10.000 BLD (11,0%) → VaultCreator   — Fondatore: 5.000 lineare + 3 tranche in 33 anni
├──  6.000 BLD  (6,6%) → BaldaReserve   — Bloccati per sempre, permanentemente inaccessibili
└──  5.000 BLD  (5,5%) → Wallet deployer — Per la fornitura di liquidità DEX
```

---

## Ordine di deployment

I contratti devono essere deployati in questa precisa sequenza:

```
1. BaldaReserve.sol    — Nessuna dipendenza
2. VaultCreator.sol    — Richiede: indirizzo token, indirizzo fondatore, passwordHash
3. BaldaAirdrop.sol    — Richiede: indirizzo token
4. Balda.sol           — Richiede: indirizzo BaldaAirdrop, BaldaReserve, VaultCreator
```

> **Nota:** `VaultCreator` e `BaldaAirdrop` richiedono l'indirizzo del token BLD nei loro costruttori, ma BLD deve essere deployato per ultimo. In pratica questo si gestisce pre-calcolando l'indirizzo futuro del token tramite `CREATE2` o previsione basata sul nonce del deployer.

---

## Proprietà di sicurezza

| Proprietà | Stato |
|-----------|-------|
| Supply fissa, nessun minting aggiuntivo | ✅ |
| Nessuna funzione di burn | ✅ |
| Nessun owner / admin | ✅ |
| Nessun upgrade / proxy | ✅ |
| Nessuna pausa / blacklist | ✅ |
| Nessuna tassa di trasferimento | ✅ |
| Nessuna funzione rescue | ✅ |
| SafeERC20 usato ovunque | ✅ |
| Immutabile dopo il deployment | ✅ |
| Enforcement globale un-wallet-un-claim | ✅ |
| Timing basato su secondi del calendario gregoriano | ✅ |

---

## Rischi e osservazioni rilevanti

1. **Front-running della password delle tranche:** La funzione `registerTrancheWallet()` invia la password in chiaro on-chain. Se chiamata tramite una transazione standard, un bot MEV potrebbe vedere la password nel mempool e anticipare la registrazione con un wallet diverso. **Mitigazione:** il contratto consiglia esplicitamente di usare Flashbots o un bundle di transazioni private.

2. **Indirizzo del token in `VaultCreator`/`BaldaAirdrop` prima che BLD esista:** L'ordine di deployment richiede che gli indirizzi del token BLD siano noti prima che BLD venga deployato. Questo richiede una pre-computazione accurata degli indirizzi.

3. **`finalizePeriod()` e `startCycle2()` sono pubbliche:** Chiunque può avanzare la macchina a stati. Questo è intenzionale — evita blocchi — ma significa che lo stato può transitare senza nessuna attività di claim.

4. **Il Ciclo 2 inizia esattamente 11 anni dopo il deploy, indipendentemente dall'attività del Ciclo 1:** Se il Ciclo 1 termina prima, il contratto entra in uno stato di attesa. Il Ciclo 2 non può iniziare fino al completamento dei 11 anni.

5. **I token in BaldaReserve sono permanentemente inaccessibili:** 6.000 BLD (6,6% della supply) non circoleranno mai. Si tratta di una scelta di design deliberata per la contabilità della riserva del protocollo, non di un bug.

6. **I 5.000 BLD del deployer sono liberamente utilizzabili:** Questi token non hanno vesting e sono destinati alla fornitura di liquidità DEX. Il deployer mantiene il pieno controllo su questi token dopo il deployment.

7. **Il burn dei LP in LiquidityVault è irreversibile:** Una volta che `burnLP()` viene chiamata da qualsiasi parte, la liquidità BLD/ETH è bloccata permanentemente. Questo avvantaggia i holder del token eliminando il rischio di rug-pull, ma significa anche che la liquidità non potrà mai essere adattata alle condizioni di mercato.

---

*Balda Protocol — Concept & Decisione esclusivamente di Deaf Italian. Realizzato con AI.*
