module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy } = deployments;
  const { deployer, dev } = await getNamedAccounts();

  const rocketJoeFactoryAddress = (await deployments.get("RocketJoeFactory"))
    .address;

  await deploy("RocketJoeLens", {
    from: deployer,
    args: [rocketJoeFactoryAddress],
    log: true,
  });
};

module.exports.tags = ["RocketJoeLens"];
module.exports.dependencies = ["RocketJoeFactory"];
