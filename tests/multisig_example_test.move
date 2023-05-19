#[test_only]
module Multisig::multisig_example_test{
    use Multisig::Multisig::{Self, MultiSignature};
    use Multisig::Example::{Self, Vault};
    use sui::test_scenario;
    use std::vector::{Self};

    #[test]
    public fun test_mint() {
        let user = @0xA;
        //let participant1 = @0xB;

        let scenario_val = test_scenario::begin(user);
        let scenario = &mut scenario_val;
        // init
        {
            let ctx = test_scenario::ctx(scenario);
            Example::init_for_testing(ctx);
        };

        let multi_sig: MultiSignature;
        let vault: Vault;
        // mint request
        test_scenario::next_tx(scenario, user);
        {
            multi_sig = test_scenario::take_shared<MultiSignature>(scenario);
            vault = test_scenario::take_shared<Vault>(scenario);

            Multisig::Example::mint_request(&vault, &mut multi_sig, user, 100, test_scenario::ctx(scenario));
        };
        // query proposal
        let proposal_id: u256;
        test_scenario::next_tx(scenario, user);
        {
            let proposals = Multisig::Multisig::pending_proposals(&mut multi_sig, user, test_scenario::ctx(scenario));
            assert!(vector::length(&proposals) == 1, 1);
            proposal_id = vector::pop_back(&mut proposals);
        };
        // vote
        test_scenario::next_tx(scenario, user);
        {
            Multisig::Multisig::vote(&mut multi_sig, proposal_id, true, test_scenario::ctx(scenario));
        };
        // execute
        test_scenario::next_tx(scenario, user);
        {
            Multisig::Example::mint_execute(&vault,&mut multi_sig, proposal_id, test_scenario::ctx(scenario));
        };

        // execute
        test_scenario::next_tx(scenario, user);
        {
            let proposals = Multisig::Multisig::pending_proposals(&mut multi_sig, user, test_scenario::ctx(scenario));
            assert!(vector::length(&proposals) == 0, 1);

        };
        // end
        test_scenario::return_shared(multi_sig);
        test_scenario::end(scenario_val);

    }
}