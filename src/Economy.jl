module Economy

using Discord, JuliaDB, CSV

using Dates

using .Emoji, .Corporation

abstract type STONK_ORDER end
abstract type CALL    <: STONK_ORDER end # Issue a contract to buy stonk
abstract type PUT     <: STONK_ORDER end # Issue a contract to sell stonk
abstract type ISSUE   <: STONK_ORDER end # Issue new stonk in a Corporation
abstract type BUYBACK <: STONK_ORDER end # Issue a contract to buy back stonk in a Corporation

#! Stonks can be Corporations OR Emoji!
#! Corporations can only issue stonk in themselves, not Emoji
#! Corporations can still manufacture Emoji as usual (think of like a commodities market)

# List of Stonk market orders
const STONK_MARKET = table((
    CORP_ID   =           UInt[],   # ID of Corporation initiating order
    STONK_ID  =           UInt[],   # ID of Stonk involved in order
    ORDER     =    STONK_ORDER[],   # Order type
    COUNT     =        Float64[],   # Number of stonk involved in order
    PRICE     =        Float64[],   # Price of stonk involved in order
    DURATION  =   Dates.Period[],   # Duration that order is active
    TIMESTAMP = Dates.DateTime[],   # Time order was initiated
    FILLED    =           Bool[]    # Boolean indicating whether this order is filled
))

# List of Stonk market order fulfillments
const STONK_MARKET_FILLED = table((
    ACTION_ID    =           UInt[],    # Primary Key of order in STONK_MARKET
    FILLER_ID    =           UInt[],    # ID of Corporation that filled this order
    FILLER_COUNT =        Float64[],    # Number of stonk involed in filling this order
    TIMESTAMP    = Dates.DateTime[]     # Time order was filled
))

# Summary of Stonk ownership
const STONKS = table((
    CORP_ID  =    UInt[],   # ID of Corporation
    STONK_ID =    UInt[],   # ID of Corporation in which CORP_ID is buying stonk
    COUNT    = Float64[],   # Number of stonk in STONK_ID that CORP_ID owns
))

# List of loans owned by each corporation
const LOANS = table((
    CORP_ID = UInt[],                   # ID of Corporation that took out loan
    LENDER_ID = UInt[],                 # ID of Corporation (or bank) that lent out loan
    PRINCIPLE = Float64[],              # Original principle amount of loan
    PRINCIPLE_REMAINING = Float64[],    # Principle remaining on loan
    INTEREST_REMAINING = Float64[],     # Interest remaining on loan
    INTEREST_RATE = Float64[],          # Interest rate of loan
    TERM = Dates.Period[],              # Term length of loan
    TIMESTAMP = DateTime[],             # Time loan was lent
    ACTIVE = Bool[]                     # Boolean indicating whether this loan has been paid back
))

# List of StonkBux transactions by each corporation
const TRANSACTIONS = table((
    CORP_ID_FROM = UInt[],          # ID of originating Coropration
    CORP_ID_TO  = UInt[],           # ID of destination Corporation
    AMOUNT = Float64[],             # Amount of transaction (positive)
    TIMESTAMP = Dates.DateTime[],   # Time transaction occurred
    DESCRIPTION = AbstractString[]  # Description of transaction
))

# List of each emoji being produced by each corporation
const MEMES_OF_PRODUCTION = table()

# List of each emoji being sold by each corporation
const PRICES = table()

"""
    Make a call on a corporation's stonk
"""
function call(caller_ID, corp_ID, count, price, duration)
    push!(Economy.EMOJI_MARKET, (corp_ID, :CALL, caller_ID, count, price, duration, now(), true))
end

"""
    Make a put on a corporation's stonk
"""
function put(putter_ID, corp_ID, count, price, duration)
    push!(Economy.EMOJI_MARKET, (corp_ID, :PUT, putter_ID, count, price, duration, now(), true))
end

"""
    Issue stonks in a corporation
"""
function issue(corp_ID, count, price, duration)
    push!(Economy.EMOJI_MARKET, (corp_ID, :ISSUE, :GLOBAL, count, price, duration, now(), true))
end

"""
    Buy-back stonks in a corporation
"""
function buyback(corp_ID, count, price, duration)
    push!(Economy.EMOJI_MARKET, (corp_ID, :BUYBACK, :GLOBAL, count, price, duration, now(), true))
end

"""
    Set emoji production
"""
function produce(corp_ID, emojis, counts, interval, duration)
    for emoji in emojis

    end
end

end