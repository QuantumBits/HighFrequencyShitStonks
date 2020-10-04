module HFSS

using HTTP, Discord, JSON
using JuliaDB, DataFrames, CSV, SQLite
using Dates, Plots, FileIO
using ColorTypes, FixedPointNumbers, DelimitedFiles, Printf

const EmojiImageArray = Array{ColorTypes.RGBA{FixedPointNumbers.Normed{UInt8,8}},2}

const MAX_MSG_LENGTH = 2000

const SETTINGS_FILENAME = joinpath(@__DIR__,"..","config","discord.json")
const SETTINGS = JSON.parsefile(SETTINGS_FILENAME)

include("Constants.jl")
include("Utils.jl")
include("DB.jl")
include("Economy.jl")

using .Constants, .Utils, .DB, .Economy

function setup(;epoch::DateTime=now(UTC)-Day(0), reset::Bool=false)

    # Start Client
    c = Client(HFSS.SETTINGS["TOKEN"])

    # Connect to database and create tables (if they don't exist)
    default_guilds = Discord.Guild[]
    for guild_ID in HFSS.SETTINGS["DEFAULT_GUILD_IDS"]
        push!(default_guilds, fetchval(Discord.get_guild(c, guild_ID)))
    end
    db = HFSS.DB.create(c, default_guilds; reset=reset)
 
    # Load stuff
    HFSS.DB.load_humans(c, db)
    HFSS.DB.load_emojis(c, db)
    # HFSS.DB.load_reacts(c, db, epoch)

    #= Handle Events =#

    @debug "Order? $(Constants.call)"

    add_handler!(c, MessageReactionAdd, (c, e) -> handle_reaction_add(c, e, db))

    #= Admin commands =#

    add_command!(c, :portfolio,
        (c, m) -> portfolio(c, m, db);
        pattern=r"^(?i)hfss portfolio$",
        allowed=[Discord.Snowflake(HFSS.SETTINGS["HFSS_ADMIN_ID"])])

    add_command!(c, :echo,
        (c, m, msg) -> echo(c, m, msg);
        pattern=r"^(?i)hfss echo\s([\s\S]*)",
        allowed=[Discord.Snowflake(HFSS.SETTINGS["HFSS_ADMIN_ID"])])

    add_command!(c, :epoch,
        (c, m) -> DB.set_channel_epoch(m, db);
        pattern=r"^(?i)hfss epoch$",
        allowed=[Discord.Snowflake(HFSS.SETTINGS["HFSS_ADMIN_ID"])])

    #= Update HFSS Status =#
    update_status(c, 0, Activity(;name = "Shitstonks", type = AT_GAME), "", true)

    open(c)

    return c

end

function handle_reaction_add(c::Client, e::MessageReactionAdd, db::SQLite.DB)
    # Create a market order to buy one stonk
    # price is based on:
    # - lowest available market sell order
    # - if no available market sell orders, then base on price of last filled order for that emoji
    # - if no orders available at all for that emoji, then emoji is free!

    # Query Stonk Price
    stonk_price = HFSS.Economy.StonkBux(1.0) #! For now assume static price

    # Stonk Count
    stonk_count = 1.0

    # Duration
    duration = Dates.Second(0)

    # Timestamp
    timestamp = fetchval(Discord.get_channel_message(c, e.channel_id, e.message_id)).timestamp
    
    @debug "About to make a '$(Constants.call)' type order ($(typeof(Constants.call)))"
    @debug "User ID $(e.user_id) reacted to message ID $(e.message_id) in channel ID $(e.channel_id) in guild ID $(e.guild_id) with emoji $(e.emoji)"
    @debug "Emoji image: $(DB.get_emojis(db, Utils.clean_emoji_string(e.emoji))[1].img)"

    # Create Stonk Order
    HFSS.Economy.stonk_order(db, Discord.Snowflake(e.user_id), Utils.clean_emoji_string(e.emoji), Constants.call, stonk_count, stonk_price, duration, timestamp)

end

# https://docs.juliaplots.org/latest/generated/plotly/#plotly-ref23-1
# TODO: Update this to display an actual portfolio
function portfolio(c::Client, m::Message, db::SQLite.DB)

    N = 32
    account = DataFrame(Emoji=rand(column(DB.get_emojis_all(db), :emoji), N), Volume=ceil.(10.0.^rand(0:6,N).*rand(N)), Price=10.0.^rand(0:9,N).*rand(N))

    account[:Value] = account[:Price] .* account[:Volume]

    sort!(account, :Value; rev=true)

    account = account[1:min(size(account, 1), N), :]
    summary = [@sprintf("`%16d × %16.2f = %17.2f` %s",r[:Volume], r[:Price], r[:Value], r[:Emoji]) for r in eachrow(account)]

    msg = Discord.Embed(;
        title = "$(m.author.username)'s Portfolio",
        description = join(summary, '\n'))

    Discord.create_message(c, m.channel_id; embed=msg)
    @debug "Replying with Embed:\n$msg"

end

function echo(c::Client, m::Message, msg::AbstractString)

    @debug "ECHO test:\n$msg"
    @debug "ECHO test:\n$(parse_emoji(msg))"
    reply(c, m, "ECHO: $msg")

end

#= DEPRECATED FUNCTIONS =# # TODO: UPDATE THEM

function parse_emoji(msg::AbstractString)

    emojis = AbstractString[]

    while occursin(EMOJI_REGEX, msg)
        e = String(match(EMOJI_REGEX, msg).match)
        push!(emojis, e)
        msg = replace(msg, e => "")
    end
    @debug "Emojis so far: $emojis"

    emoji_candidates = String.(split(msg, " "; keepempty=false))
    @debug "Emoji Candidates: $emoji_candidates"
    @debug "Emoji CodePoints: $(codepoint.(Char.(emoji_candidates)))"

    for k in emoji_candidates
        if haskey(EMOJI, k)
            push!(emojis, k)
        end
    end

    return emojis

end

function load_prices()::DataFrame

    DataFrame(emoji = AbstractString[], price=Float64[], timestamp=DateTime[])
    return DataFrame(CSV.File(HFSS.PRICES_DB))

end

function store_prices(df::DataFrame)

    CSV.write(PRICES_DB, df)

end

function read_prices(c::Client, m::Message, msg::AbstractString)

    Discord.reply(c, m, msg)

end

function stonks_manual(c::Client, m::Message, msg::AbstractString)

    Discord.reply(c, m, "!stonks $msg")

end

function read_ticker(c::Client, m::Message, msg::AbstractString)

    if m.author.id == Discord.Snowflake(SETTINGS["STONKS_BOT_ID"])
        Discord.reply(c, m, "Hey! No infinite loops!")
        return
    end

    Discord.reply(c, m, "This is the read_ticker() function\n$msg"; at=true)

end

function handle_at_me(c::Client, m::Message, msg::AbstractString)

    if m.author.id == Discord.Snowflake(SETTINGS["STONKS_BOT_ID"])
        Discord.reply(c, m, "Hey! No infinite loops!")
        return
    end

    Discord.reply(c, m, msg; at=true)

end


end
