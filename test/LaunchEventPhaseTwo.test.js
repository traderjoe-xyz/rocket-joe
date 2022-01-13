const { ethers, network } = require("hardhat");
const { expect } = require("chai");

describe("Launch event contract phase two", function () {
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
      ethers.utils.parseEther("0.5").sub("1"), // Max withdraw penalty
      ethers.utils.parseEther("0.4"), // Fixed withdraw penalty
      5000, // min allocation
      ethers.utils.parseEther("5.0"), // max allocation
      60 * 60 * 24 * 7 - 1, // User timelock
      60 * 60 * 24 * 8 // Issuer timelock
    );

    // Get a reference to the acutal launch event contract.
    this.LaunchEvent = await ethers.getContractAt(
      "LaunchEvent",
      this.RocketFactory.getRJLaunchEvent(this.AUCTOK.address)
    );

    await network.provider.send("evm_increaseTime", [120]);
    await network.provider.send("evm_mine");
    await this.rJOE
      .connect(this.bob)
      .approve(this.LaunchEvent.address, ethers.utils.parseEther("100.0"));
    await this.LaunchEvent.connect(this.bob).depositAVAX({
      value: ethers.utils.parseEther("1.0"),
    });
    expect(
      this.LaunchEvent.getUserAllocation(this.bob.address).amount
    ).to.equal(ethers.utils.parseEther("1.0").number);
    // increase time by 3 days.
    await network.provider.send("evm_increaseTime", [60 * 60 * 24 * 3]);
    await network.provider.send("evm_mine");
  });

  describe("Interacting with phase two", function () {
    it("should revert if try do withdraw liquidity", async function () {
      expect(
        this.LaunchEvent.connect(this.bob).withdrawLiquidity()
      ).to.be.revertedWith(
        "LaunchEvent: can't withdraw before user's timelock"
      );
    });

    it("should revert if deposited", async function () {
      await this.rJOE
        .connect(this.bob)
        .approve(this.LaunchEvent.address, ethers.utils.parseEther("100.0"));
      expect(
        this.LaunchEvent.connect(this.bob).depositAVAX({
          value: ethers.utils.parseEther("1.0"),
        })
      ).to.be.revertedWith("LaunchEvent: not in phase one");
    });

    it("should revert try to create pool", async function () {
      expect(
        this.LaunchEvent.connect(this.bob).createPair()
      ).to.be.revertedWith("LaunchEvent: not in phase three");
    });

    it("should charge a fixed withdraw penalty", async function () {
      await this.LaunchEvent.connect(this.bob).withdrawAVAX(
        ethers.utils.parseEther("1.0")
      );
      expect(await this.carol.getBalance()).to.be.above(
        "1000040000000000000000"
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
