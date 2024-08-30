// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPaymaster, ExecutionResult, PAYMASTER_VALIDATION_SUCCESS_MAGIC} from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IPaymaster.sol";
import {IPaymasterFlow} from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IPaymasterFlow.sol";
import {TransactionHelper, Transaction} from "@matterlabs/zksync-contracts/l2/system-contracts/libraries/TransactionHelper.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";

error Paymaster__InvalidLengthOfInput();
error Paymaster__InvalidToken();
error Paymaster__AllowanceIsTooLow();

contract Paymaster is IPaymaster{

    uint256 constant PRICE = 1;
    address public allowedToken;

    constructor(address _allowedToken) {
        allowedToken = _allowedToken;
    }

    modifier onlyBootloader() {
        require(msg.sender == BOOTLOADER_FORMAL_ADDRESS, "Only bootloader can call this method");
        // Continue execution if called from the bootloader.
        _;
    }

    /// @notice 
    function validateAndPayForPaymasterTransaction(
        bytes32 /*_txHash*/,
        bytes32 /*_suggestedSignedHash*/,
        Transaction calldata _transaction
    ) external payable onlyBootloader() returns (bytes4 magic, bytes memory context) {

        magic = PAYMASTER_VALIDATION_SUCCESS_MAGIC;
        
        /// input length validation
        if(_transaction.paymasterInput.length < 4) {
            revert Paymaster__InvalidLengthOfInput();
        }
        bytes4 paymasterInputSelector = bytes4(_transaction.paymasterInput[0:4]);

        /// @notice the first 4 bytes of paymasterInput is the selector
        /// @notice remaining bytes are used to get the data like token, amount, data that is encoded in it
        // this checks if paymasterInputSelector extracted from the transaction input matches approvalBased selector from IPaymasterFlow interface, checking if transaction is requesting to use the `approvalBased` paymaster flow
        // if some else function is called, this is reverted

        if (paymasterInputSelector == IPaymasterFlow.approvalBased.selector) {

            // decoding token, amount and data from rest of the paymasterInput, staring from 5th byte 
            // if token is not the allowed token, then reverting using custom error
            (address token, uint256 amount, bytes memory data) = abi.decode(_transaction.paymasterInput[4:], (address, uint256, bytes));
            if(token != allowedToken) {
                revert Paymaster__InvalidToken();
            }

            // converts the sender address into address variable
            // checking the allowance of token own by user given to this contract
            // If that is not enough, revert 
            address userAddress = address(uint160(_transaction.from));
            address thisAddress = address(this);
            uint256 providedAllowance = IERC20(token).allowance(userAddress, thisAddress);
            if(PRICE > providedAllowance) {
                revert Paymaster__AllowanceIsTooLow();
            }

            // calculating gas required from gasLimit and max fee per gas
            // transferring token from user to this contract with amount (from paymasterInput)
            // if the erc20 transaction fails, then we get revertReason as error
            // if revertReason is generic (<=4), throw simple error
            // if revertReason is more complex, use assembly to get exact error reason

            uint256 requiredETH = _transaction.gasLimit * _transaction.maxFeePerGas;

            try IERC20(token).transferFrom(userAddress, thisAddress, amount) {} catch(bytes memory revertReason) {
                // revert reason is empty or represented by just a function selector, we replace it by user friendly msg
                if(revertReason.length <= 4) {
                    revert("Failed to transferFrom from users account");
                } else {
                    assembly {
                        revert(add(0x20, revertReason), mload(revertReason))
                    }
                }
            }

            // After the token transfer, calling the bootloader account and transfering the requiredETH calculated from gas limit and fee per gas
            (bool success, ) = payable(BOOTLOADER_FORMAL_ADDRESS).call{value: requiredETH}("");
            require(success);
        } else {
            revert("unsupported paymaster flow");
        }
    }


    function postTransaction(
        bytes calldata _context,
        Transaction calldata _transaction,
        bytes32 _txHash,
        bytes32 _suggestedSignedHash,
        ExecutionResult _txResult,
        uint256 _maxRefundedGas
    ) external payable override onlyBootloader{

        // REFUNDS 

    }

    receive() external payable {}
}