// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title RelayerRegistry
 * @notice Registry and payment system for privacy-preserving relayers
 * @dev Inspired by Tornado Cash relayer architecture
 * 
 * Relayers enable gas abstraction by:
 * 1. Executing transactions on behalf of users
 * 2. Paying gas costs upfront
 * 3. Receiving fees from the privacy pool
 * 
 * This breaks the link between the user's funding address and their private operations.
 */
contract RelayerRegistry is ReentrancyGuard {
    
    // Minimum stake required to become a relayer
    uint256 public constant MIN_STAKE = 1 ether;
    
    // Maximum fee percentage (basis points: 10000 = 100%)
    uint256 public constant MAX_FEE_BPS = 500; // 5%
    
    // Cooldown period before unstaking
    uint256 public constant UNSTAKE_DELAY = 7 days;
    
    struct Relayer {
        uint256 stake;           // Amount staked by relayer
        uint256 feeBps;          // Fee in basis points (e.g., 100 = 1%)
        uint256 totalTxs;        // Total transactions executed
        uint256 successfulTxs;   // Successful transactions
        uint256 unstakeTime;     // Timestamp when unstake was requested
        bool isActive;           // Whether relayer is active
        bool exists;             // Whether relayer exists in registry
    }
    
    // Relayer address => Relayer info
    mapping(address => Relayer) public relayers;
    
    // Array of all relayer addresses
    address[] public relayerList;
    
    // Admin address
    address public admin;
    
    // Events
    event RelayerRegistered(address indexed relayer, uint256 stake, uint256 feeBps);
    event RelayerDeactivated(address indexed relayer);
    event RelayerReactivated(address indexed relayer);
    event StakeIncreased(address indexed relayer, uint256 amount);
    event UnstakeRequested(address indexed relayer, uint256 unlockTime);
    event StakeWithdrawn(address indexed relayer, uint256 amount);
    event FeeUpdated(address indexed relayer, uint256 oldFee, uint256 newFee);
    event TransactionExecuted(address indexed relayer, address indexed user, bool success);
    event RelayerSlashed(address indexed relayer, uint256 amount, string reason);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }
    
    modifier onlyActiveRelayer() {
        require(relayers[msg.sender].exists, "Not a relayer");
        require(relayers[msg.sender].isActive, "Relayer not active");
        _;
    }
    
    constructor() {
        admin = msg.sender;
    }
    
    /**
     * @notice Register as a relayer with stake
     * @param feeBps Fee in basis points (100 = 1%)
     */
    function registerRelayer(uint256 feeBps) external payable {
        require(!relayers[msg.sender].exists, "Already registered");
        require(msg.value >= MIN_STAKE, "Insufficient stake");
        require(feeBps <= MAX_FEE_BPS, "Fee too high");
        
        relayers[msg.sender] = Relayer({
            stake: msg.value,
            feeBps: feeBps,
            totalTxs: 0,
            successfulTxs: 0,
            unstakeTime: 0,
            isActive: true,
            exists: true
        });
        
        relayerList.push(msg.sender);
        
        emit RelayerRegistered(msg.sender, msg.value, feeBps);
    }
    
    /**
     * @notice Increase stake
     */
    function increaseStake() external payable onlyActiveRelayer {
        require(msg.value > 0, "Must send ETH");
        relayers[msg.sender].stake += msg.value;
        emit StakeIncreased(msg.sender, msg.value);
    }
    
    /**
     * @notice Request to unstake (starts cooldown)
     */
    function requestUnstake() external onlyActiveRelayer {
        require(relayers[msg.sender].unstakeTime == 0, "Unstake already requested");
        
        relayers[msg.sender].unstakeTime = block.timestamp + UNSTAKE_DELAY;
        relayers[msg.sender].isActive = false;
        
        emit UnstakeRequested(msg.sender, relayers[msg.sender].unstakeTime);
    }
    
    /**
     * @notice Withdraw stake after cooldown
     */
    function withdrawStake() external nonReentrant {
        Relayer storage relayer = relayers[msg.sender];
        require(relayer.exists, "Not a relayer");
        require(relayer.unstakeTime > 0, "Unstake not requested");
        require(block.timestamp >= relayer.unstakeTime, "Cooldown not finished");
        
        uint256 amount = relayer.stake;
        require(amount > 0, "No stake to withdraw");
        
        relayer.stake = 0;
        relayer.unstakeTime = 0;
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        
        emit StakeWithdrawn(msg.sender, amount);
    }
    
    /**
     * @notice Cancel unstake request and reactivate
     */
    function cancelUnstake() external {
        require(relayers[msg.sender].exists, "Not a relayer");
        require(relayers[msg.sender].unstakeTime > 0, "No unstake request");
        
        relayers[msg.sender].unstakeTime = 0;
        relayers[msg.sender].isActive = true;
        
        emit RelayerReactivated(msg.sender);
    }
    
    /**
     * @notice Update fee (must be lower or equal to max)
     * @param newFeeBps New fee in basis points
     */
    function updateFee(uint256 newFeeBps) external onlyActiveRelayer {
        require(newFeeBps <= MAX_FEE_BPS, "Fee too high");
        
        uint256 oldFee = relayers[msg.sender].feeBps;
        relayers[msg.sender].feeBps = newFeeBps;
        
        emit FeeUpdated(msg.sender, oldFee, newFeeBps);
    }
    
    /**
     * @notice Record transaction execution (called by SPNFT contract)
     * @param relayer Address of the relayer
     * @param success Whether transaction succeeded
     */
    function recordTransaction(address relayer, bool success) external {
        // In production, only allow SPNFT contract to call this
        // For now, we track all calls
        require(relayers[relayer].exists, "Not a relayer");
        
        relayers[relayer].totalTxs++;
        if (success) {
            relayers[relayer].successfulTxs++;
        }
        
        emit TransactionExecuted(relayer, msg.sender, success);
    }
    
    /**
     * @notice Slash relayer for misbehavior (admin only)
     * @param relayer Address to slash
     * @param amount Amount to slash
     * @param reason Reason for slashing
     */
    function slashRelayer(
        address relayer,
        uint256 amount,
        string calldata reason
    ) external onlyAdmin {
        require(relayers[relayer].exists, "Not a relayer");
        require(amount <= relayers[relayer].stake, "Slash exceeds stake");
        
        relayers[relayer].stake -= amount;
        
        // Send slashed amount to admin (could go to treasury)
        (bool success, ) = admin.call{value: amount}("");
        require(success, "Transfer failed");
        
        emit RelayerSlashed(relayer, amount, reason);
    }
    
    /**
     * @notice Deactivate a relayer (admin only)
     * @param relayer Address to deactivate
     */
    function deactivateRelayer(address relayer) external onlyAdmin {
        require(relayers[relayer].exists, "Not a relayer");
        require(relayers[relayer].isActive, "Already inactive");
        
        relayers[relayer].isActive = false;
        emit RelayerDeactivated(relayer);
    }
    
    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    /**
     * @notice Get relayer information
     */
    function getRelayer(address relayer) external view returns (
        uint256 stake,
        uint256 feeBps,
        uint256 totalTxs,
        uint256 successfulTxs,
        bool isActive
    ) {
        Relayer memory r = relayers[relayer];
        return (r.stake, r.feeBps, r.totalTxs, r.successfulTxs, r.isActive);
    }
    
    /**
     * @notice Check if address is an active relayer
     */
    function isActiveRelayer(address relayer) external view returns (bool) {
        return relayers[relayer].exists && relayers[relayer].isActive;
    }
    
    /**
     * @notice Calculate fee for given amount
     * @param relayer Relayer address
     * @param amount Transaction amount
     * @return Fee amount
     */
    function calculateFee(address relayer, uint256 amount) public view returns (uint256) {
        if (!relayers[relayer].exists) return 0;
        return (amount * relayers[relayer].feeBps) / 10000;
    }
    
    /**
     * @notice Get success rate for relayer
     * @param relayer Relayer address
     * @return Success rate in basis points (10000 = 100%)
     */
    function getSuccessRate(address relayer) external view returns (uint256) {
        Relayer memory r = relayers[relayer];
        if (r.totalTxs == 0) return 0;
        return (r.successfulTxs * 10000) / r.totalTxs;
    }
    
    /**
     * @notice Get all relayers
     */
    function getAllRelayers() external view returns (address[] memory) {
        return relayerList;
    }
    
    /**
     * @notice Get all active relayers
     */
    function getActiveRelayers() external view returns (address[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < relayerList.length; i++) {
            if (relayers[relayerList[i]].isActive) {
                activeCount++;
            }
        }
        
        address[] memory active = new address[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < relayerList.length; i++) {
            if (relayers[relayerList[i]].isActive) {
                active[index] = relayerList[i];
                index++;
            }
        }
        
        return active;
    }
}


