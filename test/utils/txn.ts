
import { ethers } from "ethers";
import { Contract, EIP712Signer, Provider, types, utils, Wallet } from "zksync-web3";
import { PriorityOpTree } from "zksync-web3/build/src/types";

export async function sendTransaction(provider: Provider, account: Contract, user: Wallet, tx: any) {
    tx = { 
        ...tx, 
        from: account.address, 
        chainId: (await provider.getNetwork()).chainId, 
        nonce: await provider.getTransactionCount(account.address), 
        type: 113, 
        customData: {
            gasPerPubData: utils.DEFAULT_GAS_PER_PUBDATA_LIMIT
        } as types.Eip712Meta
    }

    tx.gasPrice = await provider.getGasPrice()
    if (tx.gasLimit == undefined) {
        tx.gasLimit = await provider.estimateGas(tx)
    }

    const signedTxHash = EIP712Signer.getSignedDigest(tx)
    const signature = ethers.utils.arrayify(ethers.utils.joinSignature(user._signingKey().signDigest(signedTxHash)))
    tx.customData = {
        ...tx.customData,
        customSignature: signature
    }

    return await provider.sendTransaction(utils.serialize(tx))
}