// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

contract BetTribe {

    struct Bet {
        uint256 id;
        string eventName;
        uint256 amount;
        address creator;
        mapping(address => bool) predictions;
        mapping(address => bool) hasPaid;
        bool isResolved;
        bool result;
        address[] user;
    }

    mapping(uint256 => Bet) public groupBets;
    address public admin;
    uint256 public totalBets;

    event BetCreated(
        uint256 indexed betId,
        string eventName,
        uint256 amount,
        address creator
    );
    event BetParticipated(
        uint256 indexed betId,
        address indexed user,
        bool prediction
    );
    event BetResolved(
        uint256 indexed betId,
        bool result,
        uint256 totalPool,
        uint256 winningAmount
    );

    constructor(address _admin) {
        admin = _admin;
    }

    function createBet(
        string memory _eventName,
        uint256 _amount
    ) external {
        require(_amount >= 1, "Minimum bet amount is 1");
        Bet storage newBet = groupBets[totalBets];
        newBet.id = totalBets;
        newBet.eventName = _eventName;
        newBet.amount = _amount;
        newBet.creator = msg.sender;

        emit BetCreated(totalBets, _eventName, _amount, msg.sender);
        totalBets = totalBets + 1;
    }

    function participateInBet(
        uint256 _betId,
        bool _prediction
    ) external  payable {
        Bet storage bet = groupBets[_betId];
        require(!bet.isResolved, "Bet has already been resolved");
        require(!bet.hasPaid[msg.sender], "Already participated");
        require(msg.value == bet.amount, "Incorrect bet amount");

        bet.predictions[msg.sender] = _prediction;
        bet.hasPaid[msg.sender] = true;
        bet.user.push(msg.sender);
        
        emit BetParticipated(_betId, msg.sender, _prediction);
    }

    function resolveBet(
        uint256 _betId,
        bool _result
    ) external {
        Bet storage bet = groupBets[_betId];
        require(!bet.isResolved, "Bet has already been resolved");
        require(bet.user.length > 0, "No participants in bet");

        bet.isResolved = true;
        bet.result = _result;

        uint256 totalPool = _calculateTotalPool(_betId);
        require(totalPool > 0, "No funds in pool");
        uint256 winningAmount = _calculateWinningAmount(_betId, totalPool);

        emit BetResolved(_betId, _result, totalPool, winningAmount);

        _distributeWinnings(_betId, winningAmount);
    }

    function _calculateTotalPool(uint256 _betId) internal view returns (uint256) {
        Bet storage bet = groupBets[_betId];
        uint256 totalPool = 0;
        
        for (uint i = 0; i < bet.user.length; i++) {
            if (bet.hasPaid[bet.user[i]]) {
                totalPool += bet.amount;
            }
        }
        return totalPool;
    }

    function _calculateWinningAmount(uint256 _betId, uint256 _totalPool) internal view returns (uint256) {
        Bet storage bet = groupBets[_betId];
        uint256 winnerCount = 0;
        
        for (uint i = 0; i < bet.user.length; i++) {
            if (bet.predictions[bet.user[i]] == bet.result) {
                winnerCount++;
            }
        }
        require(winnerCount > 0, "No winners found");
        return _totalPool / winnerCount;
    }

    function _distributeWinnings(uint256 _betId, uint256 _winningAmount) internal {
        Bet storage bet = groupBets[_betId];
        require(
            address(this).balance >= _winningAmount,
            "Insufficient contract balance"
        );
        
        for (uint i = 0; i < bet.user.length; i++) {
            if (bet.predictions[bet.user[i]] == bet.result) {
                payable(bet.user[i]).transfer(_winningAmount);
                bet.hasPaid[bet.user[i]] = false;
            }
        }
    }
}