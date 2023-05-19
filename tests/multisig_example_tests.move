#[test_only]
module Multisig::multisig_example_tests{
    use Multisig::Multisig::{MultiSignature};
    use sui::vec_map::{Self, VecMap};
    use Multisig::Example::{Self, Vault};
    use sui::test_scenario::{Self, Scenario};
    use std::vector::{Self};
    const user = @0xA; // weight 1
    const participant1 = @0xB; // weight 2
    const participant2 = @0xC; // weight 3
    #[test]
    public fun test_mint_single() {
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
        test_scenario::return_shared(vault);
        test_scenario::end(scenario_val);

    }

    #[expected_failure]
    #[test]
    public fun test_change_setting_access_deny() {
        let user = @0xA;
        let participant1 = @0xB;

        let scenario_val = test_scenario::begin(user);
        let scenario = &mut scenario_val;

        let scenario_val1 = test_scenario::begin(participant1);
        let scenario1 = &mut scenario_val1;
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
            let weight_map = vec_map::empty<address, u64>();
            let remove = vector::empty<address>();
            // create proposal using a unauthorized user
            Multisig::Multisig::create_multisig_setting_proposal(&mut multi_sig, b"propose from B", weight_map, remove, test_scenario::ctx(scenario1));
        };
        
        // end
        test_scenario::return_shared(multi_sig);
        test_scenario::return_shared(vault);

        test_scenario::end(scenario_val);
        test_scenario::end(scenario_val1);
    }

    fun change_setting(weight_map: VecMap<address, u64>,  remove: vector<address>, scenario: &mut Scenario ){
        let user = @0xA; // weight 1
        let multi_sig: MultiSignature;
        let vault: Vault;
        // change request
        test_scenario::next_tx(scenario, user);
        {
            multi_sig = test_scenario::take_shared<MultiSignature>(scenario);
            vault = test_scenario::take_shared<Vault>(scenario);
            // create proposal using a original user
            Multisig::Multisig::create_multisig_setting_proposal(&mut multi_sig, b"propose from B", weight_map, remove, test_scenario::ctx(scenario));
        };

        // vote
        test_scenario::next_tx(scenario, user);
        {
            Multisig::Multisig::vote(&mut multi_sig, 0, true, test_scenario::ctx(scenario));
        };
        // execute
        test_scenario::next_tx(scenario, user);
        {
            Multisig::Multisig::multisig_setting_execute(&mut multi_sig, 0, test_scenario::ctx(scenario));
        };
                   
        // end
        test_scenario::return_shared(multi_sig);
        test_scenario::return_shared(vault);
    }

    #[test]
    public fun test_change_setting_success(){

        let scenario_val = test_scenario::begin(user);
        let scenario = &mut scenario_val;
        // init
        {
            let ctx = test_scenario::ctx(scenario);
            Example::init_for_testing(ctx);
        };

        let multi_sig: MultiSignature;
        let vault: Vault;
        let weight_map = vec_map::empty<address, u64>();
        vec_map::insert<address, u64>(&mut weight_map, user, 1);
        vec_map::insert<address, u64>(&mut weight_map, participant1, 2);
        vec_map::insert<address, u64>(&mut weight_map, participant2, 3);
    }

    #[test]
    public fun test_change_setting_success() {
        let user = @0xA; // weight 1
        let participant1 = @0xB; // weight 2
        let participant2 = @0xC; // weight 3

        let scenario_val = test_scenario::begin(user);
        let scenario = &mut scenario_val;  
        // init
        {
            let ctx = test_scenario::ctx(scenario);
            Example::init_for_testing(ctx);
        };

        let multi_sig: MultiSignature;
        let vault: Vault;


        change_setting(weight_map(), remove_vector(), scenario);
        // now weight is user1: 1,  user2: 2, user3: 3

        // let scenario_val1 = test_scenario::begin(participant1);
        // let scenario1 = &mut scenario_val1;

        // let scenario_val2 = test_scenario::begin(participant2);
        // let scenario2 = &mut scenario_val2;      


        test_scenario::end(scenario_val);
        // test_scenario::end(scenario_val1);
        // test_scenario::end(scenario_val2);
            abort 32

    }

    fun weight_map(): VecMap<address, u64>{
        let weight_map = vec_map::empty<address, u64>();
        vec_map::insert<address, u64>(&mut weight_map, user, 1);
        vec_map::insert<address, u64>(&mut weight_map, participant1, 2);
        vec_map::insert<address, u64>(&mut weight_map, participant2, 3);
        weight_map
    }

    fun remove_vector(): vector<address>{
        let remove = vector::empty<address>();
        vector::push_back<address>(&mut remove, user);
        remove
    }
}