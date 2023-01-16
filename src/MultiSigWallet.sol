// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

error NotEnoughOwners();
error Unauthorized();
error CannotVoteTwice();
error CannotRetractWhenNotVoted();
error NotEnoughVotes();
error ExternalCallFailed();

contract MultiSigWallet {
    struct openVoting {
        uint256 id;
        address callee;
        bytes fn;
        uint256 weiAmount;
        address[] votes;
    }

    mapping(address => bool) isOwner;
    uint256 public ownersAmount;
    openVoting[] public openVotings;
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
        uint256 votingId = nextVotingNum();
        address[] memory votes;
        openVotings.push(openVoting(votingId, callee, fn, weiAmount, votes));
        emit NewVoting(votingId, callee, fn, weiAmount);
        return votingId;
    }

    function voteFor(uint256 votingId) external onlyOwner {
        uint256 votesAmount = openVotings[votingId].votes.length;
        for(uint256 i = 0; i < votesAmount; i++) {
            if(openVotings[votingId].votes[i] == msg.sender) {
                revert CannotVoteTwice();
            }
        }
        openVotings[votingId].votes.push(msg.sender);
        emit VoteFor(votingId, msg.sender);
    }

    function retractVote(uint256 votingId) external onlyOwner{
        uint256 votesAmount = openVotings[votingId].votes.length;
        for(uint256 i = 0; i < votesAmount; i++) {
            if(openVotings[votingId].votes[i] == msg.sender) {
                removeByIndex(i, openVotings[votingId].votes);
                if(votesAmount == 1) {
                    removeByIndex(votingId, openVotings);
                }
                emit RetractVote(votingId, msg.sender);
                return;
            }
        }
        revert CannotRetractWhenNotVoted();
    }

    function callByABI(uint256 votingId) external payable onlyOwner returns (bytes memory) {
        // Check if voting has 51% of votes.
        if(openVotings[votingId].votes.length * 100 / ownersAmount > 50) {
            (bool sent, bytes memory data) = openVotings[votingId].callee.call{value: openVotings[votingId].weiAmount}(openVotings[votingId].fn);
            if(!sent)
                revert ExternalCallFailed();
            removeByIndex(votingId, openVotings);
            emit ExternalCall(votingId, msg.sender);
            return data;
        }
        revert NotEnoughVotes();
    }

    function removeByIndex(uint256 id, address[] storage arr) private {
        arr[id] = arr[arr.length - 1];
        arr.pop();
    }

    function removeByIndex(uint256 id, openVoting[] storage arr) private {
        arr[id] = arr[arr.length - 1];
        arr.pop();
    }

    function nextVotingNum() private returns (uint256) {
        return votingsCounter++;
    }

    function getOpenVotings() view external returns (openVoting[] memory) {
        return openVotings;
    }
}
