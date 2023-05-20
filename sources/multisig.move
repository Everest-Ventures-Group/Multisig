module multisig::multisig {
    use sui::object::{Self, UID, ID};
    use sui::object_bag::{Self, ObjectBag};
    use std::vector::{Self};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use sui::vec_map::{Self, VecMap};
    use sui::event;

    const ERegistered: u64 = 1;
    const ECanNotFinish: u64 = 2;
    const EInvalidArguments: u64 = 3;

    const PROPOSAL_TYPE_MULTISIG_SETTING: u64 = 0;
    
    struct MultiSignatureSetting has store, key{
        id: UID,
        participants_remove: vector<address>,
        participants_by_weight: VecMap<address, u64>, // address, weight
    }

    // event
    struct ProposalCreatedEvent has copy, drop{
        id: u256,
        type: u64,
        description: vector<u8>,
        creator: address
    }

    struct Proposal has store {
        id: u256,
        for: ID,
        description: vector<u8>,
        type: u64, // 0 reserved for MultiSignatureSetting, > 0 for customization
        value: ObjectBag,
        approved_weight: u64,
        reject_weight: u64,
        participants_voted: Table<address, bool>
    }

    struct MultiSignature has store, key{
        id: UID,
        participants_by_weight: VecMap<address, u64>, // address, weight
        threshold: u64, // if sum of participants's weights > threshold, proposal can be execute
        proposal_index: u256,
        pending_proposals: Table<u256, Proposal>,
        pending_proposal_ids: vector<u256>,
        complete_proposals: Table<u256, Proposal>
    }

    public fun create_multisig(_tx: &mut TxContext): MultiSignature{
        let participants_by_weight = vec_map::empty<address,u64>();
        vec_map::insert(&mut participants_by_weight, tx_context::sender(_tx), 1);
        MultiSignature { id: object::new(_tx), participants_by_weight, threshold: 1, 
            proposal_index: 0, pending_proposals: table::new<u256, Proposal>(_tx), 
            complete_proposals: table::new<u256, Proposal>(_tx), pending_proposal_ids: vector::empty<u256>()}
    }

    /// only participants can call multisig_setting_execute
    public fun create_proposal<T: store + key>(multi_signature: &mut MultiSignature, description: vector<u8>, type: u64, request: T, _tx: &mut TxContext){
        // only participants
        let value = object_bag::new(_tx);
        object_bag::add<u256, T>(&mut value, 0, request);
        let id = multi_signature.proposal_index;
        let for = object::uid_as_inner(&multi_signature.id);
        table::add<u256, Proposal>(&mut multi_signature.pending_proposals, id, 
            Proposal{ id, for: *for, description, type, value, approved_weight: 0, reject_weight: 0, participants_voted: table::new<address, bool>(_tx)});
        
        vector::push_back(&mut multi_signature.pending_proposal_ids, id);
        multi_signature.proposal_index = id + 1;
        event::emit(ProposalCreatedEvent{id, type, description, creator: tx_context::sender(_tx)});
    }

    /// only participants can call multisig_setting_execute
    public entry fun create_multisig_setting_proposal(multi_signature: &mut MultiSignature, description: vector<u8>, participants: vector<address>, participant_weights: vector<u64>, participants_remove: vector<address>, _tx: &mut TxContext){
        let participant_ref = &mut participants;
        let participant_weights_ref = &mut participant_weights;
        let len = vector::length<address>(participant_ref);
        assert!(len == vector::length<u64>(participant_weights_ref), EInvalidArguments);
        assert!(len > 0, EInvalidArguments);
        let index = 0;
        let participants_by_weight: VecMap<address, u64> = vec_map::empty<address, u64>();

        loop{
            vec_map::insert(&mut participants_by_weight, vector::pop_back<address>(participant_ref), vector::pop_back<u64>(&mut participant_weights));
            index = index + 1;
            if(index >= len){
                break
            };
        };
        let request = MultiSignatureSetting{ id: object::new(_tx),  participants_by_weight, participants_remove};
        create_proposal<MultiSignatureSetting>(multi_signature, description, 0, request, _tx)
    }

    /// only participants can call multisig_setting_execute
    public entry fun vote(multi_signature: &mut MultiSignature, proposal_id: u256, is_approve: bool, _tx: &mut TxContext){
        // only participants
        let proposal = table::borrow_mut<u256, Proposal>(&mut multi_signature.pending_proposals, proposal_id);
        let sender: address = tx_context::sender(_tx);

        if(is_approve){
            proposal.approved_weight = proposal.approved_weight + *vec_map::get<address, u64>(&multi_signature.participants_by_weight, &sender);
        }else{
            proposal.reject_weight = proposal.reject_weight + *vec_map::get<address, u64>(&multi_signature.participants_by_weight, &sender);
        };
        // marked voted
        table::add<address, bool>(&mut proposal.participants_voted, sender, true);
    }

    /// mark complete, should be called when business is executed on user module
    /// only any weight > threshold can complete
    public fun mark_proposal_complete(multi_signature: &mut MultiSignature, proposal_id: u256, _tx: &mut TxContext){
        let proposal = table::borrow<u256, Proposal>(&multi_signature.pending_proposals, proposal_id);
        assert!(proposal.approved_weight >= multi_signature.threshold || proposal.reject_weight >= multi_signature.threshold, ECanNotFinish);

        let removed = table::remove<u256, Proposal>(&mut multi_signature.pending_proposals, proposal_id);
        //add to complete proposal
        let proposal_ids = &mut multi_signature.pending_proposal_ids;
        let (exist, idx) = vector::index_of<u256>(proposal_ids, &proposal_id);
        if(exist){
            vector::remove(&mut multi_signature.pending_proposal_ids, idx);
        };
        table::add<u256, Proposal>(&mut multi_signature.complete_proposals, proposal_id, removed);
    }

    // list all pending proposal
    // return vector of (proposal_id, type, description)
    public entry fun pending_proposals(multi_signature: &MultiSignature, user: address, _tx: &TxContext): vector<u256>{
        // proposal_id, type, description
        let result = vector::empty<u256>();
        let result_mut = &mut result;
        // filter participant
        if(!vec_map::contains<address, u64>(&multi_signature.participants_by_weight ,&user)){
            return result
        };
        let pending_proposals_table = &multi_signature.pending_proposals;
        let pending_proposal_ids = &multi_signature.pending_proposal_ids;
        let len = vector::length<u256>(pending_proposal_ids);
        let index: u64 = 0;
        while (index < len) { 
            let proposal = table::borrow<u256, Proposal>(pending_proposals_table, *vector::borrow<u256>(pending_proposal_ids, index));
            vector::push_back<u256>(result_mut, proposal.id);
            index = index + 1;
        };
        result
    }

    #[test_only]
    public fun debug_multisig(multi_signature: &MultiSignature){
        use std::debug;
        debug::print(multi_signature);
    }

    public entry fun pending_proposal_description(multi_signature: &MultiSignature, proposal_id: u256): vector<u8>{
        let proposal = table::borrow<u256, Proposal>(&multi_signature.pending_proposals, proposal_id);
        proposal.description
    }

    public entry fun pending_proposal_type(multi_signature: &MultiSignature, proposal_id: u256): u64{
        let proposal = table::borrow<u256, Proposal>(&multi_signature.pending_proposals, proposal_id);
        proposal.type
    }

    public entry fun is_proposal_approved(multi_signature: &mut MultiSignature, proposal_id: u256): bool{
        let proposal = table::borrow<u256, Proposal>(&multi_signature.pending_proposals, proposal_id);
        return proposal.approved_weight >= multi_signature.threshold
    }

    public entry fun is_proposal_rejected(multi_signature: &mut MultiSignature, proposal_id: u256): bool{
        let proposal = table::borrow<u256, Proposal>(&multi_signature.pending_proposals, proposal_id);
        return proposal.reject_weight >= multi_signature.threshold
    }

    /// borrow the original business request body
    public fun borrow_proposal_request<T: store + key>(multi_signature: &mut MultiSignature, proposal_id: u256): & T {
        let proposal = table::borrow<u256, Proposal>(& multi_signature.pending_proposals, proposal_id);
        object_bag::borrow<u256, T>(& proposal.value, 0)
    }

    // 1) business side take proposal  2) take request  3) drop request 4) add to complete 
    public fun extract_proposal_request<T: store + key>(multi_signature: &mut MultiSignature, proposal_id: u256): T{
        let proposals = &mut multi_signature.pending_proposals;
        let proposal = table::borrow_mut<u256, Proposal>(proposals, proposal_id);
        let v = extract_request<T>(proposal);
        v
    }

    fun extract_request<T: store + key>(proposal: &mut Proposal): T{
        object_bag::remove<u256, T>(&mut proposal.value, 0)
    }

    fun borrow_request<T: store + key>(proposal: &Proposal): & T{
        object_bag::borrow<u256, T>(&proposal.value, 0)
    }

    /// change the multisig setting
    /// only participants can call multisig_setting_execute
    public fun multisig_setting_execute(multi_signature: &mut MultiSignature, proposal_id: u256, tx: &mut TxContext){
        let proposal = table::borrow<u256, Proposal>(&multi_signature.pending_proposals, proposal_id);
        let setting_request = borrow_request<MultiSignatureSetting>(proposal);
        let approved_weight = proposal.approved_weight;
        let reject_weight = proposal.reject_weight;
        assert!(approved_weight >= multi_signature.threshold || reject_weight >= multi_signature.threshold, ECanNotFinish);
        if(approved_weight >= multi_signature.threshold){
            let len = vector::length<address>(&setting_request.participants_remove);
            let index: u64 = 0;
            let participants_by_weight = &mut multi_signature.participants_by_weight;
            let new_participants_by_weight = &setting_request.participants_by_weight;
            loop{
                // remove the old participants
                vec_map::remove<address, u64>( participants_by_weight, vector::borrow<address>(&setting_request.participants_remove, index));
                index = index + 1;
                if(index >= len){
                    break
                };
            };
            let keys = vec_map::keys<address, u64>( new_participants_by_weight);
            let keys_len = vec_map::size<address, u64>( new_participants_by_weight);
            let keys_ref = &mut keys;
            let cnt = 0;
            loop{
                if(vector::length(keys_ref) == 0){
                    break
                };
                let key = vector::pop_back<address>(keys_ref);
                let v = vec_map::get<address, u64>( new_participants_by_weight, &key);
                // each weight should > 0
                assert!(*v > 0, EInvalidArguments);
                vec_map::insert<address, u64>( participants_by_weight, copy key, *v);
                cnt = cnt + *v;
            };
            // sum of weights should > 0
            assert!(cnt > 0, EInvalidArguments);
            assert!(keys_len == vec_map::size<address, u64>(participants_by_weight), EInvalidArguments);
        };
        mark_proposal_complete(multi_signature, proposal_id, tx);
    }

    /// is user belong to this multi_signature
    public fun is_participant(multi_signature: &MultiSignature, user_address: address): bool{
        vec_map::contains<address,u64>(&multi_signature.participants_by_weight, &user_address)
    }
}

