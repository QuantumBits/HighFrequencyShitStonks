module HFSS

using HTTP, Discord, JSON
using JuliaDB, SQLite, Tables
using Dates, Plots, FileIO, Images
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

function setup(;epoch::DateTime=now(UTC)-Day(7), reset::Bool=false)

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
    HFSS.DB.load_reacts(c, db, epoch)

    #= Handle Events =#

    add_handler!(c, MessageReactionAdd, (c, e) -> handle_reaction_add(c, e, db))

    #= User Commands =#

    add_command!(c, :top,
        (c, m, N) -> top(c, m, parse(Int, N), db),
        pattern=r"^(?i)hfss top\s*(\d+)$")

    add_command!(c, :top_today,
        (c, m, N) -> top(c, m, parse(Int, N), db, now(UTC), Day(1)),
        pattern=r"^(?i)hfss top\s*(\d+)\s*today$")

    add_command!(c, :top_week,
        (c, m, N) -> top(c, m, parse(Int, N), db, now(UTC), Week(1)),
        pattern=r"^(?i)hfss top\s*(\d+)\s*week$")

    add_command!(c, :top_month,
        (c, m, N) -> top(c, m, parse(Int, N), db, now(UTC), Month(1)),
        pattern=r"^(?i)hfss top\s*(\d+)\s*month$")

    add_command!(c, :top_year,
        (c, m, N) -> top(c, m, parse(Int, N), db, now(UTC), Year(1)),
        pattern=r"^(?i)hfss top\s*(\d+)\s*year$")

    add_command!(c, :history,
        (c, m, e) -> history(c, m, e, db),
        pattern=r"^(?i)hfss history\s+(.+)$")

    #= Admin commands =#

    add_command!(c, :portfolio,
        (c, m) -> portfolio(c, m, db);
        pattern=r"^(?i)hfss portfolio$",
        allowed=[Discord.Snowflake(HFSS.SETTINGS["HFSS_ADMIN_ID"])])

    add_command!(c, :pie,
        (c, m, N) -> pie(c, m, parse(Int, N), db);
        pattern=r"^(?i)hfss pie\s*(\d+)$",
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
    # The cheapest available market sell order will be completed

    # Query Stonk Price
    stonk_price = HFSS.Economy.StonkBux(1.0) #! For now assume static price

    # Stonk Count
    stonk_count = 1.0

    # Duration
    duration = Dates.Second(0)

    # Timestamp
    timestamp = fetchval(Discord.get_channel_message(c, e.channel_id, e.message_id)).timestamp

    # Add Reaction
    HFSS.DB.add_reaction(db, e, timestamp)

    # Create Stonk Order
    HFSS.Economy.stonk_order(db, Discord.Snowflake(e.user_id), Utils.emoji_string(e.emoji), Constants.call, stonk_count, stonk_price, duration, timestamp)
    @debug "Making $(Constants.call) Order: User $(e.user_id) reacted to message $(e.message_id) in channel $(e.channel_id) in guild $(e.guild_id) with emoji $(e.emoji) [$(DB.get_emoji(db, e.emoji)[1].img)]"

end

function top(c::Client, m::Message, N::Int, db::SQLite.DB, epoch::DateTime, duration::Period)

    reacts = table(DBInterface.execute(db, "SELECT * FROM $(DB.REACTS_TABLE) WHERE timestamp BETWEEN '$(epoch-duration)' AND '$epoch'"))

    emoji_count = sort(filter(x -> x[2] > 0, [ (e, count(==(e), column(reacts,:stonk_ID))) for e in union(column(reacts,:stonk_ID)) ]); by = x -> x[2], rev=true)

    top_string = ""

    N = min(N, length(emoji_count))

    for i = 1:N
        top_string_i = "$i. $(emoji_count[i][1]) ($(emoji_count[i][2]))\n"
        if length(top_string) + length(top_string_i) > MAX_MSG_LENGTH
            N = i-1
            break
        else
            top_string = "$top_string$top_string_i"
        end
    end

    embed = Discord.Embed(;title=titlecase("Top $N Emoji For $duration"), description=top_string)

    Discord.create_message(c, m.channel_id; embed=embed)
end

function top(c::Client, m::Message, N::Int, db::SQLite.DB)

    member_id = m.author.id

    reacts = table(DBInterface.execute(db, "SELECT * FROM $(DB.REACTS_TABLE) WHERE corp_ID = $member_id"))

    emoji_count = sort(filter(x -> x[2] > 0, [ (e, count(==(e), column(reacts,:stonk_ID))) for e in union(column(reacts,:stonk_ID)) ]); by = x -> x[2], rev=true)

    top_string = ""

    N = min(N, length(emoji_count))

    for i = 1:N
        top_string_i = "$i. $(emoji_count[i][1]) ($(emoji_count[i][2]))\n"
        if length(top_string) + length(top_string_i) > MAX_MSG_LENGTH
            N = i-1
            break
        else
            top_string = "$top_string$top_string_i"
        end
    end

    embed = Discord.Embed(;title="$(m.author.username)'s Top $N Emoji", description=top_string)

    Discord.create_message(c, m.channel_id; embed=embed)

end

# https://docs.juliaplots.org/latest/generated/plotly/#plotly-ref23-1
# TODO: Update this to display an actual portfolio
function portfolio(c::Client, m::Message, db::SQLite.DB)

    N = 32

    account = table((
        emoji   = rand(column(DB.get_emojis_all(db), :emoji), N),
        volume  = ceil.(10.0.^rand(0:6,N).*rand(N)),
        price   = 10.0.^rand(0:9,N).*rand(N)
    ))

    sort!(account; by = r -> r.volume * r.price, rev=true)

    account_view = @view account[1:min(length(account), N), :]

    summary = [@sprintf("`%16d × %16.2f = %17.2f` %s",r.volume, r.price, r.volume * r.price, r.emoji) for r in eachrow(account_view)]

    msg = Discord.Embed(;
        title = "$(m.author.username)'s Portfolio",
        description = join(summary, '\n'))

    Discord.create_message(c, m.channel_id; embed=msg)
    @debug "Replying with Embed:\n$msg"

end

function history(c::Client, m::Message, e::AbstractString, db::SQLite.DB)

    emoji = HFSS.Utils.emoji_string(e)

    isemoji = length(DB.get_emoji(db, emoji)) > 0

    @info "testing emoji: $emoji"


    if isemoji

        reacts = sort(filter(r -> r.stonk_ID == emoji, DB.get_reacts(db)); by = r -> r.timestamp)

        png_file = tempname()

        gr()

        png(
            plot(DateTime.(column(reacts,:timestamp)), 1:length(reacts), label=nothing, legend=:topleft),
        png_file)

        Discord.create_message(c, m.channel_id; content="Found string: $e ($isemoji)", file=open("$png_file.png"))

    else

        Discord.create_message(c, m.channel_id; content="Input \"$e\" is not a singular, recognized emoji.")

    end


end

function echo(c::Client, m::Message, msg::AbstractString)

    @debug "ECHO test:\n$msg"
    @debug "ECHO test:\n$(parse_emoji(msg))"
    reply(c, m, "ECHO: $msg")

end

#= DEPRECATED FUNCTIONS =# # TODO: UPDATE THEM

#=

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

=#

end
