module multisig::multisig {
    use sui::object::{Self, UID, ID};
    use sui::object_bag::{Self, ObjectBag};
    use std::vector::{Self};
    use sui::tx_context::{Self, TxContext};
    use sui::vec_map::{Self, VecMap};
    use sui::transfer::{Self};
    use sui::event;

    const EThresholdInvalid: u64 = 1;
    const ECanNotFinish: u64 = 2;
    const EInvalidArguments: u64 = 3;
    const ENotAuthorized: u64 = 4;
    const EVoted: u64 = 5;
    const ENotVoted: u64 = 6;


    const PROPOSAL_TYPE_MULTISIG_SETTING: u64 = 0;
    
    struct MultiSignatureSetting has store, key{
        id: UID,
        participants_remove: vector<address>,
        participants_by_weight: VecMap<address, u64>, // address, weight
        threshold: u64
    }

    // event start
    struct ProposalCreatedEvent has copy, drop{
        id: u256,
        for: ID,
        type: u64,
        description: vector<u8>,
        creator: address
    }

    struct ProposalVotedEvent has copy, drop{
        id: u256,
        for: ID,
        type: u64,
        voter: address
    }

    struct ProposalExecutedEvent has copy, drop{
        id: u256,
        for: ID,
        type: u64,
        executor: address
    }

    // event end


    struct Proposal has store, key {
        id: UID,
        pid: u256,
        for: ID,
        description: vector<u8>,
        type: u64, // 0 reserved for MultiSignatureSetting, > 0 for customization
        value: ObjectBag,
        approved_weight: u64,
        reject_weight: u64,
        participants_voted: VecMap<address, bool>,
        creator: address
    }

    struct MultiSignature has store, key{
        id: UID,
        participants_by_weight: VecMap<address, u64>, // address, weight
        threshold: u64, // if sum of participants's weights > threshold, proposal can be execute
        proposal_index: u256,
        pending_proposals: VecMap<u256, Proposal>,
        pending_proposal_ids: vector<u256>,
        //complete_proposals: VecMap<u256, Proposal>
    }

    public fun create_multisig(_tx: &mut TxContext): MultiSignature{
        let participants_by_weight = vec_map::empty<address,u64>();
        vec_map::insert(&mut participants_by_weight, tx_context::sender(_tx), 1);
        MultiSignature { id: object::new(_tx), participants_by_weight, threshold: 1, 
            proposal_index: 0, pending_proposals: vec_map::empty<u256, Proposal>(), pending_proposal_ids: vector::empty<u256>()}
    }

    /// only participants can call multisig_setting_execute
    /// only the one same type proposal can be in pending proposals waiting approval
    public fun create_proposal<T: store + key>(multi_signature: &mut MultiSignature, description: vector<u8>, type: u64, request: T, _tx: &mut TxContext){
        // only participants
        onlyParticipant(multi_signature, _tx);
        // check type, only one type can be processed at one time
        let pending_proposals = &multi_signature.pending_proposals;
        let proposals_ids = vec_map::keys<u256, Proposal>(pending_proposals);
        let ids_ref = &mut proposals_ids;
        while(vector::length(ids_ref)>0){
            let key = vector::pop_back<u256>(ids_ref);
            let proposal = vec_map::get(pending_proposals, &key);
            // only one with the same type in pending proposals
            assert!(proposal.type == type, EInvalidArguments);
        };

        let value = object_bag::new(_tx);
        object_bag::add<u256, T>(&mut value, 0, request);
        let proposal_id = object::new(_tx);
        let id = multi_signature.proposal_index;
        let for = object::uid_as_inner(&multi_signature.id);
        vec_map::insert<u256, Proposal>(&mut multi_signature.pending_proposals, id, 
            Proposal{ id: proposal_id, pid: id, for: *for, description, type, value, approved_weight: 0, reject_weight: 0, participants_voted: vec_map::empty<address, bool>(), creator: tx_context::sender(_tx)});
        
        vector::push_back(&mut multi_signature.pending_proposal_ids, id);
        multi_signature.proposal_index = id + 1;
        event::emit(ProposalCreatedEvent{id, type, for: *for, description, creator: tx_context::sender(_tx)});
    }

