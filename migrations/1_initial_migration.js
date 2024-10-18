var Staking = artifacts.require("./Staking.sol");

module.exports = function(deployer) {
  deployer.deploy(Staking);
};
