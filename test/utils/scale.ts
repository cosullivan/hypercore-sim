import { BigNumberish } from "ethers";

export const scale = (amount: BigNumberish, decimals: number = 18): bigint => {
  return BigInt(amount) * 10n ** BigInt(decimals);
};
