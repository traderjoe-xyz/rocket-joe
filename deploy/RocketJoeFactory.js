module.exports = async function ({ getNamedAccounts, deployments}) {
  const {deploy} = deployments;
  const {deployer, dev} = await getNamedAccounts();

  const launchEventAddress = (await deployments.get("LaunchEvent")).address;
  const rJoeAddress = (await deployments.get("RocketJoeToken")).address;

  const WAVAX = "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7";
  const routerAddress = "0x60aE616a2155Ee3d9A68541Ba4544862310933d4";
  const factoryAddress = "0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10";

  await deploy('RocketJoeFactory', {
    from: deployer,
    args: [
      launchEventAddress,
	  rJoeAddress,
	  WAVAX,
	  dev,
	  routerAddress,
	  factoryAddress
    ],
    log: true,
  });

}

module.exports.tags = ["RocketJoeFactory"];
module.exports.dependencies = ["LaunchEvent", "RocketJoeToken"]
