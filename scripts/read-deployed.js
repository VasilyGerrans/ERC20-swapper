const { ethers } = require("hardhat");
const Web3 = require("web3");

const amountIn = Web3.utils.toWei("1", "ether");

/**
 * My little script to read my swapper contracts. Insert specific address into `await Swapper.attach("...")`.
 */
async function main() {
    const Swapper = await ethers.getContractFactory("Swapper");
    const swapper = await Swapper.attach("0xCa8059F012793393EBf4F1d6191B94D3B96534A4");

    const response = await swapper.priceTo("WMATIC", "WBTC", amountIn);

    console.log(response.bestAmountOut.toString());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

