// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Staking is Ownable {
  using SafeERC20 for IERC20;
  
  // Struct for staking information
  struct StakeInfo {
    uint256 stakedAmount;
    uint256 firstStakeTime;
    uint256 lastUpdateTime;
    uint256 oldRewards;
    address referredBy;
    bool referralRewardsClaimed;
  }

  // Tokens to be staked
  IERC20 public USDT;
  IERC20 public WETH;
  IERC20 public WBTC;
  // Minimum stake time
  uint256 public minStakingTime = 3600*24*60;
  // Total stake amount for tokens
  mapping(address => uint256) public totalStakedAmount;
  // Reward rate for stakers between 1 and 1000. (1 => 0.1%, 1000 => 100%)
  uint256 rewardRate = 10; // 1%
  // Reward rate for referrers between 1 and 1000. (1 => 0.1%, 1000 => 100%)
  uint256 referralRewardRate = 10; // 1%
  // stakerAddress => tokenAddress => StakeInfo
  mapping(address => mapping(address=>StakeInfo)) public userERC20Stakes;

  event Staked(address stakerAddress, address tokenAddress, uint256 amount);
  event ClaimedRewards(address stakerAddress, address tokenAddress, uint256 amount);
  event Withdrawn(address stakerAddress, address tokenAddress, uint256 amount);
  event ReferralERC20RewardClaimed(address referrerAddress, address stakerAddress, address tokenAddress, uint256 amount);

  constructor(
    address _usdtAddress,
    address _wethAddress,
    address _wbtcAddress
  ) {
    USDT = IERC20(_usdtAddress);
    WETH = IERC20(_wethAddress);
    WBTC = IERC20(_wbtcAddress);
  }

  // @desc
  // function for stake ERC20 tokens. only accept USDT, WBTC and WETH. Staker address will be msg.sender
  // @params
  // address tokenAddress : address of token to be staked 
  // uint amount : amount of token to be staked
  // address referredBy : address of referrer. If there is no referrer, it will be address(0)
  function stake(
    address tokenAddress,
    uint256 amount,
    address referredBy
  ) external {
    uint256 currentTimestamp = block.timestamp;
    require(tokenAddress == address(USDT) || tokenAddress == address(WBTC) || tokenAddress == address(WETH), "Invalid token address");
    totalStakedAmount[tokenAddress] += amount;
    if (userERC20Stakes[msg.sender][tokenAddress].stakedAmount > 0) {
      uint256 newRewards = _calculateERC20Rewards(msg.sender, tokenAddress);
      uint256 newAmount = userERC20Stakes[msg.sender][tokenAddress].stakedAmount + amount;
      userERC20Stakes[msg.sender][tokenAddress].stakedAmount = newAmount;
      userERC20Stakes[msg.sender][tokenAddress].oldRewards = newRewards;
      userERC20Stakes[msg.sender][tokenAddress].referredBy = referredBy;
      userERC20Stakes[msg.sender][tokenAddress].lastUpdateTime = currentTimestamp;
      IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
      emit Staked(msg.sender, tokenAddress, amount);
    } else {
      userERC20Stakes[msg.sender][tokenAddress].stakedAmount = amount;
      userERC20Stakes[msg.sender][tokenAddress].lastUpdateTime = currentTimestamp;
      if (userERC20Stakes[msg.sender][tokenAddress].firstStakeTime == 0) {
        userERC20Stakes[msg.sender][tokenAddress].firstStakeTime = currentTimestamp;
      }
    }
  }

  // @desc
  // function for unstake tokens. It can be called by only owner of this contract.
  // Stakers will request owners to unstake their tokens and the owners withdraw tokens to their wawllets and send them to stakers
  // @params
  // address stakerAddress : address of staker wallet
  // address tokenAddress : address of staked token
  // uint amount : amount of token to be unstaked
  function unstake(
    address stakerAddress,
    address tokenAddress,
    uint256 amount
  ) external onlyOwner {
    require(tokenAddress == address(USDT) || tokenAddress == address(WBTC) || tokenAddress == address(WETH), "Invalid token address");
    require(amount < userERC20Stakes[stakerAddress][tokenAddress].stakedAmount, "Invalid amount");
    _unstake(stakerAddress, tokenAddress, amount);
  }

  // @desc
  // function for unstake all tokens. It can be called by only owner.
  // @params
  // address stakerAddress : address of staker wallet
  // address tokenAddress : address of staked token
  function unstakeAll(
    address stakerAddress,
    address tokenAddress
  ) external onlyOwner {
    require(tokenAddress == address(USDT) || tokenAddress == address(WBTC) || tokenAddress == address(WETH), "Invalid token address");
    require(userERC20Stakes[stakerAddress][tokenAddress].stakedAmount > 0, "Invalid staker address");
    _unstakeAll(stakerAddress, tokenAddress);
  }

  // @desc
  // function for claim rewards from stakers. It can be also called by only owner.
  // Rewards will be withdrawn to owner wallet and owner will transfer rewards to stakers.
  // @params
  // address stakerAddress : address of staker wallet
  // address tokenAddress : address of staked token
  function claimRewards(
    address stakerAddress,
    address tokenAddress
  ) external onlyOwner {
    require(tokenAddress == address(USDT) || tokenAddress == address(WBTC) || tokenAddress == address(WETH), "Invalid token address");
    uint256 currentTimestamp = block.timestamp;
    require(currentTimestamp - userERC20Stakes[stakerAddress][tokenAddress].firstStakeTime >= minStakingTime, "No time yet");
    uint256 currentRewards = _calculateERC20Rewards(stakerAddress, tokenAddress);
    userERC20Stakes[stakerAddress][tokenAddress].oldRewards = 0;
    userERC20Stakes[stakerAddress][tokenAddress].lastUpdateTime = currentTimestamp;
    IERC20(tokenAddress).safeTransfer(owner(), currentRewards);    
    emit ClaimedRewards(stakerAddress, tokenAddress, currentRewards);
  }

  // @desc
  // function for claim rewards from referrers. It can be called by only owner
  // If the referrer requests to claim referrer rewards, the rewards will be withdrawn to owner wallet and owner will transfer rewards to the referrers.
  // @params
  // address referrerAddress : address of referrer wallet
  // address stakerAddress : address of staker wallet
  // address tokenAddress : address of staked token
  function claimReferralRewards(
    address referrerAddress,
    address stakerAddress,
    address tokenAddress
  ) external onlyOwner {
    require(referrerAddress == userERC20Stakes[stakerAddress][tokenAddress].referredBy, "Invalid referrer address");
    uint256 currentTimestamp = block.timestamp;
    require((currentTimestamp - userERC20Stakes[stakerAddress][tokenAddress].firstStakeTime) >= minStakingTime, "Not time yet");
    uint256 referralERC20Rewards = userERC20Stakes[stakerAddress][tokenAddress].stakedAmount * referralRewardRate / 1000;
    IERC20(stakerAddress).safeTransfer(owner(), referralERC20Rewards);
    emit ReferralERC20RewardClaimed(referrerAddress, stakerAddress, tokenAddress, referralERC20Rewards);
  }

  // @desc
  // function for update minimum staking time
  // @params
  // uint256 newMinStakingTime : seconds of minimum staking time
  function updateMinStakingTime(
    uint256 newMinStakingTime
  ) external {
    minStakingTime = newMinStakingTime;
  }

  // @desc
  // view function for getting current rewards
  // @params
  // address stakerAddress : address of staker wallet
  // address tokenAddress : address of staked token
  function getCurrentERC20Rewards(
    address stakerAddress,
    address tokenAddress
  ) external view returns (uint256 currentRewards) {
    currentRewards = _calculateERC20Rewards(stakerAddress, tokenAddress);
  }

  function _unstake(
    address stakerAddress,
    address tokenAddress,
    uint256 amount
  ) internal {
    uint256 currentTimestamp = block.timestamp;
    uint256 currentRewards = _calculateERC20Rewards(stakerAddress, tokenAddress);
    uint256 stakedAmount = userERC20Stakes[stakerAddress][tokenAddress].stakedAmount;
    userERC20Stakes[stakerAddress][tokenAddress].stakedAmount = stakedAmount - amount;
    userERC20Stakes[stakerAddress][tokenAddress].oldRewards = currentRewards;
    userERC20Stakes[stakerAddress][tokenAddress].lastUpdateTime = currentTimestamp;
    totalStakedAmount[tokenAddress] -= amount;
    IERC20(tokenAddress).safeTransfer(owner(), amount);
    emit Withdrawn(stakerAddress, tokenAddress, amount);
  }

  function _unstakeAll(
    address stakerAddress,
    address tokenAddress
  ) internal {
    uint256 stakedAmount = userERC20Stakes[stakerAddress][tokenAddress].stakedAmount;
    _unstake(stakerAddress, tokenAddress, stakedAmount);
  }

  function _calculateERC20Rewards(
    address stakerAddress,
    address tokenAddress
  ) internal view returns (uint256 rewards) {
    uint256 currentTimestamp = block.timestamp;
    uint256 stakedTimeInDays = (currentTimestamp - userERC20Stakes[stakerAddress][tokenAddress].lastUpdateTime) / (3600 * 24);
    rewards = userERC20Stakes[stakerAddress][tokenAddress].stakedAmount * stakedTimeInDays * rewardRate / 1000 + userERC20Stakes[stakerAddress][tokenAddress].oldRewards;
  }
}