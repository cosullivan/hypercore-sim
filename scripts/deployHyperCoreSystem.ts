import { ethers } from "hardhat";
import { AddressLike } from "ethers";
import { HyperCoreSystem__factory } from "./typechain-types";
import { setCode } from "@nomicfoundation/hardhat-toolbox/network-helpers";

export const deployHyperCoreSystem = async (hyperCoreWrite: AddressLike) => {
  const [signer] = await ethers.getSigners();

  const hyperCoreSystemFactory = new HyperCoreSystem__factory(signer);

  const hyperCoreSystem = await hyperCoreSystemFactory.deploy();
  await hyperCoreSystem.waitForDeployment();

  await setCode(
    "0x2222222222222222222222222222222222222222",
    await signer.provider.send("eth_getCode", [await hyperCoreSystem.getAddress()])
  );

  const instance = HyperCoreSystem__factory.connect("0x2222222222222222222222222222222222222222", signer);
  await instance.setHyperCoreWrite(hyperCoreWrite);

  return instance;
};
