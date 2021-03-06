const { ethers, network } = require("hardhat");
const { expect } = require("chai");
const { HARDHAT_FORK_CURRENT_PARAMS } = require("./utils/hardhat");
const {
  getWavax,
  getJoeFactory,
  deployRocketFactory,
  createLaunchEvent,
} = require("./utils/contracts");

describe("launch event contract initialisation", function () {
  before(async function () {
    // The wallets taking part in tests.
    this.signers = await ethers.getSigners();
    this.dev = this.signers[0];
    this.penaltyCollector = this.signers[1];
    this.issuer = this.signers[2];
    this.participant = this.signers[3];
    this.factory = await getJoeFactory();
    this.wavax = await getWavax();

    this.RocketJoeTokenCF = await ethers.getContractFactory("RocketJoeToken");
    this.ERC20TokenCF = await ethers.getContractFactory("ERC20Token");

    await network.provider.request({
      method: "hardhat_reset",
      params: HARDHAT_FORK_CURRENT_PARAMS,
    });
  });

  beforeEach(async function () {
    // Deploy the tokens used for tests.
    this.rJOE = await this.RocketJoeTokenCF.deploy();
    this.AUCTOK = await this.ERC20TokenCF.deploy();

    this.RocketFactory = await deployRocketFactory(
      this.dev,
      this.rJOE,
      this.penaltyCollector
    );

    // Keep a reference to the current block.
    this.block = await ethers.provider.getBlock();

    // Send the tokens used to the issuer and approve spending to the factory.
    await this.AUCTOK.connect(this.dev).mint(
      this.dev.address,
      ethers.utils.parseEther("105")
    );
    await this.AUCTOK.connect(this.dev).approve(
      this.RocketFactory.address,
      ethers.utils.parseEther("105")
    );

    // Valid initialization parameters for `createRJLaunchEvent` used as
    // base arguments when we want to check reversions for specific values.
    this.validParams = {
      _issuer: this.issuer.address,
      _auctionStart: this.block.timestamp + 60,
      _token: this.AUCTOK.address,
      _tokenAmount: ethers.utils.parseEther("105"),
      _tokenIncentivesPercent: ethers.utils.parseEther("0.05"),
      _floorPrice: 1,
      _maxWithdrawPenalty: ethers.utils.parseEther("0.5"),
      _fixedWithdrawPenalty: ethers.utils.parseEther("0.4"),
      _maxAllocation: 100,
      _userTimelock: 60 * 60 * 24 * 7,
      _issuerTimelock: 60 * 60 * 24 * 8,
    };
  });

  describe("initialising the contract", function () {
    it("should emit event when token added", async function () {
      await this.factory.createPair(this.AUCTOK.address, this.wavax.address);
      await expect(
        this.RocketFactory.createRJLaunchEvent(
          this.validParams._issuer,
          this.validParams._auctionStart,
          this.validParams._token,
          this.validParams._tokenAmount,
          this.validParams._tokenIncentivesPercent,
          this.validParams._floorPrice,
          this.validParams._maxWithdrawPenalty,
          this.validParams._fixedWithdrawPenalty,
          this.validParams._maxAllocation,
          this.validParams._userTimelock,
          this.validParams._issuerTimelock
        )
      )
        .to.emit(this.RocketFactory, "IssuingTokenDeposited")
        .withArgs(this.AUCTOK.address, this.validParams._tokenAmount)
        .to.emit(this.RocketFactory, "RJLaunchEventCreated")
        .withArgs(
          await this.RocketFactory.getRJLaunchEvent(this.AUCTOK.address),
          this.issuer.address,
          this.AUCTOK.address,
          this.validParams._auctionStart,
          this.validParams._auctionStart + 60 * 60 * 24 * 2,
          this.validParams._auctionStart + 60 * 60 * 24 * 3,
          this.rJOE.address,
          ethers.utils.parseEther("100")
        )
        .to.emit(
          await ethers.getContractAt(
            "LaunchEvent",
            await this.RocketFactory.getRJLaunchEvent(this.AUCTOK.address)
          ),
          "LaunchEventInitialized"
        )
        .withArgs(
          this.validParams._tokenIncentivesPercent,
          this.validParams._floorPrice,
          this.validParams._maxWithdrawPenalty,
          this.validParams._fixedWithdrawPenalty,
          this.validParams._maxAllocation,
          this.validParams._userTimelock,
          this.validParams._issuerTimelock,
          ethers.utils.parseEther("100"),
          ethers.utils.parseEther("5")
        );
    });

    it("should create a launch event if pair created with no liquidity", async function () {
      await this.factory.createPair(this.AUCTOK.address, this.wavax.address);
      await this.RocketFactory.createRJLaunchEvent(
        this.validParams._issuer,
        this.validParams._auctionStart,
        this.validParams._token,
        this.validParams._tokenAmount,
        this.validParams._tokenIncentivesPercent,
        this.validParams._floorPrice,
        this.validParams._maxWithdrawPenalty,
        this.validParams._fixedWithdrawPenalty,
        this.validParams._maxAllocation,
        this.validParams._userTimelock,
        this.validParams._issuerTimelock
      );
    });

    const testReverts = async (factory, args, message) => {
      await expect(
        factory.createRJLaunchEvent(
          args._issuer,
          args._auctionStart,
          args._token,
          args._tokenAmount,
          args._tokenIncentivesPercent,
          args._floorPrice,
          args._maxWithdrawPenalty,
          args._fixedWithdrawPenalty,
          args._maxAllocation,
          args._userTimelock,
          args._issuerTimelock
        )
      ).to.be.revertedWith(message);
    };

    it("should revert if issuer address is 0", async function () {
      const args = {
        ...this.validParams,
        _issuer: ethers.constants.AddressZero,
      };
      await testReverts(
        this.RocketFactory,
        args,
        "RJFactory: issuer can't be 0 address"
      );
    });

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

    it("should revert if incentives percent too high", async function () {
      const args = {
        ...this.validParams,
        _tokenIncentivesPercent: ethers.utils.parseEther("1"),
      };
      await testReverts(
        this.RocketFactory,
        args,
        "LaunchEvent: token incentives too high"
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
        "LaunchEvent: start of phase 1 cannot be in the past"
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
        "RJFactory: liquid pair already exists"
      );
    });

    it("should revert if max withdraw penalty is too high", async function () {
      const args = {
        ...this.validParams,
        _maxWithdrawPenalty: ethers.utils.parseEther("0.5").add("1"),
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
      expect(
        await this.RocketFactory.createRJLaunchEvent(
          this.validParams._issuer,
          this.validParams._auctionStart,
          this.validParams._token,
          this.validParams._tokenAmount,
          this.validParams._tokenIncentivesPercent,
          this.validParams._floorPrice,
          this.validParams._maxWithdrawPenalty,
          this.validParams._fixedWithdrawPenalty,
          this.validParams._maxAllocation,
          this.validParams._userTimelock,
          this.validParams._issuerTimelock
        )
      );
    });

    it("should revert if initialised twice", async function () {
      expect(
        await this.RocketFactory.createRJLaunchEvent(
          this.validParams._issuer,
          this.validParams._auctionStart,
          this.validParams._token,
          this.validParams._tokenAmount,
          this.validParams._tokenIncentivesPercent,
          this.validParams._floorPrice,
          this.validParams._maxWithdrawPenalty,
          this.validParams._fixedWithdrawPenalty,
          this.validParams._maxAllocation,
          this.validParams._userTimelock,
          this.validParams._issuerTimelock
        )
      );
      LaunchEvent = await ethers.getContractAt(
        "LaunchEvent",
        this.RocketFactory.getRJLaunchEvent(this.AUCTOK.address)
      );

      expect(
        LaunchEvent.initialize(
          this.validParams._issuer,
          this.validParams._auctionStart,
          this.validParams._token,
          this.validParams._tokenIncentivesPercent,
          this.validParams._floorPrice,
          this.validParams._maxWithdrawPenalty,
          this.validParams._fixedWithdrawPenalty,
          this.validParams._maxAllocation,
          this.validParams._userTimelock,
          this.validParams._issuerTimelock
        )
      ).to.be.revertedWith("LaunchEvent: already initialized");
    });

    it("should report it is in the correct phase", async function () {
      await this.RocketFactory.createRJLaunchEvent(
        this.validParams._issuer,
        this.validParams._auctionStart,
        this.validParams._token,
        this.validParams._tokenAmount,
        this.validParams._tokenIncentivesPercent,
        this.validParams._floorPrice,
        this.validParams._maxWithdrawPenalty,
        this.validParams._fixedWithdrawPenalty,
        this.validParams._maxAllocation,
        this.validParams._userTimelock,
        this.validParams._issuerTimelock
      );
      LaunchEvent = await ethers.getContractAt(
        "LaunchEvent",
        this.RocketFactory.getRJLaunchEvent(this.AUCTOK.address)
      );
      expect((await LaunchEvent.currentPhase()) == 0);
    });
  });

  after(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    });
  });
});
