module narwhalc::game {
    use sui::object::{Self, UID, ID};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::vector;
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use sui::event;
    use narwhalc::avatar::{Self, Avatar};

    /// Error codes
    const ENotHost: u64 = 0;
    const EInvalidWinnersCount: u64 = 1;
    const EGameNotActive: u64 = 2;
    const EGameNotWaiting: u64 = 3;
    const ENoRewardToClaim: u64 = 4;
    const EAlreadyJoined: u64 = 5;

    /// Game States
    const STATE_WAITING: u8 = 0;
    const STATE_ACTIVE: u8 = 1;
    const STATE_ENDED: u8 = 2;

    /// Events
    public struct ScoreSubmitted has copy, drop {
        game_id: ID,
        player: address,
        score: u64,
    }

    /// A Game Pool that holds the prize and tracks state
    public struct GamePool has key, store {
        id: UID,
        balance: Balance<SUI>,
        host: address,
        winners_config: u8,
        state: u8,
        players: vector<address>, 
        pending_rewards: Table<address, u64>,
        start_timestamp_ms: u64,
        scores: Table<address, u64>, 
    }

    /// Create a new game pool
    public fun create_game(
        prize: Coin<SUI>, 
        winners_config: u8, 
        ctx: &mut TxContext
    ) {
        assert!(winners_config >= 1 && winners_config <= 3, EInvalidWinnersCount);
        
        let pool = GamePool {
            id: object::new(ctx),
            balance: coin::into_balance(prize),
            host: tx_context::sender(ctx),
            winners_config,
            state: STATE_WAITING,
            players: vector::empty(),
            pending_rewards: table::new(ctx),
            start_timestamp_ms: 0,
            scores: table::new(ctx),
        };

        transfer::share_object(pool);
    }

    /// User joins the game
    public fun join_game(pool: &mut GamePool, ctx: &mut TxContext) {
        assert!(pool.state == STATE_WAITING, EGameNotWaiting);
        let player = tx_context::sender(ctx);
        assert!(!vector::contains(&pool.players, &player), EAlreadyJoined);
        vector::push_back(&mut pool.players, player);
    }

    /// User submits their score at the end of the game
    public fun submit_score(pool: &mut GamePool, score: u64, ctx: &mut TxContext) {
        // Can submit score in Active or Ended state (to allow late submissions)
        let player = tx_context::sender(ctx);
        if (table::contains(&pool.scores, player)) {
            table::remove(&mut pool.scores, player);
        };
        table::add(&mut pool.scores, player, score);

        event::emit(ScoreSubmitted {
            game_id: object::uid_to_inner(&pool.id),
            player,
            score
        });
    }

    /// Host starts the game
    public fun start_game(pool: &mut GamePool, clock: &Clock, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == pool.host, ENotHost);
        assert!(pool.state == STATE_WAITING, EGameNotWaiting);
        pool.state = STATE_ACTIVE;
        pool.start_timestamp_ms = clock::timestamp_ms(clock);
    }

    /// Host finalizes the game and calculates rewards
    /// This populates the pending_rewards table.
    public fun finalize_game(
        pool: &mut GamePool, 
        mut winners: vector<address>, 
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == pool.host, ENotHost);
        assert!(pool.state == STATE_ACTIVE, EGameNotActive);
        
        pool.state = STATE_ENDED;
        let total_amount = balance::value(&pool.balance);
        let num_winners = vector::length(&winners);
        
        let mut i = 0;
        while (i < num_winners) {
            let winner = vector::pop_back(&mut winners);
            let mut amount = 0;
            
            if (num_winners == 1) {
                amount = total_amount; 
            } else if (num_winners == 2) {
                // Input [1st, 2nd] -> pop gives 2nd
                if (i == 0) { amount = (total_amount * 40) / 100; }
                else { amount = (total_amount * 60) / 100; };
            } else if (num_winners == 3) {
                 // Input [1st, 2nd, 3rd] -> pop gives 3rd
                 if (i == 0) { amount = (total_amount * 20) / 100; }
                 else if (i == 1) { amount = (total_amount * 30) / 100; }
                 else { amount = (total_amount * 50) / 100; };
            };

            if (amount > 0) {
                // Add to table
                table::add(&mut pool.pending_rewards, winner, amount);
            };
            i = i + 1;
        };
    }

    /// User claims their reward
    /// Splits 90% to wallet, 10% to Avatar liquidity
    public fun claim_reward(
        pool: &mut GamePool, 
        avatar: &mut Avatar,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(table::contains(&pool.pending_rewards, sender), ENoRewardToClaim);

        let amount = table::remove(&mut pool.pending_rewards, sender);
        
        // Split Logic
        // 10% to Avatar
        let liquidity_amount = amount / 10;
        // 90% to Wallet
        let wallet_amount = amount - liquidity_amount;

        // Take from pool
        let mut total_coin = coin::take(&mut pool.balance, amount, ctx);
        
        // Split coin
        let liquidity_coin = coin::split(&mut total_coin, liquidity_amount, ctx);
        let liquidity_balance = coin::into_balance(liquidity_coin);

        // Inject 10% to Avatar
        avatar::inject_liquidity(avatar, liquidity_balance);
        avatar::update_stats(avatar, true); // Mark as win + increase value_score

        // Send 90% to User
        transfer::public_transfer(total_coin, sender);
    }
}
