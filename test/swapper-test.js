const { expect } = require("chai");
const { ethers } = require("hardhat");
const Web3 = require("web3");
const abi = require("./ERC20ABI.json");

describe("Swapper", function () {
  let parent, whale, Swapper, swapper, WMATIC, WBTC;
  let whaleAddress = "0x01aeFAC4A308FbAeD977648361fBAecFBCd380C7"; // big boy on Polygon
  let sushiRouter = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
  let amount = Web3.utils.toWei("1000", "ether");

  beforeEach(async () => {
    [parent, _] = await ethers.getSigners();
    Swapper = await ethers.getContractFactory("Swapper");
    swapper = await Swapper.deploy(whaleAddress, sushiRouter); // set whale as parent
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [whaleAddress],
    });
    whale = await ethers.getSigner(whaleAddress);

    WMATIC = new ethers.Contract("0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270", abi, ethers.provider);
    WBTC = new ethers.Contract("0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6", abi, ethers.provider); 
  });
  
  describe("swap", async () => {
    it("should allow swapping WMATIC for WBTC", async () => {
      await WMATIC.connect(whale).approve(swapper.address, amount);
      
      const initialWMATICBalance = await WMATIC.balanceOf(whaleAddress);
      const initialWBTCBalance = await WBTC.balanceOf(whaleAddress);
      
      await swapper.connect(whale).swap(WMATIC.address, WBTC.address, amount, 0);
 
      const finalWMATICBalance = await WMATIC.balanceOf(whaleAddress);
      const finalWBTCBalance = await WBTC.balanceOf(whaleAddress);

      expect(initialWMATICBalance.gt(finalWMATICBalance));
      expect(initialWBTCBalance.lt(finalWBTCBalance));
      expect(initialWMATICBalance.sub(finalWMATICBalance).toString()).to.be.equal(amount);
    });
  });
});
