import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import { ethers } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import * as zk from "zksync-web3"

export default async function (hre: HardhatRuntimeEnvironment) {

    const testMnemonic = "stuff slive staff easily soup parent arm payment cotton trade scatter struggle"
    const wallet = hre.network.name == "zkSyncLocal" ? zk.Wallet.fromMnemonic(testMnemonic, "m/44'/60'/0'/0/0") : zk.Wallet.fromMnemonic(process.env.PRIVATE_KEY as string)
    
    const deployer = new Deployer(hre, wallet)
    const provider = deployer.zkWallet.provider

    const emptyWallet = new zk.Wallet(zk.Wallet.createRandom().privateKey, provider)
    console.log(`Empty wallet's address: ${emptyWallet.address}`)
    console.log(`Empty wallet's private key: ${emptyWallet.privateKey}`)

    const depositHandle = await deployer.zkWallet.deposit({
        to: deployer.zkWallet.address,
        token: zk.utils.ETH_ADDRESS,
        amount: ethers.utils.parseEther("0.1")
    })
    await depositHandle.wait()


    const erc20Artifact = await deployer.loadArtifact("Token")
    const erc20 = await deployer.deploy(erc20Artifact, ["Token", "TKN", 18])
    console.log(`ERC20 deployed at ${erc20.address}`)

    const paymasterArtifact = await deployer.loadArtifact("Paymaster")
    const paymaster = await deployer.deploy(paymasterArtifact, [deployer.zkWallet.address])
    console.log(`Paymaster deployed at ${paymaster.address}`)

    await (await deployer.zkWallet.sendTransaction({
        to: paymaster.address,
        value: ethers.utils.parseEther("0.6")
    })).wait()

    const ethBalance = await provider.getBalance(deployer.zkWallet.address)
    if(!ethBalance.eq(0)) {
        throw new Error("Failed to fund paymaster")
    } else {
        console.log(`emptyWallet ETH balance is now ${ethBalance.toString()}`)
    }

    let paymasterBalance = await provider.getBalance(paymaster.address)
    await (await erc20.mint(emptyWallet.address, 10)).wait()

    const erc20ConnectEmptyWallet = new ethers.Contract(erc20.address, erc20Artifact.abi, emptyWallet)
    const gasPrice = await provider.getGasPrice()
    const paymasterParams = zk.utils.getPaymasterParams(paymaster.address, {
        type: "ApprovalBased",
        token: erc20ConnectEmptyWallet.address,
        minimalAllowance: ethers.BigNumber.from(1),
        innerInput: new Uint8Array()
    })

    const gasLimit = await erc20ConnectEmptyWallet.estimateGas.mint(emptyWallet.address, 5, {
        customData: {
            gasPerPubdata: zk.utils.DEFAULT_GAS_PER_PUBDATA_LIMIT,
            paymasterParams: paymasterParams,
        },
    })

    const fee = gasPrice.mul(gasLimit.toString())
    console.log("transaction fee: ", fee.toString())
    await (await erc20ConnectEmptyWallet.mint(emptyWallet.address, 5, {
        customData: {
            paymasterParams: paymasterParams,
            gasPerPubdata: zk.utils.DEFAULT_GAS_PER_PUBDATA_LIMIT,
        },
    })).wait()

    paymasterBalance = await provider.getBalance(paymaster.address)
    console.log(`Paymaster balance is now ${paymasterBalance.toString()}`)
    console.log(`erc20 token balance of the empty wallet after mint: ${await erc20ConnectEmptyWallet.balanceOf(emptyWallet.address)}`)
    

}