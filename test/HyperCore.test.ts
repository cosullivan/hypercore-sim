import { time, loadFixture, setCode } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, { ethers } from "hardhat";
import { AddressLike, ZeroAddress } from "ethers";
import { scale, systemAddress } from "./utils";
import { deployHyperCoreFixture } from "./deployHyperCoreFixture";

describe("HyperCore <> HyperEVM", function () {
  describe("spot", function () {
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

  describe("perp", function () {
    it("succeeds when transferring spot to perps", async function () {
      const { users, hyperCore, hyperCoreWrite } = await loadFixture(deployHyperCoreFixture);

      await hyperCore.forceSpot(users[0], 0, scale(10, 8));

      let spotBalance = await hyperCore.readSpotBalance(users[0], 0);
      expect(spotBalance.total).eq(scale(10, 8));
      expect(await hyperCore.readWithdrawable(users[0])).deep.eq([0n]);

      await hyperCoreWrite.sendUsdClassTransfer(scale(6, 6), true);
      await hyperCoreWrite.flushActionQueue();

      spotBalance = await hyperCore.readSpotBalance(users[0], 0);
      expect(spotBalance.total).eq(scale(4, 8));
      expect(await hyperCore.readWithdrawable(users[0])).deep.eq([scale(6, 6)]);
    });

    it("silently fails when transferring more than is available from spot to perps", async function () {
      const { users, hyperCore, hyperCoreWrite } = await loadFixture(deployHyperCoreFixture);

      await hyperCore.forceSpot(users[0], 0, scale(10, 8));

      await hyperCoreWrite.sendUsdClassTransfer(scale(20, 8), true);
      await hyperCoreWrite.flushActionQueue();

      expect(await hyperCore.readWithdrawable(users[0])).deep.eq([0n]);
    });

    it("succeeds when transferring from perps to spot", async function () {
      const { users, hyperCore, hyperCoreWrite } = await loadFixture(deployHyperCoreFixture);

      await hyperCore.forceSpot(users[0], 0, scale(10, 8));

      await hyperCoreWrite.sendUsdClassTransfer(scale(10, 6), true);
      await hyperCoreWrite.flushActionQueue();

      expect(await hyperCore.readWithdrawable(users[0])).deep.eq([scale(10, 6)]);

      await hyperCoreWrite.sendUsdClassTransfer(scale(4, 6), false);
      await hyperCoreWrite.flushActionQueue();

      expect(await hyperCore.readWithdrawable(users[0])).deep.eq([scale(6, 6)]);
      expect(await hyperCore.readSpotBalance(users[0], 0)).deep.eq([scale(4, 8), 0, 0]);
    });
  });

  describe("serialization", function () {
    it("can serialize and deserialize a withdraw request", async function () {
      const { hyperCore } = await loadFixture(deployHyperCoreFixture);

      const bytes = await hyperCore.serializeWithdrawRequest({
        account: "0x0000000000000000000000000000000000001234",
        amount: 123456789,
        lockedUntilTimestamp: 987654321,
      });

      const request = await hyperCore.deserializeWithdrawRequest(bytes);

      expect(request.account).eq("0x0000000000000000000000000000000000001234");
      expect(request.amount).eq(123456789);
      expect(request.lockedUntilTimestamp).eq(987654321);
    });
  });

  describe("equity", function () {
    it("succeeds when transferring into vault equity", async function () {
      const { users, hyperCore, hyperCoreWrite } = await loadFixture(deployHyperCoreFixture);

      await hyperCore.forcePerp(users[0], scale(10, 6));

      await hyperCoreWrite.sendVaultTransfer("0x0000000000000000000000000000000000000123", true, scale(6, 6));
      await hyperCoreWrite.flushActionQueue();

      expect(await hyperCore.readWithdrawable(users[0])).deep.eq([scale(4, 6)]);

      const equity = await hyperCore.readUserVaultEquity(users[0], "0x0000000000000000000000000000000000000123");
      expect(equity.equity).eq(scale(6, 6));
    });

    it("succeeds when transferring from vault equity", async function () {
      const { users, hyperCore, hyperCoreWrite } = await loadFixture(deployHyperCoreFixture);

      await hyperCore.forceVaultEquity(users[0], "0x0000000000000000000000000000000000000123", scale(10, 6), 1);

      await hyperCoreWrite.sendVaultTransfer("0x0000000000000000000000000000000000000123", false, scale(6, 6));
      await hyperCoreWrite.flushActionQueue();

      expect(await hyperCore.readWithdrawable(users[0])).deep.eq([scale(6, 6)]);

      const equity = await hyperCore.readUserVaultEquity(users[0], "0x0000000000000000000000000000000000000123");
      expect(equity.equity).eq(scale(4, 6));
    });

    it("fails silently when vault equity is locked", async function () {
      const { users, hyperCore, hyperCoreWrite } = await loadFixture(deployHyperCoreFixture);

      await hyperCore.forceVaultEquity(users[0], "0x0000000000000000000000000000000000000123", scale(10, 6), 0);

      await hyperCoreWrite.sendVaultTransfer("0x0000000000000000000000000000000000000123", false, scale(6, 6));
      await hyperCoreWrite.flushActionQueue();

      expect(await hyperCore.readWithdrawable(users[0])).deep.eq([0n]);
    });
  });
});
