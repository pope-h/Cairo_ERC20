use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn get_name(self: @TContractState) -> felt252;
    fn get_symbol(self: @TContractState) -> felt252;
    fn get_decimals(self: @TContractState) -> u8;
    fn get_total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn transfer_from(ref self: TContractState, owner: ContractAddress, recipient: ContractAddress, amount: u256);
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256);
    fn increase_allowance(ref self: TContractState, spender: ContractAddress, added_value: u256);
    fn decrease_allowance(ref self: TContractState, spender: ContractAddress, subtracted_value: u256);
    fn mint(ref self: TContractState, account: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, account: ContractAddress, amount: u256);
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
}

#[starknet::contract]
mod erc_20 {
    use starknet::{ContractAddress, contract_address_const, get_caller_address};

    #[storage]
    struct Storage {
        name: felt252,
        symbol: felt252,
        decimals: u8,
        total_supply: u256,
        owner: ContractAddress,
        balances: LegacyMap::<ContractAddress, u256>,
        allowances: LegacyMap::<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        #[key]
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, recipient: ContractAddress, name: felt252, decimals: u8, initial_supply: felt252, symbol: felt252) {
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals);
        self.owner.write(owner);

        assert(recipient != self.address_zero(), 'Zero address');
        let _initial_supply: u256 = initial_supply.try_into().unwrap();
        self.total_supply.write(_initial_supply);
        self.balances.write(recipient, _initial_supply);
        self.emit(Transfer {
            from: self.address_zero(),
            to: recipient,
            value: _initial_supply,
        });
    }

    #[abi(embed_v0)]
    impl ERC20Impl of super::IERC20<ContractState> {
        fn get_name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn get_symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn get_decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn get_total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let sender = get_caller_address();
            let sender_balance = self.balances.read(sender);

            assert(sender_balance >= amount, 'Insufficient balance');
            assert(sender != self.address_zero(), 'zero address');
            assert(recipient != self.address_zero(), 'zero address');
            self.balances.write(sender, (self.balances.read(sender) - amount));
            self.balances.write(recipient, (self.balances.read(recipient) + amount));
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        fn transfer_from(ref self: ContractState, owner: ContractAddress, recipient: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            let current_allowance = self.allowances.read((owner, caller));

            assert(current_allowance >= amount, 'Insufficient allowance');
            assert(owner != self.address_zero(), 'zero address');
            assert(recipient != self.address_zero(), 'zero address');
            self.balances.write(owner, (self.balances.read(owner) - amount));
            self.balances.write(recipient, (self.balances.read(recipient) + amount));
            self.emit(Transfer { from: owner, to: recipient, value: amount });
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) {
            let owner = get_caller_address();

            assert(spender != self.address_zero(), 'zero address');
            self.allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        fn increase_allowance(ref self: ContractState, spender: ContractAddress, added_value: u256) {
            let owner = get_caller_address();
            let current_allowance = self.allowances.read((owner, spender));
            self.allowances.write((owner, spender), current_allowance + added_value);
            self.emit(Approval { owner, spender, value: current_allowance + added_value });
        }

        fn decrease_allowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u256) {
            let owner = get_caller_address();
            let current_allowance = self.allowances.read((owner, spender));
            assert(current_allowance >= subtracted_value, 'Allowance underflow');
            self.allowances.write((owner, spender), current_allowance - subtracted_value);
            self.emit(Approval { owner, spender, value: current_allowance - subtracted_value });
        }

        fn mint(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.only_owner();
            assert(account != self.address_zero(), 'zero address');

            self.total_supply.write(self.total_supply.read() + amount);
            self.balances.write(account, self.balances.read(account) + amount);
            self.emit(Transfer { from: self.address_zero(), to: account, value: amount });
        }

        fn burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.only_owner();
            assert(account != self.address_zero(), 'zero address');
            assert(self.balances.read(account) >= amount, 'Insufficient balance');

            self.total_supply.write(self.total_supply.read() - amount);
            self.balances.write(account, self.balances.read(account) - amount);
            self.emit(Transfer { from: account, to: self.address_zero(), value: amount });
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            self.only_owner();

            assert(new_owner != self.address_zero(), 'zero account not allowed');
            self.owner.write(new_owner);
        }
    }

    #[generate_trait]
    pub impl internalImpl of InternalTrait {
        fn address_zero(ref self: ContractState) -> ContractAddress {
            contract_address_const::<0>()
        }

        fn only_owner(ref self: ContractState) -> bool {
            let caller = get_caller_address();
            let owner = self.owner.read();

            assert(caller == owner, 'Only owner'); // The next line should serve but i needed to return a message
            caller == owner
        }
    }
}