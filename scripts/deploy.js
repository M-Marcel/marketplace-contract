const { ethers, upgrades } = require("hardhat");

async function main() {

  const Cloudax = await ethers.getContractFactory("NftMarketplace");
  const cloudax = await upgrades.deployProxy(Cloudax,{kind:'uups'});
  await cloudax.deployed();
  console.log("Cloudax deployed to:", cloudax.address);

  await hre.run("verify:verify", {
    address: cloudax.address
});
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
