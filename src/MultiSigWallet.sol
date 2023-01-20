// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

error NotEnoughOwners();
error Unauthorized();
error CannotVoteTwice();
error CannotRetractWhenNotVoted();
error NotEnoughVotes();
error ExternalCallFailed();
error VotingClosed();
error VotingDoesNotExist();

contract MultiSigWallet {
    struct voting {
        uint256 id;
        address callee;
        bytes fn;
        uint256 weiAmount;
        address[] votes;
        bool isOpened;
    }

    mapping(address => bool) public isOwner;
    uint256 public ownersAmount;
    voting[] public votings;
    uint256 public votingsCounter = 0;

    event NewVoting(uint256 id, address callee, bytes fn, uint256 weiAmount);
    event VoteFor(uint256 id, address voter);
    event RetractVote(uint256 id, address voter);
    event ExternalCall(uint256 votingId, address caller);

    constructor(address[] memory owners_) {
        if(owners_.length <= 1)
            revert NotEnoughOwners();
        ownersAmount = owners_.length;
        for(uint256 i = 0; i < ownersAmount; i++)
        {
            isOwner[owners_[i]] = true;
        }
    }

    modifier onlyOwner {
        if(!isOwner[msg.sender])
            revert Unauthorized();
        _;
    }

    function newVoting(address callee, bytes memory fn, uint256 weiAmount) external onlyOwner returns (uint256) {
        uint256 votingId = _nextVotingNum();
        address[] memory votes;
        votings.push(voting(votingId, callee, fn, weiAmount, votes, true));
        emit NewVoting(votingId, callee, fn, weiAmount);
        return votingId;
    }

    function voteFor(uint256 votingId) external onlyOwner {
        if(votingId >= votingsCounter) revert VotingDoesNotExist();
        if(!votings[votingId].isOpened) revert VotingClosed();
        uint256 votesAmount = votings[votingId].votes.length;
        for(uint256 i = 0; i < votesAmount; i++) {
            if(votings[votingId].votes[i] == msg.sender) {
                revert CannotVoteTwice();
            }
        }
        votings[votingId].votes.push(msg.sender);
        emit VoteFor(votingId, msg.sender);
    }

    function retractVote(uint256 votingId) external onlyOwner {
        if(votingId >= votingsCounter) revert VotingDoesNotExist();
        if(!votings[votingId].isOpened) revert VotingClosed();
        uint256 votesAmount = votings[votingId].votes.length;
        for(uint256 i = 0; i < votesAmount; i++) {
            if(votings[votingId].votes[i] == msg.sender) {
                _removeByIndex(i, votings[votingId].votes);
                emit RetractVote(votingId, msg.sender);
                return;
            }
        }
        revert CannotRetractWhenNotVoted();
    }

    function callByABI(uint256 votingId) external payable onlyOwner returns (bytes memory) {
        if(votingId >= votingsCounter) revert VotingDoesNotExist();
        if(!votings[votingId].isOpened) revert VotingClosed();
        // Check if voting has 51% of votes.
        if(votings[votingId].votes.length * 100 / ownersAmount > 50) {
            (bool sent, bytes memory data) = votings[votingId].callee.call{value: votings[votingId].weiAmount}(votings[votingId].fn);
            if(!sent)
                revert ExternalCallFailed();
            votings[votingId].isOpened = false;
            emit ExternalCall(votingId, msg.sender);
            return data;
        }
        revert NotEnoughVotes();
    }

    function _removeByIndex(uint256 id, address[] storage arr) private {
        arr[id] = arr[arr.length - 1];
        arr.pop();
    }

    function _nextVotingNum() private returns (uint256) {
        return votingsCounter++;
    }

    function getVotings() view external returns (voting[] memory) {
        return votings;
    }
}
