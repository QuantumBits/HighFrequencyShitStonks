module HFSS

#=

    * Global Properties

    - Loan Interest Rate (2%-ish)
    - Number of issued emoji stock

    * Bots

    - For now, they are like players but they make random decisions on what to put / call

    * Players

    - Basic actions
        - Call ("Buy" contract)
            - You agree to buy stock from another player at set upon price at a certain time
            - `HFSS CALL <@USER/#CHANNEL> :EMOJI: <COUNT> AT <PRICE> (WITHIN <DURATION>)`
            - #CHANNEL sees a message from HFSS if initiating player has enough money
                - You immediately set aside that amount of money upon initiating the call
                - The first @USER(S) to agree then complete the transation (assuming within <DURATION> and have available stock)
                    - Allow for partial fulfullment of contract, up to amount requested
            - @USER sees a message from HFSS if the initiating player has enough money and @USER has enough of that stock (otherwise no messages sent)
                - You immediately set aside that amount of money upon initiating the call
                - If @USER agrees, then transaction completes immediately (assuming within <DURATION> and have available stock)
        - Put ("Sell" contract)
            - You agree to sell stock to another player at a set upon price
            - `HFSS PUT <@USER/#CHANNEL> :EMOJI: <COUNT> AT <PRICE> (WITHIN <DURATION>)`
            - #CHANNEL sees a message from HFSS if initiating player has enough stock
                - You immeidately set aside that amount of stock upon initiating the put
                - The first @USER(S) to agree then complete the transation (assuming within <DURATION> and have available funds)
            - @USER sees a message from HFSS if initiating player has enough stock (otherwise no messages sent)
                - You immediately set aside that amount of stock upon initiating the put
                - If @USER agrees, then transation completes immediately (assuming within <DURATION> and have available funds)
        - Issue Stock
            - You agree to sell stock in an emoji you own to everyone in the server at a price you set, ADDING NEW stock to the market
        - Stock Buy-Back
            - You agree to buy stock in an emoji you own from anyone in the server at a price you set, REMOVING stock from the market

    - Stock counts
    - Savings account balance
    - Loan balances, with individual interest rates
    - Number of times gone bankrupt (has no effect on game mechanics)
    - Emoji "Corporations" they "own"
        - This is based on who created the emoji!
        - Can issue stock for the emoji (including to themselves)
            - People can buy these stock from the original player at whatever price they want
            - Share profits, but increase overall profitability of company (less likely to post losses)

    * Corporations

    - One per custom emoji (default emoji are owned by bots!)
    - Can issue any amount of shares at any time at any price
        - Doesn't mean anyone will buy them
    - Can attempt to buy back any amount of shares at any price at any time
        - Doesn't mean anyone will sell them
    - Each emoji "corporation" ()



    * Game Loop

    - Everyday, players make automated loan payments, paying off highest interest rate loans first
    - If players cannot make loan payments, they "go bankrupt" and start again with a new loan at current Fed Interest Rate
    - Every week, each publicly-traded emoji posts a "quarterly review", detailing how they did overall
    - Each time someone uses an emoji, they pay a (small) amount of "BitStonks" that factors into the revenue of the "emoji" corp
    - Each week, a random percentage of a corporation's revenue will become "operating costs", and the net amount will be deemed "profits"
        - 

=#

import Base: string

using HTTP, Discord, JSON, DataFrames, CSV, Dates, Plots, FileIO
using ColorTypes, FixedPointNumbers, DelimitedFiles, Printf

const MAX_MSG_LENGTH = 2000
const SETTINGS_FILENAME = joinpath(@__DIR__,"..","config","discord.json")
const PRICES_FILENAME = joinpath(@__DIR__,"..","data","prices.csv")
const EMOJI_URL = "https://unicode.org/Public/emoji/13.0/emoji-test.txt"
const EMOJI_REGEX = r"<a?:(?:\w+):(?:\d+)>"
const EmojiImageArray = Array{ColorTypes.RGBA{FixedPointNumbers.Normed{UInt8,8}},2}

const EMOJI = Dict{AbstractString,AbstractString}()

const SETTINGS = JSON.parsefile(SETTINGS_FILENAME)

const PRICES = DataFrame(emoji = AbstractString[], price=Float64[], timestamp=DateTime[])

string(e::Discord.Emoji) = "<$(e.animated ? "a" : "")$(e.require_colons || e.animated ? ":" : "")$(e.name):$(Int(e.id))>"