spec multisig::multisig{
    spec schema OnlyParticipant{
        requires vec_map::contains<address,u64>(multi_signature.participants_by_weight, &tx_context::sender(_tx));
        requires vec_map::get<address, u64>(multi_signature.participants_by_weight, &tx_context::sender(_tx)) > 0;
    }
    /// only PendingProposal can continue
    spec schema PendingProposal{
        requires table::contains<u256, Proposal>(multi_signature.pending_proposals, proposal_id);
    }
    spec schema ValidProposalFor{
        let proposal = table::borrow<u256, Proposal>(multi_signature.pending_proposals, proposal_id);
        let for = object::uid_to_inner(multi_signature.id);
        requires proposal.for == multi_signature.id;
    }
    /// vote spec
    spec vote{
        include OnlyParticipant;
        include PendingProposal;
        include ValidProposalFor;
        // user not voted
        let proposal = table::borrow<u256, Proposal>(multi_signature.pending_proposals, proposal_id);
        requires !table::contains<address, bool>(proposal.participants_voted);
        requires !*table::borrow<address, bool>(proposal.participants_voted, tx_context::sender(_tx));
    }
    spec create_proposal{
        include OnlyParticipant;
    }
    spec multisig_setting_execute{
        include OnlyParticipant;
        include PendingProposal;
        include ValidProposalFor;
    }
    spec mark_proposal_complete{
        include OnlyParticipant;
        include PendingProposal;
        include ValidProposalFor;
    }
    spec create_proposal{
        include OnlyParticipant;
    }
    spec create_multisig_setting_proposal{
        include OnlyParticipant;
    }
    spec is_proposal_approved{
        include PendingProposal;
        include ValidProposalFor;
    }
    spec extract_proposal{
        include PendingProposal;
        include ValidProposalFor;        
    }

}