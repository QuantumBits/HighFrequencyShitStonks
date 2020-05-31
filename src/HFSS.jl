module HFSS

import Base.String

using HTTP, Discord, JSON, DataFrames, CSV, Dates, Plots, FileIO, ORCA, Cairo, Rsvg, Gadfly, Formatting
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

Base.String(e::Discord.Emoji) = "<$(e.animated ? "a" : "")$(e.require_colons || e.animated ? ":" : "")$(e.name):$(Int(e.id))>"

function setup()

    EMOJI = read_emoji_standard(HFSS.EMOJI, download(EMOJI_URL))

    try
        PRICES = load_prices()
    catch e
    end

    # Initialize Plotly Plots backend
    gr()

    # Start Client
    c = Client(SETTINGS["TOKEN"])

    # Get Guild Emoji
    emojis_guild = fetchval(list_guild_emojis(c, Discord.Snowflake(SETTINGS["GUILD_ID"])))

    for e in emojis_guild
        EMOJI[String(e)] = "https://cdn.discordapp.com/emojis/$(e.id).png"
    end

    #= Admin commands =#

    add_command!(c, :pie,
        (c, m, msg) -> plot_pie(c, m, parse_emoji(msg));
        pattern=r"^(?i)hfss account\s+(.*)",
        allowed=[Discord.Snowflake(SETTINGS["HFSS_ADMIN_ID"])])

    add_command!(c, :volume,
        (c, m, msg) -> volume(c, m, parse_emoji(msg));
        pattern=r"^(?i)hfss volume\s+(.*)",
        allowed=[Discord.Snowflake(SETTINGS["HFSS_ADMIN_ID"])])

    add_command!(c, :portfolio,
        (c, m) -> portfolio(c, m);
        pattern=r"^(?i)hfss portfolio$",
        allowed=[Discord.Snowflake(SETTINGS["HFSS_ADMIN_ID"])])

    add_command!(c, :hfss_echo,
        (c, m, msg) ->   echo(c, m, msg);
        pattern=r"^(?i)hfss echo\s+([\s\S]*)",
        allowed=[Discord.Snowflake(SETTINGS["HFSS_ADMIN_ID"])])

    add_command!(c, :ticker,
        (c,m) -> tickerALLTheThings(c,m) ;
        pattern=r"^(?i)hfss ticker ALL THE THINGS$",
        allowed=[Discord.Snowflake(SETTINGS["HFSS_ADMIN_ID"])])

    add_command!(c, :read_prices,
        (c,m,msg) -> read_prices(c, m, parse_emoji(msg));
        pattern=r"^(?i)hfss read (.*)",
        allowed=[Discord.Snowflake(SETTINGS["HFSS_ADMIN_ID"])])

    add_command!(c, :stonks_manual,
        (c,m,msg) -> stonks_manual(c, m, msg);
        pattern=r"^(?i)hfss stonks (.*)",
        allowed=[Discord.Snowflake(SETTINGS["HFSS_ADMIN_ID"])])

    #= Shitstonks commands =#
    add_command!(c, :at_me,
        (c,m,post_msg) -> handle_at_me(c, m, post_msg);
        pattern=Regex("^<@$(SETTINGS["HFSS_BOT_ID"])>([\\s\\S]*)"))


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

function read_prices(c::Client, m::Message, emoji::Vector{AbstractString})

    for e in emoji
        Discord.reply(c, m, e)
    end

end

function stonks_manual(c::Client, m::Message, msg::AbstractString)

    Discord.reply(c, m, "!stonks $msg")

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

function tickerALLTheThings(c::Client, m::Message)

    chunks = split_message(join(keys(EMOJI), " "))

    for chunk in chunks
        reply(c, m, "!stonks ticker $chunk)")
    end

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

    N = 100
    account = DataFrame(Emoji=rand(keys(HFSS.EMOJI), N), Volume=10.0.^rand(0:6,N).*rand(N), Price=10.0.^rand(0:9,N).*rand(N))

    account[:Value] = account[:Price] .* account[:Volume]

    sort!(account, :Value; rev=true)
    N_bar = 10
    p_bar = Plots.bar(account[1:N_bar, :Value], 
        xticks = (1:N_bar, account[1:N_bar, :Emoji]),
        legend = false);
    
    sort!(account, :Volume; rev=true)
    p_pie = Plots.pie(account[:Emoji], account[:Volume],
        legend = false)

    p = Plots.plot(p_bar, p_pie)

    Plots.png(p, temp_png)
    @debug "Temporary png file exists?:$(isfile(temp_png))"

    Plots.svg(p, temp_svg)
    @debug "Temporary svg file exists?:$(isfile(temp_svg))"


    account = account[1:min(size(account, 1), 20), :]
    summary = [@sprintf("`%1.15E × %1.15E = %1.15E`%s",r[:Volume], r[:Price], r[:Value], r[:Emoji]) for r in eachrow(account)]

    msg = Embed(;
        title = "$(m.author.username)'s Portfolio",
        description = join(summary, '\n'),
        url = "https://svgshare.com/i/LdU.svg")

    Discord.create_message(c, m.channel_id; embed=msg, file=open(temp_png))
    @debug "Replying with Embed:\n$msg"
    @debug "Replying with File:\n$temp_svg"

    # reply(c, m, msg);


