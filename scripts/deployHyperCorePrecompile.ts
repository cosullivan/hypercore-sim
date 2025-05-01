import { ethers } from "hardhat";
import { AddressLike } from "ethers";
import HyperCorePrecompilesArtifact from "../artifacts/contracts/HyperCorePrecompiles.sol/HyperCorePrecompiles.json";
import { HyperCorePrecompiles, HyperCorePrecompiles__factory } from "./typechain-types";
import { setCode } from "@nomicfoundation/hardhat-toolbox/network-helpers";

export const deployHyperCorePrecompile = async (hyperCore: AddressLike, precompileAddress: string) => {
  const [signer] = await ethers.getSigners();

  const mockPrecompilesFactory = await ethers.getContractFactoryFromArtifact<[], HyperCorePrecompiles>(
    HyperCorePrecompilesArtifact
  );

  const mockPrecompile = await mockPrecompilesFactory.deploy();
  await mockPrecompile.waitForDeployment();

  await setCode(precompileAddress, await signer.provider.send("eth_getCode", [await mockPrecompile.getAddress()]));

  const precompile = HyperCorePrecompiles__factory.connect(precompileAddress, signer);
  await precompile.setHyperCore(hyperCore);
};
