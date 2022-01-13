const { ethers, network } = require("hardhat");
const { expect } = require("chai");
const { advanceTimeAndBlock, duration } = require("./utils/time");
const { HARDHAT_FORK_CURRENT_PARAMS } = require("./utils/hardhat")

describe("launch event contract phase one", function () {

  before(async function () {

    // The wallets taking part in tests.
    this.signers = await ethers.getSigners();
    this.dev = this.signers[0];
    this.penaltyCollector = this.signers[1];
    this.issuer = this.signers[2];
    this.participant = this.signers[3];

    // The contracts we interact with.
    this.wavax = await ethers.getContractAt(
      "IWAVAX",
      "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7"
    );
    this.router = await ethers.getContractAt(
      "IJoeRouter02",
      "0x60aE616a2155Ee3d9A68541Ba4544862310933d4"
    );
    this.factory = await ethers.getContractAt(
      "IJoeFactory",
      "0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10"
    );

    // Factories for deploying our contracts.
    this.RocketJoeTokenCF = await ethers.getContractFactory("RocketJoeToken");
    this.RocketJoeFactoryCF = await ethers.getContractFactory(
      "RocketJoeFactory"
    );
    this.LaunchEventCF = await ethers.getContractFactory("LaunchEvent");

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
    this.AUCTOK = await this.RocketJoeTokenCF.deploy();

    // Deploy the rocket joe contracts.
    this.LaunchEventPrototype = await this.LaunchEventCF.deploy();
    this.RocketFactory = await this.RocketJoeFactoryCF.deploy(
      this.LaunchEventPrototype.address,
      this.rJOE.address,
      this.wavax.address,
      this.penaltyCollector.address,
      this.router.address,
      this.factory.address
    );
    await this.LaunchEventPrototype.connect(this.dev).transferOwnership(
      this.RocketFactory.address
    );

    // Keep a reference to the current block.
    this.block = await ethers.provider.getBlock();

    // Send the tokens used to the issuer and approve spending to the factory.
    await this.AUCTOK.connect(this.dev).mint(
      this.dev.address,
      ethers.utils.parseEther("1000000")
    ); // 1_000_000 tokens
    await this.AUCTOK.connect(this.dev).approve(
      this.RocketFactory.address,
      ethers.utils.parseEther("1000000")
    );
    await this.rJOE.connect(this.dev).mint(
      this.participant.address,
      ethers.utils.parseEther("1000000")
    ); // 1_000_000 tokens

    // Deploy the launch event contract
    await this.RocketFactory.createRJLaunchEvent(
      this.issuer.address, // Issuer
      this.block.timestamp + 60, // Start time (60 seconds from now)
      this.AUCTOK.address, // Address of the token being auctioned
      1000000, // Amount of tokens for auction
      1000, // Floor price (100 Wei)
      ethers.utils.parseEther("0.5"), // Max withdraw penalty
      ethers.utils.parseEther("0.4"), // Fixed withdraw penalty
      5000, // min allocation
      ethers.utils.parseEther("5.0"), // max allocation
      60 * 60 * 24 * 7, // User timelock
      60 * 60 * 24 * 8 // Issuer timelock
    );

    // Get a reference to the acutal launch event contract.
    this.LaunchEvent = await ethers.getContractAt(
      "LaunchEvent",
      this.RocketFactory.getRJLaunchEvent(this.AUCTOK.address)
    );
  });

  describe("interacting with phase one", function () {

	describe("depositing in phase one", function () {
      it("should revert if issuer tries to participate", async function () {
        await advanceTimeAndBlock(duration.seconds(120));
        expect(
          this.LaunchEvent.connect(this.issuer).depositAVAX({
            value: ethers.utils.parseEther("1.0"),
          })
        ).to.be.revertedWith("LaunchEvent: issuer cannot participate");
      });

      it("should revert if sale has not started yet", async function () {
        expect(
          this.LaunchEvent.connect(this.participant).depositAVAX({
            value: ethers.utils.parseEther("1.0"),
          })
        ).to.be.revertedWith("LaunchEvent: not in phase one");
      });

      it("should revert if rJOE not approved", async function () {
        await advanceTimeAndBlock(duration.seconds(120));
        expect(
          this.LaunchEvent.connect(this.participant).depositAVAX({
            value: ethers.utils.parseEther("1.0"),
          })
        ).to.be.revertedWith("ERC20: transfer amount exceeds allowance");
      });

      it("should be payable with AVAX", async function () {
        await advanceTimeAndBlock(duration.seconds(120));
        await this.rJOE
          .connect(this.participant)
          .approve(this.LaunchEvent.address, ethers.utils.parseEther("100.0"));
        await this.LaunchEvent.connect(this.participant).depositAVAX({
          value: ethers.utils.parseEther("1.0"),
        });
        expect(
          this.LaunchEvent.getUserAllocation(this.participant.address).amount
        ).to.equal(ethers.utils.parseEther("1.0").number);
      });

      it("should revert if AVAX sent less than min allocation", async function () {
        await advanceTimeAndBlock(duration.seconds(120));
        await this.rJOE.connect(this.participant).approve(this.LaunchEvent.address, 4999);
        expect(
          this.LaunchEvent.connect(this.participant).depositAVAX({ value: 4999 })
        ).to.be.revertedWith(
          "LaunchEvent: amount doesn't fulfill min allocation"
        );
      });

      it("should revert on deposit if stopped", async function () {
        await advanceTimeAndBlock(duration.seconds(120));
        await this.rJOE
          .connect(this.participant)
          .approve(this.LaunchEvent.address, 6000 * 100);
        await this.LaunchEvent.connect(this.dev).allowEmergencyWithdraw();
        expect(
          this.LaunchEvent.connect(this.participant).depositAVAX({ value: 6000 })
        ).to.be.revertedWith("LaunchEvent: stopped");
      });

      it("should revert if AVAX sent more than max allocation", async function () {
        await advanceTimeAndBlock(duration.seconds(120));
        await this.rJOE
          .connect(this.participant)
          .approve(this.LaunchEvent.address, ethers.utils.parseEther("6"));
        expect(
          this.LaunchEvent.connect(this.participant).depositAVAX({
            value: ethers.utils.parseEther("6"),
          })
        ).to.be.revertedWith("LaunchEvent: amount exceeds max allocation");
      });

      it("should burn rJOE on succesful deposit", async function () {
        let rJOEBefore = await this.rJOE.totalSupply();

        await advanceTimeAndBlock(duration.seconds(120));
        await this.rJOE
          .connect(this.participant)
          .approve(this.LaunchEvent.address, ethers.utils.parseEther("100.0"));

        await this.LaunchEvent.connect(this.participant).depositAVAX({
          value: ethers.utils.parseEther("1.0"),
        });

        expect(await this.rJOE.totalSupply()).to.be.equal(
          rJOEBefore.sub(ethers.utils.parseEther("100.0"))
        );
      });

	});

	describe("withdrawing in phase one", function () {

      beforeEach(async function () {
        await advanceTimeAndBlock(duration.seconds(120));
        await this.rJOE
          .connect(this.participant)
          .approve(this.LaunchEvent.address, ethers.utils.parseEther("100.0"));
        await this.LaunchEvent.connect(this.participant).depositAVAX({
          value: ethers.utils.parseEther("1.0"),
        });
      });

      it("should apply no fee if withdraw in first day", async function () {
        // Test the amount received
        const balanceBefore = await this.participant.getBalance();
        await this.LaunchEvent.connect(this.participant).withdrawAVAX(
          ethers.utils.parseEther("1.0")
        );
        expect(await this.participant.getBalance()).to.be.above(balanceBefore);
        // Check the balance of penalty collecter.
        expect(await this.penaltyCollector.getBalance()).to.equal(
	    	  ethers.utils.parseEther("10000")
	      );
      });

      it("should apply gradient fee if withdraw in second day", async function () {
        await advanceTimeAndBlock(duration.hours(36));
        await this.LaunchEvent.connect(this.participant).withdrawAVAX(
          ethers.utils.parseEther("1.0")
        );

        // Check the balance of penalty collecter.
        expect(await this.penaltyCollector.getBalance()).to.be.above(
          ethers.utils.parseEther("10000")
        );
      });

	  });

    it("should only be stopped by RJFactory owner", async function () {
      // issuer of the LaunchEvent
      await expect(
        this.LaunchEvent.connect(this.issuer).allowEmergencyWithdraw()
      ).to.be.revertedWith("LaunchEvent: caller is not RocketJoeFactory owner");

      // any user
      await expect(
        this.LaunchEvent.connect(this.participant).allowEmergencyWithdraw()
      ).to.be.revertedWith("LaunchEvent: caller is not RocketJoeFactory owner");
    });

    it("should revert try to create pool during phase one", async function () {
      await advanceTimeAndBlock(duration.seconds(120));
      expect(
        this.LaunchEvent.connect(this.dev).createPair()
      ).to.be.revertedWith("LaunchEvent: not in phase three");
    });

    it("should revert trying to send AVAX to the contract", async function () {
      await expect(
        this.participant.sendTransaction({
          to: this.LaunchEvent.address,
          value: ethers.utils.parseEther("1.0"),
        })
      ).to.be.revertedWith(
        "LaunchEvent: you can't send AVAX directly to this contract"
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
