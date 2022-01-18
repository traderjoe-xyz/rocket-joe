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
  });

  describe("interacting with phase three", function () {
    beforeEach(async function () {
      // Send the tokens used to the issuer and approve spending to the factory
      await this.rJOE
        .connect(this.dev)
        .mint(this.participant.address, ethers.utils.parseEther("150")); // 150 rJOE

      this.LaunchEvent = await createLaunchEvent(
        this.RocketFactory,
        this.issuer,
        this.block,
        this.AUCTOK
      );

      await advanceTimeAndBlock(duration.seconds(120));
      await this.LaunchEvent.connect(this.participant).depositAVAX({
        value: ethers.utils.parseEther("1.0"),
      });
      expect(
        this.LaunchEvent.getUserAllocation(this.participant.address).amount
      ).to.equal(ethers.utils.parseEther("1.0").number);
      await advanceTimeAndBlock(duration.days(3));
    });

    it("should revert if try to withdraw liquidity", async function () {
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


  describe("withdrawing liquidity in phase three", async function () {
    beforeEach(async function () {
      // Deploy the tokens used for tests.
      this.factory = await ethers.getContractAt(
        "IJoeFactory",
        "0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10"
      );
      await this.rJOE
        .connect(this.dev)
        .mint(this.participant.address, ethers.utils.parseEther("10000"));
      this.LaunchEvent = await createLaunchEvent(
        this.RocketFactory,
        this.issuer,
        this.block,
        this.AUCTOK,
        "100",  // token amount
        "1",    // floor price
        "100"   // max allocation
      );

    });

    it("should not create pair when no avax deposited", async function () {
     await advanceTimeAndBlock(duration.days(4));
     await expect(
        this.LaunchEvent.connect(this.participant).createPair()
      ).to.be.revertedWith("LaunchEvent: no wavax balance");
    });

    it("should evenly distribute liquidity to issuer and participant", async function () {

      await advanceTimeAndBlock(duration.seconds(120));

      // Participant buys all the pool at floor price.

      await this.LaunchEvent.connect(this.participant).depositAVAX({
        value: ethers.utils.parseEther("100.0"),
      });
      await advanceTimeAndBlock(duration.days(3));
      await this.LaunchEvent.createPair();

      await advanceTimeAndBlock(duration.days(8));

      const pairAddress = await this.factory.getPair(
        "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7",
        this.AUCTOK.address
      );
      const pair = await ethers.getContractAt(
        "IJoePair",
        pairAddress);

      const totalSupply = await pair.totalSupply()
      expect(totalSupply).to.equal(ethers.utils.parseEther("100"));

      const MINIMUM_LIQUIDITY = await pair.MINIMUM_LIQUIDITY();

      expect(
        await pair.balanceOf(this.LaunchEvent.address)
      ).to.equal(
        totalSupply.sub(MINIMUM_LIQUIDITY)
      );

      await this.LaunchEvent.connect(this.participant).withdrawLiquidity();
      await this.LaunchEvent.connect(this.issuer).withdrawLiquidity();
      expect(
        await pair.balanceOf(this.participant.address)
      ).to.equal(
        totalSupply.div(2).sub(MINIMUM_LIQUIDITY.div(2))
      );
      expect(
        await pair.balanceOf(this.issuer.address)
      ).to.equal(
        totalSupply.div(2).sub(MINIMUM_LIQUIDITY.div(2))
      );

    });

    it("should refund tokens if floor not met", async function () {

      await advanceTimeAndBlock(duration.seconds(120));

      // Participant buys half the pool, floor price not met.
      // There should be a refund of 50 tokens to issuer.
      await this.LaunchEvent.connect(this.participant).depositAVAX({
        value: ethers.utils.parseEther("50.0"),
      });
      await advanceTimeAndBlock(duration.days(3));
      await this.LaunchEvent.createPair();

      await advanceTimeAndBlock(duration.days(8));
      const pairAddress = await this.factory.getPair(
        "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7",
        this.AUCTOK.address
      );
      const pair = await ethers.getContractAt(
        "IJoePair",
        pairAddress);

      const totalSupply = await pair.totalSupply()
      expect(totalSupply).to.equal(ethers.utils.parseEther("50"));

      const MINIMUM_LIQUIDITY = await pair.MINIMUM_LIQUIDITY();

      expect(
        await pair.balanceOf(this.LaunchEvent.address)
      ).to.equal(
        totalSupply.sub(MINIMUM_LIQUIDITY)
      );

      await this.LaunchEvent.connect(this.participant).withdrawLiquidity();

      const tokenBalanceBefore = await this.AUCTOK.balanceOf(this.issuer.address);
      await this.LaunchEvent.connect(this.issuer).withdrawLiquidity();

      expect(
        await this.AUCTOK.balanceOf(this.issuer.address)
      ).to.equal(
        tokenBalanceBefore.add(ethers.utils.parseEther("50"))
      )
      expect(
        await pair.balanceOf(this.participant.address)
      ).to.equal(
        totalSupply.div(2).sub(MINIMUM_LIQUIDITY.div(2))
      );
      expect(
        await pair.balanceOf(this.issuer.address)
      ).to.equal(
        totalSupply.div(2).sub(MINIMUM_LIQUIDITY.div(2))
      );

    });

    it("should evenly distribute liquidity to issuer and participants if overly subscribed", async function () {

      this.participant2 = this.signers[4];
      await this.rJOE
        .connect(this.dev)
        .mint(this.participant2.address, ethers.utils.parseEther("10000"));

      await advanceTimeAndBlock(duration.seconds(120));

      // Participant buys all the pool at floor price.
      await this.LaunchEvent.connect(this.participant).depositAVAX({
        value: ethers.utils.parseEther("100.0"),
      });
      await this.LaunchEvent.connect(this.participant2).depositAVAX({
        value: ethers.utils.parseEther("100.0"),
      });

      await advanceTimeAndBlock(duration.days(3));
      await this.LaunchEvent.createPair();
      await advanceTimeAndBlock(duration.days(8));

      const pairAddress = await this.factory.getPair(
        "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7",
        this.AUCTOK.address
      );
      const pair = await ethers.getContractAt(
        "IJoePair",
        pairAddress);

      const totalSupply = await pair.totalSupply()
      expect(totalSupply).to.equal(
        "141421356237309504880"  // sqrt ( avax * token)
      );

      const MINIMUM_LIQUIDITY = await pair.MINIMUM_LIQUIDITY();

      expect(
        await pair.balanceOf(this.LaunchEvent.address)
      ).to.equal(
        totalSupply.sub(MINIMUM_LIQUIDITY)
      );

      await this.LaunchEvent.connect(this.participant).withdrawLiquidity();
      await this.LaunchEvent.connect(this.participant2).withdrawLiquidity();
      await this.LaunchEvent.connect(this.issuer).withdrawLiquidity();

      expect(
        await pair.balanceOf(this.participant.address)
      ).to.equal(
        totalSupply.div(4).sub(MINIMUM_LIQUIDITY.div(4))
      );
      expect(
        await pair.balanceOf(this.participant2.address)
      ).to.equal(
        totalSupply.div(4).sub(MINIMUM_LIQUIDITY.div(4))
      );
      expect(
        await pair.balanceOf(this.issuer.address)
      ).to.equal(
        totalSupply.div(2).sub(MINIMUM_LIQUIDITY.div(2))
      );
    });
  });

  after(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    });
  });
});
