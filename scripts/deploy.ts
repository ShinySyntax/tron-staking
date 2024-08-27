import { ethers, network } from "hardhat";
import { Staking__factory, Staking } from "../typechain-types";


async function main() {

  const usdt_address = "";
  const wbtc_address = "";
  const weth_address = "";

  const stakingFactory: Staking__factory = await ethers.getContractFactory("Staking");
  const staking: Staking = await stakingFactory.deploy(usdt_address, weth_address, wbtc_address);
  await staking.waitForDeployment();

  const stakingAddress = await staking.getAddress();
  console.log("Staking deployed to:", stakingAddress);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
