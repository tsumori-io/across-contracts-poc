## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
forge build
```

### Test

```shell
forge test
```

### Format

```shell
forge fmt
```

### Gas Snapshots

```shell
forge snapshot
```

### Anvil

```shell
anvil
```

### Deploy

```shell
forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
cast <subcommand>
```

### Help

```shell
forge --help
anvil --help
cast --help
```

---

## Local forked deployment

```sh
anvil --fork-url wss://arbitrum-one-rpc.publicnode.com
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/TsumoriBridge.s.sol --rpc-url http://localhost:8545 --broadcast -v
```

## Arbitrum deployment

```sh
# NOTE: ensure correct PRIVATE_KEY is set in .env file
forge script script/TsumoriBridge.s.sol --rpc-url wss://arbitrum-one-rpc.publicnode.com --broadcast -v
```

## Base deployment

```sh
# NOTE: ensure correct PRIVATE_KEY is set in .env file
forge script script/TsumoriBridge.s.sol --rpc-url https://mainnet.base.org --broadcast -v
```

### Bridging Examples

#### Transfer USDC.e to Base (Contract recipient)

Get quote (fee) and timestamp:

```sh
curl "https://app.across.to/api/suggested-fees?token=0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8&originChainId=42161&destinationChainId=8453&amount=4000000&recipient=0x131524511C2A53A0FB9f2352CA716e87643Cae4A&message=0x000000000000000000000000000007357111e4789005d4ebff401a18d99770ce" | jq .totalRelayFee.total
```

```sh
# Approve SPOKE_POOL contract to accept funds
SPOKE_POOL_ADDRESS=0xe35e9842fceaca96570b734083f4a58e8f7c5f2a
USDCE_ADDRESS=0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8
cast send $USDCE_ADDRESS "approve(address,uint256)" $SPOKE_POOL_ADDRESS 50000000 --rpc-url https://arbitrum-one-rpc.publicnode.com --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

```sh
# NOTE: replace `totalRelayFee` from API response
forge script script/SpokePoolDeposit.s.sol --rpc-url https://arb1.arbitrum.io/rpc --broadcast -v
```

#### Deposit Tx hash

`https://arbiscan.io/tx/0xd947e64018cd10d640351fb26edfdf0afb70e9290d22d5430ac6f3e00fc5f561`

#### Recieval Tx hash

`https://basescan.org/tx/0x81c42aea9dfd3f066df4e959541da43948f5cf547a622024c77772c3569a2e7b`

```sh
cast call 0xd9aaec86b65d86f6a7b5b1b0c42ffa531710b6ca "balanceOf(address)(uint256)" 0x000007357111E4789005d4eBfF401a18D99770cE --rpc-url https://mainnet.base.org
```

---

#### Transfer USDC.e to Base (EOA recipient)

```sh
curl "https://app.across.to/api/suggested-fees?token=0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8&originChainId=42161&destinationChainId=8453&amount=5000000" | jq .totalRelayFee.total,.timestamp 
```

```sh
SPOKE_POOL_ADDRESS=0xe35e9842fceaca96570b734083f4a58e8f7c5f2a
USDCE_ADDRESS=0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8
DESTINATION_CHAIN_ID=8453

# Deposit
cast send \
  $SPOKE_POOL_ADDRESS \
  "depositV3(address,address,address,address,uint256,uint256,uint256,address,uint32,uint32,uint32,bytes)" \
  0x000007357111E4789005d4eBfF401a18D99770cE \
  0x000007357111E4789005d4eBfF401a18D99770cE \
  $USDCE_ADDRESS \
  0x0000000000000000000000000000000000000000 \
  5000000 \
  $((5000000 - 78346)) \
  $DESTINATION_CHAIN_ID \
  0x0000000000000000000000000000000000000000 \
  1715336927 \
  $((1715336927 + 240)) \
  0 \
  0x \
  --rpc-url https://arbitrum-one-rpc.publicnode.com \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

#### Deposit Tx hash

`https://arbiscan.io/tx/0x64dece5c3dda944d632f29bdec39ec00694c400bd9a661c8004ec2aeec0081b9`

#### Recieval Tx hash

`https://basescan.org/tx/0x5f1366d8d77af9739f2100c821105233c1232e7c0f0a868621d817134caabc43`

```sh
cast call 0xd9aaec86b65d86f6a7b5b1b0c42ffa531710b6ca "balanceOf(address)(uint256)" 0x000007357111E4789005d4eBfF401a18D99770cE --rpc-url https://mainnet.base.org
```

---

### Quick checks

```sh
cast call 0xC959Cd0B0eEF8091449622460DD2925d956735a5 "signer()" --rpc-url https://mainnet.base.org
```

---

## TODOs

- [ ] Account for refunds if tokens not transferred
  - This could be offchain; i.e. admin account cals contract to send funds to recipient
- [ ] Try to get the same tsumori bridge address on all chains

---
