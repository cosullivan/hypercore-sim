import { BigNumberish } from "ethers";

export const systemAddress = (token: BigNumberish) => {
  return `0x${BigInt(BigInt("0x2000000000000000000000000000000000000000") + BigInt(token)).toString(16)}`;
};
