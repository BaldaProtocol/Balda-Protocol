# Balda Protocol — Token BLD

> **Supply fissa · Senza owner · Immutabile · Nessuna chiave admin**
>
> *Concept & Decisione di Deaf Italian. Sviluppato con l'aiuto dell'AI.*

---

## ⚠️ Disclaimer

> Questi contratti non sono stati sottoposti a un audit professionale. Usare a proprio rischio.

---

## Panoramica

Balda Protocol è un sistema ERC-20 completamente autonomo e senza owner, deployato su Ethereum. L'intera supply di **91.000 BLD** viene distribuita al momento del deploy in un'unica transazione atomica verso quattro destinazioni. Dopo il deploy, nessun indirizzo — incluso il deployer — detiene alcun potere amministrativo sui contratti.

Il sistema è composto da cinque smart contract indipendenti, ognuno con un ruolo specifico e immutabile.

---

## Token — BLD

| Proprietà | Valore |
|---|---|
| Nome | Balda |
| Simbolo | BLD |
| Decimali | 18 |
| Supply totale | 91.000 BLD (fissa per sempre) |
| Minting | Una sola volta, al deploy |
| Funzione burn | Nessuna |
| Owner | Nessuno |
| Pause / blacklist | Nessuna |
| Transfer tax | Nessuna |
| Standard | ERC-20 (OpenZeppelin) |

Il costruttore conia l'intera supply in un'unica operazione atomica e verifica con `assert(totalSupply() == 91_000 * 1e18)`. Se il controllo fallisce, l'intero deploy viene annullato.

---

## Distribuzione Supply

| Destinatario | Importo | % | Scopo |
|---|---|---|---|
| Contratto `BaldaAirdrop` | 70.000 BLD | 76,9% | Airdrop automatico in tre fasi |
| Contratto `VaultCreator` | 10.000 BLD | 11,0% | Vesting founder (lineare + tranche) |
| Contratto `BaldaReserve` | 6.000 BLD | 6,6% | Riserva eterna — bloccata per sempre |
| Wallet deployer | 5.000 BLD | 5,5% | Liquidità DEX (Uniswap V2 BLD/ETH) |

---

## Contratti

### 1. `BaldaReserve.sol` — Riserva Eterna

Un contratto intenzionalmente **completamente vuoto**. Nessuna variabile di stato, nessuna funzione, nessun fallback, nessun hook receive. I 6.000 BLD inviati qui al momento del deploy sono bloccati permanentemente senza alcun meccanismo per muoverli. Il codice sorgente minimale e pubblicamente verificabile on-chain è la prova definitiva che questa quota di supply non potrà mai essere accessibile da nessuno.

---

### 2. `VaultCreator.sol` — Vesting Founder

Gestisce 10.000 BLD divisi in due meccanismi indipendenti.

#### A) Vesting Lineare — 5.000 BLD

| Parametro | Valore |
|---|---|
| Importo totale | 5.000 BLD |
| Durata | 11 anni Gregoriani (347.126.472 secondi) |
| Tipo | Streaming continuo per secondo |
| Cliff | Nessuno — prelevabile da subito, dal secondo 1 |
| Destinatario | Indirizzo `founder` impostato al deploy (immutabile) |
| Funzione | `withdrawVesting()` |

#### B) Tranche — 5.000 BLD

| Tranche | Importo | Unlock dopo | Secondi dal deploy |
|---|---|---|---|
| Tranche 1 | 2.500 BLD | 11 anni | 347.126.472 |
| Tranche 2 | 1.250 BLD | 22 anni | 694.252.944 |
| Tranche 3 | 1.250 BLD | 33 anni | 1.041.379.416 |

#### Registrazione Tranche Wallet

Al deploy, viene salvato on-chain solo l'hash `keccak256(abi.encodePacked(password))` — la password in chiaro non compare mai nel contratto. Per registrarsi:

1. Chiamare `registerTrancheWallet(password)` — il contratto verifica che l'hash corrisponda.
2. Il `msg.sender` viene registrato permanentemente come `trancheWallet`.
3. Una volta registrato, il wallet non è modificabile.
4. Tutte e tre le tranche verranno inviate esclusivamente a quell'indirizzo; dopo la registrazione non è più necessaria la password.

> ⚠️ Usare Flashbots o un bundle privato quando si chiama `registerTrancheWallet()` per proteggere la password in chiaro dal mempool pubblico.

#### Funzioni di Lettura

| Funzione | Descrizione |
|---|---|
| `vestedAmount()` | BLD totali maturati finora (inclusi già prelevati) |
| `availableVesting()` | BLD disponibili per il prelievo in questo momento |
| `trancheUnlockAt(id)` | Timestamp Unix esatto di unlock della tranche (0 se già sbloccata) |

---

### 3. `LiquidityVault.sol` — Lock Liquidità Permanente

Riceve i token LP di Uniswap V2 (coppia BLD/ETH) e li blocca permanentemente. Una volta depositati, nessuno — incluso il depositor originale — può mai ritirarli.

