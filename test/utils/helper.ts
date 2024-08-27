import exp from "constants"
import {ethers, BigNumber, Contract} from "ethers"
import { Provider, Wallet } from "zksync-web3"

export const toBigNumber = (x : string) : BigNumber => {
    return ethers.utils.parseEther(x)
}

export const Tx  =(wallet: Wallet, value: string) => {
    return {
        to: wallet.address,
        value: ethers.utils.parseEther(value),
        data: "0x",
    }
}

export async function consoleLimit(limit: any) {
    console.log("\n",'"Limit"',
        "\n",
        "- Limit: ",
        limit.limit.toString(),
        "\n",
        "- Available: ",
        limit.available.toString(),
        "\n",
        "- Reset Time: ",
        limit.resetTime.toString(),
        "\n",
        "- Now: ",
        Math.floor(Date.now() / 1000).toString(),
        "\n",
        "- isEnabled: ",
        limit.isEnabled.toString(),
        "\n",
        "\n",
    )
}

export async function consoleAddress(wallet: Wallet, factory: Contract, account: Contract, user: Wallet) {
    console.log(
        "\n",
        "-- Addresses -- ",
        "\n",
        "- Wallet: ",
        wallet.address,
        "\n",
        "- Factory: ",
        factory.address,
        "\n",
        "- Account: ",
        account.address,
        "\n",
        "- User: ",
        user.address,
        "\n",
        "\n",
    )
}

export async function getBalances(provider: Provider, wallet: Wallet, account: Contract, user: Wallet) {
    const walletBalanceEth = await provider.getBalance(wallet.address)
    const AccountBalanceEth = await provider.getBalance(account.address)
    const UserBalanceEth = await provider.getBalance(user.address)
    const balances = { walletBalanceEth, AccountBalanceEth, UserBalanceEth }
    return balances;
}