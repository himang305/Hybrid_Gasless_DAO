const { expect } = require("chai");
const { ethers, BigNumber } = require("hardhat");
const { upgrades } = require("hardhat");
const { Utils } = require("alchemy-sdk");

describe("Initiating Tests", function () {

  let factoryContract;
  let factoryAddress;
  let daoContract;
  let daoAddress;
  let daoProxyContract;
  let daoProxyAddress;
  let description = "Mint 15 token to User_3";
  const inputBytes = Utils.toUtf8Bytes(description);
  let descriptionHash = ethers.keccak256(inputBytes);

  let ABI = [
    "function mint(address[] calldata _owners, uint256[] calldata _votes)"
  ];
  let iface = new ethers.Interface(ABI);
  let func;


  beforeEach(async function () {
    [admin, user1, user2, user3] = await ethers.getSigners();
  })

  describe("Hybrid DAO Tests", function () {

    it("Deployment of Contracts", async function () {

      const daos = await ethers.deployContract("HybridDAO");
      daoContract = await daos.waitForDeployment();
      daoAddress = daoContract.target;
      console.log("Deployed DAO Contract: " + daoAddress);

      const factory = await ethers.deployContract("DaoFactory", [daoAddress]);
      factoryContract = await factory.waitForDeployment();
      factoryAddress = factoryContract.target;
      console.log("Deployed Factory Contract: " + factoryAddress);

    })
  });

  describe("Proposal Tests", function () {

    it("Deploy new DAO with 2 users", async function () {
      let votePeriod = 10; // 10 seconds DAO voting period

      await factoryContract.createDao("Commodity ID 371",
        "C_371",
        ethers.parseUnits("100", "ether"),
        [user1.address, user2.address],
        [ethers.parseUnits("20", "ether"), ethers.parseUnits("10", "ether")],
        ethers.parseUnits("30", "ether"),  // Execution Threshold
        ethers.parseUnits("10", "ether"),  // Proposal Threshold
        votePeriod);

      let daoList = await factoryContract.getUserDao(admin.address);
      daoProxyAddress = daoList[0];
      console.log("DAO Proxy Address : ", daoProxyAddress);

      let proxy = await ethers.getContractFactory("HybridDAO");
      daoProxyContract = proxy.attach(daoProxyAddress);

    });

    it("Create a proposal to mint 15 tokens to user 3", async function () {

      func = iface.encodeFunctionData("mint", [[user3.address], [ethers.parseUnits("15", "ether")]]);
      await daoProxyContract.connect(user1).createProposal([daoProxyAddress], [0], [func], description);

    });

    it(" Vote on proposal by User1 and User2 Off chain and send their vote to DAO ", async function () {

      const proposal_id = await daoProxyContract.hashProposal([daoProxyAddress.toLowerCase()], [0], [func], descriptionHash);

      let hashdata = await daoProxyContract.getMessageHashed(31337, daoProxyAddress, proposal_id);
      
      let signature1 = await user1.signMessage(Utils.arrayify(hashdata));
      let signature2 = await user2.signMessage(Utils.arrayify(hashdata));
      let sign = signature1.concat(signature2.slice(2));

      await daoProxyContract.castMultipleVoteBySignature(proposal_id, sign);

      await daoProxyContract.executeProposal([daoProxyAddress], [0], [func], descriptionHash);
      expect(await daoProxyContract.balanceOf(user3.address)).to.equal(ethers.parseUnits("15", "ether"));

    });

    it(" Execute Proposal and verify execution", async function () {

      await daoProxyContract.executeProposal([daoProxyAddress], [0], [func], descriptionHash);
      expect(await daoProxyContract.balanceOf(user3.address)).to.equal(ethers.parseUnits("15", "ether"));

    });


  })


});
