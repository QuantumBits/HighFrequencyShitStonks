module Economy

using ..Constants
using ..DB

using Discord, JuliaDB, SQLite
import Discord: Snowflake, Emoji

using Dates

#= STONKBUX =#

StonkBux = Float64

#= EMOJIS =#

#TODO: Replace with SQLite DB
# List of each emoji being produced by each corporation
const MemesOfProduction = table((
    corp_ID     =   Snowflake[],    # Corporation ID
    emoji       =       Emoji[],    # Discord Emoji type
    count       =        UInt[],    # Number of emoji to produce (whole numbers only)
    interval    =      Period[],    # How often to produce
    duration    =      Period[],    # How long to produce
))

#TODO: Replace with SQLite DB
# List of each emoji being sold by each corporation
const EmojiMarket = table((
    corp_ID     =   Snowflake[],    # Corporation ID
    emoji       =       Emoji[],    # Discord Emoji type
    price       =    StonkBux[],    # Price of emoji
))

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

"""
    Create a stonk market order
"""
function stonk_order(db::SQLite.DB, corp_ID::Snowflake, stonk_ID::AbstractString, order::Order, count::Real, price::StonkBux, duration::Period, timestamp::DateTime)

    expiration = timestamp + duration

    DBInterface.execute(db, """
        INSERT INTO $(DB.ORDERS_TABLE) (corp_ID, stonk_ID, order_type, count, price, expiration, timestamp, open)
        VALUES
        ($corp_ID, '$stonk_ID', '$order', $count, $price, '$expiration', '$timestamp', 1)
    """)

end

end