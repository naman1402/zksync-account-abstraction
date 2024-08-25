// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IAccount.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/TransactionHelper.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/SystemContractsCaller.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";

error Account__NotEnoughBalance();


contract Account is IAccount, IERC1271{

    address public owner;
    bytes4 constant EIP1271_SUCCESS_RETURN_VALUE = 0x1626ba7e;

    constructor(address _owner) {
        owner = _owner;
    }


    function validateTransaction(
        bytes32 /*_txHash*/,
        bytes32 _suggestedSignedHash,
        Transaction calldata _transaction
    ) external payable override returns (bytes4 magic) {
        return _validateTransaction(_suggestedSignedHash, _transaction);
    }

    function _validateTransaction(bytes32 _suggestedSignedHash, Transaction calldata _transaction) internal returns (bytes4 magic) {
        SystemContractsCaller.systemCallWithPropagatedRevert(uint32(gasleft()), address(NONCE_HOLDER_SYSTEM_CONTRACT), 0, abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce)));
        bytes32 txhash;
        if (_suggestedSignedHash == bytes32(0)) {
            txhash = TransactionHelper.encodeHash(_transaction);
        } else {
            txhash = _suggestedSignedHash;
        }

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
        bytes32 _txHash,
        bytes32 _suggestedSignedHash,
        Transaction calldata _transaction
    ) external payable{}

    function executeTransactionFromOutside(Transaction calldata _transaction) external payable {}

    function payForTransaction(
        bytes32 _txHash,
        bytes32 _suggestedSignedHash,
        Transaction calldata _transaction
    ) external payable {}

    function prepareForPaymaster(
        bytes32 _txHash,
        bytes32 _possibleSignedHash,
        Transaction calldata _transaction
    ) external payable {}

    function isValidSignature(bytes32 _hash, bytes memory _signature) public view override returns (bytes4 magic) {}

}