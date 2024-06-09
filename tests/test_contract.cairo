use starknet::{ContractAddress, contract_address_const};

use snforge_std::{declare, ContractClassTrait, cheat_caller_address, start_cheat_caller_address,
    stop_cheat_caller_address, CheatSpan, spy_events, SpyOn, EventSpy, EventAssertions}; // Added extra for reference

use erc20contract::erc20::IERC20SafeDispatcher;
use erc20contract::erc20::IERC20SafeDispatcherTrait;
use erc20contract::erc20::IERC20Dispatcher;
use erc20contract::erc20::IERC20DispatcherTrait;

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap();
    let owner: ContractAddress = contract_address_const::<'owner'>();
    let recipient: ContractAddress = contract_address_const::<'recipient'>();
    let name: felt252 = 'PopeToken'.into();
    let decimals: u8 = 18;
    let initial_supply: felt252 = 1000000;
    let symbol: felt252 = 'PTK'.into();

    let mut constructor_calldata = array![owner.into(), recipient.into(), name, decimals.into(), initial_supply.into(), symbol];

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap(); //@ArrayTrait::new()
    contract_address
}

#[test]
fn test_get_name() {
    let contract_address = deploy_contract("erc_20");

    let dispatcher = IERC20Dispatcher { contract_address };

    let name = dispatcher.get_name();
    assert(name == 'PopeToken', 'Invalid name');
}

#[test]
fn test_get_symbol() {
    let contract_address = deploy_contract("erc_20");

    let dispatcher = IERC20Dispatcher { contract_address };

    let symbol = dispatcher.get_symbol();
    assert(symbol == 'PTK', 'Invalid symbol');
}

#[test]
fn test_get_decimals() {
    let contract_address = deploy_contract("erc_20");

    let dispatcher = IERC20Dispatcher { contract_address };

    let decimals = dispatcher.get_decimals();
    assert(decimals == 18, 'Invalid decimals');
}

#[test]
fn test_owner() {
    let contract_address = deploy_contract("erc_20");

    let owner: ContractAddress = contract_address_const::<'owner'>().into();
    let dispatcher = IERC20Dispatcher { contract_address };

    let deployer = dispatcher.get_owner();
    assert(owner == deployer, 'Invalid owner');
}

#[test]
fn test_total_supply() {
    let contract_address = deploy_contract("erc_20");

    let dispatcher = IERC20Dispatcher { contract_address };

    let total_supply = dispatcher.get_total_supply();
    assert(total_supply == 1000000, 'Invalid total supply');
}

#[test]
fn test_balance_of() {
    let contract_address = deploy_contract("erc_20");

    let recipient: ContractAddress = contract_address_const::<'recipient'>().into();
    let dispatcher = IERC20Dispatcher { contract_address };

    let balance = dispatcher.balance_of(recipient);
    assert(balance == 1000000, 'Invalid balance');
}

#[test]
fn test_transfer() {
    let contract_address = deploy_contract("erc_20");

    let user: ContractAddress = contract_address_const::<'user'>().into();
    let recipient: ContractAddress = contract_address_const::<'recipient'>().into();
    let dispatcher = IERC20Dispatcher { contract_address };
    cheat_caller_address(contract_address, recipient, CheatSpan::Indefinite); // OR start_cheat_caller_address(contract_address, recipient);

    let balance_before_user = dispatcher.balance_of(user);
    let balance_before_recipient = dispatcher.balance_of(recipient);

    dispatcher.transfer(user, 400000);

    let balance_after_user = dispatcher.balance_of(user);
    let balance_after_recipient = dispatcher.balance_of(recipient);

    assert(balance_before_user == 0, 'Invalid balance');
    assert(balance_before_recipient == 1000000, 'Invalid balance');
    assert(balance_after_user == 400000, 'Invalid balance');
    assert(balance_after_recipient == 600000, 'Invalid balance');
}

#[test]
fn test_transfer_from() {
    let contract_address = deploy_contract("erc_20");

    let user: ContractAddress = contract_address_const::<'user'>().into();
    let owner: ContractAddress = contract_address_const::<'owner'>();
    let recipient: ContractAddress = contract_address_const::<'recipient'>().into();
    let dispatcher = IERC20Dispatcher { contract_address };

    let balance_before_user = dispatcher.balance_of(user);
    let balance_before_recipient = dispatcher.balance_of(recipient);
    let allowance_before = dispatcher.allowance(recipient, owner);

    start_cheat_caller_address(contract_address, recipient);
    dispatcher.approve(owner, 400000);
    start_cheat_caller_address(contract_address, owner);

    let allowance_after = dispatcher.allowance(recipient, owner);

    assert(allowance_before == 0, 'Invalid allowance');
    assert(allowance_after == 400000, 'Invalid allowance');

    dispatcher.transfer_from(recipient, user, 400000);

    let balance_after_user = dispatcher.balance_of(user);
    let balance_after_recipient = dispatcher.balance_of(recipient);

    assert(balance_before_user == 0, 'Invalid balance');
    assert(balance_before_recipient == 1000000, 'Invalid balance');
    assert(balance_after_user == 400000, 'Invalid balance');
    assert(balance_after_recipient == 600000, 'Invalid balance');
}

