#[test_only]
module multisig::multisig_example_tests{
    use multisig::multisig::{MultiSignature};
    use sui::vec_map::{Self, VecMap};
    use multisig::Example::{Self, Vault};
    use sui::test_scenario::{Self, Scenario};
    use std::vector::{Self};
    const USER: address = @0xA; // weight 1
    const PARTICIPANT1: address = @0xB; // weight 2
    const PARTICIPANT2: address = @0xC; // weight 3
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

            multisig::Example::mint_request(&vault, &mut multi_sig, user, 100, test_scenario::ctx(scenario));
        };
        // query proposal
        let proposal_id: u256;
        test_scenario::next_tx(scenario, user);
        {
            let proposals = multisig::multisig::pending_proposals(&mut multi_sig, user, test_scenario::ctx(scenario));
            assert!(vector::length(&proposals) == 1, 1);
            proposal_id = vector::pop_back(&mut proposals);
        };
        // vote
        test_scenario::next_tx(scenario, user);
        {
            multisig::multisig::vote(&mut multi_sig, proposal_id, true, test_scenario::ctx(scenario));
        };
        // execute
        test_scenario::next_tx(scenario, user);
        {
            multisig::Example::mint_execute(&vault,&mut multi_sig, proposal_id, test_scenario::ctx(scenario));
        };

        // execute
        test_scenario::next_tx(scenario, user);
        {
            let proposals = multisig::multisig::pending_proposals(&mut multi_sig, user, test_scenario::ctx(scenario));
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
            multisig::multisig::create_multisig_setting_proposal(&mut multi_sig, b"propose from B", weight_map, remove, test_scenario::ctx(scenario1));
        };
        
        // end
        test_scenario::return_shared(multi_sig);
        test_scenario::return_shared(vault);

        test_scenario::end(scenario_val);
        test_scenario::end(scenario_val1);
    }

    fun change_setting(weight_map: VecMap<address, u64>,  remove: vector<address>, scenario: &mut Scenario ){
        let multi_sig: MultiSignature;
        let vault: Vault;
        // change request
        test_scenario::next_tx(scenario, USER);
        {
            multi_sig = test_scenario::take_shared<MultiSignature>(scenario);
            vault = test_scenario::take_shared<Vault>(scenario);
            // create proposal using a original user
            multisig::multisig::create_multisig_setting_proposal(&mut multi_sig, b"propose from B", weight_map, remove, test_scenario::ctx(scenario));
        };

        // vote
        test_scenario::next_tx(scenario, USER);
        {
            multisig::multisig::vote(&mut multi_sig, 0, true, test_scenario::ctx(scenario));
        };
        // execute
        test_scenario::next_tx(scenario, USER);
        {
            multisig::multisig::multisig_setting_execute(&mut multi_sig, 0, test_scenario::ctx(scenario));
        };
         
        // end
        test_scenario::return_shared(multi_sig);
        test_scenario::return_shared(vault);

        test_scenario::next_tx(scenario, USER);

    }

    #[test]
    public fun test_change_setting_success(){

        let scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;
        // init
        {
            let ctx = test_scenario::ctx(scenario);
            Example::init_for_testing(ctx);
        };
        change_setting(weight_map(), remove_vector(), scenario);
        test_scenario::end(scenario_val); 
    }

    #[test]
    public fun test_mint_multi_success() {

        let scenario_val = test_scenario::begin(USER);
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
        // begin to vote
        multi_sig = test_scenario::take_shared<MultiSignature>(scenario);
        vault = test_scenario::take_shared<Vault>(scenario);
        test_scenario::next_tx(scenario, USER);
        {
            multisig::Example::mint_request(&vault, &mut multi_sig, USER, 100, test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, USER);
        let proposal_id: u256;
        // vote1
        {
            let proposals = multisig::multisig::pending_proposals(&mut multi_sig, USER, test_scenario::ctx(scenario));
            assert!(vector::length(&proposals) == 1, 1);
            proposal_id = vector::pop_back(&mut proposals);
        };
        test_scenario::next_tx(scenario, USER);
        {
            multisig::multisig::vote(&mut multi_sig, proposal_id, true, test_scenario::ctx(scenario));
        };
        test_scenario::return_shared(multi_sig);
        test_scenario::return_shared(vault);
        test_scenario::next_tx(scenario, USER);

        // participant 1 start to vote
        let scenario_val1 = test_scenario::begin(PARTICIPANT1);
        let scenario1 = &mut scenario_val1;
        multi_sig = test_scenario::take_shared<MultiSignature>(scenario1);
        vault = test_scenario::take_shared<Vault>(scenario1);
        test_scenario::next_tx(scenario1, PARTICIPANT1);
        // vote1
        {
            multisig::multisig::vote(&mut multi_sig, proposal_id, true, test_scenario::ctx(scenario1));
        };
        test_scenario::return_shared(multi_sig);
        test_scenario::return_shared(vault);
        test_scenario::next_tx(scenario1, PARTICIPANT1);

        // participant 2 start to execute
        let scenario_val2 = test_scenario::begin(PARTICIPANT2);
        let scenario2 = &mut scenario_val2;

        // execute
        test_scenario::next_tx(scenario2, PARTICIPANT2);
        {
            multisig::Example::mint_execute(&vault,&mut multi_sig, proposal_id, test_scenario::ctx(scenario2));
        };

        test_scenario::next_tx(scenario2, PARTICIPANT2);
        
        test_scenario::return_shared(multi_sig);
        test_scenario::return_shared(vault);
        test_scenario::end(scenario_val);
        test_scenario::end(scenario_val1);
        test_scenario::end(scenario_val2);
    }

    fun weight_map(): VecMap<address, u64>{
        let weight_map = vec_map::empty<address, u64>();
        vec_map::insert<address, u64>(&mut weight_map, USER, 1);
        vec_map::insert<address, u64>(&mut weight_map, PARTICIPANT1, 2);
        vec_map::insert<address, u64>(&mut weight_map, PARTICIPANT2, 3);
        weight_map
    }

    fun remove_vector(): vector<address>{
        let remove = vector::empty<address>();
        vector::push_back<address>(&mut remove, USER);
        remove
    }
}