// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {TsumoriBridgeV3} from "../src/TsumoriBridgeV3.sol";

contract TsumoriBridgeV1Test is Test {
    uint256 public constant PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    TsumoriBridgeV3 public tsumoriBridgeV3;
    address public admin = vm.addr(PRIVATE_KEY);

    function setUp() public {
        address permit2 = address(2);
        address acrossSpokePool = address(3);
        TsumoriBridgeV3 tsumoriBridgeV3Impl = new TsumoriBridgeV3(permit2);
        tsumoriBridgeV3 = TsumoriBridgeV3(payable(address(
            new ERC1967Proxy(address(tsumoriBridgeV3Impl), abi.encodeWithSignature("initialize(address,address,address)", admin, admin, acrossSpokePool))
        )));
    }

    // function test_DefaultAddresses() public {
    //     assertEq(tsumoriBridgeV1.owner(), address(1));
    //     assertEq(address(tsumoriBridgeV1.permit2()), address(2));
    //     assertEq(address(tsumoriBridgeV1.acrossSpokePool()), address(3));
    // }

    function test_recover() public {
        // construct ethereum signed message with the following data
        address user = address(0x000007357111E4789005d4eBfF401a18D99770cE);
        bytes memory data = abi.encode(user);

        bytes32 messageHash = keccak256(data);
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        // sign message & construct signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        console.logBytes(data);
        console.logBytes(signature);
        console.logBytes(abi.encode(data, signature));

        assertTrue(tsumoriBridgeV3.verify(data, signature));
    }

    // TODO: a test for upgrading and adding an additional function, validate old storage slot works, and new storage slot works too
    // function testFuzz_SetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}
