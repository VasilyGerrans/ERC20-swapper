// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  const Library = await hre.ethers.getContractFactory("TokenLibrary");
  const library = await Library.deploy();

  await library.deployed(); // 0x4758346953b13C0AE2b9b700CcaF18B47Ca365Fc
  
  console.log("TokenLibrary deployed to:", library.address);

  const Swapper = await hre.ethers.getContractFactory("Swapper");
  const swapper = await Swapper.deploy(library.address);

  await swapper.deployed();

  console.log("Swapper deployed to:", swapper.address);

  await library.setEditor(swapper.address, true);

  console.log("Swapper is now an authorised editor of the TokenLibrary.");

  await hre.run("verify:verify", {
    address: swapper.address,
    constructorArguments: [
      library.address
    ]
  });

  console.log("Swapper has been verified.");

  await hre.run("verify:verify", {
    address: library.address
  });

  console.log("TokenLibrary has been verified.");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
