const { network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
const { n18 } = require("../utils/utils");
const { ethers } = require("ethers");
const { verify } = require("../utils/verify")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    log("-----------------------------------------------")

    const args = [
        n18("1000000000")
    ]
    const testToken = await deploy("TestToken", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    if (!developmentChains.includes(network.name) && process.env.BSCSCAN_API_KEY) {
        log("Verifying Cloudax Test Token...")
        await verify(testToken.address, args)
        // }
        log("--------------------------------Cloudax Test Token up")
    }

    module.exports.tags = ["all", "testToken"]
}