#[test]
fn test_approve() {
    let contract_address = deploy_contract("erc_20");

    let owner: ContractAddress = contract_address_const::<'owner'>();
    let recipient: ContractAddress = contract_address_const::<'recipient'>().into();
    let dispatcher = IERC20Dispatcher { contract_address };

    let allowance_before = dispatcher.allowance(recipient, owner);

    start_cheat_caller_address(contract_address, recipient);
    dispatcher.approve(owner, 400000);
    start_cheat_caller_address(contract_address, owner);

    let allowance_after = dispatcher.allowance(recipient, owner);

    assert(allowance_before == 0, 'Invalid allowance');
    assert(allowance_after == 400000, 'Invalid allowance');
}

#[test]
fn test_mint() {
    let contract_address = deploy_contract("erc_20");

    let owner: ContractAddress = contract_address_const::<'owner'>();
    let dispatcher = IERC20Dispatcher { contract_address };

    let total_supply_before = dispatcher.get_total_supply();
    let balance_before = dispatcher.balance_of(owner);

    start_cheat_caller_address(contract_address, owner);
    dispatcher.mint(owner, 1000000);

    let total_supply_after = dispatcher.get_total_supply();
    let balance_after = dispatcher.balance_of(owner);

    assert(total_supply_before == 1000000, 'Invalid total supply');
    assert(balance_before == 0, 'Invalid balance');
    assert(total_supply_after == 2000000, 'Invalid total supply');
    assert(balance_after == 1000000, 'Invalid balance');
}

#[test]
fn test_burn() {
    let contract_address = deploy_contract("erc_20");

    let owner: ContractAddress = contract_address_const::<'owner'>();
    let recipient: ContractAddress = contract_address_const::<'recipient'>();
    let dispatcher = IERC20Dispatcher { contract_address };

    let total_supply_before = dispatcher.get_total_supply();
    let balance_before = dispatcher.balance_of(recipient);

    start_cheat_caller_address(contract_address, owner);
    dispatcher.burn(recipient, 400000);

    let total_supply_after = dispatcher.get_total_supply();
    let balance_after = dispatcher.balance_of(recipient);

    assert(total_supply_before == 1000000, 'Invalid total supply');
    assert(balance_before == 1000000, 'Invalid balance');
    assert(total_supply_after == 600000, 'Invalid total supply');
    assert(balance_after == 600000, 'Invalid balance');
}

#[test]
fn test_transfer_ownership() {
    let contract_address = deploy_contract("erc_20");

    let owner: ContractAddress = contract_address_const::<'owner'>();
    let new_owner: ContractAddress = contract_address_const::<'new_owner'>();
    let dispatcher = IERC20Dispatcher { contract_address };

    let owner_before = dispatcher.get_owner();

    start_cheat_caller_address(contract_address, owner);
    dispatcher.transfer_ownership(new_owner);

    let owner_after = dispatcher.get_owner();

    assert(owner_before == owner, 'Invalid owner');
    assert(owner_after == new_owner, 'Invalid owner');
}

#[test]
#[should_panic(expected: ('Insufficient balance',))]
fn test_transfer_insufficient_balance() {
    let contract_address = deploy_contract("erc_20");

    let user: ContractAddress = contract_address_const::<'user'>();
    let recipient: ContractAddress = contract_address_const::<'recipient'>().into();
    let dispatcher = IERC20Dispatcher { contract_address };

    start_cheat_caller_address(contract_address, recipient);
    dispatcher.transfer(user, 1000001);
}

#[test]
#[should_panic(expected: ('Insufficient allowance',))]
fn test_transfer_from_insufficient_allowance() {
    let contract_address = deploy_contract("erc_20");

    let user: ContractAddress = contract_address_const::<'user'>();
    let owner: ContractAddress = contract_address_const::<'owner'>();
    let recipient: ContractAddress = contract_address_const::<'recipient'>().into();
    let dispatcher = IERC20Dispatcher { contract_address };

    start_cheat_caller_address(contract_address, recipient);
    dispatcher.approve(owner, 400000);
    start_cheat_caller_address(contract_address, owner);
    dispatcher.transfer_from(recipient, user, 400001);
}

#[test]
#[should_panic(expected: ('Only owner',))]
fn test_transfer_ownership_not_owner() {
    let contract_address = deploy_contract("erc_20");

    let new_owner: ContractAddress = contract_address_const::<'new_owner'>();
    let dispatcher = IERC20Dispatcher { contract_address };

    dispatcher.transfer_ownership(new_owner);
}