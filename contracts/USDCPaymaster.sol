// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPaymaster, ExecutionResult, PAYMASTER_VALIDATION_SUCCESS_MAGIC} from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IPaymaster.sol";
import {IPaymasterFlow} from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IPaymasterFlow.sol";
import {TransactionHelper, Transaction} from "@matterlabs/zksync-contracts/l2/system-contracts/libraries/TransactionHelper.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// this interface specifies the structure that a proxy contract should follow. primarily used to fetch and return data from dAPIs or other data sources
import { IProxy } from "@api3/contracts/v0.8/interfaces/IProxy.sol";

error USDCPaymaster__NotBootloader();
error USDCPaymaster__InvalidPaymasterInput();
error USDCPaymaster__InvalidToken();
error USDCPaymaster__AllowanceTooLow();

contract USDCPaymaster is IPaymaster, Ownable {

    address public allowedToken;
    uint256 public requiredETH;
    address public USDCAPIProxy;
    address public ETHAPIProxy;

    modifier onlyBootLoader() {
        if(msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert USDCPaymaster__NotBootloader();
        }
        _;
    }

    constructor(address _token) {
        allowedToken = _token;
    }


    /// @notice decentralised data providers: designed to provide reliable, tamper-resistent data for smart contracts and decentralised applications
    /// Only paymaster contract owner can call this function 
    function setProxy(address usdcProxy, address ethProxy) public onlyOwner {
        USDCAPIProxy = usdcProxy;
        ETHAPIProxy = ethProxy;
    }

    /// read() is used to retreive the latest data from the proxy, returns value and timestamp(when updated or fetched)
    function readProxy(address _proxy) public view returns (uint256) {
        (int256 value, ) = IProxy(_proxy).read();
        return uint224(value);
    }

    /// @param _transaction Transaction is being executed
    function validateAndPayForPaymasterTransaction(
        bytes32 /*_txHash*/,
        bytes32 /*_suggestedSignedHash*/,
        Transaction calldata _transaction
    ) external payable onlyBootLoader returns (bytes4 magic, bytes memory context) {

        /// @notice checking the length of _transaction.paymasterInput
        /// first four bytes of this variable tells the FUNCITON SELECTOR !!
        /// remaining gives us the information about the parameters (called with the selector function) 
        /// then, we verify the token (70), compare the providedAllowance (allowance) and the requiredERC20 (maths) (85)
        /// After verification, we transfer the erc20 token from user to paymaster and pay the requiredETH to bootloader from the paymaster

        magic = PAYMASTER_VALIDATION_SUCCESS_MAGIC;
        if(_transaction.paymasterInput.length < 4) {
            revert USDCPaymaster__InvalidPaymasterInput();
        }

        bytes4 paymasterInputSelector = bytes4(_transaction.paymasterInput[0:4]);
        if(paymasterInputSelector == IPaymasterFlow.approvalBased.selector) {

            (address token, uint256 amount, bytes memory data) = abi.decode(_transaction.paymasterInput[4:], (address, uint256, bytes));
            if(token != allowedToken) {
                revert USDCPaymaster__InvalidToken();
            }


            address userAddress = address(uint160(_transaction.from));
            address thisAddress = address(this);
            uint256 providedAllowance = IERC20(token).allowance(userAddress, thisAddress);


            uint256 ETH_USD_Price = readProxy(ETHAPIProxy);
            uint256 USDC_USD_Price = readProxy(USDCAPIProxy);

            requiredETH = _transaction.gasLimit * _transaction.maxFeePerGas;
            uint256 requiredERC20 = (requiredETH * ETH_USD_Price) / USDC_USD_Price;
            if(providedAllowance < requiredERC20) {
                revert USDCPaymaster__AllowanceTooLow();
            }

            try IERC20(token).transferFrom(userAddress, thisAddress, requiredERC20) {} catch (bytes memory revertReason) {
                if(requiredERC20 > amount) {
                    revert();
                }
                if (revertReason.length <= 4) {
                    revert();
                }
                else {
                    assembly {
                        revert(add(0x20, revertReason), mload(revertReason))
                    }
                }
            }

            (bool success, ) = payable(BOOTLOADER_FORMAL_ADDRESS).call{value: requiredETH}("");
            require(success);
        }  else {
            revert();
        }
    }

    function postTransaction(
        bytes calldata _context,
        Transaction calldata _transaction,
        bytes32 _txHash,
        bytes32 _suggestedSignedHash,
        ExecutionResult _txResult,
        uint256 _maxRefundedGas
    ) external payable onlyBootLoader {}
}