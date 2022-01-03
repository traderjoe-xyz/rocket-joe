const { ethers, network } = require("hardhat");
const { expect } = require("chai");

describe("Launch Event Contract", function () {
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
    WAVAX = "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7";
    PENALTY_COLLECTOR = this.carol.address;
    ROUTER = "0x60aE616a2155Ee3d9A68541Ba4544862310933d4";
    FACTORY = "0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10";

    this.RocketJoeTokenCF = await ethers.getContractFactory("RocketJoeToken");
    this.rJOE = await this.RocketJoeTokenCF.deploy();
    this.rJOE2 = await this.RocketJoeTokenCF.deploy();
    await this.rJOE
      .connect(this.dev)
      .mint(this.dev.address, "1000000000000000000000000");
    await this.rJOE2
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
    await this.rJOE2
      .connect(this.dev)
      .approve(this.RocketFactory.address, "1000000000000000000000000");
  });

  describe("Initialising the contract", function () {
    it("should revert initialisation if token address is 0", async function () {
      await expect(
        this.RocketFactory.createRJLaunchEvent(
          ethers.constants.AddressZero,
          Math.floor(Date.now() / 1000),
          ethers.constants.AddressZero,
          100,
          1,
          1,
          1,
          100,
          10000,
          60,
          120
        )
      ).to.be.revertedWith("RocketJoeFactory: Token can't be null address");
    });

    it("should revert initialisation if issuer is not set", async function () {
      await expect(
        this.RocketFactory.createRJLaunchEvent(
          ethers.constants.AddressZero,
          Math.floor(Date.now() / 1000),
          this.rJOE2.address,
          100,
          1,
          1,
          1,
          100,
          10000,
          60,
          120
        )
      ).to.be.revertedWith("LaunchEvent: Issuer can't be null address");
    });

    it("should revert initialisation if start time is in the past", async function () {
      await expect(
        this.RocketFactory.createRJLaunchEvent(
          this.alice.address,
          Math.floor(Date.now() / 1000) - 60 * 60 * 24,
          this.rJOE2.address,
          100,
          1,
          1,
          1,
          100,
          10000,
          60,
          120
        )
      ).to.be.revertedWith(
        "LaunchEvent: Phase 1 needs to start after the current timestamp"
      );
    });

    it("should revert initialisation if token is wavax", async function () {
      await expect(
        this.RocketFactory.createRJLaunchEvent(
          this.alice.address,
          Math.floor(Date.now() / 1000),
          "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7",
          100,
          1,
          1,
          1,
          100,
          10000,
          60,
          120
        )
      ).to.be.revertedWith("RocketJoeFactory: Token can't be wavax");
    });

    it("should revert initialisation if launch pair already exists (USDC)", async function () {
      await expect(
        this.RocketFactory.createRJLaunchEvent(
          this.alice.address,
          Math.floor(Date.now() / 1000),
          "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E",
          100,
          1,
          1,
          1,
          100,
          10000,
          60,
          120
        )
      ).to.be.revertedWith("RocketJoeFactory: Pair already exists");
    });

    it("should revert initialisation if withdraw penalty gradient is too high", async function () {
      await expect(
        this.RocketFactory.createRJLaunchEvent(
          this.alice.address,
          Math.floor(Date.now() / 1000) + 60,
          this.rJOE2.address,
          100,
          1,
          2893519,
          1,
          100,
          10000,
          60,
          120
        )
      ).to.be.revertedWith("LaunchEvent: withdrawPenatlyGradient too big");
    });

    it("should revert initialisation if fixed withdraw penalty is too high", async function () {
      await expect(
        this.RocketFactory.createRJLaunchEvent(
          this.alice.address,
          Math.floor(Date.now() / 1000) + 60,
          this.rJOE2.address,
          100,
          1,
          2893517,
          6e11,
          100,
          10000,
          60,
          120
        )
      ).to.be.revertedWith("LaunchEvent: fixedWithdrawPenalty too big");
    });

    it("should revert initialisation if max allocation is greater than min", async function () {
      await expect(
        this.RocketFactory.createRJLaunchEvent(
          this.alice.address,
          Math.floor(Date.now() / 1000) + 60,
          this.rJOE2.address,
          100,
          1,
          2893517,
          4e11,
          10001,
          10000,
          60,
          120
        )
      ).to.be.revertedWith(
        "LaunchEvent: Max allocation needs to be greater than min"
      );
    });

    it("should revert initialisation if user timelock is too long", async function () {
      await expect(
        this.RocketFactory.createRJLaunchEvent(
          this.alice.address,
          Math.floor(Date.now() / 1000) + 60,
          this.rJOE2.address,
          100,
          1,
          2893517,
          4e11,
          5000,
          10000,
          60 * 60 * 24 * 8,
          120
        )
      ).to.be.revertedWith(
        "LaunchEvent: Can't lock user LP for more than 7 days"
      );
    });

    it("should revert initialisation if issuer timelock is before user", async function () {
      await expect(
        this.RocketFactory.createRJLaunchEvent(
          this.alice.address,
          Math.floor(Date.now() / 1000) + 60,
          this.rJOE2.address,
          100,
          1,
          2893517,
          4e11,
          5000,
          10000,
          60 * 60 * 24 * 6,
          60 * 60 * 24 * 5
        )
      ).to.be.revertedWith(
        "LaunchEvent: Issuer can't withdraw their LP before everyone"
      );
    });

    it("should deploy with correct paramaters", async function () {
      this.RocketFactory.createRJLaunchEvent(
        this.alice.address,
        Math.floor(Date.now() / 1000) + 60,
        this.rJOE2.address,
        100,
        1,
        2893517,
        4e11,
        5000,
        10000,
        60 * 60 * 24 * 7 - 1,
        60 * 60 * 24 * 8
      );
    });
  });

  describe("Interacting with phase one", function () {
    it("should revert if cant transfer rJOE", async function () {});
    it("should revert if AVAX sent less than min allocation", async function () {});
    it("should revert if AVAX sent more than max allocation", async function () {});
    it("should burn rJOE on succesful deposit", async function () {});
    it("should revert if second deposit is above max allocation", async function () {});
    it("should revert if we withdraw during phase one", async function () {});
    it("should revert try to create pool during phase one", async function () {});
  });

  describe("Interacting with phase two", function () {
    it("should revert try to create pool during phase two", async function () {});
  });

  describe("Interacting with phase three", function () {
    it("should revert if users withdraws before timelock", async function () {});
    it("should revert if issuer withdraws before timelock", async function () {});
    it("should revert when timelock finishes", async function () {});
    it("should create the pair", async function () {});
    it("should revert if the pair is already created", async function () {});
  });

  describe("The penalty structure", function () {
    it("should be static for the first day", function () {});
    it("should be linear for second day", function () {});
  });

  after(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    });
  });
});
