// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

error NotEnoughOwners();
error Unauthorized();
error CannotVoteTwice();
error CannotRetractWhenNotVoted();
error NotEnoughVotes();
error MultiSigActionFailed();
error VotingClosed();
error VotingDoesNotExist();

/// @notice Conctract allows multi-signature calls having 51% of signatures.
/// Owners' wallets specified on deploy and cannot be modified after.
/// @dev All votings for multi-signature calls are stored in "votings" mapping.
contract MultiSigWallet {
    struct Voting {
        address payable callee;
        bytes fn;
        uint256 weiAmount;
        address[] votes;
        bool isOpened;
    }

    mapping(address => bool) public isOwner;
    uint256 public ownersAmount;
    mapping(uint256 => Voting) public votings;
    uint256 public votingsCounter = 0;

    event NewVoting(uint256 indexed votingId, address callee, bytes fn, uint256 weiAmount);
    event VoteFor(uint256 indexed votingId , address voter);
    event RetractVote(uint256 indexed votingId, address voter);
    event MultiSigAction(uint256 indexed votingId, address caller);

    /// @notice Minimum 2 owners. Maximum not limited.
    /// @param owners - owners' wallets.
    constructor(address[] memory owners) {
        if(owners.length <= 1)
            revert NotEnoughOwners();
        ownersAmount = owners.length;
        for(uint256 i = 0; i < ownersAmount; i++)
        {
            isOwner[owners[i]] = true;
        }
    }

    modifier onlyOwner {
        if(!isOwner[msg.sender])
            revert Unauthorized();
        _;
    }

    /// @notice Opens new voting.
    /// @param callee - address of the callee contract.
    /// @param fn - ABI encoded function call. If empty string sent only WEI will be transferred.
    /// @param weiAmount - amount of WEI to transfer to callee.
    /// @return Identifier of the new voting.
    function newVoting(address payable callee, bytes memory fn, uint256 weiAmount) external onlyOwner returns (uint256) {
        uint256 votingId = _nextVotingId();
        address[] memory votes;
        votings[votingId] = Voting(callee, fn, weiAmount, votes, true);
        emit NewVoting(votingId, callee, fn, weiAmount);
        return votingId;
    }

    /// @notice Allows vote for an opened voting.
    /// @param votingId - identifier of the voting.
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

    /// @notice Allows retract vote from an opened voting.
    /// @param votingId - identifier of the voting.
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

    /// @notice Perform action if voting has 51% of votes.
    /// Perform contract's call if the voting's "fn" is not empty, sends WEI otherwise.
    /// @param votingId - identifier of the voting.
    function multiSigAction(uint256 votingId) external payable onlyOwner {
        if(votingId >= votingsCounter) revert VotingDoesNotExist();
        if(!votings[votingId].isOpened) revert VotingClosed();
        // Check if voting has 51% of votes.
        if(votings[votingId].votes.length * 100 / ownersAmount <= 50) revert NotEnoughVotes();
        
        (bool sent, /*bytes memory data*/) = votings[votingId].callee.call{value: votings[votingId].weiAmount}(votings[votingId].fn);
        if(!sent)
            revert MultiSigActionFailed();
        votings[votingId].isOpened = false;
        emit MultiSigAction(votingId, msg.sender);
    }

    /// @notice Helper function.
    /// @dev Check for correctness of id param is made outside. Used only in "retractVote" function.
    function _removeByIndex(uint256 id, address[] storage arr) private {
        arr[id] = arr[arr.length - 1];
        arr.pop();
    }

    /// @notice Helper function.
    /// @dev Used only in "newVoting" function.
    /// @return New voting id.
    function _nextVotingId() private returns (uint256) {
        // Notice the order of evaluation here.
        // Firstly we return a value and only after increase it by 1.
        return votingsCounter++;
    }

    /// @notice Helper function for tests. Remove on deploy.
    /// @dev https://stackoverflow.com/questions/72124271/solidity-mapping-not-returns-an-array-in-a-struct
    function getVotedAddresses(uint256 votingId) public view returns (address[] memory) {
        return votings[votingId].votes;
    }
}
