const { ethers, network } = require("hardhat");
const { expect } = require("chai");
const { advanceTimeAndBlock, duration } = require("./utils/time");
const { HARDHAT_FORK_CURRENT_PARAMS } = require("./utils/hardhat");
const { deployRocketFactory, createLaunchEvent } = require("./utils/contracts");

describe("launch event contract phase three", function () {
  before(async function () {
    // The wallets taking part in tests.
    this.signers = await ethers.getSigners();
    this.dev = this.signers[0];
    this.penaltyCollector = this.signers[1];
    this.issuer = this.signers[2];
    this.participant = this.signers[3];

    this.RocketJoeTokenCF = await ethers.getContractFactory("RocketJoeToken");
    this.ERC20TokenCF = await ethers.getContractFactory("ERC20Token");

    // Fork the avalanche network to work with WAVAX.
    await network.provider.request({
      method: "hardhat_reset",
      params: HARDHAT_FORK_CURRENT_PARAMS,
    });
  });

  beforeEach(async function () {
    // Deploy the tokens used for tests.
    this.rJOE = await this.RocketJoeTokenCF.deploy();
    // XXX: Should we replace this with a standard ERC20?
    this.AUCTOK = await this.ERC20TokenCF.deploy();

    // Keep a reference to the current block.
    this.block = await ethers.provider.getBlock();

    this.RocketFactory = await deployRocketFactory(
      this.dev,
      this.rJOE,
      this.penaltyCollector
    );

    // Send the tokens used to the issuer and approve spending to the factory
    await this.AUCTOK.connect(this.dev).mint(
      this.dev.address,
      ethers.utils.parseEther("105")
    ); // 1_000_000 tokens
    await this.AUCTOK.connect(this.dev).approve(
      this.RocketFactory.address,
      ethers.utils.parseEther("105")
    );
    await this.rJOE
      .connect(this.dev)
      .mint(this.participant.address, ethers.utils.parseEther("150")); // 150 rJOE

    this.LaunchEvent = await createLaunchEvent(
      this.RocketFactory,
      this.issuer,
      this.block,
      this.AUCTOK
    );

  });

  describe("interacting with phase three", function () {

    beforeEach(async function () {
      await advanceTimeAndBlock(duration.seconds(120));
      await this.LaunchEvent.connect(this.participant).depositAVAX({
        value: ethers.utils.parseEther("1.0"),
      });
      expect(
        this.LaunchEvent.getUserAllocation(this.participant.address).amount
      ).to.equal(ethers.utils.parseEther("1.0").number);
      // increase time by 4 days
      await advanceTimeAndBlock(duration.days(4));
    });


    it("should revert if try do withdraw liquidity", async function () {
      await expect(
        this.LaunchEvent.connect(this.participant).withdrawLiquidity()
      ).to.be.revertedWith(
        "LaunchEvent: can't withdraw before user's timelock"
      );
    });

    it("should revert if try do withdraw WAVAX", async function () {
      await expect(
        this.LaunchEvent.connect(this.participant).withdrawAVAX(
          ethers.utils.parseEther("1")
        )
      ).to.be.revertedWith("LaunchEvent: unable to withdraw");
    });

    it("should revert if deposited", async function () {
      await expect(
        this.LaunchEvent.connect(this.participant).depositAVAX({
          value: ethers.utils.parseEther("1"),
        })
      ).to.be.revertedWith("LaunchEvent: not in phase one");
    });

    it("should revert when withdraw liquidity if pair not created", async function () {
      await advanceTimeAndBlock(duration.days(8));
      await expect(
        this.LaunchEvent.connect(this.participant).withdrawLiquidity()
      ).to.be.revertedWith("LaunchEvent: pair does not exist");
    });

    it("should create a JoePair", async function () {
      await this.LaunchEvent.connect(this.participant).createPair();
      // TODO: assert event emitted.
    });

    it("should revert if JoePair already created", async function () {
      await this.LaunchEvent.connect(this.participant).createPair();
      await expect(
        this.LaunchEvent.connect(this.participant).createPair()
      ).to.be.revertedWith("LaunchEvent: pair already created");
    });

    it("should revert if issuer tries to withdraw liquidity more than once", async function () {
      await this.LaunchEvent.connect(this.participant).createPair();

      // increase time to allow issuer to withdraw liquidity
      await advanceTimeAndBlock(duration.days(8));

      // issuer withdraws liquidity
      await this.LaunchEvent.connect(this.issuer).withdrawLiquidity();

      await expect(
        this.LaunchEvent.connect(this.issuer).withdrawLiquidity()
      ).to.be.revertedWith("LaunchEvent: liquidity already withdrawn");
    });

    it("should report it is in the correct phase", async function () {
      await expect((await this.LaunchEvent.currentPhase()) === 3);
    });

  });

  describe("phase 3 edge case", async function () {
    beforeEach(async function () {
      await advanceTimeAndBlock(duration.days(5));
    });

    it("should not create pair when no avax deposited", async function () {
      await expect(
        this.LaunchEvent.connect(this.participant).createPair()
      ).to.be.revertedWith("LaunchEvent: no wavax balance");
    });

  });

  after(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    });
  });
});