    /// only participants can call multisig_setting_execute
    /// participants are newly added
    /// participants_remove are going to be removed
    public entry fun create_multisig_setting_proposal(multi_signature: &mut MultiSignature, description: vector<u8>, participants: vector<address>, participant_weights: vector<u64>, participants_remove: vector<address>, threshold: u64, _tx: &mut TxContext){
        onlyParticipant(multi_signature, _tx);
        
        let participant_ref = &mut participants;
        let participant_weights_ref = &mut participant_weights;
        let len = vector::length<address>(participant_ref);
        assert!(len == vector::length<u64>(participant_weights_ref), EInvalidArguments);
        assert!(len > 0, EInvalidArguments);
        // threshold should less than total weight subtract any single weight the make sure vote can proceed
        let participants_by_weight = & multi_signature.participants_by_weight;
        // copy a new setting to simulate
        let copy_map = vec_map::empty<address, u64>();
        let copy_map_ref = &mut copy_map;
        let copy_keys = vec_map::keys<address, u64>( participants_by_weight);
        let copy_keys_ref = &mut copy_keys;
        while(vector::length(copy_keys_ref) > 0){
            let key = vector::pop_back<address>(copy_keys_ref);
            let v = vec_map::get<address, u64>( participants_by_weight, &key);
            vec_map::insert<address, u64>( copy_map_ref, copy key, *v);
        };

        // check participants_remove should all exist
        let remove_len = vector::length(&participants_remove);
        let remove_index = 0;
        while(remove_index < remove_len){
            let key = vector::borrow<address>(&participants_remove, remove_index);
            assert!(vec_map::contains(copy_map_ref, key), EInvalidArguments);
            // simulate remove
            vec_map::remove<address, u64>( copy_map_ref, key);
            remove_index = remove_index + 1;
        };

        // simulate add
        let add_len = vector::length(&participants);
        let add_index = 0;
        let new_participants_by_weight = vec_map::empty<address, u64>();
        while(add_index < add_len){
            let key = vector::borrow<address>(&participants, add_index);
            let weight = vector::borrow<u64>(&participant_weights, add_index);
            // each weight should > 0
            assert!(*weight > 0, EInvalidArguments);
            // update the old one
            if(vec_map::contains(copy_map_ref, key)){
                vec_map::remove<address, u64>(copy_map_ref, key);
            };
            vec_map::insert<address, u64>(copy_map_ref, *key, *weight);
            vec_map::insert<address, u64>(&mut new_participants_by_weight, *key, *weight);
            add_index = add_index +1;
        };
    
        // make sure threshold >= min and threshold <= sum
        // reset index
        let sum = 0;
        let min = 0;
        let keys = vec_map::keys<address, u64>( copy_map_ref);
        let keys_ref = &mut keys;
        while(vector::length(keys_ref) > 0){
            let key = vector::pop_back<address>(keys_ref);
            let v = vec_map::get<address, u64>( copy_map_ref, &key);
            if (min == 0){
                min = *v;
            };
            if(*v < min){
                min = *v;
            };
            sum = sum + *v;
        };
        assert!(sum > 0, EInvalidArguments);
        assert!(threshold >= min, EThresholdInvalid);
        assert!(threshold <= sum, EThresholdInvalid);

        let request = MultiSignatureSetting{ id: object::new(_tx),  participants_by_weight: new_participants_by_weight, participants_remove, threshold};
        create_proposal<MultiSignatureSetting>(multi_signature, description, PROPOSAL_TYPE_MULTISIG_SETTING, request, _tx)
    }

