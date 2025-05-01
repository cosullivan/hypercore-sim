import { ethers } from "hardhat";
import { HyperCore__factory } from "./typechain-types";

export const deployHyperCore = async () => {
  const [signer] = await ethers.getSigners();

  const hyperCoreFactory = new HyperCore__factory(signer);

  const hyperCore = await hyperCoreFactory.deploy();
  await hyperCore.waitForDeployment();

  return hyperCore;
};
