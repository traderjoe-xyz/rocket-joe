const { ethers, network } = require("hardhat");
const { expect } = require("chai");

const HARDHAT_FORK_CURRENT_PARAMS = [
  {
    forking: {
      jsonRpcUrl: "https://api.avax.network/ext/bc/C/rpc",
    },
    live: false,
    saveDeployments: true,
    tags: ["test", "local"],
  },
];

describe("launch event contract initialisation", function () {
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

    // Valid initialization parameters for `createRJLaunchEvent` used as
    // base arguments when we want to check reversions for specific values.
    this.validParams = {
      _issuer: this.issuer.address,
      _auctionStart: this.block.timestamp + 60,
      _token: this.AUCTOK.address,
      _tokenAmount: 100,
      _floorPrice: 1,
      _withdrawPenaltyGradient: 2893517,
      _fixedWithdrawPenalty: 4e11,
      _minAllocation: 100,
      _maxAllocation: 100,
      _userTimelock: 60 * 60 * 24 * 7,
      _issuerTimelock: 60 * 60 * 24 * 8,
    };
  });

  describe("initialising the contract", function () {
    const testReverts = async (factory, args, message) => {
      await expect(
        factory.createRJLaunchEvent(
          args._issuer,
          args._auctionStart,
          args._token,
          args._tokenAmount,
          args._floorPrice,
          args._withdrawPenaltyGradient,
          args._fixedWithdrawPenalty,
          args._minAllocation,
          args._maxAllocation,
          args._userTimelock,
          args._issuerTimelock
        )
      ).to.be.revertedWith(message);
    };

    it("should revert if token address is 0", async function () {
      const args = {
        ...this.validParams,
        _token: ethers.constants.AddressZero,
      };
      await testReverts(
        this.RocketFactory,
        args,
        "RJFactory: token can't be 0 address"
      );
    });

    it("should revert if startime has elapsed", async function () {
      const args = {
        ...this.validParams,
        _auctionStart: this.block.timestamp - 1,
      };
      await testReverts(
        this.RocketFactory,
        args,
        "LaunchEvent: phase 1 has not started"
      );
    });

    it("should revert if token is wavax", async function () {
      const args = {
        ...this.validParams,
        _token: this.wavax.address,
      };
      await testReverts(
        this.RocketFactory,
        args,
        "RJFactory: token can't be wavax"
      );
    });

    it("should revert initialisation if launch pair already exists (USDC)", async function () {
      const args = {
        ...this.validParams,
        _token: "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E",
      };
      await testReverts(
        this.RocketFactory,
        args,
        "RJFactory: pair already exists"
      );
    });

    it("should revert if max withdraw penalty is too high", async function () {
      const args = {
        ...this.validParams,
        _withdrawPenaltyGradient: ethers.utils.parseEther("0.5").add("1"),
      };
      await testReverts(
        this.RocketFactory,
        args,
        "LaunchEvent: maxWithdrawPenalty too big"
      );
    });

    it("should revert if fixed withdraw penalty is too high", async function () {
      const args = {
        ...this.validParams,
        _fixedWithdrawPenalty: ethers.utils.parseEther("0.5").add("1"),
      };
      await testReverts(
        this.RocketFactory,
        args,
        "LaunchEvent: fixedWithdrawPenalty too big"
      );
    });

    it("should revert if min allocation is greater than max", async function () {
      const args = {
        ...this.validParams,
        _minAllocation: 1001,
        _maxAllocation: 1000,
      };
      await testReverts(
        this.RocketFactory,
        args,
        "LaunchEvent: max allocation less than min"
      );
    });

    it("should revert initialisation if user timelock is too long", async function () {
      const args = {
        ...this.validParams,
        _userTimelock: 60 * 60 * 24 * 7 + 1,
      };
      await testReverts(
        this.RocketFactory,
        args,
        "LaunchEvent: can't lock user LP for more than 7 days"
      );
    });

    it("should revert initialisation if issuer timelock is before user", async function () {
      const args = {
        ...this.validParams,
        _userTimelock: 60 * 60 * 24 * 7,
        _issuerTimelock: 60 * 60 * 24 * 7 - 1,
      };
      await testReverts(
        this.RocketFactory,
        args,
        "LaunchEvent: issuer can't withdraw before users"
      );
    });

    it("should deploy with correct paramaters", async function () {
      await expect(
        this.RocketFactory.createRJLaunchEvent(
          this.validParams._issuer,
          this.validParams._auctionStart,
          this.validParams._token,
          this.validParams._tokenAmount,
          this.validParams._floorPrice,
          this.validParams._withdrawPenaltyGradient,
          this.validParams._fixedWithdrawPenalty,
          this.validParams._minAllocation,
          this.validParams._maxAllocation,
          this.validParams._userTimelock,
          this.validParams._issuerTimelock
        )
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
