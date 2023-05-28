#[test_only]
module multisig::Example {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, ID, UID};
    use sui::transfer;
 
    use multisig::multisig::{Self, MultiSignature};

    struct MintRequest has store, key{
        id: UID,
        mint_to: address,
        amount: u256
    }

    struct Vault has store, key{
        id: UID,
        for_admin: ID,
        for_cashier:  ID
    }

    fun init(tx: &mut TxContext){
        let multi_sig = multisig::create_multisig(tx);
        transfer::share_object(Vault{ id: object::new(tx), for_admin: object::id(&multi_sig), for_cashier: object::id(&multi_sig)});
        transfer::public_share_object(multi_sig)
    }

    #[test_only]
    public fun init_for_testing(tx: &mut TxContext) {
        init(tx)
    }

    // create a mint request
    public fun mint_request(_: &Vault, multi_signature: &mut MultiSignature, mint_to: address, amount: u256, tx: &mut TxContext){
        // only vault for cashier
        // only participant
        assert!(multisig::is_participant(multi_signature, tx_context::sender(tx)), 1);
        multisig::create_proposal(multi_signature, b"create to @mint_to", 1, MintRequest{id: object::new(tx), mint_to, amount}, tx);
        
    }

    // execute mint
    public fun mint_execute(_: &Vault,  multi_signature: &mut MultiSignature, proposal_id: u256,  tx: &mut TxContext){
        // only vault for cashier

        assert!(multisig::is_participant(multi_signature, tx_context::sender(tx)), 1);
        let (is_approved, _) = multisig::is_proposal_approved(multi_signature, proposal_id);
        if(is_approved){
            let request = multisig::borrow_proposal_request<MintRequest>(multi_signature, &proposal_id, tx);
            mint(request);
            multisig::multisig::mark_proposal_complete(multi_signature, proposal_id, tx);
        }
    }

    public fun mint_execute_vote_not_pass(_: &Vault,  multi_signature: &mut MultiSignature, proposal_id: u256,  tx: &mut TxContext){
        // only vault for cashier

        assert!(multisig::is_participant(multi_signature, tx_context::sender(tx)), 1);
        let request = multisig::borrow_proposal_request<MintRequest>(multi_signature, &proposal_id, tx);
        mint(request);
        multisig::multisig::mark_proposal_complete(multi_signature, proposal_id, tx);
    }

    public fun complete(_: &Vault,  multi_signature: &mut MultiSignature, proposal_id: u256,  tx: &mut TxContext){
        multisig::multisig::mark_proposal_complete(multi_signature, proposal_id, tx);
    }

    fun mint(_: &MintRequest){
        // called
        
    }
}