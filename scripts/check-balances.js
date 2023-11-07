const { ethers } = require("hardhat");

async function main() {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    const balance = await ethers.provider.getBalance(account.address);
    console.log(`Balance of ${account.address} is ${ethers.utils.formatEther(balance)} ETH`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