    /// only participants can call multisig_setting_execute
    public entry fun vote(multi_signature: &mut MultiSignature, proposal_id: u256, is_approve: bool, _tx: &mut TxContext){
        onlyParticipant(multi_signature, _tx);
        onlyPendingProposal(multi_signature, proposal_id);
        onlyValidProposalFor(multi_signature, proposal_id);
        // only not voted
        onlyNotVoted(multi_signature, proposal_id, tx_context::sender(_tx));
    

        // only participants
        let proposal = vec_map::get_mut<u256, Proposal>(&mut multi_signature.pending_proposals, &proposal_id);
        let sender: address = tx_context::sender(_tx);

        if(is_approve){
            proposal.approved_weight = proposal.approved_weight + *vec_map::get<address, u64>(&multi_signature.participants_by_weight, &sender);
        }else{
            proposal.reject_weight = proposal.reject_weight + *vec_map::get<address, u64>(&multi_signature.participants_by_weight, &sender);
        };
        // marked voted
        vec_map::insert<address, bool>(&mut proposal.participants_voted, sender, true);
        let for = object::uid_as_inner(&multi_signature.id);

        event::emit(ProposalVotedEvent{id: proposal_id, for: *for, type: proposal.type, voter: sender});
    }

    /// mark complete, should be called when business is executed on user module
    /// only any weight > threshold can complete
    public entry fun mark_proposal_complete(multi_signature: &mut MultiSignature, proposal_id: u256, _tx: &mut TxContext){
        onlyParticipant(multi_signature, _tx);
        onlyPendingProposal(multi_signature, proposal_id);
        onlyValidProposalFor(multi_signature, proposal_id);
        onlyVoted(multi_signature, proposal_id);
        
        inner_mark_proposal_complete(multi_signature, proposal_id, _tx);
    }

    /// mark proposal as completed, make sure all condition are checked, only used in multisig_setting_execute
    fun inner_mark_proposal_complete(multi_signature: &mut MultiSignature, proposal_id: u256, _tx: &mut TxContext){
        let pending_proposals = &mut multi_signature.pending_proposals;
        let (_, removed) = vec_map::remove<u256, Proposal>(pending_proposals, &proposal_id);
        //add to complete proposal
        let proposal_ids = &mut multi_signature.pending_proposal_ids;
        let (exist, idx) = vector::index_of<u256>(proposal_ids, &proposal_id);
        if(exist){
            vector::remove(proposal_ids, idx);
        };

        let type  = removed.type;
        let for = object::uid_as_inner(&multi_signature.id);
        transfer::freeze_object(removed);
        event::emit(ProposalExecutedEvent{id: proposal_id, for: *for, type, executor: tx_context::sender(_tx)});
        
    } 

    // list all pending proposal
    // return vector of (proposal_id, type, description)
    public fun pending_proposals(multi_signature: &MultiSignature, _tx: &TxContext): vector<u256>{
        // proposal_id, type, description
        let result = vector::empty<u256>();
        let result_mut = &mut result;
        // filter participant
        if(!vec_map::contains<address, u64>(&multi_signature.participants_by_weight ,&tx_context::sender(_tx))){
            return result
        };
        let pending_proposals_table = &multi_signature.pending_proposals;
        let pending_proposal_ids = &multi_signature.pending_proposal_ids;
        let len = vector::length<u256>(pending_proposal_ids);
        let index: u64 = 0;
        while (index < len) { 
            let proposal = vec_map::get<u256, Proposal>(pending_proposals_table, vector::borrow<u256>(pending_proposal_ids, index));
            vector::push_back<u256>(result_mut, proposal.pid);
            index = index + 1;
        };
        result
    }

    public fun pending_proposal_description(multi_signature: &MultiSignature, proposal_id: u256): vector<u8>{
        let proposal = vec_map::get<u256, Proposal>(&multi_signature.pending_proposals, &proposal_id);
        proposal.description
    }

    public fun pending_proposal_type(multi_signature: &MultiSignature, proposal_id: u256): u64{
        let proposal = vec_map::get<u256, Proposal>(&multi_signature.pending_proposals, &proposal_id);
        proposal.type
    }

