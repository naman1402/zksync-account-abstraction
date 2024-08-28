import { Contract, Provider, Wallet } from "zksync-web3";
import { _wallet } from "./utils/wallet";
import { deployAAFactory, deployAccount } from "./utils/deploy";
import { getBalances, toBigNumber, Tx } from "./utils/helper";
import exp from "constants";
import { expect } from "chai";
import { ETH_ADDRESS } from "zksync-web3/build/src/utils";
import { sendTransaction } from "./utils/txn";

const priv1 = _wallet[0].privateKey
const SLEEP_TIME = 10


let provider: Provider
let wallet: Wallet
let user: Wallet
let factory: Contract
let account: Contract

before(async() => {

    provider = Provider.getDefaultProvider()
    wallet = new Wallet(priv1, provider)
    user = Wallet.createRandom();

    factory = await deployAAFactory(wallet)
    account = await deployAccount(wallet, user, factory.address)

    await (await wallet.sendTransaction({
        to: account.address, 
        value: toBigNumber("100")
    })).wait()

    await (await account.changeONE_DAY(SLEEP_TIME)).wait()
})

describe("Deployment, setup and transfer", function () {

    it.only("Should deploy contracts, send ETH, and set variable correctly", async function () {

        expect(await provider.getBalance(account.address)).to.eq(toBigNumber("100"))
        expect((await account.ONE_DAY()).toNumber()).to.eq(SLEEP_TIME)
        expect(await account.owner()).to.equal(user.address)
    })

    it.only("Set Limit: Should add ETH spendinglimit correctly", async function () {
        let tx = await account.populateTransaction.setSpendingLimit(ETH_ADDRESS, toBigNumber("10"), {
            value: toBigNumber("0")
        })

        const txReceipt = await sendTransaction(provider, account, user, tx)
        await txReceipt.wait()

        const limit = await account.limits(ETH_ADDRESS)
        expect(limit.limit).to.eq(toBigNumber("10"))
        expect(limit.available).to.eq(toBigNumber("10"))
        expect(limit.resetTime.toNumber()).to.closeTo(Math.floor(Date.now() / 1000), 5)
        expect(limit.isEnabled).to.eq(true)
    })

    it.only("Transfer ETH 1: Should transfer correctly", async function () {

        const balances = await getBalances(provider, wallet, account, user)
        const tx = Tx(user, "5")

        const txReceipt = await sendTransaction(provider, account, user, tx)
        await txReceipt.wait()

        expect(await provider.getBalance(account.address)).to.be.closeTo(
            balances.AccountBalanceEth.sub(toBN("5")),
            toBigNumber("0.01"),
        )
        expect(await provider.getBalance(user.address)).to.eq(balances.UserBalanceEth.add(toBigNumber("5")))

        const limit = await account.limits(ETH_ADDRESS)

        expect(limit.limit).to.eq(toBigNumber("10"))
        expect(limit.available).to.eq(toBigNumber("5"))
        expect(limit.resetTime.toNumber()).to.gt(Math.floor(Date.now() / 1000))
        expect(limit.isEnabled).to.eq(true)

    })
})
