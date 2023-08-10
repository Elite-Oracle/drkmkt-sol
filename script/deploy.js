const DarkMarketAuction = artifacts.require("DarkMarketAuction");

module.exports = async (deployer, network, accounts) => {
  await deployer.deploy(DarkMarketAuction);
};
