const { n18, toEther, increaseTimestamp, ONE_DAY } = require("../utils/utils");
const { assert, expect } = require("chai");
const { network, deployments, ethers, getNamedAccounts } = require("hardhat")
const { developmentChains, networkConfig, networks } = require("../helper-hardhat-config")


describe("Cloudax Marketplace Tests", function () {
    let cloudaxMarketplace, deployer, alice, bob, carol;
    const PRICE = n18("0.01");
    const QUANTITY = 10;
    const ROYALTY = 20;
    const ITEMID = 1;
    const tokenBaseUri = "https://cloudaxnftmarketplace.xyz/metadata/25"
    const itemId1 = 01776

    beforeEach(async () => {
        [signer, account1, account2, account3] = await ethers.getSigners();
        provider = ethers.provider;
        const CloudaxMarketplace = await ethers.getContractFactory(CloudaxNftMarketplace, signer);
        const cloudaxMarketplace = CloudaxMarketplace.deploy()
        // [deployer, alice, bob, carol] = await ethers.getSigners();
        // const CloudaxMarketplace = await ethers.getContractFactory("CloudaxNftMarketplace");
        // cloudaxMarketplace = await CloudaxMarketplace.deploy();
        // await cloudaxMarketplace.deployed();
        // console.log(cloudaxMarketplace.address)
        // console.log(deployer.address)
    });

    // describe("#deployment", function () {
    //     it("Create an item", async function () {
    //         const buyItem = await cloudaxMarketplace.buyItemCopy(deployer.address, PRICE, QUANTITY, ROYALTY, itemId1, tokenBaseUri, { value: PRICE, sender: deployer.address })
    //         // const contractOwner = await cloudaxMarketplace.owner()
    //         // expect(contractOwner).to.equal(alice.address);
    //         const buyItem2 = await cloudaxMarketplace.buyItemCopy(alice.address, PRICE, QUANTITY, ROYALTY, itemId1, tokenBaseUri, { value: PRICE, sender: deployer.address })
    //         expect(buyItem).to.emit(
    //             "ItemCreated"
    //         )
    //         expect(buyItem2).to.emit(
    //             "ItemCreated"
    //         )
    //     });
    // });

    // describe("Confirm that index count starts at zero", function () {
    //     it("Item Index", async () => {
    //         expect(await cloudaxMarketplacev2.getItemsSold()).to.equal(0);
    //     })

    // })

    // beforeEach(async () => {
    //     [owner, referrer, alice, bob, carol] = await ethers.getSigners();
    //     const CloudaxMarketplacev2 = await ethers.getContractFactory("CloudaxNftMarketplacevvv");
    //     cloudaxMarketplacev2 = await CloudaxMarketplacev2.deploy();
    // })

    // describe("Confirm that index count starts at zero", function(){
    //     it("Item Index", async () => {
    //         expect(await cloudaxMarketplacev2.getItemsSold()).to.equal(0);
    //     })

    // })

});