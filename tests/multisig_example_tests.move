#[test_only]
module multisig::multisig_example_tests{
    use multisig::multisig::{MultiSignature, EInvalidArguments, ENotAuthorized, EVoted, ENotVoted, EThresholdInvalid};
    use multisig::Example::{Self, Vault};
    use sui::test_scenario::{Self, Scenario};
    use sui::vec_map::{Self};
    use std::vector::{Self};
    use std::debug;
    use std::ascii;
    const USER: address = @0xA; // weight 1
    const PARTICIPANT1: address = @0xB; // weight 2
    const PARTICIPANT2: address = @0xC; // weight 3
    const UNAUTHORIZED: address = @0xD; // UNAUTHORIZED USER
    const PARTICIPANT3: address = @0xE; // weight 2
    const PARTICIPANT4: address = @0xF; // weight 3

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
            let proposals = multisig::multisig::pending_proposals(&mut multi_sig, test_scenario::ctx(scenario));
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
            let proposals = multisig::multisig::pending_proposals(&mut multi_sig, test_scenario::ctx(scenario));
            assert!(vector::length(&proposals) == 0, 1);

        };
        debug::print(&ascii::string(b"debug info [test_mint_single]"));
        multisig::multisig::debug_multisig(&mut multi_sig);
        // end
        test_scenario::return_shared(multi_sig);
        test_scenario::return_shared(vault);
        test_scenario::end(scenario_val);

    }

    #[expected_failure(abort_code = EInvalidArguments)]
    #[test]
    public fun test_invalid_proposal() {
        let scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;

        // init
        {
            let ctx = test_scenario::ctx(scenario);
            Example::init_for_testing(ctx);
        };

        let multi_sig: MultiSignature;
        let vault: Vault;
        // mint request
        test_scenario::next_tx(scenario, USER);
        {
            multi_sig = test_scenario::take_shared<MultiSignature>(scenario);
            vault = test_scenario::take_shared<Vault>(scenario);
            let participants = participant_vector();
            let participant_weights = weight_vector();

            let remove = vector::empty<address>();
            // create proposal using a unauthorized user
            multisig::multisig::create_multisig_setting_proposal(&mut multi_sig, participants, participant_weights, remove, 3,test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, USER);
        {
            // invalid 
            multisig::multisig::vote(&mut multi_sig, 33, true, test_scenario::ctx(scenario));
        };
        
        // end
        test_scenario::return_shared(multi_sig);
        test_scenario::return_shared(vault);

        test_scenario::end(scenario_val);
    }

    #[expected_failure(abort_code = ENotAuthorized)]
    #[test]
    public fun test_change_setting_access_deny() {

        let scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;
        // init
        {
            let ctx = test_scenario::ctx(scenario);
            Example::init_for_testing(ctx);
        };

        let multi_sig: MultiSignature;
        let vault: Vault;
        // mint request
        test_scenario::next_tx(scenario, UNAUTHORIZED);
        {
            multi_sig = test_scenario::take_shared<MultiSignature>(scenario);
            vault = test_scenario::take_shared<Vault>(scenario);
            let participants = participant_vector();
            let participant_weights = weight_vector();

            let remove = vector::empty<address>();
            // create proposal using a unauthorized user
            multisig::multisig::create_multisig_setting_proposal(&mut multi_sig, participants, participant_weights, remove, 3, test_scenario::ctx(scenario));
        };
        
        // end
        test_scenario::return_shared(multi_sig);
        test_scenario::return_shared(vault);

        test_scenario::end(scenario_val);
    }

    fun change_setting(participants: vector<address>, participant_weights: vector<u64>,  remove: vector<address>, threshold: u64, scenario: &mut Scenario ){
        let multi_sig: MultiSignature;
        let vault: Vault;
        // change request
        test_scenario::next_tx(scenario, USER);
        {
            multi_sig = test_scenario::take_shared<MultiSignature>(scenario);
            vault = test_scenario::take_shared<Vault>(scenario);
            // create proposal using a original user
            multisig::multisig::create_multisig_setting_proposal(&mut multi_sig, participants, participant_weights, remove, threshold, test_scenario::ctx(scenario));
        };

        // vote
        test_scenario::next_tx(scenario, USER);
        {
            multisig::multisig::vote(&mut multi_sig, 0, true, test_scenario::ctx(scenario));
        };
        // execute
        test_scenario::next_tx(scenario, USER);
        {
            multisig::multisig::debug_multisig(&multi_sig);
            multisig::multisig::multisig_setting_execute(&mut multi_sig, 0, test_scenario::ctx(scenario));
        };
         
        //multisig::multisig::debug_multisig(&mut multi_sig);

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
        change_setting(participant_vector(), weight_vector(), remove_vector(), 3, scenario);
        let multi_sig = test_scenario::take_shared<MultiSignature>(scenario);

        let weights = multisig::multisig::get_participants_by_weight(&multi_sig);
        multisig::multisig::debug_multisig(&multi_sig);
        assert!(*vec_map::get<address, u64>(weights, &USER) == 3, 3);
        assert!(*vec_map::get<address, u64>(weights, &PARTICIPANT1) == 2, 2);
        test_scenario::return_shared(multi_sig);
        test_scenario::end(scenario_val); 
    }


    #[test]
    public fun test_change_setting_new_success(){

        let scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;
        // init
        {
            let ctx = test_scenario::ctx(scenario);
            Example::init_for_testing(ctx);
        };
        change_setting(participant_vector_new(), weight_vector(), remove_vector(), 3, scenario);
        let multi_sig = test_scenario::take_shared<MultiSignature>(scenario);

        let weights = multisig::multisig::get_participants_by_weight(&multi_sig);
        multisig::multisig::debug_multisig(&multi_sig);
        assert!(*vec_map::get<address, u64>(weights, &USER) == 3, 3);
        assert!(*vec_map::get<address, u64>(weights, &PARTICIPANT3) == 2, 2);
        test_scenario::return_shared(multi_sig);
        test_scenario::end(scenario_val); 
    }

    #[expected_failure(abort_code = EThresholdInvalid)]
    #[test]
    public fun test_change_setting_threshold_greater_than_sum_fail(){

        let scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;
        // init
        {
            let ctx = test_scenario::ctx(scenario);
            Example::init_for_testing(ctx);
        };
        change_setting(participant_vector(), weight_vector(), remove_vector(), 7, scenario);
        test_scenario::end(scenario_val); 
    }

    #[expected_failure(abort_code = EThresholdInvalid)]
    #[test]
    public fun test_change_setting_threshold_less_than_min_fail(){

        let scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;
        // init
        {
            let ctx = test_scenario::ctx(scenario);
            Example::init_for_testing(ctx);
        };
        let weight_v = vector::empty<u64>();
        vector::push_back<u64>(&mut weight_v, 3);
        vector::push_back<u64>(&mut weight_v, 2);
        vector::push_back<u64>(&mut weight_v, 2);
        change_setting(participant_vector(), weight_v, remove_vector(), 1, scenario);
        test_scenario::end(scenario_val); 
    }

    #[expected_failure(abort_code = EInvalidArguments)]
    #[test]
    public fun test_change_setting_remove_not_exist_fail(){

        let scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;
        // init
        {
            let ctx = test_scenario::ctx(scenario);
            Example::init_for_testing(ctx);
        };
        let remove = vector::empty<address>();
        vector::push_back<address>(&mut remove, UNAUTHORIZED);
        change_setting(participant_vector(), weight_vector(), remove, 1, scenario);
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

        change_setting(participant_vector(), weight_vector(), remove_vector(), 3, scenario);
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
            let proposals = multisig::multisig::pending_proposals(&mut multi_sig, test_scenario::ctx(scenario));
            assert!(vector::length(&proposals) == 1, 1);
            proposal_id = vector::pop_back(&mut proposals);
        };
        test_scenario::next_tx(scenario, USER);
        {
            multisig::multisig::vote(&mut multi_sig, proposal_id, true, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, PARTICIPANT1);
        // vote1
        {
            multisig::multisig::vote(&mut multi_sig, proposal_id, true, test_scenario::ctx(scenario));
        };
        // execute
        test_scenario::next_tx(scenario, PARTICIPANT2);
        {
            multisig::Example::mint_execute(&vault,&mut multi_sig, proposal_id, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, PARTICIPANT2);
        
        debug::print(&ascii::string(b"debug info [test_mint_multi_success]"));
        multisig::multisig::debug_multisig(&mut multi_sig);

        test_scenario::return_shared(multi_sig);
        test_scenario::return_shared(vault);
        test_scenario::end(scenario_val);
    }

    #[expected_failure(abort_code = EVoted)]
    #[test]
    public fun test_mint_multi_duplicate_vote() {

        let scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;  
        // init
        {
            let ctx = test_scenario::ctx(scenario);
            Example::init_for_testing(ctx);
        };

        let multi_sig: MultiSignature;
        let vault: Vault;

        change_setting(participant_vector(), weight_vector(), remove_vector(), 3,scenario);
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
            let proposals = multisig::multisig::pending_proposals(&mut multi_sig, test_scenario::ctx(scenario));
            assert!(vector::length(&proposals) == 1, 1);
            proposal_id = vector::pop_back(&mut proposals);
        };
        test_scenario::next_tx(scenario, USER);
        {
            multisig::multisig::vote(&mut multi_sig, proposal_id, true, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, PARTICIPANT1);
        // vote1
        {
            multisig::multisig::vote(&mut multi_sig, proposal_id, true, test_scenario::ctx(scenario));
        };
        // vote again
        test_scenario::next_tx(scenario, PARTICIPANT1);
        {
            multisig::multisig::vote(&mut multi_sig, proposal_id, true, test_scenario::ctx(scenario));
        };
        
        test_scenario::return_shared(multi_sig);
        test_scenario::return_shared(vault);
        test_scenario::end(scenario_val);
    }


    #[expected_failure]
    #[test]
    public fun test_mint_multi_unauthorized_vote() {

        let scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;  
        // init
        {
            let ctx = test_scenario::ctx(scenario);
            Example::init_for_testing(ctx);
        };

        let multi_sig: MultiSignature;
        let vault: Vault;

        change_setting(participant_vector(), weight_vector(), remove_vector(), 3, scenario);
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
            let proposals = multisig::multisig::pending_proposals(&mut multi_sig, test_scenario::ctx(scenario));
            assert!(vector::length(&proposals) == 1, 1);
            proposal_id = vector::pop_back(&mut proposals);
        };
        test_scenario::next_tx(scenario, USER);
        {
            multisig::multisig::vote(&mut multi_sig, proposal_id, true, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, PARTICIPANT1);
        // multisig::multisig::debug_multisig(&mut multi_sig);
        // vote1
        {
            multisig::multisig::vote(&mut multi_sig, proposal_id, true, test_scenario::ctx(scenario));
        };
        // vote again
        test_scenario::next_tx(scenario, UNAUTHORIZED);
        {
            multisig::multisig::vote(&mut multi_sig, proposal_id, true, test_scenario::ctx(scenario));
        };
        
        test_scenario::return_shared(multi_sig);
        test_scenario::return_shared(vault);
        test_scenario::end(scenario_val);
    }

    #[expected_failure(abort_code=ENotVoted)]
    #[test]
    public fun test_mint_multi_vote_threshold_not_reach() {

        let scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;  
        // init
        {
            let ctx = test_scenario::ctx(scenario);
            Example::init_for_testing(ctx);
        };

        let multi_sig: MultiSignature;
        let vault: Vault;

        change_setting(participant_vector(), weight_vector(), remove_vector(), 3, scenario);
        // now weight is USER: 3,  PARTICIPANT1: 2, PARTICIPANT2: 1
        // begin to vote
        multi_sig = test_scenario::take_shared<MultiSignature>(scenario);
        vault = test_scenario::take_shared<Vault>(scenario);
        test_scenario::next_tx(scenario, USER);
        {
            multisig::Example::mint_request(&vault, &mut multi_sig, USER, 100, test_scenario::ctx(scenario));
        };

        // weight 2
        test_scenario::next_tx(scenario, PARTICIPANT1);
        let proposal_id: u256;
        // PARTICIPANT1 vote 2
        {
            let proposals = multisig::multisig::pending_proposals(&mut multi_sig, test_scenario::ctx(scenario));
            assert!(vector::length(&proposals) == 1, 1);
            proposal_id = vector::pop_back(&mut proposals);
        };
        test_scenario::next_tx(scenario, PARTICIPANT1);
        {
            multisig::multisig::vote(&mut multi_sig, proposal_id, true, test_scenario::ctx(scenario));
        };

        // execute
        test_scenario::next_tx(scenario, PARTICIPANT2);
        {
            multisig::Example::mint_execute_vote_not_pass(&vault,&mut multi_sig, proposal_id, test_scenario::ctx(scenario));
        };
    
        test_scenario::return_shared(multi_sig);
        test_scenario::return_shared(vault);
        test_scenario::end(scenario_val);
    }

    #[expected_failure(abort_code=ENotVoted)]
    #[test]
    public fun test_mint_multi_vote_direct_complete() {

        let scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;  
        // init
        {
            let ctx = test_scenario::ctx(scenario);
            Example::init_for_testing(ctx);
        };

        let multi_sig: MultiSignature;
        let vault: Vault;

        change_setting(participant_vector(), weight_vector(), remove_vector(), 3, scenario);
        // now weight is USER: 3,  PARTICIPANT1: 2, PARTICIPANT2: 1
        // begin to vote
        multi_sig = test_scenario::take_shared<MultiSignature>(scenario);
        vault = test_scenario::take_shared<Vault>(scenario);
        test_scenario::next_tx(scenario, USER);
        {
            multisig::Example::mint_request(&vault, &mut multi_sig, USER, 100, test_scenario::ctx(scenario));
        };

        // weight 2
        test_scenario::next_tx(scenario, PARTICIPANT1);
        let proposal_id: u256;
        // PARTICIPANT1 vote 2
        {
            let proposals = multisig::multisig::pending_proposals(&mut multi_sig, test_scenario::ctx(scenario));
            assert!(vector::length(&proposals) == 1, 1);
            proposal_id = vector::pop_back(&mut proposals);
        };
        test_scenario::next_tx(scenario, PARTICIPANT1);
        {
            multisig::multisig::vote(&mut multi_sig, proposal_id, true, test_scenario::ctx(scenario));
        };

        // execute
        test_scenario::next_tx(scenario, PARTICIPANT2);
        {
            multisig::Example::complete(&vault,&mut multi_sig, proposal_id, test_scenario::ctx(scenario));
        };
    
        test_scenario::return_shared(multi_sig);
        test_scenario::return_shared(vault);
        test_scenario::end(scenario_val);
    }

    fun participant_vector(): vector<address>{
        let participants = vector::empty<address>();
        vector::push_back<address>(&mut participants, USER);
        vector::push_back<address>(&mut participants, PARTICIPANT1);
        vector::push_back<address>(&mut participants, PARTICIPANT2);
        participants
    }

    fun participant_vector_new(): vector<address>{
        let participants = vector::empty<address>();
        vector::push_back<address>(&mut participants, USER);
        vector::push_back<address>(&mut participants, PARTICIPANT3);
        vector::push_back<address>(&mut participants, PARTICIPANT4);
        participants
    }

    fun weight_vector(): vector<u64>{
        let weight_v = vector::empty<u64>();
        vector::push_back<u64>(&mut weight_v, 3);
        vector::push_back<u64>(&mut weight_v, 2);
        vector::push_back<u64>(&mut weight_v, 1);
        weight_v
    }

    fun remove_vector(): vector<address>{
        let remove = vector::empty<address>();
        vector::push_back<address>(&mut remove, USER);
        remove
    }
}