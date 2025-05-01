import { time, loadFixture, setCode } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, { ethers } from "hardhat";
import { AddressLike, ZeroAddress } from "ethers";
import { scale, systemAddress } from "./utils";
import { deployHyperCoreFixture } from "./deployHyperCoreFixture";

describe("Transfers", function () {
  it("succeeds when transferring token to HyperCore", async function () {
    const { users, hyperCore, hyperCoreWrite, usdc } = await loadFixture(deployHyperCoreFixture);

    await usdc.mint(users[0], scale(10, 8));

    let spotBalance = await hyperCore.readSpotBalance(users[0], 0);
    expect(spotBalance.total).eq(0);

    await usdc.transfer(systemAddress(0), scale(5, 8));
    await hyperCoreWrite.flushActionQueue();

    spotBalance = await hyperCore.readSpotBalance(users[0], 0);
    expect(spotBalance.total).eq(scale(5, 8));
  });

  it("silently fails when transferring token to HyperCore if account hasnt been created", async function () {
    const { users, hyperCore, hyperCoreWrite, usdc } = await loadFixture(deployHyperCoreFixture);

    await usdc.mint(users[1], scale(10, 8));

    let spotBalance = await hyperCore.readSpotBalance(users[1], 0);
    expect(spotBalance.total).eq(0);

    await usdc.connect(users[1]).transfer(systemAddress(0), scale(5, 8));
    await hyperCoreWrite.flushActionQueue();

    spotBalance = await hyperCore.readSpotBalance(users[1], 0);
    expect(spotBalance.total).eq(0);
  });

  it("succeeds when transferring native gas token to HyperCore", async function () {
    const { users, hyperCore, hyperCoreWrite, usdc, KNOWN_TOKEN_HYPE } = await loadFixture(deployHyperCoreFixture);

    let spotBalance = await hyperCore.readSpotBalance(users[0], KNOWN_TOKEN_HYPE);
    expect(spotBalance.total).eq(0);

    await users[0].sendTransaction({ to: "0x2222222222222222222222222222222222222222", value: scale(1, 18) });
    await hyperCoreWrite.flushActionQueue();

    spotBalance = await hyperCore.readSpotBalance(users[0], KNOWN_TOKEN_HYPE);
    expect(spotBalance.total).eq(scale(1, 8));
  });

  it("spotSend can transfer between accounts on HyperCore", async function () {
    const { users, hyperCore, hyperCoreWrite, usdc } = await loadFixture(deployHyperCoreFixture);

    await usdc.mint(users[0], scale(10, 8));
    await usdc.transfer(systemAddress(0), scale(10, 8));
    await hyperCoreWrite.flushActionQueue();

    let spotBalance1 = await hyperCore.readSpotBalance(users[0], 0);
    expect(spotBalance1.total).eq(scale(10, 8));

    let spotBalance2 = await hyperCore.readSpotBalance(users[1], 0);
    expect(spotBalance2.total).eq(0);

    await hyperCoreWrite.connect(users[0]).sendSpot(users[1], 0, scale(10, 8));
    await hyperCoreWrite.flushActionQueue();

    spotBalance1 = await hyperCore.readSpotBalance(users[0], 0);
    expect(spotBalance1.total).eq(0);

    spotBalance2 = await hyperCore.readSpotBalance(users[1], 0);
    expect(spotBalance2.total).eq(scale(10, 8));

    await hyperCoreWrite.connect(users[1]).sendSpot(users[0], 0, scale(6, 8));
    await hyperCoreWrite.flushActionQueue();

    spotBalance1 = await hyperCore.readSpotBalance(users[0], 0);
    expect(spotBalance1.total).eq(scale(6, 8));

    spotBalance2 = await hyperCore.readSpotBalance(users[1], 0);
    expect(spotBalance2.total).eq(scale(4, 8));
  });

  it("spotSend can transfer from HyperCore to HyperEVM", async function () {
    const { users, hyperCore, hyperCoreWrite, usdc } = await loadFixture(deployHyperCoreFixture);

    await usdc.mint(users[0], scale(10, 8));
    await usdc.transfer(systemAddress(0), scale(10, 8));
    await hyperCoreWrite.flushActionQueue();

    expect(await usdc.balanceOf(users[0])).eq(0);

    let spotBalance1 = await hyperCore.readSpotBalance(users[0], 0);
    expect(spotBalance1.total).eq(scale(10, 8));

    await hyperCoreWrite.sendSpot(systemAddress(0), 0, scale(5, 8));
    await hyperCoreWrite.flushActionQueue();

    spotBalance1 = await hyperCore.readSpotBalance(users[0], 0);
    expect(spotBalance1.total).eq(scale(5, 8));

    expect(await usdc.balanceOf(users[0])).eq(scale(5, 8));
  });

  it("spotSend can transfer native from HyperCore to HyperEVM", async function () {
    const { users, hyperCore, hyperCoreWrite, KNOWN_TOKEN_HYPE } = await loadFixture(deployHyperCoreFixture);

    await users[0].sendTransaction({ to: "0x2222222222222222222222222222222222222222", value: scale(10, 18) });
    await hyperCoreWrite.flushActionQueue();

    let spotBalance = await hyperCore.readSpotBalance(users[0], KNOWN_TOKEN_HYPE);
    expect(spotBalance.total).eq(scale(10, 8));

    await hyperCoreWrite.sendSpot("0x2222222222222222222222222222222222222222", KNOWN_TOKEN_HYPE, scale(5, 8));
    await hyperCoreWrite.flushActionQueue();

    spotBalance = await hyperCore.readSpotBalance(users[0], KNOWN_TOKEN_HYPE);
    expect(spotBalance.total).eq(scale(5, 8));
  });
});
