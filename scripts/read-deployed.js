const { ethers } = require("hardhat");
const Web3 = require("web3");

const amountIn = Web3.utils.toWei("1", "ether");

/**
 * My little script to read my swapper contracts. Insert specific address into `await Swapper.attach("...")`.
 */
async function main() {
    const Swapper = await ethers.getContractFactory("Swapper");
    const swapper = await Swapper.attach("0x2f8ff2011d7494D251dacC3bD2802E48F090D03c");

    const response = await swapper.priceTo("WMATIC", "WBTC", amountIn);

    console.log(response.bestAmountOut.toString());

    const fromResponse = await swapper.priceFrom("WMATIC", "WBTC", "47715441855");

    console.log(fromResponse);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

