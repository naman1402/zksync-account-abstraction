// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IAccount.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/TransactionHelper.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/SystemContractsCaller.sol";

error MultiSig__OnlyBootLoaderCanCall();

contract MultiSig is IAccount, IERC1271{

    using TransactionHelper for Transaction;

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
        _;
    }

    function validateTransaction(
        bytes32 /*_txHash*/,
        bytes32 _suggestedSignedHash,
        Transaction calldata _transaction
    ) external payable override onlyBootLoader returns (bytes4 magic) {
        magic = _validateTransaction(_suggestedSignedHash, _transaction);
    }

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
    ) external payable{
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
        require(success);
    }

    function prepareForPaymaster(
        bytes32 /*_txHash*/,
        bytes32 /*_possibleSignedHash*/,
        Transaction calldata _transaction
    ) external payable {
        TransactionHelper.processPaymasterInput(_transaction);
    }

    function isValidSignature(bytes32 hash, bytes memory signature) public view returns (bytes4 magicValue) {}

    fallback() external {
        assert(msg.sender != BOOTLOADER_FORMAL_ADDRESS);
    }

    receive() external payable {}

}