const { expect } = require("chai");
const { ethers } = require("hardhat");
const { uid } = require("uid/secure");
const Web3 = require("web3");
const abi = require("./ERC20ABI.json");

describe("Swapper", function () {
  let whale, Swapper, swapper, WMATIC, WBTC, WETH, USDC;
  const whaleAddress = "0x01aeFAC4A308FbAeD977648361fBAecFBCd380C7"; // big boy on Polygon
  const sushiRouter = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
  const quickRouter = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
  const amount = Web3.utils.toWei("100000", "ether");
  const amountOut = "100000000"; // 1 wbtc

  beforeEach(async () => {
    whale = await ethers.getSigner(whaleAddress);
    
    WMATIC = new ethers.Contract("0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270", abi, ethers.provider);
    WBTC = new ethers.Contract("0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6", abi, ethers.provider); 
    WETH = new ethers.Contract("0x7ceb23fd6bc0add59e62ac25578270cff1b9f619", abi, ethers.provider);
    USDC = new ethers.Contract("0x2791bca1f2de4661ed88a30c99a7a9449aa84174", abi, ethers.provider);

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [whaleAddress],
    });
    
    Swapper = await ethers.getContractFactory("Swapper");
    swapper = await Swapper.connect(whale).deploy(
      [
        `SUSHI:WMATIC/WBTC:${uid(5)}`, 
        `SUSHI:WMATIC/WBTC:${uid(5)}`,
        `QUICK:WMATIC/WBTC:${uid(5)}`,
        `QUICK:WMATIC/WBTC:${uid(5)}`
      ], // [5-letter router name]:[from]/[to]/[5-character uid]
      [
        [WMATIC.address, WBTC.address],
        [WMATIC.address, WETH.address, WBTC.address], 
        [WMATIC.address, WBTC.address],
        [WMATIC.address, WETH.address, WBTC.address]
      ],
      [sushiRouter, sushiRouter, quickRouter, quickRouter]      
    );  
  });
  
  describe("Swapper.sol", async () => {
    it("gets optimal path from WMATIC to WBTC", async () => {
      const path = await swapper.getOptimalPathTo(WMATIC.address, WBTC.address, amount);

      console.log(path, path.bestAmountOut.toString());
      expect(path.bestID.toString().slice(5, -5)).to.be.equal(":WMATIC/WBTC:");
    });

    it("gets empty string for non-existent optimal path from WMATIC to USDC", async () => {
      const path = await swapper.getOptimalPathTo(WMATIC.address, USDC.address, amount);

      console.log(path.bestAmountOut.toString());
      expect(path.bestID.toString()).to.be.equal("");
      expect(path.bestAmountOut.toString()).to.be.equal("0");
    });

    it("gets optimal input for WMATIC to WBTC", async () => {
      const path = await swapper.getOptimalPathFrom(WMATIC.address, WBTC.address, amountOut);

      console.log(path);
    });
    
    /* 
    it("allows swapping WMATIC for WBTC via the best path", async () => {
      await WMATIC.connect(whale).approve(swapper.address, amount);
      
      const initialWMATICBalance = await WMATIC.balanceOf(whaleAddress);
      const initialWBTCBalance = await WBTC.balanceOf(whaleAddress);
      
      await swapper.connect(whale).swap(
        WMATIC.address,
        WBTC.address,
        amount, 
        8
      );
 
      const finalWMATICBalance = await WMATIC.balanceOf(whaleAddress);
      const finalWBTCBalance = await WBTC.balanceOf(whaleAddress);

      expect(initialWMATICBalance.gt(finalWMATICBalance));
      expect(initialWBTCBalance.lt(finalWBTCBalance));
      expect(initialWMATICBalance.sub(finalWMATICBalance).toString()).to.be.equal(amount);
    });

    it("leaves no remaining funds in the swapper contract", async () => {
      await WMATIC.connect(whale).approve(swapper.address, amount);
      await swapper.connect(whale).swap(
        WMATIC.address,
        WBTC.address,
        amount, 
        3
      );

      const finalSwapperWMATICBalance = await WMATIC.balanceOf(swapper.address);
      const finalSwapperWBTCBalance = await WBTC.balanceOf(swapper.address);

      expect(finalSwapperWMATICBalance.toString()).to.be.equal("0");
      expect(finalSwapperWBTCBalance.toString()).to.be.equal("0");
    });
     */
  });
});
