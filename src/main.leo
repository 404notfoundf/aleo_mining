import credits.aleo;

// The 'mining' program.
program mining_pool_online_v1_test.aleo {

    // 定义了poolInfo
    struct PoolInfo {
        validator: address,
        is_open: bool, // Custom data can be added here as needed.
    }

    // 判断地址是否是admins
    mapping admins: address => bool;

    // 每个 address 质押了多少
    mapping bonded: address => u64;

    // A set of stakers with their unbonding microcredits and unlock height.
    mapping unbonding: address => unbond_state;

    // Tracks the total staking bonds and unbonds by the delegators in the mining pool contract.
    // 0 -> total delegated (no stake rewards)
    // 1 -> total pending unbonds
    mapping totals: u8 => u64;

    // 0 -> 存储当前pool的状态信息
    mapping pool_info: u8 => PoolInfo;

    // constructor
    @custom
    async constructor() {
        assert_eq(true, true);
    }

    // Initializes the admin address that manages the pool contract and start the initial staking process.
    // A minimum of 10,000 credits is required for the initial bond to succeed.
    //
    // Note: This is a naive approach where first person who calls this function and bonds credits will become the admin of the mining pool contract.
    //       The better approach is to hard-code an address that is by default an admin and is allowed to add and remove other admins.
    async transition initialize(public validator_address: address, public initial_stake_amount: u64) -> Future {
        // Transfer credits to the mining pool contract.
        let f1: Future = credits.aleo/transfer_public_as_signer(mining_pool_online_v1_test.aleo, initial_stake_amount);

        // Bond the credits to the validator using the mining pool program as the delegator.
        let f2: Future = credits.aleo/bond_public(validator_address, mining_pool_online_v1_test.aleo, initial_stake_amount);

        return finalize_initialize(self.caller, validator_address, initial_stake_amount, f1, f2);
    }

    async function finalize_initialize(public caller: address, validator_address: address, initial_stake_amount: u64, f1: Future, f2: Future) {
        // Await the futures
        f1.await();
        f2.await();

        // TODO 是否需要 硬编码 admins的地址, 做判断

        // Set the admin address.
        Mapping::set(admins, caller, true);

        // Ensure that the total staked mapping is not initialized.
        let is_initialized: bool = Mapping::contains(totals, 0u8);
        assert(!is_initialized);

        // Update the total staked mapping with the initial amount.
        Mapping::set(totals, 0u8, initial_stake_amount);

        // Update the caller's bonded balance.
        Mapping::set(bonded, caller, initial_stake_amount);

        // Set the default mining pool info.
        let info: PoolInfo = PoolInfo {
            validator: validator_address,
            is_open: true,
        };

        Mapping::set(pool_info, 0u8, info);
    }

    // 用来更新pool is_open的状态
    async transition set_pool_state(public is_open: bool) -> Future {
        return finalize_set_pool_state(self.caller, is_open);
    }

    async function finalize_set_pool_state(public caller: address, public is_open: bool) {
        // 只有admin才能够更新
        let is_admin: bool = Mapping::get(admins, caller);
        assert(is_admin);

        let current_pool_info: PoolInfo = Mapping::get(pool_info, 0u8);

        // Create the updated pool info struct.
        let updated_pool_info: PoolInfo = PoolInfo {
            validator: current_pool_info.validator,
            is_open: is_open,
        };

        // 更新pool状态
        Mapping::set(pool_info, 0u8, updated_pool_info);
    }

    // Transfer funds into the mining pool program and bond them to the validator.
    // This is callable by anyone who wishes to join the mining pool.
    async transition bond_public(public validator_address: address, public stake_amount: u64) -> Future {
        // Transfer credits to the mining pool contract.
        let f1: Future = credits.aleo/transfer_public_as_signer(mining_pool_online_v1_test.aleo, stake_amount);

        // Bond the credits into the mining pool.
        let f2: Future = credits.aleo/bond_public(validator_address, mining_pool_online_v1_test.aleo, stake_amount);

        return finalize_bond_public(self.caller, validator_address, stake_amount, f1, f2);
    }

    async function finalize_bond_public(public caller: address, validator_address: address, stake_amount: u64, f1: Future, f2: Future) {
        // Await the futures
        f1.await();
        f2.await();

        // 判断 pool_info 中 validator_address 是否一致 、 pool的状态是否是open
        let current_pool_info: PoolInfo = Mapping::get(pool_info, 0u8);
        // Check that the validator address is the same as the one in the mapping.
        assert_eq(current_pool_info.validator, validator_address);
        // Check that the pool is open.
        assert(current_pool_info.is_open);

        // 更新 caller 的 bond balance
        let existing_balance: u64 = Mapping::get_or_use(bonded, caller, 0u64);
        let new_balance = existing_balance + stake_amount;
        Mapping::set(bonded, caller, new_balance);

        // totals 新质押的部分增加
        let existing_total_staked: u64 = Mapping::get(totals, 0u8);
        let new_total_staked = existing_total_staked + stake_amount;
        Mapping::set(totals, 0u8, new_total_staked);
    }

    // Unbond a certain number of credits.
    // The unbonded credits will be held by the mining pool contract's public address and can only be withdrawn via the `claim_unbond_public` function.
    // This is callable by the delegator who wishes to unbond or by the pool admin. The pool admin is allowed to unbond on behalf of any delegator.
    //
    // Note: This model currently does not automatically calculate the staking rewards of individual delegators. It is up to the pool operator to
    //       determine how to properly distribute the staking rewards.
    async transition unbond_public(public delegator_address: address, public unbond_amount: u64) -> Future {
        // Unbond the credits from the validator.
        let f1: Future = credits.aleo/unbond_public(mining_pool_online_v1_test.aleo, unbond_amount);

        return finalize_unbond_public(self.caller, delegator_address, unbond_amount, f1);
    }

    async function finalize_unbond_public(public caller: address, public delegator_address: address, public unbond_amount: u64, f1: Future) {
            // Set the default bonded state.
            let default_bond = bond_state {
                validator: mining_pool_online_v1_test.aleo, // Placeholder address, as this is not used in this function.
                microcredits: 0u64,
            };

            // 获取原先总共绑定多少
            let program_bonded: bond_state = Mapping::get_or_use(credits.aleo/bonded, mining_pool_online_v1_test.aleo, default_bond);
            let stake_amount_before_unbonding: u64 = program_bonded.microcredits;

            // Await the future.
            f1.await();

            // Check if the caller is authorized to unbond.
            let is_admin: bool = Mapping::get_or_use(admins, caller, false);

            // caller 地址 必须和 入参 delegate地址相同
            let is_unbonding_self = caller == delegator_address;

            // Get the amount staked for the delegator.
            let delegator_stake_amount: u64 = Mapping::get(bonded, delegator_address);
            // Get the total staked amount for the pool.
            // get total staked
            let total_staked_amount: u64 = Mapping::get(totals, 0u8);

            // Determine if the bonded balance for the mining pool still exists.
            let is_fully_unbonded: bool = !Mapping::contains(credits.aleo/bonded, mining_pool_online_v1_test.aleo);

            // If the caller is the admin and the stake amount drops below the minimum, ensure that there is no other delegators in the pool
            // Note: Currently, the only the admin that called `initialize` can call this.
            // If more admins are needed, this logic should be updated.
            if is_admin {
                if is_fully_unbonded {
                    // 只有一个情况是相等的，所有的delegator都退出了
                    // Ensure there are no other delegators in the pool.
                    // This is to ensure that the minimum stake amount of 10,000 credits is always held.
                    assert_eq(delegator_stake_amount, total_staked_amount);
                }
            // If the caller is not an admin ensure that the delegator address and the caller are equivalent and the mining pool is still bonded.
            } else {
               assert(is_unbonding_self);
               assert(!is_fully_unbonded);
            }

            // Calculate the remaining amounts.
            let remaining_balance = delegator_stake_amount - unbond_amount;
            let remaining_total_stake = total_staked_amount - unbond_amount;

            // 如果质押数量 = 0了, 直接remove，否则重新set
            // Update the delegator's balance.
            if remaining_balance == 0u64 || is_fully_unbonded {
                // If the remaining balance is zero, remove the delegator's entry from the bonded mapping.
                Mapping::remove(bonded, delegator_address);
            } else {
                // If the remaining balance is not zero, update the delegator's bonded balance.
                Mapping::set(bonded, delegator_address, remaining_balance);
            }

            // 如果total_stake = 0 了, 直接remove, 否则重新set
            // Update the total stake.
            if remaining_total_stake == 0u64 || is_fully_unbonded {
                // If the remaining total stake is zero, total staked entry and the `PoolInfo` to allow a new `initialize` to be called.
                Mapping::remove(totals, 0u8);
                Mapping::remove(pool_info, 0u8);
            } else {
                // If the remaining total stake is not zero, update the total staked mapping.
                Mapping::set(totals, 0u8, remaining_total_stake);
            }

            // Create a default unbond state.
            // 需要等待360个块
            let unlock_height = block.height + 360u32;
            let default_unbond_state = unbond_state {
                microcredits: 0u64,
                height: unlock_height,
            };

            // 如果unbond了一笔, 没到 unlock height, 那么下一次再提取又会继续更新 unlock height

            // Fetch the current unbond state or use the default state if it does not exist.
            let current_unbond_state: unbond_state = Mapping::get_or_use(unbonding, delegator_address, default_unbond_state);

            // Determine how much to add to the existing unbonding state amount.
            let additional_unbond = is_fully_unbonded ? stake_amount_before_unbonding : unbond_amount;

            // Update the unbond state with the unbonded amount and unlock height.
            let updated_unbond_state = unbond_state {
                microcredits: current_unbond_state.microcredits + additional_unbond,
                height: unlock_height,
            };

            // Set the unbonding state.
            Mapping::set(unbonding, delegator_address, updated_unbond_state);

            // 更新pending_unbond的值
            let pending_unbond: u64 = Mapping::get_or_use(totals, 1u8, 0u64);
            let new_pending_unbond = pending_unbond + additional_unbond;
            Mapping::set(totals, 1u8, new_pending_unbond);
    }

    // Claims the unbonded credits that have been unlocked and transfers them to the staker.
    // This is callable by anyone.
    //
    // Note: A call to `credits.aleo/claim_unbond_public` for this program's address may be required to unlock sufficient public balance to support this claim.
    // TODO: Consider adding more restrictions to prevent perpetual cycle of increasing unlock height. Perhaps limiting
    //       the the calls to `unbond_public` to only be one at a time.
    // 没有办法调用 claim_unbond_public
    async transition claim_unbond_public(public staker: address, public amount: u64) -> Future {
        let f1: Future = credits.aleo/transfer_public(staker, amount);

        return finalize_claim_unbond_public(staker, amount, f1);
    }

    async function finalize_claim_unbond_public(public staker: address, public amount: u64, public f1: Future) {
        // Await the future.
        f1.await();

        // Get the staker's unbond state
        let staker_unbond_state: unbond_state = Mapping::get(unbonding, staker);

        // Ensure that the correct amount was claimed.
        // 判断了原先 unbond的 amount 是否和 传入参数 保持一致
        assert_eq(staker_unbond_state.microcredits, amount);

        // Ensure that the unlock height has passed.
        assert(block.height >= staker_unbond_state.height);

        // Remove the staker's unbond state.
        Mapping::remove(unbonding, staker);

        // Update the total amount of microcredits pending unbond.
        let pending_unbond: u64 = Mapping::get(totals, 1u8);
        let new_pending_unbond = pending_unbond - amount;
        Mapping::set(totals, 1u8, new_pending_unbond);
    }

    // Send the specified amount of public credits to the recipient. This can be used by the admin to distribute
    // the mining rewards or to re-balance the pool amounts.
    // This is callable by the admin of the mining pool contract.
    // 只有admin才能调用
    async transition transfer_public(public recipient: address, public amount: u64) -> Future {
        // Transfer the public credits held by the mining pool program to the recipient.
        let f1: Future = credits.aleo/transfer_public(recipient, amount);

        return finalize_transfer_public(self.caller, recipient, amount, f1);
    }

    async function finalize_transfer_public(public caller: address, public recipient: address, public amount: u64, f1: Future) {
        // Await the future.
        f1.await();

        // Ensure that the caller is an admin.
        let is_admin: bool = Mapping::get(admins, caller);
        assert(is_admin);

        // Fetch the remaining public balance of the mining pool contract.
        let public_balance: u64 = Mapping::get(credits.aleo/account, mining_pool_online_v1_test.aleo);

        // Set the default bonded state.
        let default_bond = bond_state {
            validator: mining_pool_online_v1_test.aleo, // Placeholder address, as this is not used in this function.
            microcredits: 0u64,
        };

        // Get the amount of microcredits pending unbonding for the mining pool contract.
        let program_bonded: bond_state = Mapping::get_or_use(credits.aleo/bonded, mining_pool_online_v1_test.aleo, default_bond);
        let program_bonded_amount: u64 = program_bonded.microcredits;

        // Set the default unbond state.
        let default_unbond = unbond_state {
            microcredits: 0u64,
            height: 0u32,
        };

        // Get the amount of microcredits pending unbonding for the mining pool contract.
        let program_unbond_state: unbond_state = Mapping::get_or_use(credits.aleo/unbonding, mining_pool_online_v1_test.aleo, default_unbond);
        let program_unbonding_amount: u64 = program_unbond_state.microcredits;

        // Calculate the total amount of credits that the mining pool has either in public balance, bonded, or pending unbonding.
        let total_balance = public_balance + program_bonded_amount + program_unbonding_amount;

        // Fetch the total amount of microcredits bonded and unbonding by the delegators.
        let delegators_bonded_amount = Mapping::get_or_use(totals, 0u8, 0u64);
        let delegators_pending_unbond = Mapping::get_or_use(totals, 1u8, 0u64);

        // Calculate the total minimum amount of credits that the mining pool must retain.
        let total_delegated_amount = delegators_bonded_amount + delegators_pending_unbond;

        // 判断账户的余额是否能够cover, 因为此地址会收到reward
        assert(total_balance >= total_delegated_amount);
    }

    // This function unbonds the delegator's credits in the emergency case where the validator forcibly unbonded the mining pool contract.
    // This is callable by anyone and can only be called if the mining pool is no longer bonded to the validator, but the delegator address is still bonded.
    async transition fallback_unbond_if_removed(public delegator_address: address) -> Future {
        return finalize_unbond_if_removed(delegator_address);
    }

    async function finalize_unbond_if_removed(public delegator_address: address) {
            // Determine if the bonded balance for the mining pool still exists.
            let is_fully_unbonded: bool = !Mapping::contains(credits.aleo/bonded, mining_pool_online_v1_test.aleo);
            // 判断下是否全部在 unbond 中
            assert(is_fully_unbonded);

            // Get the amount staked for the delegator.
            // 将用户质押的全部 unlock
            let delegator_stake_amount: u64 = Mapping::get(bonded, delegator_address);
            // Get the total staked amount for the pool.
            let total_staked_amount: u64 = Mapping::get(totals, 0u8);

            // Remove the delegator's bonded entry.
            Mapping::remove(bonded, delegator_address);

            // Calculate the remaining amounts.
            let remaining_total_stake = total_staked_amount - delegator_stake_amount;

            // 更新 total stake
            if remaining_total_stake == 0u64 {
                // If the remaining total stake is zero, total staked entry and the `PoolInfo` to allow a new `initialize` to be called.
                Mapping::remove(totals, 0u8);
                Mapping::remove(pool_info, 0u8);
            } else {
                // If the remaining total stake is not zero, update the total staked mapping.
                Mapping::set(totals, 0u8, remaining_total_stake);
            }

            // Create a default unbond state.
            let unlock_height = block.height + 360u32;
            let default_unbond_state = unbond_state {
                microcredits: 0u64,
                height: unlock_height,
            };

            // Fetch the current unbond state or use the default state if it does not exist.
            let current_unbond_state: unbond_state = Mapping::get_or_use(unbonding, delegator_address, default_unbond_state);

            // Update the unbond state with the unbonded amount and unlock height.
            let updated_unbond_state = unbond_state {
                microcredits: current_unbond_state.microcredits + delegator_stake_amount,
                height: unlock_height,
            };

            // 设置 unbonding 状态
            Mapping::set(unbonding, delegator_address, updated_unbond_state);

            // Update the total amount of microcredits pending unbond.
            let pending_unbond: u64 = Mapping::get_or_use(totals, 1u8, 0u64);
            let new_pending_unbond = pending_unbond + delegator_stake_amount;
            Mapping::set(totals, 1u8, new_pending_unbond);
    }
}