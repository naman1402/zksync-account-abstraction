import { HardhatRuntimeEnvironment } from "hardhat/types";
import * as zk from "zksync-web3";
import * as ethers from "ethers";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";

export default async function (hre: HardhatRuntimeEnvironment) {

    const testMnemonic =
        "stuff slice staff easily soup parent arm payment cotton trade scatter struggle"
    const zkWallet = zk.Wallet.fromMnemonic(testMnemonic, "m/44'/60'/0'/0/0")

    const contractDeployer = new Deployer(hre, zkWallet, "create")
    const aaDeployer = new Deployer(hre, zkWallet, "createAccount")
    const aaArtifact = await aaDeployer.loadArtifact("MultiSig")
    const provider =  aaDeployer.zkWallet.provider

    const depositHandle = await contractDeployer.zkWallet.deposit({
        to: contractDeployer.zkWallet.address,
        token: zk.utils.ETH_ADDRESS,
        amount: ethers.utils.parseEther("0.001"),
    })
    await depositHandle.wait()

    const owner1 = zk.Wallet.createRandom()
    const owner2 = zk.Wallet.createRandom()

    const aa = await aaDeployer.deploy(aaArtifact, [owner1.address, owner2.address], undefined, [])
    const mutlisigAddress = aa.address
    
    await ( await contractDeployer.zkWallet.sendTransaction({
        to: mutlisigAddress,
        value: ethers.utils.parseEther("0.003"),
    })).wait()
    
}