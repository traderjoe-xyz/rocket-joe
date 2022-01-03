const { ethers, network, upgrades } = require("hardhat");
const { expect } = require("chai");

describe("Rocket Joe Staking Contract", function () {
  before(async function () {
    this.RocketJoeStakingContractCF = await ethers.getContractFactory(
      "RocketJoeStakingContract"
    );
    this.RocketJoeTokenCF = await ethers.getContractFactory("RocketJoeToken");

    this.signers = await ethers.getSigners();
    this.dev = this.signers[0];
    this.alice = this.signers[1];
    this.bob = this.signers[2];
    this.carol = this.signers[3];
  });

  beforeEach(async function () {
    this.moJOE = await this.RocketJoeTokenCF.deploy();
    await this.moJOE.transferOwnership(this.dev.address);
    this.rJOE = await this.RocketJoeTokenCF.deploy();

    await this.moJOE
      .connect(this.dev)
      .mint(this.alice.address, "1000000000000000000000");
    await this.moJOE
      .connect(this.dev)
      .mint(this.bob.address, "1000000000000000000000");
    await this.moJOE
      .connect(this.dev)
      .mint(this.carol.address, "1000000000000000000000");

    this.RJStaking = await upgrades.deployProxy(
      this.RocketJoeStakingContractCF,
      [this.moJOE.address, this.rJOE.address, "10000000000000000"]
    );
    await this.rJOE.transferOwnership(this.RJStaking.address);
  });

  describe("should allow deposits and withdraws", function () {
    it("should allow deposits and withdraws of multiple users", async function () {
      await this.moJOE
        .connect(this.alice)
        .approve(this.RJStaking.address, "100000000000000000000000000000000");
      await this.moJOE
        .connect(this.bob)
        .approve(this.RJStaking.address, "100000000000000000000000000000000");
      await this.moJOE
        .connect(this.carol)
        .approve(this.RJStaking.address, "100000000000000000000000000000000");

      await this.RJStaking.connect(this.alice).deposit("100000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.alice.address)).toString()
      ).to.be.equal("900000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("100000000000000000000");

      await this.RJStaking.connect(this.bob).deposit("200000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.bob.address)).toString()
      ).to.be.equal("800000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("300000000000000000000");

      await this.RJStaking.connect(this.carol).deposit("300000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.carol.address)).toString()
      ).to.be.equal("700000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("600000000000000000000");

      await this.RJStaking.connect(this.alice).withdraw(
        "100000000000000000000"
      );
      expect(
        (await this.moJOE.balanceOf(this.alice.address)).toString()
      ).to.be.equal("1000000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("500000000000000000000");

      await this.RJStaking.connect(this.carol).withdraw(
        "100000000000000000000"
      );
      expect(
        (await this.moJOE.balanceOf(this.carol.address)).toString()
      ).to.be.equal("800000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("400000000000000000000");

      await this.RJStaking.connect(this.bob).withdraw("1");
      expect(
        (await this.moJOE.balanceOf(this.bob.address)).toString()
      ).to.be.equal("800000000000000000001");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("399999999999999999999");
    });

    it("should allow deposits and withdraws of multiple users and distribute rewards accordingly", async function () {
      await this.moJOE
        .connect(this.alice)
        .approve(this.RJStaking.address, "100000000000000000000000000000000");
      await this.moJOE
        .connect(this.bob)
        .approve(this.RJStaking.address, "100000000000000000000000000000000");
      await this.moJOE
        .connect(this.carol)
        .approve(this.RJStaking.address, "100000000000000000000000000000000");

      await this.RJStaking.connect(this.alice).deposit("100000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.alice.address)).toString()
      ).to.be.equal("900000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("100000000000000000000");

      await this.RJStaking.connect(this.bob).deposit("200000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.bob.address)).toString()
      ).to.be.equal("800000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("300000000000000000000");

      await this.RJStaking.connect(this.carol).deposit("300000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.carol.address)).toString()
      ).to.be.equal("700000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("600000000000000000000");

      await increase(60 * 60 * 24);

      await this.RJStaking.connect(this.alice).withdraw(
        "100000000000000000000"
      );
      expect(
        (await this.moJOE.balanceOf(this.alice.address)).toString()
      ).to.be.equal("1000000000000000000000");
      expect(
        (await this.rJOE.balanceOf(this.alice.address)).toString()
      ).to.be.equal("144014999999900000000");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("500000000000000000000");

      await this.RJStaking.connect(this.carol).withdraw(
        "100000000000000000000"
      );
      expect(
        (await this.moJOE.balanceOf(this.carol.address)).toString()
      ).to.be.equal("800000000000000000000");
      expect(
        (await this.rJOE.balanceOf(this.carol.address)).toString()
      ).to.be.equal("432010999999800000000");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("400000000000000000000");

      await this.RJStaking.connect(this.bob).withdraw("0");
      expect(
        (await this.moJOE.balanceOf(this.bob.address)).toString()
      ).to.be.equal("800000000000000000000");
      expect(
        (await this.rJOE.balanceOf(this.bob.address)).toString()
      ).to.be.equal("288018999999800000000");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("400000000000000000000");
    });

    it("should allow deposits and withdraws of multiple users and distribute rewards accordingly even if someone enters or leaves", async function () {
      await this.moJOE
        .connect(this.alice)
        .approve(this.RJStaking.address, "100000000000000000000000000000000");
      await this.moJOE
        .connect(this.bob)
        .approve(this.RJStaking.address, "100000000000000000000000000000000");
      await this.moJOE
        .connect(this.carol)
        .approve(this.RJStaking.address, "100000000000000000000000000000000");

      await this.RJStaking.connect(this.alice).deposit("300000000000000000000");
      await this.RJStaking.connect(this.carol).deposit("300000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.alice.address)).toString()
      ).to.be.equal("700000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.carol.address)).toString()
      ).to.be.equal("700000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("600000000000000000000");

      await increase(60 * 60 * 24);

      await this.RJStaking.connect(this.bob).deposit("300000000000000000000"); // bob enters after the distribution, he shouldn't receive any reward
      await this.RJStaking.connect(this.bob).withdraw("0"); // 1 seconds has passed, so bob receives 1/3rd of the token per second
      expect(
        (await this.rJOE.balanceOf(this.bob.address)).toString()
      ).to.be.equal("3333333300000000");
      expect(
        (await this.moJOE.balanceOf(this.bob.address)).toString()
      ).to.be.equal("700000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("900000000000000000000");

      await this.RJStaking.connect(this.alice).deposit("300000000000000000000"); // alice enters again to try to get more rewards
      await this.RJStaking.connect(this.alice).withdraw(
        "600000000000000000000"
      );
      expect(
        (await this.moJOE.balanceOf(this.alice.address)).toString()
      ).to.be.equal("1000000000000000000000");
      expect(
        (await this.rJOE.balanceOf(this.alice.address)) - 431026666666100000000
      ).to.be.greaterThan(0);
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("600000000000000000000");

      await increase(60 * 60 * 24 * 2);

      await this.RJStaking.connect(this.bob).withdraw("0"); // bob should only receive half of the last reward
      expect(
        (await this.moJOE.balanceOf(this.bob.address)).toString()
      ).to.be.equal("700000000000000000000");
      expect(
        (await this.rJOE.balanceOf(this.bob.address)) - 431026666666100000000
      ).to.be.greaterThan(0);
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("600000000000000000000");

      await this.RJStaking.connect(this.carol).withdraw(
        "300000000000000000000"
      ); // carol should receive both
      expect(
        (await this.moJOE.balanceOf(this.carol.address)).toString()
      ).to.be.equal("1000000000000000000000");
      expect(
        (await this.rJOE.balanceOf(this.carol.address)) - 149999999999700000000
      ).to.be.greaterThan(0);
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("300000000000000000000");

      await this.RJStaking.connect(this.alice).withdraw("0"); // alice shouldn't receive any token of the last reward
      expect(
        (await this.moJOE.balanceOf(this.alice.address)).toString()
      ).to.be.equal("1000000000000000000000");
      expect(
        (await this.rJOE.balanceOf(this.alice.address)) - 49999999999800000000
      ).to.be.greaterThan(0);
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("300000000000000000000");
    });

    it("pending tokens function should return the same number of token that user actually receive", async function () {
      await this.moJOE
        .connect(this.alice)
        .approve(this.RJStaking.address, "100000000000000000000000000000000");

      await this.RJStaking.connect(this.alice).deposit("300000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.alice.address)).toString()
      ).to.be.equal("700000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("300000000000000000000");

      await increase(60 * 60 * 24);

      const pendingReward = await this.RJStaking.pendingRJoe(
        this.alice.address
      );
      await this.RJStaking.connect(this.alice).withdraw("0"); // alice shouldn't receive any token of the last reward
      expect(
        (await this.moJOE.balanceOf(this.alice.address)).toString()
      ).to.be.equal("700000000000000000000");
      expect(
        pendingReward.add("10000000000000000") -
          (await this.rJOE.balanceOf(this.alice.address))
      ).to.be.greaterThan(0);
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("300000000000000000000");
    });

    it("should allow emergency withdraw", async function () {
      await this.moJOE
        .connect(this.alice)
        .approve(this.RJStaking.address, "100000000000000000000000000000000");

      await this.RJStaking.connect(this.alice).deposit("300000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.alice.address)).toString()
      ).to.be.equal("700000000000000000000");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("300000000000000000000");

      await increase(60 * 60 * 24);

      await this.RJStaking.connect(this.alice).emergencyWithdraw(); // alice shouldn't receive any token of the last reward
      expect(
        (await this.moJOE.balanceOf(this.alice.address)).toString()
      ).to.be.equal("1000000000000000000000");
      expect(
        (await this.rJOE.balanceOf(this.alice.address)).toString()
      ).to.be.equal("0");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("0");
      const userInfo = await this.RJStaking.userInfo(this.RJStaking.address);
      expect(userInfo.amount.toString()).to.be.equal("0");
      expect(userInfo.rewardDebt.toString()).to.be.equal("0");
    });

    it("should allow update emissionRate and rewards change accordingly", async function () {
      await this.moJOE
        .connect(this.alice)
        .approve(this.RJStaking.address, "100000000000000000000000000000000");

      await this.RJStaking.connect(this.alice).deposit("1");
      expect(
        (await this.moJOE.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("1");

      await increase(60 * 60 * 24);

      await this.RJStaking.connect(this.alice).withdraw("0");
      const balance = await this.rJOE.balanceOf(this.alice.address);

      await this.RJStaking.updateEmissionRate("11000000000000000");

      await increase(60 * 60 * 24);

      await this.RJStaking.connect(this.alice).withdraw("0");
      expect(
        (await this.rJOE.balanceOf(this.alice.address)) - balance
      ).to.be.greaterThan(0);
    });
  });

  after(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    });
  });
});

const increase = (seconds) => {
  ethers.provider.send("evm_increaseTime", [60 * 60 * 24]);
  ethers.provider.send("evm_mine", []);
};
