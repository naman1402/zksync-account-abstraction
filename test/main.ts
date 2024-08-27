import { Wallet, Provider, Contract, utils} from "zksync-web3";
import { expect } from "chai";
import * as ethers from "ethers";


const ETH_ADDRESS = "0x000000000000000000000000000000000000800A"
const SLEEP_TIME = 10

let provider: Provider
let wallet: Wallet
let user: Wallet

let factory: Contract
let account: Contract

before(async () => {
    provider = Provider.getDefaultProvider()
    wallet = new Wallet()
})