const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("MyContract", function () {
  let myContract;
  let owner;

  before(async function () {
    [owner] = await ethers.getSigners();

    // Check the balance of the owner before deployment
    const balanceBefore = await owner.getBalance();
    console.log(`Owner balance before deployment: ${ethers.utils.formatEther(balanceBefore)} ETH`);

    // Deploy the contract using the owner account
    const MyContract = await ethers.getContractFactory("DarkMarketAuction", owner);
    myContract = await upgrades.deployProxy(MyContract, [], { initializer: 'initialize' });
    await myContract.deployed();

    // Check the balance of the owner after deployment
    const balanceAfter = await owner.getBalance();
    console.log(`Owner balance after deployment: ${ethers.utils.formatEther(balanceAfter)} ETH`);
  });

  it("should be initialized correctly", async function () {
    // Your test code here
  });

  // Additional tests...
});
