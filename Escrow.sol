// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importing necessary OpenZeppelin contracts for security and access control
import "@openzeppelin/contracts/security/Pausable.sol"; // Allows the contract to be paused
import "@openzeppelin/contracts/access/Ownable.sol"; // Provides ownership control

// Escrow contract that allows two parties to securely exchange funds
contract Escrow is Pausable, Ownable {
    // Enum to represent the different states of an escrow
    enum EscrowState { Created, Funded, Completed, Refunded }

    // Struct to hold the details of an escrow transaction
    struct EscrowDetails {
        address payable buyer;       // Address of the buyer
        address payable seller;      // Address of the seller
        uint256 amount;              // Amount of funds held in escrow
        EscrowState state;           // Current state of the escrow
        uint256 createdAt;           // Timestamp when the escrow was created
    }

    // Mapping to store escrows by their ID
    mapping(uint256 => EscrowDetails) public escrows; // Maps escrow ID to its details
    uint256 public escrowCount;      // Counter for the number of escrows created
    uint256 public timeoutPeriod;    // Timeout period in seconds for automatic refunds

    // Events to log important actions for transparency
    event EscrowCreated(uint256 escrowId, address buyer, address seller, uint256 amount); // Event for escrow creation
    event EscrowFunded(uint256 escrowId); // Event for funding an escrow
    event EscrowCompleted(uint256 escrowId); // Event for completing an escrow
    event EscrowRefunded(uint256 escrowId); // Event for refunding an escrow

    // Modifier to restrict access to the buyer of the escrow
    modifier onlyBuyer(uint256 _escrowId) {
        require(msg.sender == escrows[_escrowId].buyer, "Only the buyer can call this function"); // Check if the sender is the buyer
        _; // Continue execution
    }

    // Modifier to restrict access to the seller of the escrow
    modifier onlySeller(uint256 _escrowId) {
        require(msg.sender == escrows[_escrowId].seller, "Only the seller can call this function"); // Check if the sender is the seller
        _; // Continue execution
    }

    // Modifier to check if the escrow is in a specific state
    modifier inState(uint256 _escrowId, EscrowState _state) {
        require(escrows[_escrowId].state == _state, "Invalid escrow state"); // Ensure the escrow is in the expected state
        _; // Continue execution
    }

    // Constructor to set the timeout period
    constructor(uint256 _timeoutPeriod) {
        timeoutPeriod = _timeoutPeriod; // Set the timeout period for refunds
    }

    // Function to create a new escrow
    function createEscrow(address payable _seller) external payable whenNotPaused {
        require(msg.value > 0, "Amount must be greater than zero"); // Ensure the sent amount is greater than zero
        
        // Increment the escrow count and create a new escrow entry
        escrowCount++;
        escrows[escrowCount] = EscrowDetails({
            buyer: payable(msg.sender),  // Set the buyer to the sender's address
            seller: _seller,             // Set the seller to the provided address
            amount: msg.value,           // Set the initial amount of funds
            state: EscrowState.Created,  // Set the initial state to Created
            createdAt: block.timestamp    // Set the creation timestamp
        });

        emit EscrowCreated(escrowCount, msg.sender, _seller, msg.value); // Emit an event for escrow creation
    }

    // Function to fund an existing escrow
    function fundEscrow(uint256 _escrowId) external payable onlyBuyer(_escrowId) inState(_escrowId, EscrowState.Created) whenNotPaused {
        require(msg.value > 0, "Amount must be greater than zero"); // Ensure the sent amount is greater than zero
        
        // Add the new funds to the existing escrow amount
        escrows[_escrowId].amount += msg.value;
        // Update the state of the escrow to Funded
        escrows[_escrowId].state = EscrowState.Funded;

        emit EscrowFunded(_escrowId); // Emit an event for funding the escrow
    }

    // Function to complete the escrow and transfer funds to the seller
    function completeEscrow(uint256 _escrowId) external onlySeller(_escrowId) inState(_escrowId, EscrowState.Funded) whenNotPaused {
        EscrowDetails storage escrow = escrows[_escrowId]; // Get a reference to the escrow details

        // Transfer the funds to the seller
        escrow.seller.transfer(escrow.amount);
        // Update the state of the escrow to Completed
        escrow.state = EscrowState.Completed;

        emit EscrowCompleted(_escrowId); // Emit an event for completing the escrow
    }

    // Function to refund the buyer if the escrow is not funded within the timeout period
    function refundEscrow(uint256 _escrowId) external onlyBuyer(_escrowId) inState(_escrowId, EscrowState.Created) whenNotPaused {
        require(block.timestamp >= escrows[_escrowId].createdAt + timeoutPeriod, "Timeout period has not yet passed"); // Check if the timeout period has passed

        EscrowDetails storage escrow = escrows[_escrowId]; // Get a reference to the escrow details
        // Transfer the funds back to the buyer
        escrow.buyer.transfer(escrow.amount);
        // Update the state of the escrow to Refunded
        escrow.state = EscrowState.Refunded;

        emit EscrowRefunded(_escrowId); // Emit an event for refunding the escrow
    }

    // Function to pause the contract in case of emergencies
    function pause() external onlyOwner {
        _pause(); // Call the internal pause function from the Pausable contract
    }

    // Function to unpause the contract
    function unpause() external onlyOwner {
        _unpause(); // Call the internal unpause function from the Pausable contract
    }
}