function setup()

    EMOJI = read_emoji_standard(HFSS.EMOJI, download(EMOJI_URL))

    try
        PRICES = load_prices()
    catch e
    end

    # Initialize Plotly Plots backend
    # Only one that seems to work with emoji 13.0.0
    plotly()

    # Start Client
    c = Client(SETTINGS["TOKEN"])

    # Get Guild Emoji
    emojis_guild = fetchval(list_guild_emojis(c, Discord.Snowflake(SETTINGS["GUILD_ID"])))

    for e in emojis_guild
        EMOJI[String(e)] = "https://cdn.discordapp.com/emojis/$(e.id).png"
    end

    #= Admin commands =#

    add_command!(c, :portfolio,
        (c, m) -> portfolio(c, m);
        pattern=r"^(?i)hfss portfolio$",
        allowed=[Discord.Snowflake(SETTINGS["HFSS_ADMIN_ID"])])

    add_command!(c, :hfss_echo,
        (c, m, msg) -> echo(c, m, msg);
        pattern=r"^(?i)hfss echo\s([\s\S]*)",
        allowed=[Discord.Snowflake(SETTINGS["HFSS_ADMIN_ID"])])

    add_command!(c, :read_prices,
        (c,m,msg) -> read_prices(c, m, msg);
        pattern=r"^(?i)hfss read (.*)$",
        allowed=[Discord.Snowflake(SETTINGS["HFSS_ADMIN_ID"])])

    add_command!(c, :stonks_manual,
        (c,m,msg) -> stonks_manual(c, m, msg);
        pattern=r"^(?i)hfss stonks (.*)$",
        allowed=[Discord.Snowflake(SETTINGS["HFSS_ADMIN_ID"])])

    #= Shitstonks commands =#
    add_command!(c, :read_ticker,
    (c,m,msg) -> read_ticker(c, m, msg);
    pattern=Regex("^<@$(SETTINGS["HFSS_BOT_ID"])>([\\s\\S]*)"))

    # add_command!(c, :at_me,
    #     (c,m,msg) -> handle_at_me(c, m, msg);
    #     pattern=Regex("^<@$(SETTINGS["HFSS_BOT_ID"])>([\\s\\S]*)"))

    #= Update HFSS Status =#
    update_status(c, 0, Activity(;name = "Shitstonks", type = AT_GAME), "", true)

    open(c)

    return c

end

function load_prices()

    return DataFrame(CSV.File(PRICES_FILENAME))

end

function store_prices(df::DataFrame)

    CSV.write(PRICES_FILENAME, df)

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

function read_emoji_standard(emoji_dict::Dict{AbstractString, AbstractString}, emoji_standard_filename::AbstractString)

    emojis = readdlm(emoji_standard_filename,';', AbstractString, comments=true, comment_char='#')

    demojis = DataFrame(CodePoints = split.(emojis[:, 1]," "; keepempty=false), Qualifier = strip.(emojis[:, 2]))

    codepoints = Array{String}.(demojis[ demojis[:Qualifier] .== "fully-qualified", :CodePoints])

    # Get emoji characters and links to images
    for emoji_code in codepoints

        emoji =  String(reduce(*, Char.(parse.(Int, emoji_code, base=16))))

        emoji_img_url = "https://raw.githubusercontent.com/twitter/twemoji/master/assets/72x72/$(lowercase(join(emoji_code,"-"))).png"

        emoji_dict[emoji] = emoji_img_url

    end

    return emoji_dict

end

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

function echo(c::Client, m::Message, msg::AbstractString)

    @debug "ECHO test:\n$msg"
    @debug "ECHO test:\n$(parse_emoji(msg))"
    reply(c, m, "ECHO: $msg")

end

# https://docs.juliaplots.org/latest/generated/plotly/#plotly-ref23-1
function portfolio(c::Client, m::Message)

    temp_png = joinpath("data", "portfolio_$(m.author.username)_$(m.author.id).png")
    @debug "Temporary png file location:\n$temp_png"

    temp_svg = joinpath("data", "portfolio_$(m.author.username)_$(m.author.id).svg")
    @debug "Temporary svg file location:\n$temp_svg"

    N = 20
    account = DataFrame(Emoji=rand(keys(HFSS.EMOJI), N), Volume=ceil.(10.0.^rand(0:6,N).*rand(N)), Price=10.0.^rand(0:9,N).*rand(N))

    account[:Value] = account[:Price] .* account[:Volume]

    sort!(account, :Value; rev=true)
    N_bar = 10
    p_bar = Plots.bar(account[1:N_bar, :Value],
        xticks = (1:N_bar, account[1:N_bar, :Emoji]),
        legend = false);

    sort!(account, :Volume; rev=true)
    p_pie_annotations = []

    v_accum = 0.0
    v_total = sum(account[:Volume])

    for i = 1:size(account, 1)

        δvol_i = 0.5 * account[i, :Volume] / v_total

        if δvol_i > 0.01
            θi = 2 * pi * (δvol_i + v_accum)

            push!(p_pie_annotations, (0.5 * cos(θi), 0.5 * sin(θi), text(account[i, :Emoji])) )
        else
            break
        end

        v_accum += (account[i, :Volume] / v_total)

    end

    p_pie = Plots.pie(account[:Emoji], account[:Volume],
        annotations=p_pie_annotations,
        legend = false)

    p = Plots.plot(p_bar, p_pie)

    Plots.png(p, temp_png)
    @debug "Temporary png file exists?:$(isfile(temp_png))"

    Plots.svg(p, temp_svg)
    @debug "Temporary svg file exists?:$(isfile(temp_svg))"


    account = account[1:min(size(account, 1), 20), :]
    summary = [@sprintf("`%16d × %16.2f = %16.2f`%s",r[:Volume], r[:Price], r[:Value], r[:Emoji]) for r in eachrow(account)]

    msg = Embed(;
        title = "$(m.author.username)'s Portfolio",
        description = join(summary, '\n'),
        url = "https://svgshare.com/i/LdU.svg")

    Discord.create_message(c, m.channel_id; embed=msg, file=open(temp_png))
    @debug "Replying with Embed:\n$msg"
    @debug "Replying with File:\n$temp_svg"

end

end
