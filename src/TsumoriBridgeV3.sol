// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {ISignatureTransfer} from "permit2/src/interfaces/ISignatureTransfer.sol";
// import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
// import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Across SpokePool Interface
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

// Across SpokePool Receiver Interface
interface AcrossV3Receiver {
  function handleV3AcrossMessage(
    address tokenSent,
    uint256 amount,
    address relayer,
    bytes calldata message
  ) external;
}

// Sample cross-chain order
struct CrossChainOrder {
  address rfqContract;
  address swapper;
  address relayer;
  address recipient;
  address inputToken;
  address outputToken;
  uint256 inputAmount;
  uint256 relayerBondAmount;
  uint256 outputAmount;
  uint256 destinationChainId;
  uint256 nonce;
  uint256 deadline;
}

// A typestring is required for Permit2 to be able to process the order as witness data.
string constant ORDER_WITNESS_TYPESTRING = "CrossChainOrder witness)CrossChainOrder(address rfqContract,address swapper,address relayer,address recipient,address inputToken,address outputToken,uint256 inputAmount,uint256 relayerBondAmount,uint256 outputAmount,uint256 destinationChainId,uint256 nonce,uint256 deadline)";

/**
 * @title Tsumori bridging contract to integrate with other bridges.
 * @author Tsumori Inc.
 */