    /// return the is_proposal_approved and the approved weight, user can compare the weight with is_proposal_rejected's return or just make a decision by the bool flag
    public fun is_proposal_approved(multi_signature: & MultiSignature, proposal_id: u256): (bool, u64){
        onlyPendingProposal(multi_signature, proposal_id);
        onlyValidProposalFor(multi_signature, proposal_id);

        let proposal = vec_map::get<u256, Proposal>(&multi_signature.pending_proposals, &proposal_id);
        return (proposal.approved_weight >= multi_signature.threshold, proposal.approved_weight)
    }

    /// return the is_proposal_rejected and the voted weight
    public fun is_proposal_rejected(multi_signature: & MultiSignature, proposal_id: u256): (bool, u64){
        onlyPendingProposal(multi_signature, proposal_id);
        onlyValidProposalFor(multi_signature, proposal_id);

        let proposal = vec_map::get<u256, Proposal>(&multi_signature.pending_proposals, &proposal_id);
        return (proposal.reject_weight >= multi_signature.threshold,proposal.reject_weight)
    }

    public fun borrow_proposal_request<T: store + key>(multi_signature: & MultiSignature,  proposal_id: &u256, _tx: & TxContext): &T {
        onlyParticipant(multi_signature, _tx);
        onlyPendingProposal(multi_signature, *proposal_id);
        onlyValidProposalFor(multi_signature, *proposal_id);
        onlyVoted(multi_signature, *proposal_id);

        let pending_proposals = & multi_signature.pending_proposals;
        let proposal = vec_map::get<u256, Proposal>(pending_proposals, proposal_id);
        let v = borrow_request(proposal);
        v
    }

    /// only participants && pending proposals && valid proposal && voted proposal can be extract
    public fun extract_proposal_request<T: store + key>(multi_signature: &mut MultiSignature, proposal_id: u256, _tx: &mut TxContext): T{
        // 1) business side take proposal  2) take request  3) drop request 4) add to complete 
        onlyParticipant(multi_signature, _tx);
        onlyPendingProposal(multi_signature, proposal_id);
        onlyValidProposalFor(multi_signature, proposal_id);
        onlyVoted(multi_signature, proposal_id);

        let proposals = &mut multi_signature.pending_proposals;
        let proposal = vec_map::get_mut<u256, Proposal>(proposals, &proposal_id);
        let v = extract_request<T>(proposal);
        v
    }

    fun extract_request<T: store + key>(proposal: &mut Proposal): T{
        assert!(!object_bag::is_empty(&mut proposal.value), EInvalidArguments);
        object_bag::remove<u256, T>(&mut proposal.value, 0)

    }

    fun borrow_request<T: store + key>(proposal: &Proposal): & T{
        object_bag::borrow<u256, T>(&proposal.value, 0)
    }

    /// get participants of the multisig
    public fun get_participants(multi_signature: &MultiSignature): vector<address>{
        vec_map::keys<address, u64>(&multi_signature.participants_by_weight)
    }

    public fun get_participants_by_weight(multi_signature: &MultiSignature): &VecMap<address,  u64>{
        &multi_signature.participants_by_weight
    }

