# multisig on sui move

## Example 
see multisig_example.move

## How To Use
1、create MultiSignature in your contract
```rust
public fun create_multisig(_tx: &mut TxContext): MultiSignature
```
2、change the voting weight of the MultiSignature
```rust
public entry fun create_multisig_setting_proposal(multi_signature: &mut MultiSignature, description: vector<u8>, participants: vector<address>, participant_weights: vector<u64>, participants_remove: vector<address>, _tx: &mut TxContext){

```
3、vote to the proposal
```rust
public entry fun vote(multi_signature: &mut MultiSignature, proposal_id: u256, is_approve: bool, _tx: &mut TxContext){
```
4、execute the weight changing proposal to make it effect
```rust
public entry fun multisig_setting_execute(multi_signature: &mut MultiSignature, proposal_id: u256, _tx: &mut TxContext){
```

now you can use multi parties to control to your contract.
for business votes:
6、call create_proposal proposal in your contract like below, (the first user is proposer)
```rust
// create a mint request
public fun mint_request(_: &Vault, multi_signature: &mut MultiSignature, mint_to: address, amount: u256, tx: &mut TxContext){
        // only vault for cashier
        // only participant
        assert!(multisig::is_participant(multi_signature, tx_context::sender(tx)), 1);
        multisig::create_proposal(multi_signature, b"create to @mint_to", 1, MintRequest{id: object::new(tx), mint_to, amount}, tx);
    }
```

7、vote to proposal
8、other voter can check their by call, the returned vector is the proposal ids
```rust
public entry fun pending_proposals(multi_signature: &MultiSignature, user: address, _tx: &TxContext): vector<u256>
```

do repeat voting by each voter

9、check the voting status by calling

```rust
public entry fun is_proposal_approved(multi_signature: &mut MultiSignature, proposal_id: u256): bool

```

when sum of the voter's weigh > threshold, the business contract can do its job. like below

```rust
// execute mint
public fun mint_execute(_: &Vault,  multi_signature: &mut MultiSignature, proposal_id: u256,  tx: &mut TxContext){
    // only vault for cashier

    assert!(multisig::is_participant(multi_signature, tx_context::sender(tx)), 1);
    if(multisig::is_proposal_approved(multi_signature, proposal_id)){
        let request = multisig::borrow_proposal_request<MintRequest>(multi_signature, proposal_id);
        mint(request);
        multisig::multisig::mark_proposal_complete(multi_signature, proposal_id, tx);
    }
}
```
make sure mark_proposal_complete is called when business is finished.

if business want to consume the original request body (for example *Coin\<SUI\>*), use 

```rust
public fun extract_proposal_request<T: store + key>(multi_signature: &mut MultiSignature, proposal_id: u256, _tx: &mut TxContext): T
``` 
instead of

```rust
multisig::borrow_proposal_request<MintRequest>(multi_signature, proposal_id);
```


# package address
## devnet
https://suiexplorer.com/object/0xe4f251af57e158b078eb150a4f394b38b3454421c0b0bab6ebadaf7dc75ea3f2?module=multisig&network=devnet

0xe4f251af57e158b078eb150a4f394b38b3454421c0b0bab6ebadaf7dc75ea3f2::multisig

## testnet
TBD
## mainnet
TBD