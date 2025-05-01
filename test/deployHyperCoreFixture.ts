import hre, { ethers } from "hardhat";
import { ZeroAddress } from "ethers";
import { deployHyperCorePrecompile } from "./utils/deployHyperCorePrecompile";
import { deployHyperCoreSystem, deployHyperCoreWrite } from "./utils";
import { SpotERC20__factory } from "../typechain-types";

export const deployHyperCoreFixture = async () => {
  const [signer, user2, user3] = await hre.ethers.getSigners();

  const hyperCoreFactory = await ethers.getContractFactory("HyperCore", signer);

  const hyperCore = await hyperCoreFactory.deploy();
  await hyperCore.waitForDeployment();

  const hyperCoreWrite = await deployHyperCoreWrite(hyperCore);

  const hyperCoreSystem = await deployHyperCoreSystem(hyperCoreWrite);

  await deployHyperCorePrecompile(hyperCore, "0x0000000000000000000000000000000000000801");

  await hyperCore.registerTokenInfo(0, {
    name: "USDC",
    spots: [],
    deployerTradingFeeShare: 0,
    deployer: ZeroAddress,
    evmContract: ZeroAddress,
    szDecimals: 8,
    weiDecimals: 8,
    evmExtraWeiDecimals: 0,
  });
  await hyperCore.deploySpotERC20(0);

  const usdc = await hyperCore.readTokenInfo(0);

  await hyperCore.forceAccountCreation(signer);

  return {
    users: [signer, user2, user3],
    hyperCore,
    hyperCoreWrite,
    hyperCoreSystem,
    usdc: SpotERC20__factory.connect(usdc.evmContract, signer),
    KNOWN_TOKEN_HYPE: 150,
  };
};
