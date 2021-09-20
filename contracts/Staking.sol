// SPDX-License-Identifier: None
pragma solidity ^0.8;

// Import IERC20.sol
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingRewards {
    IERC20 rewardsToken;
    IERC20 stakingToken;

    // Variables:
    uint256 public rewardsRate = 100;
    uint256 public lastUpdatedTimestamp;
    uint256 public rewardsPerTokenStored;

    uint256 private totalSupply;

    // Mappings:
    mapping(address => uint256) public userRewardsPerTokenDeposited;
    mapping(address => uint256) public rewards;
    // In-accessible mapping for balances -> only accessible to function calls:
    mapping(address => uint256) private balances; // Mapped to amount of STAKING TOKEN inside staking contract

    constructor(address _rewardsToken, address _stakingToken) {
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
    }

    // Calculation Functions For updateRewards:
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) return 0;

        // Rewards Per Token = Rewards For each Token Stored + (Time locked * rate) / totalSupply:
        return
            rewardsPerTokenStored +
            (((block.timestamp - lastUpdatedTimestamp) * rewardsRate * 1e18) /
                totalSupply);
    }

    function earned(address _account) public view returns (uint256) {
        // Calculate earned rewards:
        return
            ((balances[_account] *
                (rewardPerToken() - userRewardsPerTokenDeposited[_account])) /
                1e18) + rewards[_account];
    }

    // Modifier:
    modifier updateReward(address _account) {
        // Store rewards per token through calculation:
        rewardsPerTokenStored = rewardPerToken();
        // Update last updated time:
        lastUpdatedTimestamp = block.timestamp;

        // Update Rewards Earned:
        rewards[_account] = earned(_account);
        userRewardsPerTokenDeposited[_account] = rewardsPerTokenStored;
        _;
    }

    // ACTION Functions:
    function stake(uint256 _amount) external updateReward(msg.sender) {
        // Increment total supply of pool:
        totalSupply += _amount;
        balances[msg.sender] += _amount;

        // After updating states - transfer STAKING tokens FROM msg.sender TO this smart contract:
        stakingToken.transferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint256 _amount) external updateReward(msg.sender) {
        // Update total supply of pool:
        totalSupply -= _amount;
        balances[msg.sender] -= _amount;

        // After updating states - transfer staking tokens BACK to msg.sender FROM this smart contract:
        stakingToken.transfer(msg.sender, _amount);
    }

    function getReward() external updateReward(msg.sender) {
        uint256 rewardAmount = rewards[msg.sender];
        // Update rewards to 0 (since claimed)
        rewards[msg.sender] = 0;

        // Transfer rewards to account:
        rewardsToken.transfer(msg.sender, rewardAmount);
    }
}
