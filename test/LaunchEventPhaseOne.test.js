const { ethers, network } = require("hardhat");
const { expect } = require("chai");


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
    WAVAX = "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7";
    PENALTY_COLLECTOR = this.carol.address;
    ROUTER = "0x60aE616a2155Ee3d9A68541Ba4544862310933d4";
    FACTORY = "0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10";

    this.RocketJoeTokenCF = await ethers.getContractFactory("RocketJoeToken");
    this.rJOE = await this.RocketJoeTokenCF.deploy();
    this.AUCTOK = await this.RocketJoeTokenCF.deploy();
    // Send rJOE to dev address
    await this.rJOE
      .connect(this.dev)
      .mint(this.dev.address, "1000000000000000000000000");

    await this.rJOE
      .connect(this.dev)
      .mint(this.bob.address, ethers.utils.parseEther("10.0"));

    // Send auction token to the dev.
    await this.AUCTOK
      .connect(this.dev)
      .mint(this.dev.address, "1000000000000000000000000");

    this.LaunchEventCF = await ethers.getContractFactory("LaunchEvent");
    this.RocketFactoryCF = await ethers.getContractFactory("RocketJoeFactory");
    this.RocketFactory = await this.RocketFactoryCF.deploy(
      this.rJOE.address,
      WAVAX,
      PENALTY_COLLECTOR,
      ROUTER,
      FACTORY
    );
    await this.AUCTOK
      .connect(this.dev)
      .approve(this.RocketFactory.address, "1000000000000000000000000");

    // Deploy the launch event contract
    block = await ethers.provider.getBlock()
    await this.RocketFactory.createRJLaunchEvent(
      this.alice.address,                          // Issuer
      block.timestamp + 60,                        // Start time (60 seconds from now)
      this.AUCTOK.address,                         // Address of the token being auctioned
      100,                                         // Floor price (100 Wei)
      1000,                                        // Amount of tokens for auction
      2893517,                                     // Withdraw penalty gradient
      4e11,                                        // Fixed withdraw penalty
      5000,                                        // min allocation
      ethers.utils.parseEther("5.0"),              // max allocation
      60 * 60 * 24 * 7 - 1,                        // User timelock
      60 * 60 * 24 * 8                             // Issuer timelock
    );

    // Get a reference to the acutal launch event contract.
    this.LaunchEvent = await ethers.getContractAt(
      "LaunchEvent",
      this.RocketFactory.getRJLaunchEvent(this.AUCTOK.address)
    )
  });

  describe("Interacting with phase one", function () {
    it("It should revert if sale has not started yet", async function () {
      expect(
        this.LaunchEvent.connect(this.bob).depositAVAX({value: ethers.utils.parseEther("1.0")})
      ).to.be.revertedWith("LaunchEvent: Not in phase one")
    });

    it("It should revert if rJOE not approved", async function () {
      await network.provider.send("evm_increaseTime", [120])
      await network.provider.send("evm_mine")
      expect(
        this.LaunchEvent.connect(this.bob).depositAVAX({value: ethers.utils.parseEther("1.0")})
      ).to.be.revertedWith("ERC20: transfer amount exceeds allowance")
    });

    it("should be payable with AVAX", async function () {
      await network.provider.send("evm_increaseTime", [120])
      await network.provider.send("evm_mine")
      expect(
        this.LaunchEvent.connect(this.bob).depositAVAX({value: ethers.utils.parseEther("1.0")})
      ).to.be.revertedWith("ERC20: transfer amount exceeds allowance")

    });
    it("should be payable with WAVAX", async function () {
      await network.provider.send("evm_increaseTime", [120])
      await network.provider.send("evm_mine")
      await this.rJOE.connect(this.bob).approve(
        this.LaunchEvent.address, ethers.utils.parseEther("1.0"))
      expect(
        this.LaunchEvent.connect(this.bob).depositAVAX({value: ethers.utils.parseEther("1.0")})
      ).to.changeTokenBalance(this.rJOE, this.bob, ethers.utils.parseEther("1.0"))
    });

    it("should revert if AVAX sent less than min allocation", async function () {
      await network.provider.send("evm_increaseTime", [120])
      await network.provider.send("evm_mine")
      await this.rJOE.connect(this.bob).approve(
        this.LaunchEvent.address, 4999)
      expect(
        this.LaunchEvent.connect(this.bob).depositAVAX({value: 4999})
      ).to.be.revertedWith('min alloc')
    });
    it("should revert if AVAX sent more than max allocation", async function () {});
    it("should burn rJOE on succesful deposit", async function () {});
    it("should revert if second deposit is above max allocation", async function () {});
    it("should revert if we withdraw during phase one", async function () {});
    it("should revert try to create pool during phase one", async function () {});
  });

  after(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    });
  });
});


