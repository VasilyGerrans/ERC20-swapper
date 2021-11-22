const { expect } = require("chai");
const { ethers } = require("hardhat");
const Web3 = require("web3");
const abi = require("./ERC20ABI.json");

describe("Swapper", function () {
  let whale, Swapper, swapper, WMATIC, WBTC, WETH;
  const whaleAddress = "0x01aeFAC4A308FbAeD977648361fBAecFBCd380C7"; // big boy on Polygon
  const sushiRouter = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
  const quickRouter = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
  const amount = Web3.utils.toWei("100000", "ether");

  beforeEach(async () => {
    Swapper = await ethers.getContractFactory("Swapper");
    swapper = await Swapper.deploy(whaleAddress, [sushiRouter, quickRouter]); // set whale as parent
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [whaleAddress],
    });
    whale = await ethers.getSigner(whaleAddress);

    WMATIC = new ethers.Contract("0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270", abi, ethers.provider);
    WBTC = new ethers.Contract("0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6", abi, ethers.provider); 
    WETH = new ethers.Contract("0x7ceb23fd6bc0add59e62ac25578270cff1b9f619", abi, ethers.provider);
  });
  
  describe("swap", async () => {
    it("should allow swapping WMATIC for WBTC", async () => {
      await WMATIC.connect(whale).approve(swapper.address, amount);
      
      const initialWMATICBalance = await WMATIC.balanceOf(whaleAddress);
      const initialWBTCBalance = await WBTC.balanceOf(whaleAddress);
      
      await swapper.connect(whale).swap([WMATIC.address, WBTC.address], amount, 0);
 
      const finalWMATICBalance = await WMATIC.balanceOf(whaleAddress);
      const finalWBTCBalance = await WBTC.balanceOf(whaleAddress);

      expect(initialWMATICBalance.gt(finalWMATICBalance));
      expect(initialWBTCBalance.lt(finalWBTCBalance));
      expect(initialWMATICBalance.sub(finalWMATICBalance).toString()).to.be.equal(amount);
    });

    it("should leave no remaining funds in the swapper contract", async () => {
      await WMATIC.connect(whale).approve(swapper.address, amount);
      await swapper.connect(whale).swap([WMATIC.address, WBTC.address], amount, 0);

      const finalSwapperWMATICBalance = await WMATIC.balanceOf(swapper.address);
      const finalSwapperWBTCBalance = await WBTC.balanceOf(swapper.address);

      expect(finalSwapperWMATICBalance.toString()).to.be.equal("0");
      expect(finalSwapperWBTCBalance.toString()).to.be.equal("0");
    });

    it("finds optimal direct router", async () => {
      await WMATIC.connect(whale).approve(swapper.address, amount);

      const res = await swapper.connect(whale).findOptimalRouter(amount, [WMATIC.address, WETH.address, WBTC.address]);
      
      console.log(res[1].toString());
    });

    it("correctly registers routers", async () => {
      await WMATIC.connect(whale).approve(swapper.address, amount);

      const res0 = await swapper.connect(whale).router0(amount, [WMATIC.address, WBTC.address]);
      const res1 = await swapper.connect(whale).router1(amount, [WMATIC.address, WBTC.address]);

      console.log(res0[0], res1[0], res0[1].toString(), res1[1].toString());
    });

    /* it("finds optimal indirect router", async () => {
      await WMATIC.connect(whale).approve(swapper.address, amount);

      const res = await swapper.connect(whale).findOptimalRouter(amount, [WMATIC.address, WBTC.address]);
      console.log(res); 
    }); */
  });
});
