module narwhalc::avatar {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::random::{Self, Random};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use std::vector;

    // Friend declaration removed (using package visibility)
    // friend narwhalc::game;

    use sui::package;
    use sui::display;
    use std::string::{Self, String};
    use std::option::{Self, Option};

    // ... imports ...

    /// One-Time-Witness for the module
    public struct AVATAR has drop {}

    /// Error codes
    const ENotAuthorized: u64 = 0;
    const EInsufficientScore: u64 = 1;

    /// Evolution Thresholds
    const THRESHOLD_CYBER: u64 = 10;
    const THRESHOLD_MECH: u64 = 20;
    const THRESHOLD_LEGEND: u64 = 30;

    /// The Narwhal Avatar
    public struct Avatar has key, store {
        id: UID,
        dna: vector<u8>, // [Skin, Tusk, Eyes, Accessory]
        games_played: u64,
        games_won: u64,
        value_score: u64,
        level: u8, // 0=Base, 1=Cyber, 2=Mech, 3=Legend
        locked_balance: Balance<SUI>, // New: Holds 10% of winnings
        image_blob_id: Option<String>, // Stores the Walrus Blob ID
    }

    /// Capability to allow updating avatar stats (held by game server/admin)
    public struct AdminCap has key, store {
        id: UID,
    }

    /// Module Init: Create Publisher, Display, and AdminCap
    fun init(otw: AVATAR, ctx: &mut TxContext) {
        let publisher = package::claim(otw, ctx);

        let mut display = display::new_with_fields<Avatar>(
            &publisher,
            vector[
                string::utf8(b"name"),
                string::utf8(b"image_url"),
                string::utf8(b"description"),
                string::utf8(b"project_url"),
            ],
            vector[
                string::utf8(b"Narwhal Agent #001"), 
                // Uses the `image_blob_id` field if present, otherwise fallback to a default
                string::utf8(b"https://aggregator.walrus-testnet.walrus.space/v1/blobs/{image_blob_id}"),
                string::utf8(b"An evolvable cyber-narwhal powered by Sui AI."),
                string::utf8(b"https://narwhal.sui.io"),
            ],
            ctx
        );

        display::update_version(&mut display);

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));

        let admin_cap = AdminCap {
            id: object::new(ctx),
        };
        transfer::transfer(admin_cap, tx_context::sender(ctx));
    }

    /// Mint a new Avatar with random DNA
    entry fun evolve_avatar(avatar: &mut Avatar, ctx: &mut TxContext) {
        let score = avatar.value_score;
        let current_level = avatar.level;

        if (current_level == 0 && score >= THRESHOLD_CYBER) {
            avatar.level = 1;
        } else if (current_level == 1 && score >= THRESHOLD_MECH) {
            avatar.level = 2;
        } else if (current_level == 2 && score >= THRESHOLD_LEGEND) {
            avatar.level = 3;
        } else {
            abort EInsufficientScore
        };
    }

    entry fun mint_avatar(r: &Random, ctx: &mut TxContext) {
        let mut generator = random::new_generator(r, ctx);
        
        // Generate random DNA indices
        let mut dna = vector::empty<u8>();
        vector::push_back(&mut dna, random::generate_u8_in_range(&mut generator, 0, 5));
        vector::push_back(&mut dna, random::generate_u8_in_range(&mut generator, 0, 10));
        vector::push_back(&mut dna, random::generate_u8_in_range(&mut generator, 0, 10));
        vector::push_back(&mut dna, random::generate_u8_in_range(&mut generator, 0, 10));

        let avatar = Avatar {
            id: object::new(ctx),
            dna,
            games_played: 0,
            games_won: 0,
            value_score: 0,
            level: 0,
            locked_balance: balance::zero(),
            image_blob_id: option::none(),
        };

        transfer::transfer(avatar, tx_context::sender(ctx));
    }

    /// Update the Avatar's image blob ID (Called by User after uploading to Walrus)
    entry fun set_image_blob_id(avatar: &mut Avatar, blob_id: String) {
        avatar.image_blob_id = option::some(blob_id);
    }

    // --- Package Functions (called by Game) ---

    /// Update stats and inject liquidity
    public(package) fun update_stats(
        avatar: &mut Avatar, 
        won: bool
    ) {
        avatar.games_played = avatar.games_played + 1;
        if (won) {
            avatar.games_won = avatar.games_won + 1;
            avatar.value_score = avatar.value_score + 10;
        } else {
            avatar.value_score = avatar.value_score + 1;
        };
    }

    /// Add SUI to the avatar's locked balance
    public(package) fun inject_liquidity(
        avatar: &mut Avatar, 
        reward: Balance<SUI>
    ) {
        balance::join(&mut avatar.locked_balance, reward);
    }

    // --- Public Functions ---

    // Getters
    public fun dna(avatar: &Avatar): vector<u8> {
        avatar.dna
    }

    public fun value_score(avatar: &Avatar): u64 {
        avatar.value_score
    }
    
    public fun locked_value(avatar: &Avatar): u64 {
        balance::value(&avatar.locked_balance)
    }

    public fun level(avatar: &Avatar): u8 {
        avatar.level
    }
}
