# ZkSync Account Abstraction
> Successfully learned and developed contract on zkSync Era (Thanks to this documentation https://docs.zksync.io/build)
> Shoutout to mattterlabs for smart contract libraries

## Developed 
- Minimal account with IAccount and EIP1271 `Account.sol`
- Account Factory `AAFactory.sol`
- Multisig wallet `MutliSig.sol` with two owners
- Paymaster `Paymaster.sol` using IPaymaster.sol that accepts ERC20 token in return of paying gas
- USDCPaymaster `USDCPaymaster.sol` using IPaymaster.sol and IProxy to work with dAPI that accepts USDC in return of paying gas 


### Important Stuff
> IAccount - Interface that allows contracts to manage accounts and validate operations in a more flexible way 
[https://github.com/matter-labs/era-system-contracts/blob/main/contracts/interfaces/IAccount.sol]

> EIP1271 - defines how smart contracts validate signature, making it possible for contracts to act as wallets and verify the signatures of transactions 
[https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/interfaces/IERC1271.sol]

> IPaymaster - This interface is designed to standardize how these paymaster contracts interace with zkSync protocol 
[https://github.com/matter-labs/era-contracts/blob/main/l2-contracts/contracts/interfaces/IPaymaster.sol]

### Note
Working on ignition module and stil searching for buildModule alternative for `@matterlabs/hardhat-zksync-deploy`

Having issues with compiling as well [System error]

Testnet - [https://testnet.era.zksync.dev]
```
npx hardhat deploy-zksync --network zkSyncLocal --script <script.file>
``` 


### Resource:
https://github.com/matter-labs/custom-paymaster-tutorial

https://github.com/JackHamer09/zkSync-era-Hardhat-example

https://updraft.cyfrin.io/courses/advanced-foundry

