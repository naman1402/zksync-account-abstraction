// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/SystemContractsCaller.sol";

error AAFactory__DeploymentFailed();

contract AAFactory {

    bytes32 public codeHash;

    constructor(bytes32 _codeHash) {
        codeHash = _codeHash;
    }

    /// @param owner owner's address of the smart contract account
    /// @param salt this value along with codeHash is used to determine address of the contract
    /// SystemContractsCaller is usually used when a smart contract needs to call another contract that is part of the network's core infrastructure
    /// Using system contract calling the address(DEPLOYER_SYSTEM_CONTRACT)

    function deployAccount(bytes32 salt, address owner) external returns (address accountAddress) {

        /// gasLimit for this transaction is the gasLeft(),
        /// the data we sending are encoded version of DEPLOYER_SYSTEM_CONTRACT.create2Account function with params as 
        /// (salt, codeHash, abi.encode(owner), IContractDeployer.AccountAbstractionVersion.Version1)
        /// returns success if the account is created successfully or not, and returnData which will have address of the account
        (bool success, bytes memory returnData) = SystemContractsCaller.systemCallWithReturndata(
            uint32(gasleft()), 
            address(DEPLOYER_SYSTEM_CONTRACT), 
            uint128(0), 
            abi.encodeCall(
                DEPLOYER_SYSTEM_CONTRACT.create2Account,
                (
                    salt, 
                    codeHash, 
                    abi.encode(owner), 
                    IContractDeployer.AccountAbstractionVersion.Version1
                )
            )
        );
        if(!success) {
            revert AAFactory__DeploymentFailed();
        }
        /// Using decoding function, we can get the address of account from return data
        (accountAddress) = abi.decode(returnData, (address));
    }
}