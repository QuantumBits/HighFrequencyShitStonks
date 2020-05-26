module HighFrequencyShitStonks

import Base.String

using HTTP, Discord, JSON, DataFrames, Dates, CSV, Plots

const MAX_MSG_LENGTH = 2000

const EMOJI = Dict()

const EMOJI_REGEX = r"<a?:(?:\w+):(?:\d+)>"

const SETTINGS = JSON.parsefile(joinpath(@__DIR__,"..","config","discord.json"))

function setup()

    # Get emoji codes
    emoji_codes = Array{String}.(split.(String.(split(String(read("data/emoji-test.txt")),"\n"))," "))
    
    # Get emoji characters and links to images
    for emoji_code in emoji_codes

        emoji =  String(reduce(*, Char.(parse.(Int, emoji_code, base=16))))

        emoji_img_url = "https://raw.githubusercontent.com/twitter/twemoji/master/assets/72x72/$(lowercase(join(emoji_code,"-"))).png"

        EMOJI[emoji] = emoji_img_url

    end


    # Initialize GR Plots backend
    gr()

    # Start Client
    c = Client(SETTINGS["TOKEN"])

    # Get Guild Emoji
    emojis_guild = fetchval(list_guild_emojis(c, parse(Int, SETTINGS["GUILD_ID"])))

    for e in emojis_guild
        EMOJI[String(e)] = "https://cdn.discordapp.com/emojis/$(e.id).png"
    end

    # Add commands
    add_command!(c, :volume, (c, m, msg) -> volume(c, m, parse_emoji(msg)); pattern=r"^(?i)hfss volume\s+(.*)")
    add_command!(c, :echo,   (c, m, msg) ->   echo(c, m, parse_emoji(msg)); pattern=r"^(?i)hfss echo\s+(.*)")

    update_status(c, 0, Activity(;name = "Shitstonks", type = AT_GAME), "", true)

    open(c)

    return c

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

    for k in emoji_candidates
        if haskey(EMOJI, k)
            push!(emojis, k)
        end
    end

    return emojis

end

function echo(c::Client, m::Message, msg::Vector{AbstractString})

    reply(c, m, "ECHO: $(join(msg, " "))\nEmojis in list: $([ haskey(EMOJI, e) for e in msg ])")
    @debug "ECHO test:\n$(join(msg, " "))"

end

"""
    volume
"""
function volume(c::Client, m::Message, emoji::Vector{AbstractString})


    temp_png = joinpath("data", "temp.png")
    @debug "Temporary png file location:\n$temp_png"

    png(plot(rand(10), label=emoji), temp_png)

    @debug "Temporary file exists?:$(isfile(temp_png))"

    img_url = upload2imgur(temp_png)
    @debug "imgur URL: $img_url"

    rm(temp_png)
    @debug "Removing temporary file"

    msg = Embed(;
        title = "Volume $(join(emoji," "))",
        description = "Link(s) to $(join(emoji," ")) image: $([ EMOJI[e] for e in emoji])",
        image = EmbedImage(;url = img_url))

    reply(c, m, msg);
    @debug "Replying with Embed:\n$msg"
end

function buy(c::Client, m::Message, e::AbstractString, n::Float64)

end

function sell(c::Client, m::Message, e::AbstractString, n::Float64)

end

function upload2imgur(filename::AbstractString)

    req = HTTP.request("POST", "https://api.imgur.com/3/image", ["Authorization" => "Client-ID $(SETTINGS["IMGUR_CLIENT_ID"])"], read(filename))

    req_json = JSON.parse(String(req.body))

    return req_json["data"]["link"]

end

Base.String(e::Discord.Emoji) = "<$(e.animated ? "a" : "")$(e.require_colons || e.animated ? ":" : "")$(e.name):$(Int(e.id))>"
mention(id::Int) = "<@$id>"

end
