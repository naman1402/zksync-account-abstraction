import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import { ethers } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Provider, utils, Wallet } from "zksync-web3";

export default async function (hre: HardhatRuntimeEnvironment) {
    
    const provider = new Provider(hre.config.networks.zkSyncLocal.url)
    const wallet = new Wallet(process.env.PRIVATE_KEY as string, provider)
    const deployer = new Deployer(hre, wallet)
    const factoryArtifact = await deployer.loadArtifact("AAFactory")
    const aaArtifact = await deployer.loadArtifact("Account")

    const depositAmount = ethers.utils.parseEther("0.1")
    const depositHandle = await deployer.zkWallet.deposit({
        to: deployer.zkWallet.address,
        token: utils.ETH_ADDRESS,
        amount: depositAmount
    })

    await depositHandle.wait()
    const factory = await deployer.deploy(factoryArtifact, [utils.hashBytecode(aaArtifact.bytecode)], undefined, [aaArtifact.bytecode])
    
    const aaFactory = new ethers.Contract(factory.address, factoryArtifact.abi, wallet)
    const owner =  Wallet.createRandom()

    const salt = ethers.constants.HashZero
    const tx = await aaFactory.deployAccount(salt, owner.address)
    await tx.wait()

    const abiCoder = new ethers.utils.AbiCoder()
    const accountAddress = utils.create2Address(factory.address, await aaFactory.codeHash(), salt, abiCoder.encode(["address"], [owner.address]))
    await (await wallet.sendTransaction({
        to:accountAddress,
        value: ethers.utils.parseEther("0.02")
    })).wait()
    console.log("DONE")
}