import { ethers } from "hardhat";
import { AddressLike } from "ethers";
import { HyperCoreWrite__factory } from "./typechain-types";
import { setCode } from "@nomicfoundation/hardhat-toolbox/network-helpers";

export const deployHyperCoreWrite = async (hyperCore: AddressLike) => {
  const [signer] = await ethers.getSigners();

  const hyperCoreWriteFactory = new HyperCoreWrite__factory(signer);

  const hyperCoreWrite = await hyperCoreWriteFactory.deploy();
  await hyperCoreWrite.waitForDeployment();

  await setCode(
    "0x3333333333333333333333333333333333333333",
    await signer.provider.send("eth_getCode", [await hyperCoreWrite.getAddress()])
  );

  const instance = HyperCoreWrite__factory.connect("0x3333333333333333333333333333333333333333", signer);
  await instance.setHyperCore(hyperCore);

  return instance;
};
