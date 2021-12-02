const { expect } = require("chai");
const { ethers } = require("hardhat");
const Web3 = require("web3");
const abi = require("./ERC20ABI.json");

describe("Swapper", function () {
  let whale, 
  Swapper, 
  swapper,
  WMATIC, 
  WBTC, 
  WETH, 
  USDC;

  const whaleAddress = "0x01aeFAC4A308FbAeD977648361fBAecFBCd380C7";

  before(async () => {
    // Setup some ERC20 contracts
    WMATIC = new ethers.Contract("0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270", abi, ethers.provider);
    WBTC = new ethers.Contract("0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6", abi, ethers.provider); 
    WETH = new ethers.Contract("0x7ceb23fd6bc0add59e62ac25578270cff1b9f619", abi, ethers.provider);
    USDC = new ethers.Contract("0x2791bca1f2de4661ed88a30c99a7a9449aa84174", abi, ethers.provider);
    
    // Impersonate whale account
    whale = await ethers.getSigner(whaleAddress);
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [whaleAddress],
    });
    
    // Deploy contracts as whale
    Swapper = await ethers.getContractFactory("Swapper");
    swapper = await Swapper.connect(whale).deploy();
  });

  const amountIn = Web3.utils.toWei("1000", "ether"); // 1000 with 18 zeroes
  const amountOut = "1000000000"; // 10 in WBTC (8 decimals)

  /**
   * These tests are based on SushiSwap and QuickSwap liquidity as of December 1 2021.
   */
  describe("priceTo", async () => {
    it("Understands that indirect swaps are best between WMATIC and WBTC", async () => {
      const prediction = await swapper.priceTo("WMATIC", "WBTC", amountIn);
      const [middleToken, router, bestAmountOut] = prediction.toString().split(",");
      expect(Web3.utils.toChecksumAddress(middleToken)).to.be.oneOf([
        Web3.utils.toChecksumAddress(WETH.address),
        Web3.utils.toChecksumAddress(USDC.address)
      ]);
    });

    it("Understands that indirect swaps are best between WMATIC and DAI", async () => {
      const prediction = await swapper.priceTo("WMATIC", "DAI", amountIn);
      const [middleToken, router, bestAmountOut] = prediction.toString().split(",");
      expect(Web3.utils.toChecksumAddress(middleToken)).to.be.oneOf([
        Web3.utils.toChecksumAddress(WETH.address),
        Web3.utils.toChecksumAddress(USDC.address)
      ]);    
    });

    it("Understands that direct swap is the best option between WMATIC and USDC", async () => {
      const prediction = await swapper.priceTo("WMATIC", "USDC", amountIn);
      const [middleToken, router, bestAmountOut] = prediction.toString().split(",");
      
      /**
       * Regex test for zero address. 
       * See more info here: https://stackoverflow.com/questions/49937566/filter-out-empty-address-in-web3-js
       */
      expect(/^0x0+$/.test(middleToken)).to.be.true;
    });
  });

  describe("priceFrom", async () => {
    it("Understands that indirect swaps are best between WMATIC and WBTC", async () => {
      const prediction = await swapper.priceFrom("WMATIC", "WBTC", amountOut);
      const [middleToken, router, bestAmountIn] = prediction.toString().split(",");

      expect(Web3.utils.toChecksumAddress(middleToken)).to.be.oneOf([
        Web3.utils.toChecksumAddress(WETH.address),
        Web3.utils.toChecksumAddress(USDC.address)
      ]);   
    });

    it("Reverts on unrealistic liquidity requirements (1,000,000 WBTC output)", async () => {
      await expect(swapper.priceFrom("WMATIC", "WBTC", "100000000000000000")).to.be.revertedWith("Swapper: no option with sufficient liquidity found");
    });
  });

  describe("swapTo", async () => {
    it("Swaps the expected amounts from WMATIC to WBTC", async () => {
      const prediction = await swapper.connect(whale).priceTo("WMATIC", "WBTC", amountIn);
      const [middleToken, router, bestAmountOut] = prediction.toString().split(",");

      await WMATIC.connect(whale).approve(swapper.address, amountIn);

      const initialWMATICBalance = await WMATIC.balanceOf(whaleAddress);
      const initialWBTCBalance = await WBTC.balanceOf(whaleAddress);
      
      await swapper.connect(whale).swapTo("WMATIC", "WBTC", amountIn);

      const finalWMATICBalance = await WMATIC.balanceOf(whaleAddress);
      const finalWBTCBalance = await WBTC.balanceOf(whaleAddress);

      expect(finalWBTCBalance.sub(initialWBTCBalance).toString()).to.be.equal(bestAmountOut);
      expect(initialWMATICBalance.sub(finalWMATICBalance).toString()).to.be.equal(amountIn);
    });
  });

  describe("swapFrom", async () => {
    it("Swaps the expected amounts from WMATIC to WBTC", async () => {
      const prediction = await swapper.connect(whale).priceFrom("WMATIC", "WBTC", amountOut);
      const [middleToken, router, bestAmountIn] = prediction.toString().split(","); 

      await WMATIC.connect(whale).approve(swapper.address, bestAmountIn);

      const initialWMATICBalance = await WMATIC.balanceOf(whaleAddress);
      const initialWBTCBalance = await WBTC.balanceOf(whaleAddress);
      
      await swapper.connect(whale).swapTo("WMATIC", "WBTC", bestAmountIn);

      const finalWMATICBalance = await WMATIC.balanceOf(whaleAddress);
      const finalWBTCBalance = await WBTC.balanceOf(whaleAddress);

      expect(finalWBTCBalance.sub(initialWBTCBalance).toString()).to.be.equal(amountOut);
      expect(initialWMATICBalance.sub(finalWMATICBalance).toString()).to.be.equal(bestAmountIn); 
    });
  });
});