end


# https://docs.juliaplots.org/latest/generated/plotly/#plotly-ref23-1
function plot_pie(c::Client, m::Message, emoji::Vector{AbstractString})

    temp_png = joinpath("data", "temp_pie.png")
    @debug "Temporary png file location:\n$temp_png"

    account = DataFrame(CSV.File("data/george_data.csv"))

    account[:Value] = account[:Price] .* account[:Volume]

    sort!(account, :Value; rev=true)

    account = account[1:min(size(account, 1), 20), :]

    p = pie(account[:Emoji], account[:Volume], title = "$(m.author.username)'s Portfolio")

    Plots.png(p, temp_png)

    @debug "Temporary file exists?:$(isfile(temp_png))"

    img_url = upload2imgur(temp_png)
    @debug "imgur URL: $img_url"

    # rm(temp_png)
    @debug "Removing temporary file"

    summary = ["$(r[:Emoji]) : `$(@sprintf("%8.0f @ \$%16.2f = \$%16.2f", r[:Volume], r[:Price], r[:Value]))`" for r in eachrow(account)]

    msg = Embed(;
    title = "$(m.author.username)'s Portfolio",
    description = join(summary, '\n'),
        image = EmbedImage(;url = img_url))

    reply(c, m, msg);
    @debug "Replying with Embed:\n$msg"


end

# https://docs.juliaplots.org/latest/generated/plotly/#plotly-ref36-1
function plot_portfolio(c::Client, m::Message, emoji::Vector{AbstractString})

    temp_png = joinpath("data", "temp_portfolio.png")
    @debug "Temporary png file location:\n$temp_png"

    p = portfoliocomposition(rand(10, length(emoji)), rand(10, length(emoji)), labels=permutedims(emoji));

    png(p, temp_png)

    @debug "Temporary file exists?:$(isfile(temp_png))"

    img_url = upload2imgur(temp_png)
    @debug "imgur URL: $img_url"

    rm(temp_png)
    @debug "Removing temporary file"

    msg = Embed(;
        title = "Portfolio Composition: $(join(emoji," "))",
        description = "Link(s) to $(join(emoji," ")) image: $([ EMOJI[e] for e in emoji])",
        image = EmbedImage(;url = img_url))

    reply(c, m, msg);
    @debug "Replying with Embed:\n$msg"

end

function volume(c::Client, m::Message, emoji::Vector{AbstractString})

    @debug "Emoji going into volume():\n$emoji"


    temp_png = joinpath("data", "temp_volume.png")
    @debug "Temporary png file location:\n$temp_png"

    p = plot(rand(10, length(emoji)), label=permutedims(emoji)); # , legend=false);

    i = 0.0
    j = 0.0

    for e in emoji
        e_img = FileIO.load(download(EMOJI[e]))
        @debug "Emoji name : $e"
        @debug "Emoji image: $(EMOJI[e])"
        @debug "Emoji type : $(typeof(e_img))"
        p = put_emoji_on_plot(p, EmojiImageArray(e_img), i, j, 2.0);
        i += 1
        i > 9 ? (i -= 10; j += 1) : nothing
    end

    Plots.png(p, temp_png)

    @debug "Temporary file exists?:$(isfile(temp_png))"

    img_url = upload2imgur(temp_png)
    @debug "imgur URL: $img_url"

    # rm(temp_png)
    @debug "Removing temporary file"

    msg = Embed(;
        title = "Volume $(join(emoji," "))",
        description = "Link(s) to $(join(emoji," ")) image: $([ EMOJI[e] for e in emoji])",
        image = EmbedImage(;url = img_url))

    reply(c, m, msg);
    @debug "Replying with Embed:\n$msg"
end

#= UTILITIES =#

function put_emoji_on_plot(p::Plots.Plot, emoji::EmojiImageArray, x_pos::Float64, y_pos::Float64, scale::Float64; aspect_ratio=1.0)

    (dx, dy) = size(emoji)

    return plot!(p,
            range(x_pos,x_pos+scale*(dx/dy);length=dx),
            range(y_pos,y_pos+scale;length=dy),
            emoji[end:-1:1, :], yflip = false, aspect_ratio=aspect_ratio)

end


end
