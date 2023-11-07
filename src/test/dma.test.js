const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("DarkMarketAuction Contract", function () {
  let DarkMarketAuction, darkMarketAuction;
  let deployer, otherAccount;

  before(async function () {
    // Get the signers
    [deployer, otherAccount] = await ethers.getSigners();

    // Get the contract factory
    DarkMarketAuction = await ethers.getContractFactory("DarkMarketAuction");

    // Deploy the contract using a proxy
    darkMarketAuction = await upgrades.deployProxy(DarkMarketAuction, [], { initializer: 'initialize' });
    await darkMarketAuction.deployed();
  });

  it("should be deployed", async function () {
    expect(darkMarketAuction.address).to.be.properAddress;
  });

  it("should be initialized", async function () {
    // Add your initialization tests here
    // For example, checking if the contract is paused or not
    expect(await darkMarketAuction.paused()).to.equal(false);
  });

  // Add more tests here to cover the functionality of the contract
});
