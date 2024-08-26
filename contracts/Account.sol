// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IAccount.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/TransactionHelper.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/SystemContractsCaller.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

error Account__NotEnoughBalance();
error Account__FailedToPayTheOperator();
error Account__OnlyBootLoaderCanCall();


contract Account is IAccount, IERC1271{

    address public owner;
    bytes4 constant EIP1271_SUCCESS_RETURN_VALUE = 0x1626ba7e;

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyBootLoader() {
        if(msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert Account__OnlyBootLoaderCanCall();
        }
        _;
    }


    function validateTransaction(
        bytes32 /*_txHash*/,
        bytes32 _suggestedSignedHash,
        Transaction calldata _transaction
    ) external payable override onlyBootLoader returns (bytes4 magic) {
        return _validateTransaction(_suggestedSignedHash, _transaction);
    }

    function _validateTransaction(bytes32 _suggestedSignedHash, Transaction calldata _transaction) internal returns (bytes4 magic) {
        /// @notice making system calls to increment the nonce of the account
        SystemContractsCaller.systemCallWithPropagatedRevert(uint32(gasleft()), address(NONCE_HOLDER_SYSTEM_CONTRACT), 0, abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce)));
        bytes32 txhash;
        if (_suggestedSignedHash == bytes32(0)) {
            txhash = TransactionHelper.encodeHash(_transaction);
        } else {
            txhash = _suggestedSignedHash;
        }


        // this account contract must have enough balance to complete the transaction

        uint256 totalRequiredBalance = TransactionHelper.totalRequiredBalance(_transaction);
        if(totalRequiredBalance <= address(this).balance) {
            revert Account__NotEnoughBalance();
        }

        if(isValidSignature(txhash, _transaction.signature) == EIP1271_SUCCESS_RETURN_VALUE) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }
    }

    function executeTransaction(
        bytes32 /*_txHash*/,
        bytes32 /*_suggestedSignedHash*/,
        Transaction calldata _transaction
    ) external payable onlyBootLoader {
        _executeTransaction(_transaction);
    }

    function _executeTransaction(Transaction calldata _transaction) internal {

        // retreiving data
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;
        // call spendlimit contract to ensure that ETH `value` doesn't exceed the daily spending limit
        if(value > 0) {
            // check limit
        }

        // If receiver is SYSTEM CONTRACT, then we will make system call using SystemContractsCaller
        // For general call, we will use assembly for transaction and check success
        if(to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            SystemContractsCaller.systemCallWithPropagatedRevert(Utils.safeCastToU32(gasleft()), to, value, data);
        } else {
            bool success;
            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }
            require(success);
        }
    } 

    function executeTransactionFromOutside(Transaction calldata _transaction) external payable {
        _validateTransaction(bytes32(0), _transaction);
        _executeTransaction(_transaction);
    }

    function payForTransaction(
        bytes32 /*_txHash*/,
        bytes32 /*_suggestedSignedHash*/,
        Transaction calldata _transaction
    ) external payable {
        bool success = TransactionHelper.payToTheBootloader(_transaction);
        if (!success) {
            revert Account__FailedToPayTheOperator();
        }
    }

    function prepareForPaymaster(
        bytes32 /*_txHash*/,
        bytes32 /*_possibleSignedHash*/,
        Transaction calldata _transaction
    ) external payable {
        TransactionHelper.processPaymasterInput(_transaction);
    }

    function isValidSignature(bytes32 _hash, bytes memory _signature) public view override returns (bytes4 magic) {

        magic = EIP1271_SUCCESS_RETURN_VALUE;

        // Signature is invalid
        if(_signature.length != 65) {
            _signature = new bytes(65);
            _signature[64] = bytes1(uint8(27));
        }

        // Extracting values from the signature
        uint8 v;
        bytes32 r;
        bytes32 s;
        assembly {
            r := mload(add(_signature, 0x20))
            s := mload(add(_signature, 0x40))
            v := and(mload(add(_signature, 0x41)), 0xff)
        }

        // Invalid signature
        if(v != 27 && v != 28) {
            magic = bytes4(0);
        }


        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            magic = bytes4(0);
        }

        // Retreiving recovered address using ecrecover function from hash and signature values, 
        // If recovered address is not the contract owner or is address(0), then magic is set to 0 and signature is not valid
        address recovered = ecrecover(_hash, v, r, s);
        if(recovered != owner && recovered != address(0)) {
            magic = bytes4(0);
        }
    }

    fallback() external {
        assert(msg.sender != BOOTLOADER_FORMAL_ADDRESS);
    }

    receive() external payable {}

}