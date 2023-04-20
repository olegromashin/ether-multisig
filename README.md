# Multi-signature wallet

Account for multiple (at least 2) constant owners. Requires 51% of votes to make external calls or transfer native tokens.

## API

`newVoting` - creates new voting with 0 votes and returns its id. Takes callee address, ABI encoded function and amount of wei to be transferred to callee address. If you dont want to send any wei, you can pass 0. If you call a function and send wei to it the function must be payable.

`voteFor` - takes voting id and adds sender's vote for voting if sender is an owner of this wallet.

`retractVote` - retracts sender's vote if voted before.

`multiSigCall` - makes external call if voting has 51% of votes and if sender is one of the owners.
