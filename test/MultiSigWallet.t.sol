// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/MultiSigWallet.sol";

contract TestContract {
    uint256 public counter = 0;
    function next() external payable {
        counter++;
    }
}

contract MultiSigWalletTest is Test {
    MultiSigWallet public multiSigWallet;
    TestContract private testContract;

    function setUp() public {
        address[] memory owners_ = new address[](3);
        owners_[0] = address(this);
        owners_[1] = address(0);
        owners_[2] = address(1);
        multiSigWallet = new MultiSigWallet(owners_);
        testContract = new TestContract();
    }

    function testVoteFor() public {
        uint256 votingId = multiSigWallet.newVoting(address(testContract), abi.encodeWithSignature("next()"), 0);
        multiSigWallet.voteFor(votingId);
        assertEq(multiSigWallet.getVotings().length, 1);
        assertEq(multiSigWallet.getVotings()[0].votes.length, 1);
        assertEq(multiSigWallet.votingsCounter(), 1);
    }

    function testTwoVotes() public {
        uint256 votingId = multiSigWallet.newVoting(address(testContract), abi.encodeWithSignature("next()"), 0);
        multiSigWallet.voteFor(votingId);
        vm.prank(address(0));
        multiSigWallet.voteFor(votingId);
        assertEq(multiSigWallet.getVotings()[0].votes.length, 2);
    }

    function testCannotVoteTwice() public {
        uint256 votingId = multiSigWallet.newVoting(address(testContract), abi.encodeWithSignature("next()"), 0);
        multiSigWallet.voteFor(votingId);
        vm.expectRevert(CannotVoteTwice.selector);
        multiSigWallet.voteFor(votingId);
    }

    function testCannotVoteIfNotOwner() public {
        uint256 votingId = multiSigWallet.newVoting(address(testContract), abi.encodeWithSignature("next()"), 0);
        vm.prank(address(2));
        vm.expectRevert(Unauthorized.selector);
        multiSigWallet.voteFor(votingId);
    }

    function testRetractVote() public {
        uint256 votingId = multiSigWallet.newVoting(address(testContract), abi.encodeWithSignature("next()"), 0);
        multiSigWallet.voteFor(votingId);
        vm.prank(address(0));
        multiSigWallet.voteFor(votingId);
        multiSigWallet.retractVote(votingId);
        assertEq(multiSigWallet.getVotings()[0].votes.length, 1);
        assertEq(multiSigWallet.getVotings()[0].votes[0], address(address(0)));
    }

    function testCannotRetractVoteIfNotVoted() public {
        uint256 votingId = multiSigWallet.newVoting(address(testContract), abi.encodeWithSignature("next()"), 0);
        multiSigWallet.voteFor(votingId);
        vm.prank(address(0));
        vm.expectRevert(CannotRetractWhenNotVoted.selector);
        multiSigWallet.retractVote(votingId);
    }

    function testCannotRetractVoteIfVotingNotExists() public {
        vm.expectRevert();
        multiSigWallet.retractVote(0);
    }

    function testCannotRetractVoteIfNotOwner() public {
        vm.prank(address(2));
        vm.expectRevert(Unauthorized.selector);
        multiSigWallet.retractVote(0);
    }

    function testCallByAbi() public {
        // bytes(hex"4c8fe526") is the same as abi.encodeWithSignature("next()") that is used in other tests
        // Just tried different method
        uint256 votingId = multiSigWallet.newVoting(address(testContract), bytes(hex"4c8fe526"), 0);
        multiSigWallet.voteFor(votingId);
        vm.prank(address(0));
        multiSigWallet.voteFor(votingId);
        multiSigWallet.callByABI(votingId);
        assertEq(testContract.counter(), 1);
    }

    function testCallByAbiAfterAnotherVotingClosed() public {
        uint256 votingId1 = multiSigWallet.newVoting(address(testContract), abi.encodeWithSignature("next()"), 0);
        uint256 votingId2 = multiSigWallet.newVoting(address(testContract), abi.encodeWithSignature("next()"), 0);
        multiSigWallet.voteFor(votingId1);
        multiSigWallet.voteFor(votingId2);
        vm.prank(address(0));
        multiSigWallet.voteFor(votingId1);
        vm.prank(address(0));
        multiSigWallet.voteFor(votingId2);
        multiSigWallet.callByABI(votingId1);
        multiSigWallet.callByABI(votingId2);
        assertEq(testContract.counter(), 2);
    }

    function testCannotCallByAbiIfVotingNotExists() public {
        vm.expectRevert(VotingDoesNotExist.selector);
        multiSigWallet.callByABI(0);
    }

    function testCallByAbiWithSendingWei() public {
        vm.deal(address(multiSigWallet), 100e18);
        uint256 votingId = multiSigWallet.newVoting(address(testContract), abi.encodeWithSignature("next()"), 10e18);
        multiSigWallet.voteFor(votingId);
        vm.prank(address(0));
        multiSigWallet.voteFor(votingId);
        multiSigWallet.callByABI(votingId);
        assertEq(testContract.counter(), 1);
        assertEq(address(multiSigWallet).balance, 90e18);
        assertEq(address(testContract).balance, 10e18);
    }

    function testCannotTwiceCallByAbi() public {
        uint256 votingId = multiSigWallet.newVoting(address(testContract), abi.encodeWithSignature("next()"), 0);
        multiSigWallet.voteFor(votingId);
        vm.prank(address(0));
        multiSigWallet.voteFor(votingId);
        multiSigWallet.callByABI(votingId);
        vm.expectRevert(VotingClosed.selector);
        multiSigWallet.callByABI(votingId);
    }

    function testCannotCallByAbiIfNotEnoughVotes() public {
        uint256 votingId = multiSigWallet.newVoting(address(testContract), abi.encodeWithSignature("next()"), 0);
        multiSigWallet.voteFor(votingId);
        vm.expectRevert(NotEnoughVotes.selector);
        multiSigWallet.callByABI(votingId);
    }

    function testCannotCallByAbiIfNotOwner() public {
        vm.prank(address(2));
        vm.expectRevert(Unauthorized.selector);
        multiSigWallet.callByABI(0);
    }

    function testDontSendWeiIfCallFunctionCorrupted() public {
        vm.deal(address(multiSigWallet), 100e18);
        uint256 startBalance = address(multiSigWallet).balance;
        uint256 votingId = multiSigWallet.newVoting(address(testContract), abi.encodeWithSignature("grrgt"), 10e18);
        multiSigWallet.voteFor(votingId);
        vm.prank(address(0));
        multiSigWallet.voteFor(votingId);
        vm.expectRevert(ExternalCallFailed.selector);
        multiSigWallet.callByABI(votingId);
        assertEq(startBalance, address(multiSigWallet).balance);
    }
}
