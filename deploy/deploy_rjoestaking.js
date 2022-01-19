module.exports = async function ({ getNamedAccounts, deployments}) {
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  const joeAddress = "0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd";
  const rJoeAddress = (await deployments.get("RocketJoeToken")).address;
  const rJoePerSec = "100";

  await deploy("RocketJoeStaking", {
    from: deployer,
    proxyContract: "OpenZeppelinTransparentProxy",
    init: {
      args: [joeAddress, rJoeAddress, rJoePerSec],
    },
    log: true,
  });

  const rJoeStakingAddress = (await deployments.get('RocketJoeStaking')).address;
  const rJoe = await ethers.getContractAt("RocketJoeToken", rJoeAddress);
  await rJoe.transferOwnership(rJoeStakingAddress);

}

module.exports.tags = ["RocketJoeStaking"];
module.exports.dependencies = ["RocketJoeToken"]
