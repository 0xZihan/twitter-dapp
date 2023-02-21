module twitter_addr::main {

    use std::string::{Self, String};
    use std::signer;
    use std::vector;
    use aptos_framework::timestamp;
    // use aptos_framework::event;
    // use aptos_framework::account;
    // use aptos_std::debug::print;

    // Errors
    const ERR_ACCOUNT_EXISTS_ALREADY: u64 = 1;
    const ERR_ACCOUNT_NOT_FOUND: u64 = 2;
    const ERR_HAVE_ALREADY_FOLLOWED: u64 = 3;
    const ERR_HAVE_NOT_FOLLOWED_YET: u64 = 4;

    struct Posts has key {
        counter: u64,
        post_list: vector<Post>,
        // post_events: event::EventHandle<PostEvent>,
    }

    struct Post has store, drop, copy {
        user_address: address,
        post_id: u64,
        content: String,
        timestamp: u64,
    }

    struct PostEvent has drop, store {
        user_address: address,
        post_id: u64,
    }

    struct Followees has key {
        counter: u64,
        followee_list: vector<address>,
        // follow_events: event::EventHandle<FollowEvent>,
    }

    struct Followers has key {
        counter: u64,
        follower_list: vector<address>,
        // follow_event: event::EventHandle<FollowEvent>,
    }

    struct FollowEvent has drop, store {
        follower: address,
        followee: address,
        following: bool, // true if following, false if unfollowing
        timestamp: u64,
    }

    fun account_exists(user_address: address): bool {
        if (exists<Posts>(user_address) || exists<Followees>(user_address) || exists<Followers>(user_address)) {
            return true
        } else {
            return false
        }
    }

    /// create an account
    public entry fun create_account(user: &signer) {
        let user_address = signer::address_of(user);
        assert!(!account_exists(user_address), ERR_ACCOUNT_EXISTS_ALREADY);

        // 1. create posts container
        let posts = Posts {
            counter: 0,
            post_list: vector::empty(),
            // post_events: account::new_event_handle<PostEvent>(user),
        };
        move_to(user, posts);

        // 2. create followees container
        let followees = Followees {
            counter: 0,
            followee_list: vector::empty(),
            // follow_events: account::new_event_handle<FollowEvent>(user),
        };
        move_to(user, followees);

        // 3. create followers container
        let followers = Followers {
            counter: 0,
            follower_list: vector::empty(),
            // follow_event: account::new_event_handle<FollowEvent>(user),
        };
        move_to(user, followers);
    }

    /// create a post
    public entry fun create_post(user: &signer, content: String) acquires Posts {
        // get the user address, and asset that user has an account
        let user_address = signer::address_of(user);
        assert!(account_exists(user_address), ERR_ACCOUNT_NOT_FOUND);

        // get the posts resource
        let posts = borrow_global_mut<Posts>(user_address);

        // increment post counter
        let new_counter = posts.counter + 1;

        // create a new post
        let new_post = Post {
            user_address,
            post_id: new_counter,
            content,
            timestamp: timestamp::now_seconds(),
        };

        // append the post to the begining of posts list
        vector::push_back(&mut posts.post_list, new_post);

        // set the post counter to be the incremented counter
        posts.counter = new_counter;

        // fire a new post created event
        // event::emit_event<PostEvent>(
        //     &mut posts.post_events,
        //     PostEvent {
        //         user_address,
        //         post_id: new_counter,
        //     },
        // );
    }

    fun get_follow_event(follower: address, followee: address, following: bool): FollowEvent {
        return FollowEvent {
            follower,
            followee,
            following,
            timestamp: timestamp::now_seconds(),
        }
    }

    /// follow
    public entry fun follow(user: &signer, followee: address) acquires Followees, Followers {
        // get the user address, and asset that user has an account
        let user_address = signer::address_of(user);
        assert!(account_exists(user_address), ERR_ACCOUNT_NOT_FOUND);

        // add to followees and followers
        add_followee(user_address, followee);
        add_follower(user_address, followee);
    }

    fun add_followee(user_address: address, followee: address) acquires Followees {
        let followees = borrow_global_mut<Followees>(user_address);

        assert!(!vector::contains(&followees.followee_list, &followee), ERR_HAVE_ALREADY_FOLLOWED);

        vector::push_back(&mut followees.followee_list, followee);
        followees.counter = followees.counter + 1;

        // event::emit_event<FollowEvent>(
        //     &mut borrow_global_mut<Followees>(user_address).follow_events,
        //     get_follow_event(user_address, followee, true),
        // );
    }

    fun add_follower(follower: address, user_address: address) acquires Followers {
        let followers = borrow_global_mut<Followers>(user_address);

        assert!(!vector::contains(&followers.follower_list, &follower), ERR_HAVE_ALREADY_FOLLOWED);

        vector::push_back(&mut followers.follower_list, follower);
        followers.counter = followers.counter + 1;

        // event::emit_event<FollowEvent>(
        //     &mut borrow_global_mut<Followers>(user_address).follow_event,
        //     get_follow_event(follower, user_address, true),
        // );
    }

    /// unfollow
    public entry fun unfollow(user: &signer, followee: address) acquires Followees, Followers {
        // get the user address, and asset that user has an account
        let user_address = signer::address_of(user);
        assert!(account_exists(user_address), ERR_ACCOUNT_NOT_FOUND);

        // remove in followees and followers
        remove_followee(user_address, followee);
        remove_follower(user_address, followee);
    }

    fun remove_followee(user_address: address, followee: address) acquires Followees {
        let followees = borrow_global_mut<Followees>(user_address);

        assert!(vector::contains(&followees.followee_list, &followee), ERR_HAVE_NOT_FOLLOWED_YET);

        let (_, followee_idx) = vector::index_of(&mut followees.followee_list, &followee);
        vector::remove(&mut followees.followee_list, followee_idx);
        followees.counter = followees.counter - 1;

        // event::emit_event<FollowEvent>(
        //     &mut borrow_global_mut<Followees>(user_address).follow_events,
        //     get_follow_event(user_address, followee, false),
        // );
    }

    fun remove_follower(follower: address, user_address: address) acquires Followers {
        let followers = borrow_global_mut<Followers>(user_address);

        assert!(vector::contains(&followers.follower_list, &follower), ERR_HAVE_NOT_FOLLOWED_YET);

        let (_, follower_idx) = vector::index_of(&mut followers.follower_list, &follower);
        vector::remove(&mut followers.follower_list, follower_idx);
        followers.counter = followers.counter - 1;

        // event::emit_event<FollowEvent>(
        //     &mut borrow_global_mut<Followers>(user_address).follow_event,
        //     get_follow_event(follower, user_address, false),
        // );
    }

    #[view]
    /// return the list of users that this user are following
    public fun get_user_followees(user_address: address): vector<address> acquires Followees{
        assert!(account_exists(user_address), ERR_ACCOUNT_NOT_FOUND);
        let followees = borrow_global<Followees>(user_address);
        return followees.followee_list
    }

    #[view]
    /// return the list of followers of this user
    public fun get_user_followers(user_address: address): vector<address> acquires Followers{
        assert!(account_exists(user_address), ERR_ACCOUNT_NOT_FOUND);
        let followers = borrow_global<Followers>(user_address);
        return followers.follower_list
    }

    #[view]
    /// return all posts made by this user
    public fun get_user_posts(user_address: address): vector<Post> acquires Posts{
        assert!(account_exists(user_address), ERR_ACCOUNT_NOT_FOUND);
        let posts = borrow_global<Posts>(user_address);
        return posts.post_list
    }

    #[view]
    /// return timeline for this user
    /// this will return the top num_of_posts_per_followee posts for all the followees
    public fun get_user_timeline(user_address: address, num_of_posts_per_followee: u64): vector<Post> acquires Posts, Followees {
        assert!(account_exists(user_address), ERR_ACCOUNT_NOT_FOUND);

        let timeline = vector::empty<Post>();
        let followees = borrow_global<Followees>(user_address);

        // iterate followee list and add the recent
        let i = 0;
        let len = followees.counter;
        while (i < len) {
            let followee_address = *vector::borrow(&followees.followee_list, i);
            let followee_posts = borrow_global_mut<Posts>(followee_address);

            if (followee_posts.counter <= num_of_posts_per_followee) {
                vector::append(&mut timeline, followee_posts.post_list);
            } else {
                let j = followee_posts.counter - num_of_posts_per_followee;
                while (j < followee_posts.counter) {
                    let post = *vector::borrow_mut(&mut followee_posts.post_list, j);
                    vector::push_back(&mut timeline, post);
                    j = j + 1;
                };
            };

            i = i + 1;
        };

        return timeline
    }

    #[test(aptos_framework = @0x1, user1 = @0x123, user2 = @0x124, user3 = @0x125)]
    public entry fun test_flow(aptos_framework: &signer, user1: &signer, user2: &signer, user3: &signer) acquires Posts, Followees, Followers {
        let user1_address = signer::address_of(user1);
        let user2_address = signer::address_of(user2);
        let user3_address = signer::address_of(user3);

        // 1. test create account
        create_account(user1);
        create_account(user2);
        create_account(user3);
        assert!(account_exists(user1_address), 11);
        assert!(account_exists(user2_address), 11);
        assert!(account_exists(user3_address), 11);

        // 2. test create posts
        timestamp::set_time_has_started_for_testing(aptos_framework);
        create_post(user1, string::utf8(b"Hello Aptos! I'm user1."));
        create_post(user1, string::utf8(b"This is my 2nd post."));
        create_post(user1, string::utf8(b"This is my 3rd post."));
        create_post(user2, string::utf8(b"Hello Aptos! I'm user2."));
        create_post(user3, string::utf8(b"Hello Aptos! I'm user3."));
        let user1_posts = borrow_global<Posts>(user1_address);
        let user2_posts = borrow_global<Posts>(user2_address);
        let user3_posts = borrow_global<Posts>(user3_address);
        assert!(user1_posts.counter == 3, 12);
        assert!(user2_posts.counter == 1, 12);
        assert!(user3_posts.counter == 1, 12);

        // 3. test follow
        follow(user2, user1_address); // user2 follows user1
        follow(user3, user1_address); // user3 follows user1
        follow(user3, user2_address); // user3 follows user2
        let user1_followers = borrow_global<Followers>(user1_address);
        assert!(user1_followers.counter == 2, 13);
        let user2_followers = borrow_global<Followers>(user2_address);
        assert!(user2_followers.counter == 1, 13);

        // 4. test unfollow
        unfollow(user3, user2_address); // user3 unfollows user2
        let user2_followers = borrow_global<Followers>(user2_address);
        assert!(user2_followers.counter == 0, 13);

        // 5. test get timeline
        let num_of_posts = 2;
        let user2_timeline = get_user_timeline(user2_address, num_of_posts);
        assert!(vector::length(&user2_timeline) == num_of_posts, 14);
        let latest_post = vector::borrow(&user2_timeline, num_of_posts - 1);
        assert!(latest_post.content == string::utf8(b"This is my 3rd post."), 15);

        // 6. test get user posts
        let user1_posts = get_user_posts(user1_address);
        assert!(vector::length(&user1_posts) == 3, 16);

        // 7. test get user followers
        let user1_followers = get_user_followers(user1_address);
        assert!(vector::length(&user1_followers) == 2, 17);

        // 8. test get user followees
        let user2_followees = get_user_followees(user2_address);
        assert!(vector::length(&user2_followees) == 1, 18);
    }
}