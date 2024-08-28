import { ethers, network } from "hardhat";
import { Staking__factory, Staking } from "../typechain-types";


async function main() {

  const usdt_address = "0xdac17f958d2ee523a2206206994597c13d831ec7";
  const wbtc_address = "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599";
  const weth_address = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";

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