#### Flusso Operativo

1. Deploy di `LiquidityVault` (nessun argomento nel costruttore).
2. Deploy del token `Balda` — il deployer riceve 5.000 BLD.
3. Aggiungere ETH dal wallet del deployer.
4. Creare il pool BLD/ETH su Uniswap V2 — ricevere i token LP.
5. Autorizzare `LiquidityVault` a spendere i token LP (approve).
6. Chiamare `depositLP(lpTokenAddress, amount)` — token LP bloccati per sempre.
7. Chiamare `burnLP()` — token LP inviati all'indirizzo dead `0x000000000000000000000000000000000000dEaD`.

#### Regole

| Regola | Dettaglio |
|---|---|
| Deposito | Una sola volta. Una seconda chiamata `depositLP()` fa revert. |
| Ritiro | Impossibile. Nessuna funzione di withdraw o rescue. |
| Burn pubblico | Chiunque può chiamare `burnLP()` in qualsiasi momento dopo il deposito. |
| Indirizzo dead | `0x000000000000000000000000000000000000dEaD` |

#### Funzioni

| Funzione | Accesso | Descrizione |
|---|---|---|
| `depositLP(address, uint256)` | Pubblica (1 volta) | Deposita e blocca i token LP |
| `burnLP()` | Pubblica (chiunque) | Invia tutti i LP all'indirizzo dead |
| `lpBalance()` | View | Saldo LP attuale nel contratto |
| `vaultStatus()` | View | Stato completo: deposited, burned, lp, amount, balance |

---

### 4. `BaldaAirdrop.sol` — Distribuzione Automatica

Distribuisce **70.000 BLD** in tre fasi sequenziali senza owner, senza chiavi admin e senza percorso di upgrade.

#### Struttura delle Fasi

| Fase | BLD base | Periodi | Durata totale | Vesting |
|---|---|---|---|---|
| Ciclo 1 | 50.000 BLD | 8 | 396 giorni | Sì — 180 giorni lineari |
| Ciclo 2 | 20.000 BLD + avanzi C1 | 5 | 165 giorni | No — immediato |
| Fase Finale | Solo avanzi C2-P5 | Illimitata (∞) | Senza scadenza | No — immediato |

Il Ciclo 2 inizia esattamente **11 anni Gregoriani** dopo il deploy (347.126.472 secondi).

#### Regole Universali

1. **1 wallet = 1 claim** (assoluto per tutta la vita del contratto). Una volta reclamato, quel wallet è escluso permanentemente indipendentemente dalla fase o dal periodo.
2. **Vesting 180 giorni** (solo per il Ciclo 1). La porzione maturata (inizio periodo → momento del claim) viene trasferita immediatamente; il resto è detenuto nel contratto e prelevabile in qualsiasi momento via `withdrawVesting()`. Nessun cliff.
3. **Avanzi (remainders)** — i token non distribuiti alla fine naturale di un periodo passano al periodo successivo come allocazione aggiuntiva.
4. **Dust Rule** (solo C2-P5 e Fase Finale) — se `mcapAvailable < premio`, l'ultimo wallet reclamante riceve **tutti i token rimanenti** e il contratto si chiude permanentemente. Nei periodi normali, la chiamata fa invece revert.
5. **Chiusura automatica** — emette `ContractClosed("Distribution complete. Thank you all.")` quando si attiva la Dust Rule o quando C2-P5 termina con zero avanzi.

#### Ciclo 1 — Periodi (somma allocazione base = 50.000 BLD)

| Periodo | Durata | Allocazione base (BLD) | Premio per wallet (BLD) | Max wallet |
|---|---|---|---|---|
| C1-P1 | 11 giorni | 10.101 | 111 | **91** |
| C1-P2 | 22 giorni | 1.424,964… | 55,5 | Illimitato |
| C1-P3 | 33 giorni | 2.849,928… | 27,75 | Illimitato |
| C1-P4 | 44 giorni | 4.274,892… | 13,875 | Illimitato |
| C1-P5 | 55 giorni | 5.699,857… | 6,9375 | Illimitato |
| C1-P6 | 66 giorni | 7.124,821… | 3,46875 | Illimitato |
| C1-P7 | 77 giorni | 8.549,785… | 1,734375 | Illimitato |
| C1-P8 | 88 giorni | 9.974,750… | 0,8671875 | Illimitato |

#### Ciclo 2 — Periodi (somma allocazione base = 20.000 BLD)

| Periodo | Durata | Allocazione base (BLD) | Premio per wallet (BLD) | Dust Rule |
|---|---|---|---|---|
| C2-P1 | 11 giorni | 1.333,333… | 0,43359375 | No |
| C2-P2 | 22 giorni | 2.666,666… | 0,216796875 | No |
| C2-P3 | 33 giorni | 4.000 | 0,108398437 | No |
| C2-P4 | 44 giorni | 5.333,333… | 0,054199218 | No |
| C2-P5 | 55 giorni | 6.666,666… | 0,027099609 | **Sì** |

