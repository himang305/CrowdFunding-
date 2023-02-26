// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// CrowdFunding Contract that allow users to create crowd funding events
contract CrowdFunding is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    using SafeERC20 for IERC20;

    // counter to store the incremental ID for campaigns mapping
    uint256 public counter;

    // campaign struct to store campaign name, target, balance, owner, ending time and funding token
    struct Campaign{
        string name;
        uint256 fundingGoal;
        uint256 balance;
        uint256 campaignEndTime;
        address campaignOwner;
        IERC20 FundToken;
    }

    // mapping to store campaign IDs
    mapping(uint256 => Campaign) public CampaignMapping;
        // mapping to store users contribution mapped to campaign ID and user address
    mapping(uint256 => mapping(address => uint256)) public UserContributions;

    event _createCampaign(uint256, string, uint256, uint256, address, address);
    event _fundCampaign(uint256, uint256, address);
    event _completeCampaign(uint256, uint256);
    event _withdrawFromCampaign(uint256, address, uint256);


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // Function initialise contract owner and upgradeability feature
    function initialize() initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

// Function to create campaign by campaign owner providing name, target, duration and funding token
    function createCampaign(string calldata _name,
        uint256 _fundingGoal,
        uint256 _durationInDays,
        address _fundToken) external{
      counter++;
      Campaign storage camp = CampaignMapping[counter];
      camp.name = _name;
      camp.fundingGoal = _fundingGoal;
      camp.campaignEndTime = block.timestamp + _durationInDays * 86400;
      camp.FundToken = IERC20(_fundToken);

      emit _createCampaign(counter, _name, _fundingGoal, _durationInDays, _fundToken, msg.sender);

    }

// Function to allow users to give donation to campaign using campaign ID and amount
// Require user to first give token approval to campaign contract for fund tokens
    function fundCampaign(uint256 _campaignID, uint256 _amount) external{
        Campaign storage camp = CampaignMapping[_campaignID];
        require(block.timestamp < camp.campaignEndTime, "Campaign Ended");
        camp.balance += _amount;
        UserContributions[_campaignID][msg.sender] += _amount;
        camp.FundToken.transferFrom(msg.sender, address(this), _amount);

        emit _fundCampaign(_campaignID, _amount, msg.sender);
    }

// Function to allow users to withdraw their fund if campign unable to reach target with in given time
    function withdrawFunds(uint256 _campaignID) external nonReentrant{
        Campaign storage camp = CampaignMapping[_campaignID];
        require(block.timestamp >= camp.campaignEndTime, "Campaign Not Ended");
        require(camp.balance < camp.fundingGoal, "Campaign Target Reached");

        uint amount = UserContributions[_campaignID][msg.sender];
        UserContributions[_campaignID][msg.sender] = 0;
        camp.FundToken.transfer(msg.sender, amount);

        emit _withdrawFromCampaign(_campaignID, msg.sender, amount);

    }

// Function to allow campaign owner to collect funds in his own wallet to be used for campaign objective
    function completeCampaign(uint256 _campaignID) external nonReentrant{
        Campaign storage camp = CampaignMapping[_campaignID];
        require(msg.sender == camp.campaignOwner && block.timestamp > camp.campaignEndTime, "Invalid access");
        require(camp.balance > camp.fundingGoal, "Target not reached");
        uint amount = camp.balance;
        camp.balance = 0;
        camp.FundToken.transfer(camp.campaignOwner, amount);
        emit _completeCampaign(_campaignID, amount);
    }

// Function to upgrade contract
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}