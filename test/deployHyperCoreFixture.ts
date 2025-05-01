import hre from "hardhat";
import { ZeroAddress } from "ethers";
import { SpotERC20__factory } from "../scripts/typechain-types";
import { deployHyperCoreSim } from "../scripts";

export const deployHyperCoreFixture = async () => {
  const [signer, user2, user3] = await hre.ethers.getSigners();

  const { hyperCore, hyperCoreWrite, hyperCoreSystem } = await deployHyperCoreSim();

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
