const { ethers, upgrades } = require("hardhat");

const UPGRADEABLE_PROXY = "0x7D5BB58C84B317Ccc0523d289d27BFDDfE940Ba2";

async function main() {
   const gas = await ethers.provider.getGasPrice()
   const V2Contract = await ethers.getContractFactory("Cloudax");
   console.log("Upgrading CloudaxUpgradeContract...");
   let upgrade = await upgrades.upgradeProxy(UPGRADEABLE_PROXY, V2Contract, {
      gasPrice: gas
   });
   console.log("CloudaxUpgradeContract Upgraded to Cloudax");
   console.log("Cloudax Contract Deployed To:", upgrade.address)
}

main().catch((error) => {
   console.error(error);
   process.exitCode = 1;
 });