contract TsumoriBridgeV3 is AcrossV3Receiver, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {

  /*//////////////////////////////////////////////////////////////
                              CONSTANT
  //////////////////////////////////////////////////////////////*/

  IPermit2 public immutable permit2;

  /*//////////////////////////////////////////////////////////////
                              STORAGE
  //////////////////////////////////////////////////////////////*/

  AcrossV3SpokePool public acrossSpokePool;

  /// @notice The deadline for filling relayer orders (seconds)
  uint256 public fillDeadline;

  /// @notice The address of the signer for the order
  address public signer;

  /// @notice Nonce for signatures to prevent replay attacks
  mapping(address => mapping(uint256 => bool)) public nonceUsed;

  /*//////////////////////////////////////////////////////////////
                              MODIFIERS
  //////////////////////////////////////////////////////////////*/

  modifier onlyAcrossSpokePool() {
    // Verify that this call came from the Across SpokePool.
    if (msg.sender != address(acrossSpokePool)) revert Unauthorized();
    _;
  }

  /*//////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /*//////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  event FillDeadlineUpdated(uint256 indexed fillDeadline);

  event AdminWithdrawal(address indexed token, address indexed to, uint256 indexed amount);

  /*//////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  error Unauthorized();
  error InvalidSignature();
  error NonceUsed();

  /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  // TODO: Only initialize immutable vars in constructor
  constructor(address _permit2) {
    permit2 = IPermit2(_permit2);
  }

  function initialize(address _owner, address _signer, address _acrossSpokePool) public initializer {
    __Pausable_init();
    __Ownable_init(_owner);

    signer = _signer;
    acrossSpokePool = AcrossV3SpokePool(_acrossSpokePool);
    fillDeadline = 3600; // 1 hour
  }

  /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  // function verify(
  //   bytes memory data,
  //   bytes memory sig
  // ) public view returns (bool) {
  //   bytes32 messageHash = keccak256(abi.encode(data));
  //   bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
  //   address _signer = ECDSA.recover(ethSignedMessageHash, sig);
  //   return signer != _signer;
  // }

  function verify(
    bytes memory data,
    bytes memory sig
  ) public view returns (bool) {
    bytes32 messageHash = keccak256(data);
    bytes32 ethSignedMessageHash = keccak256(abi.encodePacked('\x19Ethereum Signed Message:\n32', messageHash));
    require(sig.length == 65, "TsumoriBridge: invalid signature length");
    bytes32 r;
    bytes32 s;
    uint8 v;
    assembly {
      // first 32 bytes, after the length prefix
      r := mload(add(sig, 32))
      // second 32 bytes
      s := mload(add(sig, 64))
      // final byte (first byte of the next 32 bytes)
      v := byte(0, mload(add(sig, 96)))
    }
    address _signer = ecrecover(ethSignedMessageHash, v, r, s);
    return signer == _signer;
  }

  /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  // The initiate function:
  // 1. Takes in an order and swapper signature.
  // 2. Verifies the signature and order validity.
  // 3. Passes along the tokens and instructions to the Across SpokePool
  //    where the order will be filled, that fill verified, and then settled.
  // TODO: Check whether we cna make this payable so that eth can be accepted
  function initiate(CrossChainOrder memory order, bytes calldata signature) external {
    // Support Permit2 if signature is provided.
    if (signature.length > 0) {
      // This code is the basic process for validating and pulling in tokens
      // for a Permit2-based order.
      // It's somewhat involved, but it does most of the work in validating the
      // order and signature.
      permit2.permitWitnessTransferFrom(
        // PermitTransferFrom struct init
        ISignatureTransfer.PermitTransferFrom({
          permitted: ISignatureTransfer.TokenPermissions({
            token: order.inputToken,
            amount: order.inputAmount
          }),
          nonce: order.nonce,
          deadline: order.deadline
        }),
        // SignatureTransferDetails struct init
        ISignatureTransfer.SignatureTransferDetails({
          to: address(this),
          requestedAmount: order.inputAmount
        }),
        order.swapper,
        keccak256(abi.encode(order)),
        ORDER_WITNESS_TYPESTRING,
        signature
      );
    }

    // Pull in the bond from the msg.sender.
    SafeERC20.safeTransferFrom(IERC20(order.inputToken), msg.sender, address(this), order.relayerBondAmount);

    // Full input amount for Across's purposes both the user amount
    // and the bond amount.
    // In the case that the relay is filled correctly, the relayer
    // gets the full input amount (including the bond).
    // In the case that the depositor is refunded, they receive the bond
    // as compensation for the relayer's failure to fill.
    uint256 amount = order.inputAmount + order.relayerBondAmount;

    // Now that all the tokens are in this contract, Across contract needs
    // to be approved to pull the tokens from here.
    SafeERC20.safeIncreaseAllowance(IERC20(order.inputToken), address(acrossSpokePool), amount);

    // Fill deadline is arbitrarily set to 1 hour after initiation.
    uint256 deadline = block.timestamp + fillDeadline;

    // Call deposit to pass the order off to Across Settlement.
    acrossSpokePool.depositV3(
      order.swapper,
      order.recipient,
      order.inputToken,
      order.outputToken,
      order.inputAmount,
      order.outputAmount,
      order.destinationChainId,
      order.relayer,
      uint32(block.timestamp),
      uint32(deadline), // 1 hour deadline
      uint32(deadline), // Exclusivity for the entire fill period
      "" // No message
    );
  }

  /*//////////////////////////////////////////////////////////////
                            RESTRICTED FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @notice Handles the cross-chain message from the Across SpokePool.
  // TODO: message should contain signature from the user
  function handleV3AcrossMessage(
    address tokenSent,
    uint256 amount,
    address relayer, // relayer is unused
    bytes memory message
  ) external onlyAcrossSpokePool {
    // decode outer message
    (bytes memory innerMsg, bytes memory signature) = abi.decode(message, (bytes, bytes));
    if (!verify(innerMsg, signature)) revert InvalidSignature();

    // decode inner message
    (address recipient, uint256 nonce) = abi.decode(innerMsg, (address, uint256));

    // Check that the nonce has not been used before
    if (nonceUsed[recipient][nonce]) revert NonceUsed();
    nonceUsed[recipient][nonce] = true;

    // Transfer the tokens to the recipient.
    SafeERC20.safeTransfer(IERC20(tokenSent), recipient, amount);

    // TODO: emit relevant TsumoriBridge event
  }

  /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  function setFillDeadline(uint256 _fillDeadline) external onlyOwner {
    fillDeadline = _fillDeadline;
    emit FillDeadlineUpdated(_fillDeadline);
  }

  function adminWithdraw(address _token, address _to, uint256 _amount) external onlyOwner {
    // If the token is address(0), then it's ETH.
    if (_token == address(0)) {
      payable(_to).transfer(_amount);
      emit AdminWithdrawal(_token, _to, _amount);
      return;
    }

    IERC20(_token).transfer(_to, _amount);
    emit AdminWithdrawal(_token, _to, _amount);
  }

  /// @notice Allows the owner to upgrade the contract to a new implementation using UUPS proxy pattern.
  /// @dev This function is called by `upgradeTo` and `upgradeToAndCall` in the UUPS proxy.
  function _authorizeUpgrade(address) internal override onlyOwner {}

  /*//////////////////////////////////////////////////////////////
                                MISC
  //////////////////////////////////////////////////////////////*/

  /// @dev Storage gap for upgradeability.
  uint256[48] private __GAP;

  /// @dev Receive ETH from the WETH contract.
  receive() external payable {}
}
