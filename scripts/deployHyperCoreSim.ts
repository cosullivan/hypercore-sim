import { deployHyperCoreWrite } from "./deployHyperCoreWrite";
import { deployHyperCoreSystem } from "./deployHyperCoreSystem";
import { deployHyperCorePrecompile } from "./deployHyperCorePrecompile";
import { deployHyperCore } from "./deployHyperCore";

export const deployHyperCoreSim = async () => {
  const hyperCore = await deployHyperCore();

  const hyperCoreWrite = await deployHyperCoreWrite(hyperCore);

  const hyperCoreSystem = await deployHyperCoreSystem(hyperCoreWrite);

  await deployHyperCorePrecompile(hyperCore, "0x0000000000000000000000000000000000000801");
  await deployHyperCorePrecompile(hyperCore, "0x0000000000000000000000000000000000000802");
  await deployHyperCorePrecompile(hyperCore, "0x0000000000000000000000000000000000000803");
  await deployHyperCorePrecompile(hyperCore, "0x0000000000000000000000000000000000000804");
  await deployHyperCorePrecompile(hyperCore, "0x0000000000000000000000000000000000000805");
  await deployHyperCorePrecompile(hyperCore, "0x0000000000000000000000000000000000000806");
  await deployHyperCorePrecompile(hyperCore, "0x0000000000000000000000000000000000000807");
  await deployHyperCorePrecompile(hyperCore, "0x0000000000000000000000000000000000000808");
  await deployHyperCorePrecompile(hyperCore, "0x0000000000000000000000000000000000000809");
  await deployHyperCorePrecompile(hyperCore, "0x000000000000000000000000000000000000080a");
  await deployHyperCorePrecompile(hyperCore, "0x000000000000000000000000000000000000080b");
  await deployHyperCorePrecompile(hyperCore, "0x000000000000000000000000000000000000080c");

  return { hyperCore, hyperCoreWrite, hyperCoreSystem };
};
