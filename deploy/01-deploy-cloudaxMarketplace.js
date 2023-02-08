const { ethers, upgrades, network } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config")
// const { n18 } = require("../utils/utils");
// const { ethers } = require("ethers");
const { verify } = require("../utils/verify")

module.exports = async function () {
    // const { deploy, log } = deployments
    // const { deployer } = await getNamedAccounts()

    // const gas = await ethers.provider.getGasPrice()
    const Marketplace = await ethers.getContractFactory("Marketplace")


    // log("-----------------------------------------------")

    const marketplace = await Marketplace.deploy()

    console.log("Deploying Marketplace...", marketplace.address)

    // if (process.env.ETHERSCAN_API_KEY) {
    //     console.log("Verifying Cloudax Marketplace...")
    //     await verify(cloudaxNftMarketplace.address)
    //     // }
    //     console.log("--------------------------------cloudaxNftMarketplace up")
    // }

    module.exports.tags = ["all", "cloudaxNftMarketplace"]
}