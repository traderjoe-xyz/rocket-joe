const RINKEBY_ROCKET_JOE_FACTORY_ADDRESS =
  "0xE2a1631268cFfE307bb1Ed002dA43dA78EB8b8B6";

module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const chainId = await getChainId();

  let rocketJoeFactoryAddress;
  if (chainId === 4) {
    // rinkeby contract addresses
    rocketJoeFactoryAddress = RINKEBY_ROCKET_JOE_FACTORY_ADDRESS;
  } else if (chainId == 43114 || chainId == 31337) {
    // avalanche mainnet or hardhat network addresses
    rocketJoeFactoryAddress = (await deployments.get("RocketJoeFactory"))
      .address;
  }

  await deploy("LaunchEventLens", {
    from: deployer,
    args: [rocketJoeFactoryAddress],
    log: true,
  });
};

module.exports.tags = ["LaunchEventLens"];
// TODO: Uncomment this once we are ready to deploy to mainnet
// module.exports.dependencies = ["RocketJoeFactory"];
