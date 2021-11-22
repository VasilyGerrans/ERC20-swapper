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
    whale = await ethers.getSigner(whaleAddress);
    
    WMATIC = new ethers.Contract("0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270", abi, ethers.provider);
    WBTC = new ethers.Contract("0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6", abi, ethers.provider); 
    WETH = new ethers.Contract("0x7ceb23fd6bc0add59e62ac25578270cff1b9f619", abi, ethers.provider);
    
    Swapper = await ethers.getContractFactory("Swapper");
    swapper = await Swapper.deploy(whaleAddress, // set whale as parent 
      [sushiRouter, quickRouter], // we supply two initial IUniswapV2Router02s
      [
        [WMATIC.address, WBTC.address], // make SushiSwap swap WMATIC for WBTC directly
        [WMATIC.address, WETH.address, WBTC.address] // make QuickSwap swap WMATIC for WBTC via WETH (optimally-full LPs)
      ]);  
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [whaleAddress],
    });
  });
  
  describe("Swapper.sol", async () => {
    it("allows swapping our default ERC20s", async () => {
      await WMATIC.connect(whale).approve(swapper.address, amount);
      
      const initialWMATICBalance = await WMATIC.balanceOf(whaleAddress);
      const initialWBTCBalance = await WBTC.balanceOf(whaleAddress);
      
      await swapper.connect(whale).swap(amount, 0);
 
      const finalWMATICBalance = await WMATIC.balanceOf(whaleAddress);
      const finalWBTCBalance = await WBTC.balanceOf(whaleAddress);

      expect(initialWMATICBalance.gt(finalWMATICBalance));
      expect(initialWBTCBalance.lt(finalWBTCBalance));
      expect(initialWMATICBalance.sub(finalWMATICBalance).toString()).to.be.equal(amount);
    });

    it("leaves no remaining funds in the swapper contract", async () => {
      await WMATIC.connect(whale).approve(swapper.address, amount);
      await swapper.connect(whale).swap(amount, 0);

      const finalSwapperWMATICBalance = await WMATIC.balanceOf(swapper.address);
      const finalSwapperWBTCBalance = await WBTC.balanceOf(swapper.address);

      expect(finalSwapperWMATICBalance.toString()).to.be.equal("0");
      expect(finalSwapperWBTCBalance.toString()).to.be.equal("0");
    });

    it("allows us to delete routers", async () => {
      await WMATIC.connect(whale).approve(swapper.address, amount);

      await swapper.connect(whale).deleteRouter(sushiRouter);
      let routers = await swapper.getRoutersQuantity();
      expect(routers.toString()).to.be.equal("1");

      await swapper.connect(whale).deleteRouter(quickRouter);
      routers = await swapper.getRoutersQuantity();
      expect(routers.toString()).to.be.equal("0");
    });

    it("allows us to create routers", async () => {
      await WMATIC.connect(whale).approve(swapper.address, amount);
      
      await swapper.connect(whale).deleteRouter(sushiRouter);
      await swapper.getRoutersQuantity();

      await swapper.connect(whale).addRouter(sushiRouter, [WMATIC.address, WBTC.address]);
      const routers = await swapper.getRoutersQuantity();
      expect(routers.toString()).to.be.equal("2");
    });

    it("allows us to edit paths", async () => {
      const initialSecondAddressInPath = await swapper.routerPaths(sushiRouter, 1); // (WBTC.address)
      await swapper.connect(whale).updatePath(sushiRouter, [WMATIC.address, WETH.address, WBTC.address]);
      const finalSecondAddressInPath = await swapper.routerPaths(sushiRouter, 1); // (WETH.address)

      expect(initialSecondAddressInPath).to.not.be.equal(finalSecondAddressInPath);
      expect(initialSecondAddressInPath).to.be.equal(Web3.utils.toChecksumAddress(WBTC.address));
      expect(finalSecondAddressInPath).to.be.equal(Web3.utils.toChecksumAddress(WETH.address));
    });
  });
});
