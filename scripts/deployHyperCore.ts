import { HyperCore__factory } from "./typechain-types";

export const deployHyperCore = async () => {
  const hyperCoreFactory = new HyperCore__factory();

  const hyperCore = await hyperCoreFactory.deploy();
  await hyperCore.waitForDeployment();

  return hyperCore;
};
