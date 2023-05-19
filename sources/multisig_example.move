module Multisig::Example {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, ID, UID};
    use sui::transfer;
 
    use Multisig::Multisig::{Self, MultiSignature};

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
        let multi_sig = Multisig::create_multisig(tx);
        transfer::share_object(Vault{ id: object::new(tx), for_admin: object::id(&multi_sig), for_cashier: object::id(&multi_sig)});
        transfer::public_share_object(multi_sig)
    }

    #[test_only]
    public fun init_for_testing(tx: &mut TxContext) {
        init(tx)
    }

    // create a mint request
    public fun mint_request(vault: &Vault, multi_signature: &mut MultiSignature, mint_to: address, amount: u256, tx: &mut TxContext){
        // only vault for cashier
        // only participant
        assert!(Multisig::is_participant(multi_signature, tx_context::sender(tx)), 1);
        Multisig::create_proposal(multi_signature, b"create to @mint_to", 1, MintRequest{id: object::new(tx), mint_to, amount}, tx);
        
    }

    // execute mint
    public fun mint_execute(vault: &Vault,  multi_signature: &mut MultiSignature, proposal_id: u256,  tx: &mut TxContext){
        // only vault for cashier

        assert!(Multisig::is_participant(multi_signature, tx_context::sender(tx)), 1);
        if(Multisig::is_proposal_approved(multi_signature, proposal_id)){
            let request = Multisig::borrow_proposal_request<MintRequest>(multi_signature, proposal_id);
            mint(request);
            Multisig::Multisig::mark_proposal_complete(multi_signature, proposal_id, tx);
        }
    }

    fun mint(request: &MintRequest){
        // called
    }
}