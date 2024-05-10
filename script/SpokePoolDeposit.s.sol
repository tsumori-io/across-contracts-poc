// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TsumoriBridgeV1} from "../src/TsumoriBridgeV1.sol";

interface AcrossV3SpokePool {
  function depositV3(
    address depositor,
    address recipient,
    address inputToken,
    address outputToken,
    uint256 inputAmount,
    uint256 outputAmount,
    uint256 destinationChainId,
    address exclusiveRelayer,
    uint32 quoteTimestamp,
    uint32 fillDeadline,
    uint32 exclusivityDeadline,
    bytes calldata message
  ) external payable;
}

contract TsumoriBridgeV1Script is Script {
  function setUp() public {}

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address admin = vm.envAddress("BRIDGE_ADMIN");

    AcrossV3SpokePool acrossSpokePool = AcrossV3SpokePool(payable(vm.envAddress("ACROSS_SPOKE_POOL")));

    vm.startBroadcast(deployerPrivateKey);

    bridgeToBaseContractFromArbitrum(admin);

    vm.stopBroadcast();
  }

  function bridgeToBaseContractFromArbitrum(address admin) public {
    AcrossV3SpokePool acrossSpokePool = AcrossV3SpokePool(payable(0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A));
    
    // USDC.e address on arbitrum
    address usdcAddress = address(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

    // contract address on base
    // 0xC959Cd0B0eEF8091449622460DD2925d956735a5 // UUPS
    address contractAddr = address(0x131524511C2A53A0FB9f2352CA716e87643Cae4A);

    uint256 deadline = block.timestamp + 120;
    uint256 destinationChainId = 8453;
    uint256 amount = 4000000;
    uint256 totalRelayFee = 125529; // fee from the suggested-fees API
    bytes memory message = abi.encode(admin);
    acrossSpokePool.depositV3(
      admin, // User's address on the origin chain.
      contractAddr, // recipient. Whatever address the user wants to recieve the funds on the destination.
      usdcAddress, // inputToken. This is the usdc address on the originChain
      address(0), // outputToken: 0 address means the output token and input token are the same. Today, no relayers support swapping so the relay will not be filled if this is set to anything other than 0x0.
      amount, // inputAmount
      amount - totalRelayFee, // outputAmount: this is the amount - relay fees. totalRelayFee is the value returned by the suggested-fees API.
      destinationChainId, // destinationChainId
      address(0), // exclusiveRelayer: set to 0x0 for typical integrations.
      uint32(block.timestamp), // timestamp: this should be the timestamp returned by the API. Otherwise, set to block.timestamp.
      uint32(block.timestamp + 240), // fillDeadline: We reccomend a fill deadline of 6 hours out. The contract will reject this if it is beyond 8 hours from now.
      0, // exclusivityDeadline: since there's no exclusive relayer, set this to 0.
      message // message: empty message since this is just a simple transfer.
    );
  }

  function bridgeToBaseContractFromArbitrumWithSignature(address admin) public {
    AcrossV3SpokePool acrossSpokePool = AcrossV3SpokePool(payable(0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A));
    
    // USDC.e address on arbitrum
    address usdcAddress = address(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

    // contract address on base
    address contractAddr = address(0x131524511C2A53A0FB9f2352CA716e87643Cae4A);

    uint256 deadline = block.timestamp + 120;
    uint256 destinationChainId = 8453;
    uint256 amount = 4000000;

    uint256 totalRelayFee = 125529; // fee from the suggested-fees API

    bytes memory message = abi.encode(admin);

    acrossSpokePool.depositV3(
      admin, // User's address on the origin chain.
      contractAddr, // recipient. Whatever address the user wants to recieve the funds on the destination.
      usdcAddress, // inputToken. This is the usdc address on the originChain
      address(0), // outputToken: 0 address means the output token and input token are the same. Today, no relayers support swapping so the relay will not be filled if this is set to anything other than 0x0.
      amount, // inputAmount
      amount - totalRelayFee, // outputAmount: this is the amount - relay fees. totalRelayFee is the value returned by the suggested-fees API.
      destinationChainId, // destinationChainId
      address(0), // exclusiveRelayer: set to 0x0 for typical integrations.
      uint32(block.timestamp), // timestamp: this should be the timestamp returned by the API. Otherwise, set to block.timestamp.
      uint32(block.timestamp + 240), // fillDeadline: We reccomend a fill deadline of 6 hours out. The contract will reject this if it is beyond 8 hours from now.
      0, // exclusivityDeadline: since there's no exclusive relayer, set this to 0.
      message // message: empty message since this is just a simple transfer.
    );
  }
}
