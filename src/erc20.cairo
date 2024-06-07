use starknet::ContractAddress;

#[starknet::interface]
trait IERC20<TContractState> {
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
    fn constructor(ref self: ContractState, owner: ContractAddress, recipient: ContractAddress, name: felt252, decimals: u8, initial_supply: u256, symbol: felt252) {
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals);
        self.owner.write(owner);
        let addressZero : ContractAddress = contract_address_const::<0>();

        assert(recipient != addressZero, 'Zero address not allowed');
        self.total_supply.write(initial_supply);
        self.balances.write(recipient, initial_supply);
        self.emit(Transfer {
            from: addressZero,
            to: recipient,
            value: initial_supply,
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
            let addressZero : ContractAddress = contract_address_const::<0>();

            assert(sender_balance >= amount, 'balance is not enough');
            assert(sender != addressZero, 'zero account not allowed');
            assert(recipient != addressZero, 'zero account not allowed');
            self.balances.write(sender, (self.balances.read(sender) - amount));
            self.balances.write(recipient, (self.balances.read(recipient) + amount));
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        fn transfer_from(ref self: ContractState, owner: ContractAddress, recipient: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            let current_allowance = self.allowances.read((owner, caller));
            let addressZero : ContractAddress = contract_address_const::<0>();

            assert(current_allowance >= amount, 'Insufficient allowance');
            assert(owner != addressZero, 'zero account not allowed');
            assert(recipient != addressZero, 'zero account not allowed');
            self.balances.write(owner, (self.balances.read(owner) - amount));
            self.balances.write(recipient, (self.balances.read(recipient) - amount));
            self.emit(Transfer { from: owner, to: recipient, value: amount });
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) {
            let owner = get_caller_address();
            let addressZero : ContractAddress = contract_address_const::<0>();

            assert(spender != addressZero, 'zero address not allowed');
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
            assert(current_allowance >= subtracted_value, 'Decreased allowance below zero');
            self.allowances.write((owner, spender), current_allowance - subtracted_value);
            self.emit(Approval { owner, spender, value: current_allowance - subtracted_value });
        }

        fn mint(ref self: ContractState, account: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            let addressZero : ContractAddress = contract_address_const::<0>();

            assert(caller == self.owner.read(), 'Only owner can mint');
            assert(account != addressZero, 'zero account not allowed');
            self.total_supply.write(self.total_supply.read() + amount);
            self.balances.write(account, self.balances.read(account) + amount);
            self.emit(Transfer { from: addressZero, to: account, value: amount });
        }

        fn burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            let owner = get_caller_address();
            let addressZero : ContractAddress = contract_address_const::<0>();

            assert(owner == self.owner.read(), 'Only owner can burn');
            assert(account != addressZero, 'zero account not allowed');
            assert(self.balances.read(account) >= amount, 'Insufficient balance');
            self.total_supply.write(self.total_supply.read() - amount);
            self.balances.write(account, self.balances.read(account) - amount);
            self.emit(Transfer { from: account, to: addressZero, value: amount });
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            let owner = get_caller_address();
            let addressZero : ContractAddress = contract_address_const::<0>();

            assert(owner == self.owner.read(), 'Only owner');
            assert(new_owner != addressZero, 'zero account not allowed');
            self.owner.write(new_owner);
        }
    }
}