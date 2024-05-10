// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TsumoriBridgeV1} from "../src/TsumoriBridgeV1.sol";
import {TsumoriBridgeV3} from "../src/TsumoriBridgeV3.sol";

contract TsumoriBridgeV1Script is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("BRIDGE_ADMIN");

        address permit2 = vm.envAddress("PERMIT2");
        address acrossSpokePool = vm.envAddress("ACROSS_SPOKE_POOL");

        vm.startBroadcast(deployerPrivateKey);

        deployContractToArbitrum(admin);
        // deployUUPSContractToArbitrum(admin);

        // deployContractToBase(admin);
        // deployUUPSContractToBase(admin);

        vm.stopBroadcast();
    }

    function deployContractToArbitrum(address admin) public {
        address permit2 = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        address acrossSpokePool = address(0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A);
        _deployContract(permit2, admin, admin, acrossSpokePool);
    }

    function deployUUPSContractToArbitrum(address admin) public {
        address permit2 = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        address acrossSpokePool = address(0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A);
        _deployUUPSContract(permit2, admin, admin, acrossSpokePool);
    }

    function deployContractToBase(address admin) public {
        address permit2 = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        address acrossSpokePool = address(0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64);
        _deployContract(permit2, admin, admin, acrossSpokePool);
    }

    function deployUUPSContractToBase(address admin) public {
        address permit2 = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        address acrossSpokePool = address(0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64);
        _deployUUPSContract(permit2, admin, admin, acrossSpokePool);
    }

    function _deployContract(address _permit2, address admin, address signer, address acrossSpokePool) internal {
        TsumoriBridgeV1 tsumoriBridgeV1 = new TsumoriBridgeV1(_permit2, admin, acrossSpokePool);
    }

    function _deployUUPSContract(address _permit2, address admin, address signer, address acrossSpokePool) internal {
        TsumoriBridgeV3 tsumoriBridgeV3Impl = new TsumoriBridgeV3(_permit2);
        new ERC1967Proxy(address(tsumoriBridgeV3Impl), abi.encodeWithSignature("initialize(address,address,address)", admin, signer, acrossSpokePool));
    }
}
