use starknet::{SyscallResultTrait, ContractAddress, syscalls};
use core::serde::Serde;

#[starknet::interface]
trait IKillSwitchTrait<T> {
    fn is_active(self: @T) -> bool;
}

#[derive(Copy, Drop, starknet::Store, Serde)]
struct IKillSwitch {
    contract_address: ContractAddress,
}

impl IKillSwitchImpl of IKillSwitchTrait<IKillSwitch> {
    fn is_active(self: @IKillSwitch) -> bool {
        let mut call_data: Array<felt252> = ArrayTrait::new();
        let contract_address: ContractAddress = *self.contract_address;
        let mut res = syscalls::call_contract_syscall(
            contract_address, selector!("is_active"), call_data.span()
        )
            .unwrap_syscall();

        Serde::<bool>::deserialize(ref res).unwrap()
    }
}

#[starknet::interface]
trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
}

#[starknet::contract]
pub mod counter_contract {

    use OwnableComponent::InternalTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::event::EventEmitter;
    use core::starknet::ContractAddress;
    use super::IKillSwitchTrait;
    use super::IKillSwitch;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: ContractAddress,

        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterIncreased: CounterIncreased,

        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[derive(Drop, starknet::Event)]
    struct CounterIncreased{
        #[key]
        value: u32
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_value: u32, kill_switch_address: ContractAddress, initial_owner: ContractAddress) {
        self.counter.write(initial_value);
        self.kill_switch.write(kill_switch_address);
        self.ownable.initializer(initial_owner)
    }

    #[abi(embed_v0)]
    impl Counter of super::ICounter<ContractState> {

        fn get_counter(self:@ContractState) -> u32{
            self.counter.read()
        }

    fn increase_counter(ref self: ContractState){

        self.ownable.assert_only_owner();

        let kill_switch_address = self.kill_switch.read();
        let is_active = IKillSwitch { contract_address: kill_switch_address }.is_active();

        // if (!is_active) {
        //     self.counter.write(self.counter.read() + 1);
        // self.emit(CounterIncreased{value:(self.counter.read())})
        // }else{
        //     self.counter.read();
        // }
        
        assert!(!is_active,"Kill Switch is active");

        self.counter.write(self.counter.read() + 1);
        self.emit(CounterIncreased{value: self.counter.read()})
        }
    }
}