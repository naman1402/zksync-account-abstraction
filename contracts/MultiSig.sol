// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IAccount.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/TransactionHelper.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";

// Used for signature validation
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// non-view methods of system contracts
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/SystemContractsCaller.sol";

error MultiSig__OnlyBootLoaderCanCall();
error MultiSig__ExecutionFailed();
error MultiSig__TransactionFailed();

contract MultiSig is IAccount, IERC1271{

    using TransactionHelper for Transaction;

    // account owners
    address public owner1;
    address public owner2;
    bytes4 constant EIP1271_SUCCESS_RETURN_VALUE = 0x1626ba7e;

    constructor(address _owner1, address _owner2) {
        owner1  = _owner1;
        owner2 = _owner2;
    }

    modifier onlyBootLoader() {
        if(msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert MultiSig__OnlyBootLoaderCanCall();
        }
        // continue execution if called from bootloader
        _;
    }

    function validateTransaction(
        bytes32 /*_txHash*/,
        bytes32 _suggestedSignedHash,
        Transaction calldata _transaction
    ) external payable override onlyBootLoader returns (bytes4 magic) {
        magic = _validateTransaction(_suggestedSignedHash, _transaction);
    }

    /// Using system contract to call nonce holder contract to increment the nonce value
    /// if suggestedHash is not provided(btyes32(0)), then generate it using Transaction functions
    /// Check if account contract has enough balance compared to requiredBalance()
    /// Calling EIP1271 function to check if the signature is valid or not
    function _validateTransaction( bytes32 _suggestedSignedHash, Transaction calldata _transaction) internal returns (bytes4 magic) {
        SystemContractsCaller.systemCallWithPropagatedRevert(uint32(gasleft()), address(NONCE_HOLDER_SYSTEM_CONTRACT), 0, abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce)));
        bytes32 txHash;

        if(_suggestedSignedHash == bytes32(0)) {
            txHash  = TransactionHelper.encodeHash(_transaction);
        } else {
            txHash = _suggestedSignedHash;
        }

        uint256 totalRequiredBalance = TransactionHelper.totalRequiredBalance(_transaction);
        require(totalRequiredBalance <= address(this).balance);
        if(isValidSignature(txHash, _transaction.signature) == EIP1271_SUCCESS_RETURN_VALUE) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        }

    }

    function executeTransaction(
        bytes32 /*_txHash*/,
        bytes32 /*_suggestedSignedHash*/,
        Transaction calldata _transaction
    ) external payable override onlyBootLoader{
        _executeTransaction(_transaction);
    }

    function _executeTransaction(Transaction calldata _transaction) internal {
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;

        if(to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            SystemContractsCaller.systemCallWithPropagatedRevert(Utils.safeCastToU32(gasleft()), to, value, data);
        } else {
            bool success;
            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }
            if(!success) {
                revert MultiSig__ExecutionFailed();
            }
        }
    }

    // To execute from outside, first we need to validate and then execute
    function executeTransactionFromOutside(Transaction calldata _transaction) external payable {
        _validateTransaction(bytes32(0), _transaction);
        _executeTransaction(_transaction);
    }

    // Pays required fees to the bootloader
    // Bootloader allows for processing not just one transaction at a time but an entire batch of transactions as a single large operation
    function payForTransaction(
        bytes32 /*_txHash*/,
        bytes32 /*_suggestedSignedHash*/,
        Transaction calldata _transaction
    ) external payable override onlyBootLoader() {
        bool success = TransactionHelper.payToTheBootloader(_transaction);
        if(!success) {
            revert MultiSig__TransactionFailed();
        }
    }

    // Paymaster sponsors gas fees for the transaction
    function prepareForPaymaster(
        bytes32 /*_txHash*/,
        bytes32 /*_possibleSignedHash*/,
        Transaction calldata _transaction
    ) external payable {
        TransactionHelper.processPaymasterInput(_transaction);
    }

    // Overrider from EIP1271, 
    function isValidSignature(bytes32 hash, bytes memory signature) public view override returns (bytes4 magicValue) {
        magicValue = EIP1271_SUCCESS_RETURN_VALUE;
        if(signature.length != 130) {
            signature = new bytes(130);
            signature[64] = bytes1(uint8(27));
            signature[129] = bytes1(uint8(27));

        }

        (bytes memory signature1, bytes memory signature2) = extractSignature(signature);
        if(!checkValidECDSASignture(signature1) || !checkValidECDSASignture(signature2)) {
            magicValue = bytes4(0);
        }

        address recoveredAddr1 = ECDSA.recover(hash, signature1);
        address recoveredAddr2 = ECDSA.recover(hash, signature2);
        if(recoveredAddr1 != owner1 || recoveredAddr2 != owner2) {
            magicValue = bytes4( 0);
        }
    }

    function checkValidECDSASignture(bytes memory _signature) internal pure returns (bool) {
        if(_signature.length != 65) {
            return false;
        }

        uint8 v;
        bytes32 r;
        bytes32 s;

        assembly {
            r := mload(add(_signature, 0x20))
            s := mload(add(_signature, 0x40))
            v := and(mload(add(_signature, 0x41)), 0xff)
        }

        if(v != 27 && v != 28) {
            return false;
        }


        if(uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return false;
        }
        return true;
    }

    function extractSignature(bytes memory _fullSignature) internal pure returns (bytes memory signature1, bytes memory signature2) {
        require(_fullSignature.length == 130);
        signature1 = new bytes(65);
        signature2 = new bytes(65);


        assembly {
            let r := mload(add(_fullSignature, 0x20))
            let s := mload(add(_fullSignature, 0x40))
            let v := and(mload(add(_fullSignature, 0x41)), 0xff)

            mstore(add(signature1, 0x20), r)
            mstore(add(signature1, 0x40), s)
            mstore8(add(signature1, 0x60), v)
        }

        assembly {
            let r := mload(add(_fullSignature, 0x61))
            let s := mload(add(_fullSignature, 0x81))
            let v := and(mload(add(_fullSignature, 0x82)), 0xff)

            mstore(add(signature2, 0x20), r)
            mstore(add(signature2, 0x40), s)
            mstore8(add(signature2, 0x60), v)
        }
    }

    fallback() external {
        assert(msg.sender != BOOTLOADER_FORMAL_ADDRESS);
    }

    receive() external payable {}

}