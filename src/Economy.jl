module Economy

using Discord, JuliaDB, CSV

using Dates

using .Emoji, .Corporation

StonkBux = Float64

#= STONKBUX =#

# List of loans owned by each corporation
const StonkBuxLoans = table((
    corp_ID             =   Snowflake[],    # ID of Corporation that took out loan
    lender_ID           =   Snowflake[],    # ID of Corporation (or bank) that lent out loan
    principle           =    StonkBux[],    # Original principle amount of loan
    interest_rate       =     Float64[],    # Interest rate of loan (5% = 0.05)
    term                =      Period[],    # Term length of loan
    timestamp           =    DateTime[],    # Time loan was lent
    is_outstanding      =        Bool[]     # Boolean indicating whether this loan has been paid back
))

# List of StonkBux transactions by each corporation
const StonkBuxTransactions = table((
    corp_ID_from =       Snowflake[],   # ID of originating Corporation
    corp_ID_to   =       Snowflake[],   # ID of destination Corporation
    amount       =        StonkBux[],   # Amount of transaction (positive)
    timestamp    =        DateTime[],   # Time transaction occurred
    description  =  AbstractString[]    # Description of transaction
))

"""
    Add a StonkBux loan
"""
function add_stonkbux_load(corp_ID:::Snowflake, lender_ID:::Snowflake, principle:::StonkBux, interest_rate:::Float64, term:::Period, timestamp:::DateTime, is_outstanding:::Bool)
    push!(Economy.StonkBuxLoans, (corp_ID, lender_ID, principle, interest_rate, term, timestamp, is_outstanding))
end

"""
    Add a StonkBux transaction
"""
function add_stonkbux_transaction(corp_ID_from::Snowflake, corp_ID_to::Snowflake, amount::StonkBux, timestamp::DateTime, description::AbstractString)
    push!(Economy.StonkBuxAccount, (corp_ID_from, corp_ID_to, amount, timestamp, description))
end

#= EMOJIS =#

# List of each emoji being produced by each corporation
const MemesOfProduction = table((
    corp_ID     =   Snowflake[],    # Corporation ID
    emoji       =       Emoji[],    # Discord Emoji type
    count       =        UInt[],    # Number of emoji to produce (whole numbers only)
    interval    =      Period[],    # How often to produce
    duration    =      Period[],    # How long to produce
))

# List of each emoji being sold by each corporation
const EmojiMarket = table((
    corp_ID     =   Snowflake[],    # Corporation ID
    emoji       =       Emoji[],    # Discord Emoji type
    price       =    StonkBux[],    # Price of emoji
))

"""
    Set emoji production
"""
function produce_emoji(corp_ID::Snowflake, emoji::Emoji, count::UInt, interval::Period, duration::Period)
    push!(MemesOfProduction, (corp_ID, emoji, count, interval, duration))
end

"""
    Set price to sell emoji
"""
function price_emoji(corp_ID::Snowflake, emoji::Emoji, price::StonkBux)
    push!(EmojiMarket, (corp_ID, emoji, price))
end

#= STONKS =#

# EMOJI SOURCE : corporations "manufacturing" them over time + the "open market"
# EMOJI SINK   : corporations using them in messages / reactions + the "open market"

# The "Black Market" will buy emoji from corporations at a very low price
# and sell to corporations at a very high price
# - buys emoji at 0.5x price for corporation to manufacture
# - sells emoji at 2x price for corporation to manufacture
# - can only be interacted with via message/reactions. You cannot buy/sell directly.

# - Stonks can be Corporations OR Emoji?
# - Corporations can only issue stonk in themselves, not Emoji
# - Corporations can still manufacture Emoji as usual (think of like a commodities market)
# - Corporations must buy an emoji before they can use it. If no corporation has any of that emoji in stock,
#   then corporations must buy emoji from the "open market" and pay the current market rate (based on most recent trades)
# - If corporations don't have enough cash to buy a message/reaction emoji, then they automatically take out a loan to do it
#

@enum Order call put issue buyback

StonkID = Union{Emoji, Snowflake}

# List of Stonk market orders
const StonkMarketOrders = table((
    corp_ID      =  Snowflake[],    # ID of Corporation initiating order
    stonk_ID     =    StonkID[],    # ID of stonk involved in order (Emoji / Corporation)
    order        =      Order[],    # Order type
    count        =    Float64[],    # Number of stonk involved in order
    price        =   StonkBux[],    # Price of stonk involved in order
    duration     =     Period[],    # Duration that order is active
    timestamp    =   DateTime[],    # Time order was initiated
    is_filled    =       Bool[],    # Boolean indicating whether this order is filled
))

# List of completed Stonk market transactions
const FilledStonkMarketOrders = table((
    order_ID     =       UInt[],    # Primary Key of order in STONK_MARKET
    filler_ID    =  Snowflake[],    # ID of Corporation that filled this order
    count        =    Float64[],    # Number of stonk involed in filling this order
    timestamp    =   DateTime[],    # Time order was filled
))

# List of Stonk account transactions
const StonkAccountTransactions = table((
    corp_ID     =   Snowflake[],    # Corporation ID
    stonk_ID    =     StonkID[],    # Stonk ID
    count       =     Float64[],    # Number of stonk added/subtracted
))

"""
    Create a stonk market order
"""
function stonk_order(corp_ID::Snowflake, stonk_ID::StonkID, order::Order, count::Float64, price::StonkBux, duration::Period)
    push!(Economy.StonkMarketOrders, (corp_ID, stonk_ID, order, count, price, duration, now(), true))
end

"""
    Fill a stonk market order (even if only partially)
"""
function fill_stonk_order(order_ID::UInt, filler_ID::Snowflake, count::Float64)
   push!(Economy.FilledStonkMarketOrders, (order_ID, filler_ID, count, now()))
end

"""
    Add a Stonk Account Transaction
"""
function add_stonkaccount_transaction(corp_ID::Snowflake, stonk_ID::StonkID, count::Float64)
    push!(Economy.StonkAccountTransactions, (corp_ID, stonk_ID, count))
end

end