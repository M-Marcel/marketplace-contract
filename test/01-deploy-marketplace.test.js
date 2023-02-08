const { n18, toEther, increaseTimestamp, ONE_DAY } = require("../utils/utils");
const { assert, expect } = require("chai");
const { network, deployments, ethers, getNamedAccounts } = require("hardhat")
const { developmentChains, networkConfig, networks } = require("../helper-hardhat-config")


describe("Cloudax Marketplace Tests", function () {
    let marketplace, orderFulfillment, deployer, john, paul, jane;
    const PRICE = n18("0.01");
    const QUANTITY = 10;
    const ROYALTY = 20;
    const ITEMID = 1;
    const tokenBaseUri = "https://cloudaxnftmarketplace.xyz/metadata/25"
    const itemId1 = "0177af61";

    beforeEach(async () => {
        [deployer, john, paul, jane] = await ethers.getSigners();
        // provider = ethers.provider;
        // const Marketplace = await ethers.getContractFactory("Marketplace");
        // marketplace = await Marketplace.deploy()
        // await marketplace.deployed()
        // const OrderFulfillment = await ethers.getContractFactory("OrderFulfillment");
        // orderFulfillment = await OrderFulfillment.deploy();
        // await orderFulfillment.deployed();
        // const owner = await orderFulfillment.owner()
        // console.log(deployer.address, owner)
        // console.log(deployer.address, marketplace.address)
    });
    describe("#deployment", function () {
        it("Offer Id starts from zero", async function () {
            // const offerId = orderFulfillment._startOfferId()
            // expect(offerId).to.equal(0);
        })
        // it("Create an item", async function () {
        //     const buyItem = await cloudaxMarketplace.buyItemCopy(deployer.address, PRICE, QUANTITY, ROYALTY, itemId1, tokenBaseUri, { value: PRICE, sender: deployer.address })
        //     // const contractOwner = await cloudaxMarketplace.owner()
        //     // expect(contractOwner).to.equal(alice.address);
        //     const buyItem2 = await cloudaxMarketplace.buyItemCopy(alice.address, PRICE, QUANTITY, ROYALTY, itemId1, tokenBaseUri, { value: PRICE, sender: deployer.address })
        //     expect(buyItem).to.emit(
        //         "ItemCreated"
        //     )
        //     expect(buyItem2).to.emit(
        //         "ItemCreated"
        //     )
        // });
    });

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

    // describe("Confirm that item sold index count starts at zero", function () {
    //     it("Item sold", async () => {
    //         expect(await marketplace.getItemsSold()).to.equal(0);
    //     })
    //     it("Service Fee", async () => {
    //         expect(await marketplace.getServiceFee()).to.equal(200);
    //     })

    // })

});