import {task} from "hardhat/config";
import { keccak256, solidityPacked } from "ethers"
task("generate-storage-location", "Generate a storage location for a contract")
    .addPositionalParam("storageSlot", "The storage slot to use", "")
    .setAction(async ({ storageSlot }, hre) => {
        // return keccak256(solidityPacked(["uint256"], [BigInt(keccak256("elite-oracle.storage.DMA") as string) as bigint - BigInt(1)]) as any) as any & ~bytes32(uint256(0xff))

    });