    /// change the multisig setting
    /// only participants can call multisig_setting_execute
    public entry fun multisig_setting_execute(multi_signature: &mut MultiSignature, proposal_id: u256, _tx: &mut TxContext){

        onlyParticipant(multi_signature, _tx);
        onlyPendingProposal(multi_signature, proposal_id);
        onlyValidProposalFor(multi_signature, proposal_id);
        onlyVoted(multi_signature, proposal_id);

        let proposal = vec_map::get<u256, Proposal>(&multi_signature.pending_proposals, &proposal_id);
        let setting_request = borrow_request<MultiSignatureSetting>(proposal);

        let approved_weight = proposal.approved_weight;
        let reject_weight = proposal.reject_weight;
        assert!(approved_weight >= multi_signature.threshold || reject_weight >= multi_signature.threshold, ECanNotFinish);
        // if vote is approved, execute the change logic
        if(approved_weight >= multi_signature.threshold && approved_weight > reject_weight){
            let len = vector::length<address>(&setting_request.participants_remove);
            let index: u64 = 0;
            let participants_by_weight = &mut multi_signature.participants_by_weight;
            let new_participants_by_weight = &setting_request.participants_by_weight;
            // remove old weights
            while((index < len) && (vector::length(&setting_request.participants_remove) > 0)){
                // remove the old participants
                vec_map::remove<address, u64>( participants_by_weight, vector::borrow<address>(&setting_request.participants_remove, index));
                index = index + 1;
            };
            let keys = vec_map::keys<address, u64>( new_participants_by_weight);
            let keys_ref = &mut keys;
            // add new weights
            while(vector::length(keys_ref) > 0){
                let key = vector::pop_back<address>(keys_ref);
                let v = vec_map::get<address, u64>( new_participants_by_weight, &key);
                // each weight should > 0
                assert!(*v > 0, EInvalidArguments);
                vec_map::insert<address, u64>( participants_by_weight, copy key, *v);
            };

            // calculate min and sum, make sure vote only effect in [minimal 1 vote, sum all votes]
            keys = vec_map::keys<address, u64>( new_participants_by_weight);
            keys_ref = &mut keys;
            let sum = 0;
            let min: u64 = 0;
            while(vector::length(keys_ref) > 0){
                let key = vector::pop_back<address>(keys_ref);
                let v = vec_map::get<address, u64>( participants_by_weight, &key);
                if(min == 0){
                    min = *v;
                };
                if(*v <= min){
                    min = *v;
                };
                assert!(*v > 0, EInvalidArguments);
                sum = sum + *v;
            };
            // sum of weights should > 0
            assert!(setting_request.threshold <= sum, EInvalidArguments);
            assert!(setting_request.threshold >= min, EInvalidArguments);

            multi_signature.threshold = setting_request.threshold;

        };
        // proposal is dropped or execute logic finished
        inner_mark_proposal_complete(multi_signature, proposal_id, _tx);
    }

    /// is user belong to this multi_signature
    public fun is_participant(multi_signature: &MultiSignature, user_address: address): bool{
        vec_map::contains<address,u64>(&multi_signature.participants_by_weight, &user_address)
    }

    // bellow is is for access check

    /// only participant check   
    fun onlyParticipant(multi_signature: & MultiSignature,_tx: & TxContext){
        let participants_by_weight = &multi_signature.participants_by_weight;
        assert!(vec_map::contains<address,u64>(participants_by_weight, &tx_context::sender(_tx)), ENotAuthorized);
        assert!(*vec_map::get<address, u64>(&multi_signature.participants_by_weight, &tx_context::sender(_tx)) > 0, ENotAuthorized);
    }
    
    fun onlyPendingProposal(multi_signature: & MultiSignature, proposal_id: u256){
        assert!(vec_map::contains<u256, Proposal>(&multi_signature.pending_proposals, &proposal_id), EInvalidArguments);
    }

    fun onlyValidProposalFor(multi_signature: & MultiSignature, proposal_id: u256){
        let proposal = vec_map::get<u256, Proposal>(&multi_signature.pending_proposals, &proposal_id);
        let for = object::uid_to_inner(&multi_signature.id);
        assert!(proposal.for == for, EInvalidArguments);        
    }
    
    fun onlyNotVoted(multi_signature: & MultiSignature, proposal_id: u256, sender: address){
        let proposal = vec_map::get<u256, Proposal>(&multi_signature.pending_proposals, &proposal_id);
        let voted = &proposal.participants_voted;
        assert!(!vec_map::contains<address, bool>(voted, &sender), EVoted);
    }

    fun onlyVoted(multi_signature: & MultiSignature, proposal_id: u256){
        let (is_approved,_) = is_proposal_approved(multi_signature, proposal_id);
        let (is_rejected,_) = is_proposal_rejected(multi_signature, proposal_id);
        assert!(is_approved || is_rejected, ENotVoted);
    }


    #[test_only]
    public fun debug_multisig(multi_signature: &MultiSignature){
        use std::debug;
        debug::print(multi_signature);
    }    
}