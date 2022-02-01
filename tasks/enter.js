task("bid", "Bid on a rocket-joe launch event")
  .addParam("event", "The launch events address")
  .addParam("amount", "The amount of avax to deposit")
  .addParam("rjoe", "The address of the rJOE contract")
  .setAction(async (taskArgs) => {
    // Get deployer account
    const accounts = await hre.ethers.getSigners();
    const dev = accounts[0];

    // Get rjoe contract
    const rjoe = await hre.ethers.getContractAt(
      "RocketJoeToken",
      taskArgs.rjoe
    );

    // Approve the launch event.
    await rjoe.approve(
      taskArgs.event,
      hre.ethers.utils.parseEther(taskArgs.amount).mul(100)
    );
    console.log(`Approved event ${taskArgs.event} ${taskArgs.amount}`);

    // Get launch event
    const event = await hre.ethers.getContractAt("LaunchEvent", taskArgs.event);

    const phase = await event.currentPhase();
    console.log(`Launch event is in phase ${phase}`);
    if (phase != 1) {
      throw "Cannot enter event";
    }

    // Deposit funds to launch event
    const entry = await event.depositAVAX({
      value: ethers.utils.parseEther(taskArgs.amount),
    });
    console.log(`Entered event`);
  });

module.exports = {};
