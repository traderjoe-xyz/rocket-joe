const { ethers, network, upgrades } = require("hardhat");
const { expect } = require("chai");
const { advanceTimeAndBlock, duration } = require("./utils/time");

describe("Rocket Joe Staking Contract", function () {
  before(async function () {
    this.RocketJoeStakingCF = await ethers.getContractFactory(
      "RocketJoeStaking"
    );
    this.RocketJoeTokenCF = await ethers.getContractFactory("RocketJoeToken");
    this.ERC20TokenCF = await ethers.getContractFactory("ERC20Token");

    this.signers = await ethers.getSigners();
    this.dev = this.signers[0];
    this.alice = this.signers[1];
    this.bob = this.signers[2];
    this.carol = this.signers[3];
  });

  beforeEach(async function () {
    this.joe = await this.ERC20TokenCF.deploy();
    await this.joe.transferOwnership(this.dev.address);
    this.rJOE = await this.RocketJoeTokenCF.deploy();

    await this.joe
      .connect(this.dev)
      .mint(this.alice.address, ethers.utils.parseEther("1000"));
    await this.joe
      .connect(this.dev)
      .mint(this.bob.address, ethers.utils.parseEther("1000"));
    await this.joe
      .connect(this.dev)
      .mint(this.carol.address, ethers.utils.parseEther("1000"));

    this.RJStaking = await upgrades.deployProxy(this.RocketJoeStakingCF, [
      this.joe.address,
      this.rJOE.address,
      ethers.utils.parseEther("0.01"),
    ]);
    await this.rJOE.transferOwnership(this.RJStaking.address);
  });

  describe("Should allow deposits and withdraws", function () {
    it("should allow deposits and withdraws of multiple users", async function () {
      await this.joe
        .connect(this.alice)
        .approve(this.RJStaking.address, ethers.utils.parseEther("100000"));
      await this.joe
        .connect(this.bob)
        .approve(this.RJStaking.address, ethers.utils.parseEther("100000"));
      await this.joe
        .connect(this.carol)
        .approve(this.RJStaking.address, ethers.utils.parseEther("100000"));

      await this.RJStaking.connect(this.alice).deposit(
        ethers.utils.parseEther("100")
      );
      expect(
        (await this.joe.balanceOf(this.alice.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("900"));
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("100"));

      await this.RJStaking.connect(this.bob).deposit(
        ethers.utils.parseEther("200")
      );
      expect(
        (await this.joe.balanceOf(this.bob.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("800"));
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("300"));

      await this.RJStaking.connect(this.carol).deposit(
        ethers.utils.parseEther("300")
      );
      expect(
        (await this.joe.balanceOf(this.carol.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("700"));
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("600"));

      await this.RJStaking.connect(this.alice).withdraw(
        ethers.utils.parseEther("100")
      );
      expect(
        (await this.joe.balanceOf(this.alice.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("1000"));
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("500"));

      await this.RJStaking.connect(this.carol).withdraw(
        ethers.utils.parseEther("100")
      );
      expect(
        (await this.joe.balanceOf(this.carol.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("800"));
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("400"));

      await this.RJStaking.connect(this.bob).withdraw("1");
      expect(
        (await this.joe.balanceOf(this.bob.address)).toString()
      ).to.be.equal("800000000000000000001");
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("399999999999999999999");
    });

    it("should allow deposits and withdraws of multiple users and distribute rewards accordingly", async function () {
      await this.joe
        .connect(this.alice)
        .approve(this.RJStaking.address, ethers.utils.parseEther("100000"));
      await this.joe
        .connect(this.bob)
        .approve(this.RJStaking.address, ethers.utils.parseEther("100000"));
      await this.joe
        .connect(this.carol)
        .approve(this.RJStaking.address, ethers.utils.parseEther("100000"));

      await this.RJStaking.connect(this.alice).deposit(
        ethers.utils.parseEther("100")
      );
      expect(
        (await this.joe.balanceOf(this.alice.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("900"));
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("100"));

      await this.RJStaking.connect(this.bob).deposit(
        ethers.utils.parseEther("200")
      );
      expect(
        (await this.joe.balanceOf(this.bob.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("800"));
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("300"));

      await this.RJStaking.connect(this.carol).deposit(
        ethers.utils.parseEther("300")
      );
      expect(
        (await this.joe.balanceOf(this.carol.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("700"));
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("600"));

      await advanceTimeAndBlock(duration.days(1));

      await this.RJStaking.connect(this.alice).withdraw(
        ethers.utils.parseEther("100")
      );
      expect(
        (await this.joe.balanceOf(this.alice.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("1000"));
      expect(
        (await this.rJOE.balanceOf(this.alice.address)).toString()
      ).to.be.above(ethers.utils.parseEther("144"));
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("500"));

      await this.RJStaking.connect(this.carol).withdraw(
        ethers.utils.parseEther("100")
      );
      expect(
        (await this.joe.balanceOf(this.carol.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("800"));
      expect(
        (await this.rJOE.balanceOf(this.carol.address)).toString()
      ).to.be.above(ethers.utils.parseEther("432"));
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("400"));

      await this.RJStaking.connect(this.bob).withdraw("0");
      expect(
        (await this.joe.balanceOf(this.bob.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("800"));
      expect(
        (await this.rJOE.balanceOf(this.bob.address)).toString()
      ).to.be.above(ethers.utils.parseEther("288"));
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("400"));
    });

    it("should allow deposits and withdraws of multiple users and distribute rewards accordingly even if someone enters or leaves", async function () {
      await this.joe
        .connect(this.alice)
        .approve(this.RJStaking.address, ethers.utils.parseEther("100000"));
      await this.joe
        .connect(this.bob)
        .approve(this.RJStaking.address, ethers.utils.parseEther("100000"));
      await this.joe
        .connect(this.carol)
        .approve(this.RJStaking.address, ethers.utils.parseEther("100000"));

      await this.RJStaking.connect(this.alice).deposit(
        ethers.utils.parseEther("300")
      );
      await this.RJStaking.connect(this.carol).deposit(
        ethers.utils.parseEther("300")
      );
      expect(
        (await this.joe.balanceOf(this.alice.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("700"));
      expect(
        (await this.joe.balanceOf(this.carol.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("700"));
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("600"));

      await advanceTimeAndBlock(duration.days(1));

      await this.RJStaking.connect(this.bob).deposit(
        ethers.utils.parseEther("300")
      ); // bob enters after the distribution, he shouldn't receive any reward
      await this.RJStaking.connect(this.bob).withdraw("0"); // 1 seconds has passed, so bob receives 1/3rd of the token per second
      expect(
        (await this.rJOE.balanceOf(this.bob.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("0.0033333333333333"));
      expect(
        (await this.joe.balanceOf(this.bob.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("700"));
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("900"));

      await this.RJStaking.connect(this.alice).deposit(
        ethers.utils.parseEther("300")
      ); // alice enters again to try to get more rewards
      await this.RJStaking.connect(this.alice).withdraw(
        ethers.utils.parseEther("600")
      );
      expect(
        (await this.joe.balanceOf(this.alice.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("1000"));
      expect(
        (await this.rJOE.balanceOf(this.alice.address)) - 431026666666100000000
      ).to.be.greaterThan(0);
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("600"));

      await advanceTimeAndBlock(duration.days(2));

      await this.RJStaking.connect(this.bob).withdraw("0"); // bob should only receive half of the last reward
      expect(
        (await this.joe.balanceOf(this.bob.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("700"));
      expect(
        (await this.rJOE.balanceOf(this.bob.address)) - 431026666666100000000
      ).to.be.greaterThan(0);
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("600"));

      await this.RJStaking.connect(this.carol).withdraw(
        ethers.utils.parseEther("300")
      ); // carol should receive both
      expect(
        (await this.joe.balanceOf(this.carol.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("1000"));
      expect(
        (await this.rJOE.balanceOf(this.carol.address)) - 149999999999700000000
      ).to.be.greaterThan(0);
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("300"));

      await this.RJStaking.connect(this.alice).withdraw("0"); // alice shouldn't receive any token of the last reward
      expect(
        (await this.joe.balanceOf(this.alice.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("1000"));
      expect(
        (await this.rJOE.balanceOf(this.alice.address)) - 49999999999800000000
      ).to.be.greaterThan(0);
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("300"));
    });

    it("pending tokens function should return the same number of token that user actually receive", async function () {
      await this.joe
        .connect(this.alice)
        .approve(this.RJStaking.address, ethers.utils.parseEther("100000"));

      await this.RJStaking.connect(this.alice).deposit(
        ethers.utils.parseEther("300")
      );
      expect(
        (await this.joe.balanceOf(this.alice.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("700"));
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("300"));

      await advanceTimeAndBlock(duration.days(1));

      const pendingReward = await this.RJStaking.pendingRJoe(
        this.alice.address
      );
      await this.RJStaking.connect(this.alice).withdraw("0");
      expect(
        (await this.joe.balanceOf(this.alice.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("700"));
      expect(
        pendingReward
          .add(ethers.utils.parseEther("0.01"))
          .sub(await this.rJOE.balanceOf(this.alice.address))
          .toNumber()
      ).to.be.greaterThan(0); // We add 0.01 as 1 second elapsed between calls to pending rewards and deposit
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("300"));
    });

    it("should allow emergency withdraw", async function () {
      await this.joe
        .connect(this.alice)
        .approve(this.RJStaking.address, ethers.utils.parseEther("100000"));

      await this.RJStaking.connect(this.alice).deposit(
        ethers.utils.parseEther("300")
      );
      expect(
        (await this.joe.balanceOf(this.alice.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("700"));
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("300"));

      await advanceTimeAndBlock(duration.days(1));

      await this.RJStaking.connect(this.alice).emergencyWithdraw(); // alice shouldn't receive any token of the last reward
      expect(
        (await this.joe.balanceOf(this.alice.address)).toString()
      ).to.be.equal(ethers.utils.parseEther("1000"));
      expect(
        (await this.rJOE.balanceOf(this.alice.address)).toString()
      ).to.be.equal("0");
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("0");
      const userInfo = await this.RJStaking.userInfo(this.RJStaking.address);
      expect(userInfo.amount.toString()).to.be.equal("0");
      expect(userInfo.rewardDebt.toString()).to.be.equal("0");
    });

    it("should allow update emissionRate and rewards change accordingly", async function () {
      await this.joe
        .connect(this.alice)
        .approve(this.RJStaking.address, ethers.utils.parseEther("100000"));

      await this.RJStaking.connect(this.alice).deposit("1");
      expect(
        (await this.joe.balanceOf(this.RJStaking.address)).toString()
      ).to.be.equal("1");

      await advanceTimeAndBlock(duration.days(1));

      await this.RJStaking.connect(this.alice).withdraw("0");
      const balance = await this.rJOE.balanceOf(this.alice.address);

      await this.RJStaking.updateEmissionRate(
        ethers.utils.parseEther("0.0011")
      );

      await advanceTimeAndBlock(duration.days(1));

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
