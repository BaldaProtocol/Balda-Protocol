# Balda Protocol (BLD) — Listing Information

## Token Details

| Field | Value |
|---|---|
| Name | Balda Protocol |
| Symbol | BLD |
| Type | ERC-20 |
| Decimals | 18 |
| Total Supply | 91,000 BLD |
| Circulating Supply | ~80,000 BLD |
| Contract | `0x626f28ba49951F95F8ec4991F6b6d6AcEFd26739` |
| Network | Ethereum Mainnet |
| Chain ID | 1 |
| Deploy Date | April 11, 2026 |

## Links

| Resource | URL |
|---|---|
| Website | https://baldaprotocol.github.io/Balda-Protocol/ |
| GitHub | https://github.com/BaldaProtocol/Balda-Protocol |
| Etherscan | https://etherscan.io/token/0x626f28ba49951F95F8ec4991F6b6d6AcEFd26739 |
| Uniswap V2 | https://app.uniswap.org/swap?outputCurrency=0x626f28ba49951F95F8ec4991F6b6d6AcEFd26739 |
| GeckoTerminal | https://www.geckoterminal.com/eth/pools/0x884300e185d2830ff15a2fcf4be91859e98264f0 |
| Pool BLD/ETH | `0x884300e185d2830fF15a2FCF4BE91859E98264f0` |
| Bitcointalk | https://bitcointalk.org/index.php?topic=5580328.0 |

## Logo Assets

| Format | Size | URL |
|---|---|---|
| SVG | Vector | https://raw.githubusercontent.com/BaldaProtocol/Balda-Protocol/main/assets/logo.svg |
| PNG | 200x200 | https://raw.githubusercontent.com/BaldaProtocol/Balda-Protocol/main/assets/logo_200x200.png |
| PNG | 256x256 | https://raw.githubusercontent.com/BaldaProtocol/Balda-Protocol/main/assets/logo_256x256.png |
| PNG | 512x512 | https://raw.githubusercontent.com/BaldaProtocol/Balda-Protocol/main/assets/logo_512x512.png |

## Description

Balda Protocol (BLD) is a fully autonomous ERC-20 token deployed on Ethereum Mainnet. Fixed supply of 91,000 BLD — ownerless, immutable, no admin keys. Liquidity permanently locked via LP burn on Uniswap V2. Features a built-in airdrop system with vesting cycles distributed across 91 wallets.

## Tokenomics

| Allocation | BLD | % | Details |
|---|---|---|---|
| Airdrop | 70,000 | 76.92% | Distributed autonomously via BaldaAirdrop smart contract over multiple cycles |
| Founder Linear Vesting | 5,000 | 5.49% | Continuous per-second stream over 11 Gregorian years from deploy |
| Founder Tranches | 5,000 | 5.49% | 2,500 BLD at 11 years · 1,250 BLD at 22 years · 1,250 BLD at 33 years |
| Reserve | 6,000 | 6.59% | Permanently locked in BaldaReserve — empty contract, no functions |
| Liquidity | 5,000 | 5.49% | Added to Uniswap V2 BLD/ETH pool — LP tokens burned permanently |

## Circulating Supply Methodology

Circulating supply excludes tokens that are permanently inaccessible or time-locked:

| Contract | Address | BLD | Reason Excluded |
|---|---|---|---|
| BaldaReserve | `0xF89337b7562B2afeA5A46F7fc9CBdeEc8B8d92DD` | 6,000 | Empty contract — no functions, tokens inaccessible forever |
| VaultCreator (tranches) | `0x315C7Db81194805840220CAfA7fcd31B24f8C8Dd` | 5,000 | Time-locked: Tranche 1 at 11 years, Tranche 2 at 22 years, Tranche 3 at 33 years |

**Circulating Supply: ~80,000 BLD**

## All Contract Addresses

| Contract | Address |
|---|---|
| Balda (BLD) | `0x626f28ba49951F95F8ec4991F6b6d6AcEFd26739` |
| BaldaAirdrop | `0x61c35A27831AE981695442Ab42B88dEB0FcF17E7` |
| BaldaReserve | `0xF89337b7562B2afeA5A46F7fc9CBdeEc8B8d92DD` |
| VaultCreator | `0x315C7Db81194805840220CAfA7fcd31B24f8C8Dd` |
| LiquidityVault | `0xAcAA96DFEB2332781f2729fc89A204d10bD62A04` |
| Pool BLD/ETH | `0x884300e185d2830fF15a2FCF4BE91859E98264f0` |

## Security

| Property | Status |
|---|---|
| Fixed supply, no minting | ✅ |
| No owner / admin keys | ✅ |
| No upgrade / proxy | ✅ |
| No pause / blacklist | ✅ |
| No transfer tax | ✅ |
| Liquidity locked forever via LP burn | ✅ |
| Deployer key permanently destroyed | ✅ |
| All 5 contracts verified on Etherscan | ✅ |
| OpenZeppelin SafeERC20 used throughout | ✅ |
