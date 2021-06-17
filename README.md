# High-Frequency Shit-Stonks (HFSS)

In HFSS, players ARE corporations!

Emoji can be purchased as "commodity" stonks!

Corporations (players) can be invested in via stonks!

Players can join forces and initiate corporate mergers and hostile takeovers!

Bots also count as corporations! Except HFSS.

## Game Loop

- Automatic Actions
    - Every day make loan payments on all outstanding loans
        - If cannot make loan payments, go "bankrupt" and start again with a new starter loan at current Fed Interest Rate and zero debt
    - Every week, corporations post a "weekly review" detailing financial performance (revenue, costs, profit, dividends, etc)
    - Every time anyone uses an emoji, they automatically buy the cheapest available emoji from all corporations that have that emoji in stock
    - Recurring emoji production occurs at frequency set by corporation
    - IPOs happen whenever a new emoji is detected
        - Automatically distribute some (random?) number of emoji to (all?) users
        - HFSS "sells" some number of these emojis at "zero" price, and whoever uses them first gets them?
- Intentional Actions
    - Put/Call stonks/emoji
    - Buy/Sell emoji
    - Lend/borrow $
    - Research emoji manufacturing
    - Manufature emoji
    - Set emoji price
    - Set your corporate dividend

## The Stonk Market

- Keeps track of ALL transactions
- Determine the current price of a stock based on most recent **completed** calls and puts
    - If not enough info, then stock value is "0"

## Loans

- Bank's interest rate is just a constant, perhaps %5
- In order to take out loan, must have collatoral? (e.g. total value of assets, stonks + emoji)

> IN FUTURE, maybe make this set by "Chairman of the Fed" - a democratically elected / randomly assigned position?

## Actions

- Call ("Buy" contract)
    - You agree to buy stock from another corporation/channel at set upon price at a certain time
    - `HFSS CALL <@USER/#CHANNEL> :EMOJI: <COUNT> AT <PRICE> (WITHIN <DURATION>)`
        - You immediately set aside that amount of money upon initiating the call
    - `#CHANNEL` sees a message from HFSS if initiating player has enough money  
        - The first `@USER(S)` to agree then complete the transation (assuming within `<DURATION>` and have available stock)
            - Allow for partial fulfullment of contract, up to amount requested
    - `@USER` sees a message from HFSS if the initiating player has enough money and `@USER` has enough of that stock (otherwise no messages sent)
        - If `@USER` agrees, then transaction completes immediately (assuming within `<DURATION>` and have available stock)
- Put ("Sell" contract)
    - You agree to sell stock to another corporation/channel at a set upon price at a certain time
    - `HFSS PUT <@USER/#CHANNEL> :EMOJI: <COUNT> AT <PRICE> (WITHIN <DURATION>)`
    - You immediately set aside that amount of stock upon initiating the put
    - `#CHANNEL` or `@USER` sees a message from HFSS if initiating player has enough stock
        - When the first `@USER(S)` / If `@USER` chooses to agree, then complete the transation (assuming within `<DURATION>` and have available funds)
- Issue Stock
    - You agree to sell stock in an emoji you own to everyone in the server at a price you set, ADDING NEW stock to the market
    - `HFSS ISSUE <COUNT> AT <PRICE> (WITHIN <DURATION>)`
    - Server sees a message from HFSS, and anyone may buy any amount of that stock at that price from you until they are gone
- Buy-Back Stock
    - You agree to buy stock in an emoji you own from anyone in the server at a price you set, REMOVING stock from the market
    - `HFSS BUYBACK <COUNT> AT <PRICE> (WITHIN <DURATION>)`
    - Server sees a message from HFSS, and anyone may sell any amount of that stock at that price to you until they are gone
        - You MUST have enough money in the bank to carry out the full buyback when command is sent, and that amount is set aside
- Manufacture Emoji
    - You can choose to produce any emoji you want! Also how many, how frequently, and for how long!
    - `HFSS MANUFACTURE { <AMOUNT> :EMOJI: , <AMOUNT> :EMOJI: , ... } (EVERY <DURATION>) (FOR <DURATION>)`
        - Defaults to a one-time purchase
        - If unable to manufacture emoji in future due to insufficient funds, then emoji will not be made, but manufacture process will contine until expired
    - The COST of the emoji you manufacture will go down if you invest in your emoji production!
- Invest In Emoji Research
    - You can choose to spend your money to make a particular emoji cheaper for you to manufacture!
    - Price of investment increases exponentially, but cost decreases logarithmically
- Set Message/Reaction Emoji Price
    - Can set separate prices for message vs reaction emoji, or a single price for both
- Borrow Money From Bank
    - You can borrow from the "bank", but all loans must be paid back within a week of borrowing, payments made daily
    - `HFSS BORROW <AMOUNT>`
    - Look into adding ways to collatoralize loans? So that you can't borrow more than you actually have (at the moment) to pay back?
- Loan Money To Another
    - You can loan money to another corporation directly, setting the terms of your loan yourself
    - `HFSS LOAN @USER <AMOUNT> AT <INTEREST_RATE>% (FOR <DURATION>)`
    - `@USER` sees a message from HFSS if initiating corporation has enough money (otherwise no message sent)
        - You immediately set aside that amount of money upon initiating loan request
        - Might be worried about spamming other players? Naaaaah
- Buy Emoji From Another
    - In order to use an emoji in a message / reaction, a corporation must buy that emoji.
    - If a corporation doesn't have enough StonkBux to buy that emoji, they go bankrupt!
    - Corporations use their inventory FIRST instead of buying from another corporation on the fly. No upkeep!
- Sell Emoji To Another
    - You can sell any excess inventory you may have lying around
    - Can sell to corporations directly (for messages/reactions, they use their own inventory FIRST before buying from a corporation on the fly!)
    - IF NONE OF THAT EMOJI EXIST IN ANY CORPORATION'S INVENTORY, THEN THAT EMOJI IS FREE

## Intellectual Property Rights

- If someone creates a new emoji, they have a ONE WEEK MONOPOLY on that new emoji's manufacture!
- And maybe a free level of "corporate research"?

## Bankruptcy

- After anyone goes bankrupt (a corporation OR bot), they will start over with a small loan (same start for everyone)
- A counter indicating how many times they've gone bankrupt will also increment, and be visible to everyone
    - HFSS will note this number whenever it @mentions a @USER

## Corporations

- Number of bankruptcies
- Stonk account
- Savings account
- Emoji account
- Loan balances
- Emoji production settings
- Emoji message/reaction prices

- Corporations ARE users!
- Can issue any amount of shares in their company at any time at any price (doesn't mean anyone will buy them)
- Can attempt to buy back any amount of shares at any price at any time (doesn't mean anyone will sell them)
- How do corporations make profits?
    - Users automatically buy emoji when they use them in a message or reaction.
        - Will always choose cheapest seller
        - NOTE: Only UNIQUE emoji need be purchased per message (spamming in a single message won't break the bank)
    - Manufactured emoji stick around as capital
        - Can sell them off, either at a loss directly to bank (~50% current manufacturing cost) or DIRECTLY to another corporation
    - Make money through all NON-EMOJI characters they type
- What are the costs associated with running an emoji corporation?
    - Each emoji manufactured costs an amount to produce
        - Can reduce this cost with "Corporate Research" (logarithmic decrease in price)
    - Emoji inventory costs an amount to keep around (disincentivized from just hoarding emoji)
    - Must issue dividends every week, as percentage of profits

## Bots

- They do not own corporations, but will be buying/selling stonks/emoji.
