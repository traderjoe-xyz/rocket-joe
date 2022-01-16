const { ethers } = require("hardhat");

async function deployRocketFactory(dev, rJoe, penaltyCollector) {
  const wavax = await ethers.getContractAt(
    "IWAVAX",
    "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7"
  );
  const router = await ethers.getContractAt(
    "IJoeRouter02",
    "0x60aE616a2155Ee3d9A68541Ba4544862310933d4"
  );
  const factory = await ethers.getContractAt(
    "IJoeFactory",
    "0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10"
  );

  // Factories for deploying our contracts.
  const RocketJoeFactoryCF = await ethers.getContractFactory(
    "RocketJoeFactory"
  );
  const LaunchEventCF = await ethers.getContractFactory("LaunchEvent");

  // Deploy the rocket joe contracts.
  const LaunchEventPrototype = await LaunchEventCF.deploy();

  const RocketFactory = await RocketJoeFactoryCF.deploy(
    LaunchEventPrototype.address,
    rJoe.address,
    wavax.address,
    penaltyCollector.address,
    router.address,
    factory.address
  );
  await LaunchEventPrototype.connect(dev).transferOwnership(
    RocketFactory.address
  );
  return RocketFactory;
}

// Return a newly created LaunchEvent with default parameters.
async function createLaunchEvent(RocketFactory, issuer, block, token) {
  await RocketFactory.createRJLaunchEvent(
    issuer.address, // Issuer
    block.timestamp + 60, // Start time (60 seconds from now)
    token.address, // Address of the token being auctioned
    ethers.utils.parseEther("1000000"), // Amount of tokens for auction
    ethers.utils.parseEther("1000"), // Floor price (100 Wei)
    ethers.utils.parseEther("0.5"), // Max withdraw penalty
    ethers.utils.parseEther("0.4"), // Fixed withdraw penalty
    ethers.utils.parseEther("5.0"), // max allocation
    60 * 60 * 24 * 7, // User timelock
    60 * 60 * 24 * 8 // Issuer timelock
  );

  // Get a reference to the acutal launch event contract.
  LaunchEvent = await ethers.getContractAt(
    "LaunchEvent",
    RocketFactory.getRJLaunchEvent(token.address)
  );
  return LaunchEvent;
}

module.exports = {
  deployRocketFactory,
  createLaunchEvent,
};
