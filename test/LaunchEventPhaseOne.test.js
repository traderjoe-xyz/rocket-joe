const { ethers, network } = require("hardhat");
const { expect } = require("chai");
const { duration, increase } = require("./utils/time");

describe("Launch event contract phase one", function () {
  before(async function () {
    this.signers = await ethers.getSigners();
    this.dev = this.signers[0];
    this.alice = this.signers[1];
    this.bob = this.signers[2];
    this.carol = this.signers[3];

    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: "https://api.avax.network/ext/bc/C/rpc",
            // blockNumber: 8465376,
          },
          live: false,
          saveDeployments: true,
          tags: ["test", "local"],
        },
      ],
    });
  });

  beforeEach(async function () {
    // We want to setup
    // The Rocket factory contract
    // A new ERC20 for the auction
    // rocket-joe token
    this.WAVAX = "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7";
    this.wavax = ethers.getContractAt("IWAVAX", this.WAVAX);
    this.PENALTY_COLLECTOR = this.carol.address;
    this.ROUTER = "0x60aE616a2155Ee3d9A68541Ba4544862310933d4";
    this.FACTORY = "0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10";

    this.LaunchEventCF = await ethers.getContractFactory("LaunchEvent");
    this.LaunchEventPrototype = await this.LaunchEventCF.deploy();

    this.RocketJoeTokenCF = await ethers.getContractFactory("RocketJoeToken");
    this.rJOE = await this.RocketJoeTokenCF.deploy();
    this.AUCTOK = await this.RocketJoeTokenCF.deploy();
    // Send rJOE to dev address
    await this.rJOE
      .connect(this.dev)
      .mint(this.dev.address, "1000000000000000000000000");

    await this.rJOE
      .connect(this.dev)
      .mint(this.bob.address, ethers.utils.parseEther("1000.0"));

    // Send auction token to the dev.
    await this.AUCTOK.connect(this.dev).mint(
      this.dev.address,
      "1000000000000000000000000"
    );

    this.LaunchEventCF = await ethers.getContractFactory("LaunchEvent");
    this.RocketFactoryCF = await ethers.getContractFactory("RocketJoeFactory");
    this.RocketFactory = await this.RocketFactoryCF.deploy(
      this.LaunchEventPrototype.address,
      this.rJOE.address,
      this.WAVAX,
      this.PENALTY_COLLECTOR,
      this.ROUTER,
      this.FACTORY
    );
    this.LaunchEventPrototype.connect(this.dev).transferOwnership(
      this.RocketFactory.address
    );

    await this.AUCTOK.connect(this.dev).approve(
      this.RocketFactory.address,
      "1000000000000000000000000"
    );

    // Deploy the launch event contract
    block = await ethers.provider.getBlock();
    await this.RocketFactory.createRJLaunchEvent(
      this.alice.address, // Issuer
      block.timestamp + 60, // Start time (60 seconds from now)
      this.AUCTOK.address, // Address of the token being auctioned
      100, // Floor price (100 Wei)
      1000, // Amount of tokens for auction
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

  describe("Interacting with phase one", function () {
    it("should revert if initialised twice", async function () {
      expect(
        this.LaunchEvent.connect(this.bob).initialize(
          this.bob.address, // _issuer
          block.timestamp, // _auctionStart
          this.AUCTOK.address, // _token
          0, // _floorPrice
          0, // _maxWithdrawPenalty
          0, // _fixedWithdrawPenalty
          0, // _minAllocation
          0, // _maxAllocation
          0, // _userTimelock
          0 // _issuerTimelock
        )
      ).to.be.revertedWith("LaunchEvent: already initialized");
    });

    it("should revert if issuer tries to participate", async function () {
      increase(duration.seconds(120));

      expect(
        this.LaunchEvent.connect(this.alice).depositAVAX({
          value: ethers.utils.parseEther("1.0"),
        })
      ).to.be.revertedWith("LaunchEvent: issuer cannot participate");
    });

    it("should revert if sale has not started yet", async function () {
      expect(
        this.LaunchEvent.connect(this.bob).depositAVAX({
          value: ethers.utils.parseEther("1.0"),
        })
      ).to.be.revertedWith("LaunchEvent: not in phase one");
    });

    it("should revert if rJOE not approved", async function () {
      increase(duration.seconds(120));

      expect(
        this.LaunchEvent.connect(this.bob).depositAVAX({
          value: ethers.utils.parseEther("1.0"),
        })
      ).to.be.revertedWith("ERC20: transfer amount exceeds allowance");
    });

    it("should be payable with AVAX", async function () {
      increase(duration.seconds(120));

      await this.rJOE
        .connect(this.bob)
        .approve(this.LaunchEvent.address, ethers.utils.parseEther("100.0"));
      await this.LaunchEvent.connect(this.bob).depositAVAX({
        value: ethers.utils.parseEther("1.0"),
      });
      expect(
        this.LaunchEvent.getUserAllocation(this.bob.address).amount
      ).to.equal(ethers.utils.parseEther("1.0").number);
    });

    it("should revert if AVAX sent less than min allocation", async function () {
      increase(duration.seconds(120));

      await this.rJOE.connect(this.bob).approve(this.LaunchEvent.address, 4999);
      expect(
        this.LaunchEvent.connect(this.bob).depositAVAX({ value: 4999 })
      ).to.be.revertedWith(
        "LaunchEvent: amount doesn't fulfill min allocation"
      );
    });

    it("should only be stopped by RJFactory owner", async function () {
      // issuer of the LaunchEvent
      await expect(
        this.LaunchEvent.connect(this.alice).allowEmergencyWithdraw()
      ).to.be.revertedWith("LaunchEvent: caller is not RocketJoeFactory owner");

      // any user
      expect(
        this.LaunchEvent.connect(this.bob).allowEmergencyWithdraw()
      ).to.be.revertedWith("LaunchEvent: caller is not RocketJoeFactory owner");
    });

    it("should revert if stopped", async function () {
      increase(duration.seconds(120));

      await this.rJOE
        .connect(this.bob)
        .approve(this.LaunchEvent.address, 6000 * 100);
      await this.LaunchEvent.connect(this.dev).allowEmergencyWithdraw();
      expect(
        this.LaunchEvent.connect(this.bob).depositAVAX({ value: 6000 })
      ).to.be.revertedWith("LaunchEvent: stopped");
    });

    it("should revert if trying to emergency withdraw with 0 allocation", async function () {
      await this.LaunchEvent.connect(this.dev).allowEmergencyWithdraw();

      // any user
      expect(
        this.LaunchEvent.connect(this.bob).emergencyWithdraw()
      ).to.be.revertedWith(
        "LaunchEvent: expected user to have non-zero allocation to perform emergency withdraw"
      );
    });

    it("should revert if AVAX sent more than max allocation", async function () {
      increase(duration.seconds(120));

      await this.rJOE
        .connect(this.bob)
        .approve(this.LaunchEvent.address, ethers.utils.parseEther("6"));
      expect(
        this.LaunchEvent.connect(this.bob).depositAVAX({
          value: ethers.utils.parseEther("6"),
        })
      ).to.be.revertedWith("LaunchEvent: amount exceeds max allocation");
    });

    it("should burn rJOE on succesful deposit", async function () {
      let rJOEBefore = await this.rJOE.totalSupply();

      increase(duration.seconds(120));

      await this.rJOE
        .connect(this.bob)
        .approve(this.LaunchEvent.address, ethers.utils.parseEther("100.0"));

      await this.LaunchEvent.connect(this.bob).depositAVAX({
        value: ethers.utils.parseEther("1.0"),
      });

      expect(await this.rJOE.totalSupply()).to.be.equal(
        rJOEBefore.sub(ethers.utils.parseEther("100.0"))
      );
    });

    it("should apply no fee if withdraw in first day", async function () {
      increase(duration.seconds(120));

      await this.rJOE
        .connect(this.bob)
        .approve(this.LaunchEvent.address, ethers.utils.parseEther("100.0"));

      await this.LaunchEvent.connect(this.bob).depositAVAX({
        value: ethers.utils.parseEther("1.0"),
      });

      // Test the amount received
      const balanceBefore = await this.bob.getBalance();
      await this.LaunchEvent.connect(this.bob).withdrawAVAX(
        ethers.utils.parseEther("1.0")
      );
      expect(await this.bob.getBalance()).to.be.above(balanceBefore);
      // Check the balance of penalty collecter.
      expect(await this.carol.getBalance()).to.equal("10000000000000000000000");
    });

    it("should apply gradient fee if withdraw in second day", async function () {
      increase(duration.seconds(120));

      await this.rJOE
        .connect(this.bob)
        .approve(this.LaunchEvent.address, ethers.utils.parseEther("100.0"));

      await this.LaunchEvent.connect(this.bob).depositAVAX({
        value: ethers.utils.parseEther("1.0"),
      });

      increase(duration.hours(36));

      await this.LaunchEvent.connect(this.bob).withdrawAVAX(
        ethers.utils.parseEther("1.0")
      );

      // Check the balance of penalty collecter.
      expect(await this.carol.getBalance()).to.be.above(
        "10000000000000000000000"
      );
    });

    it("should revert try to create pool during phase one", async function () {
      increase(duration.seconds(120));

      expect(
        this.LaunchEvent.connect(this.dev).createPair()
      ).to.be.revertedWith("LaunchEvent: not in phase three");
    });

    it("should revert trying to send AVAX to the contract", async function () {
      await expect(
        this.bob.sendTransaction({
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