#### Fase Finale

| Parametro | Valore |
|---|---|
| Allocazione base | Zero — solo gli avanzi di C2-P5 |
| Premio per wallet | 0,013549804 BLD (111 / 2¹³) |
| Durata | Illimitata (`type(uint256).max`) |
| Dust Rule | **Attiva** — l'ultimo wallet riceve tutti i token rimanenti |
| Vesting | Nessuno — pagamento immediato |

#### Serie Geometrica Premi (rapporto 1/2, base 111 BLD)

| Periodo | Formula | Premio (BLD) |
|---|---|---|
| C1-P1 | 111 / 2⁰ | 111 |
| C1-P2 | 111 / 2¹ | 55,5 |
| C1-P3 | 111 / 2² | 27,75 |
| C1-P4 | 111 / 2³ | 13,875 |
| C1-P5 | 111 / 2⁴ | 6,9375 |
| C1-P6 | 111 / 2⁵ | 3,46875 |
| C1-P7 | 111 / 2⁶ | 1,734375 |
| C1-P8 | 111 / 2⁷ | 0,8671875 |
| C2-P1 | 111 / 2⁸ | 0,43359375 |
| C2-P2 | 111 / 2⁹ | 0,216796875 |
| C2-P3 | 111 / 2¹⁰ | 0,108398437 |
| C2-P4 | 111 / 2¹¹ | 0,054199218 |
| C2-P5 | 111 / 2¹² | 0,027099609 |
| Finale | 111 / 2¹³ | 0,013549804 |

#### Funzioni Pubbliche

| Funzione | Chi può chiamare | Descrizione |
|---|---|---|
| `claim()` | Chiunque (1 volta per wallet) | Reclama il premio del periodo corrente |
| `withdrawVesting()` | Solo chi ha vesting attivo (C1) | Preleva la porzione maturata del vesting |
| `finalizePeriod()` | Chiunque | Avanza lo stato se il periodo corrente è scaduto |
| `startCycle2()` | Chiunque | Avvia manualmente il Ciclo 2 dopo gli 11 anni |
| `currentPeriodInfo()` | View | Tutti i dati del periodo corrente in una chiamata |
| `timeLeftInPeriod()` | View | Secondi rimanenti nel periodo corrente |
| `cycle2StartTime()` | View | Timestamp Unix esatto di inizio Ciclo 2 |
| `isWaitingForCycle2()` | View | True se C1 è finito e si attende il ritardo di 11 anni |
| `availableVesting(address)` | View | Quanto può prelevare un wallet in questo momento |

---

## Ordine di Deploy

| Step | Contratto | Argomenti costruttore |
|---|---|---|
| 1 | `BaldaReserve.sol` | Nessuno |
| 2 | `VaultCreator.sol` | `_token` (indirizzo BLD), `_founder`, `_passwordHash` |
| 3 | `BaldaAirdrop.sol` | `_token` (indirizzo BLD) |
| 4 | `Balda.sol` | `airdropContract`, `reserveContract`, `vaultContract` |
| 5 | `LiquidityVault.sol` | Nessuno (indipendente, usato dopo aver ricevuto i token LP) |

> ⚠️ `VaultCreator` e `BaldaAirdrop` ricevono l'indirizzo del token BLD al momento del loro deploy, ma i token arrivano realmente solo quando viene deployato `Balda.sol` allo step 4. Entrambi i contratti devono essere pronti prima del deploy del token.

---

## Riepilogo Sicurezza

| Proprietà | Balda | BaldaReserve | VaultCreator | LiquidityVault | BaldaAirdrop |
|---|---|---|---|---|---|
| Owner / admin | Nessuno | Nessuno | Nessuno | Nessuno | Nessuno |
| Upgrade / proxy | Nessuno | Nessuno | Nessuno | Nessuno | Nessuno |
| Funzione rescue | Nessuna | Nessuna | Nessuna | Nessuna | Nessuna |
| SafeERC20 | — | — | ✔ | ✔ | ✔ |
| Immutabile dopo deploy | ✔ | ✔ | ✔ | ✔ | ✔ |
| OpenZeppelin | ERC20 | — | SafeERC20, IERC20 | SafeERC20, IERC20 | SafeERC20, IERC20 |

Tutti e cinque i contratti sono completamente autonomi dopo il deploy. Nessun indirizzo detiene alcun potere amministrativo. Il sistema opera deterministicamente secondo la sola logica on-chain.

---

## Riferimento Temporale

| Durata | Secondi |
|---|---|
| 1 giorno | 86.400 |
| 180 giorni (vesting C1) | 15.552.000 |
| 11 anni (Gregoriani) | 347.126.472 |
| 22 anni | 694.252.944 |
| 33 anni | 1.041.379.416 |

*1 anno Gregoriano = 365,2425 × 86.400 = 31.556.952 secondi*

---

## Licenza

MIT — vedi file `LICENSE`.

---

*Concept & Decisione di Deaf Italian. Sviluppato con l'aiuto dell'AI.*
