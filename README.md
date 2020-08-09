# High-Frequency Shit-Stonks (HFSS)

Currently assume distinction between player/corporation, for simplicity perhaps combine into JUST the corporation

## The Stonk Market

- Keeps track of ALL transactions (completed or not)
- Determine the current price of a stock based on most recent completed calls and puts
    - If not enough info, then stock value is "0"

## Loans

- Bank's interest rate set is constant
    - #! IN FUTURE, make this set by "Chairman of the Fed" - a democratically elected position?

## Bots

- #! IN FUTURE, will be like players but make random decisions on what to put / call
- They do not own corporations, but will likely go bankrupt often and will act as a "source" of capital in this economy

## Players

- Number of bankruptcies
- Stock acount
- Savings account
- Loan balances
- Emoji account

## Player Actions

- Call ("Buy" contract)
    - You agree to buy stock from another player/channel at set upon price at a certain time
    - `HFSS CALL <@USER/#CHANNEL> :EMOJI: <COUNT> AT <PRICE> (WITHIN <DURATION>)`
    - #CHANNEL sees a message from HFSS if initiating player has enough money
        - You immediately set aside that amount of money upon initiating the call
        - The first @USER(S) to agree then complete the transation (assuming within <DURATION> and have available stock)
            - Allow for partial fulfullment of contract, up to amount requested
    - @USER sees a message from HFSS if the initiating player has enough money and @USER has enough of that stock (otherwise no messages sent)
        - You immediately set aside that amount of money upon initiating the call
        - If @USER agrees, then transaction completes immediately (assuming within <DURATION> and have available stock)
- Put ("Sell" contract)
    - You agree to sell stock to another player/channel at a set upon price
    - `HFSS PUT <@USER/#CHANNEL> :EMOJI: <COUNT> AT <PRICE> (WITHIN <DURATION>)`
    - #CHANNEL sees a message from HFSS if initiating player has enough stock
        - You immeidately set aside that amount of stock upon initiating the put
        - The first @USER(S) to agree then complete the transation (assuming within <DURATION> and have available funds)
    - @USER sees a message from HFSS if initiating player has enough stock (otherwise no messages sent)
        - You immediately set aside that amount of stock upon initiating the put
        - If @USER agrees, then transation completes immediately (assuming within <DURATION> and have available funds)


## Corporate Actions

- Issue Stock
    - You agree to sell stock in an emoji you own to everyone in the server at a price you set, ADDING NEW stock to the market
    - `HFSS ISSUE :EMOJI: <COUNT> AT <PRICE> (WITHIN <DURATION>)`
    - Server sees a message from HFSS, and anyone may buy any amount of that stock at that price from you until they are gone
- Buy-Back Stock
    - You agree to buy stock in an emoji you own from anyone in the server at a price you set, REMOVING stock from the market
    - `HFSS BUYBACK :EMOJI: <COUNT> AT <PRICE> (WITHIN <DURATION>)`
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
- Set Message/Reaction Emoji Price

## Corporate AND Player Actions

- Borrow Money From Bank
    - You can borrow from the "bank", but all loans must be paid back within a week of borrowing, payments made daily
    - `HFSS BORROW <AMOUNT>
    - Look into adding ways to collatoralize loans? So that you can't borrow more than you actually have (at the moment) to pay back?
- Loan Money To Another
    - You can loan money to another player directly, setting the terms of your loan yourself
    - `HFSS LOAN @USER <AMOUNT> AT <INTEREST_RATE>% (FOR <DURATION>)`
    - @USER sees a message from HFSS if initiating player has enough money (otherwise no message sent)
        - You immediately set aside that amount of money upon initiating loan request
        - Might be worried about spamming other players? Naaaaah
- Buy Emoji From Another
- Sell Emoji To Another
    - You can sell any excess inventory you may have lying around
    - Can sell to corporations or players directly (players use their direct-from-the-seller inventory FIRST instead of buying from a corporation on the fly. No upkeep!)
    - #! CAN SET PRICE OF THESE EMOJI, AND LOWEST AVAILABLE PRICE WILL BE TAKEN WHEN SOMEONE USES AN EMOJI
    - #! IF NONE OF THAT EMOJI EXIST IN ANY CORPORATION'S INVENTORY, THEN THAT EMOJI IS FREE

## Intellectual Property Rights

- If someone creates a new emoji, they have a ONE WEEK MONOPOLY on that new emoji's manufacture!

## Bankruptcy

- After anyone goes bankrupt (a player OR bot), they will start over with a small loan (same start for everyone)
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

- Corporations are TECHNICALLY separate from users, but the user is de-facto CEO
    - Separate accounts, though the user can freely move money back and forth to save one or the other from bankruptcy
    - #! IN THE FUTURE, want to allow SHAREHOLDERS to vote on CEO, who is only one allowed to do "Corporate Actions" as above.
    - #! CEO gets a "salary" that's a fraction of the corporation's REVENUE (regardless of profit)
    - #! Means CEO can't just move money back-and-forth between personal and corporate accounts (aww)
- Can issue any amount of shares in their company at any time at any price (doesn't mean anyone will buy them)
- Can attempt to buy back any amount of shares at any price at any time (doesn't mean anyone will sell them)
- How do corporations make profits?
    - Users automatically buy emoji when they use them in a message or reaction.
        - Will always choose cheapest seller
        - NOTE: Only UNIQUE emoji need be purchased per message (spamming in a single message won't break the bank)
    - Manufactured emoji stick around as capital
        - Can sell them off, either at a loss directly to bank (~50% current manufacturing cost) or DIRECTLY to another corporation or player
- What are the costs associated with running an emoji corporation?
    - Each emoji manufactured costs an amount to produce
        - Can reduce this cost with "Corporate Research" (logarithmic decrease in price)
    - Emoji inventory costs an amount to keep around (disincentivized from just hoarding emoji)
    - Must issue dividends every week, if any profits

## Game Loop

- Automatic Actions
    - Every day make loan payments on all outstanding loans
        - If cannot make loan payments, go "bankrupt" and start again with a new starter loan at current Fed Interest Rate and zero debt
    - Every week, corporations post a "weekly review" detailing financial performance (revenue, costs, profit, dividends, etc)
    - Every time anyone uses an emoji, they automatically buy the cheapest available emoji from all corporations that have that emoji in stock
    - Recurring emoji production occurs at frequency set by corporation
- Intentional Actions
    - Put/Call stonks (players/corporations)
    - Issue/Buyback stonks (corporations)
    - Buy/Sell emoji (players/corporations)
    - Lend/borrow (players/corporations)
    - Research emoji (corporations)
    - Manufature emoji (corporations)
    - Set emoji price (corporations)