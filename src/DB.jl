module DB

using ..Constants
using ..Utils
using Dates, DelimitedFiles
using SQLite, Discord, JuliaDB

export get_emojis

const DB_PATH = joinpath(@__DIR__,"..","data","hfss.sqlite")

const TWEMOJI_STANDARD_URL = "https://unicode.org/Public/emoji/13.0/emoji-test.txt"
const TWEMOJI_IMG_URL = "https://raw.githubusercontent.com/twitter/twemoji/master/assets/72x72/"
const DISCORD_IMG_URL = "https://cdn.discordapp.com/emojis/"

const GUILDS_TABLE = "GUILDS"
const CHANNELS_TABLE = "CHANNELS"
const HUMANS_TABLE  = "HUMANS"
const EMOJIS_TABLE = "EMOJIS"
const PRICES_TABLE = "PRICES"
const EPOCHS_TABLE = "EPOCHS"
const REACTS_TABLE = "REACTS"

const ORDERS_TYPE_TABLE = "OrderType"
const ORDERS_TABLE = "ORDERS" # List of open Stonk Market orders
const FILLED_TABLE = "FILLED" # List of filled Stonk Market orders


function create(c::Discord.Client, default_guilds::Vector{Discord.Guild}; reset::Bool=false)::SQLite.DB

    # Connect to database
    db = SQLite.DB(DB.DB_PATH)

    # List of guilds
    reset ? DBInterface.execute(db, "DROP TABLE IF EXISTS $(DB.GUILDS_TABLE);") : nothing
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS $(DB.GUILDS_TABLE) (
            id INTEGER PRIMARY KEY,
            name TEXT
    );""")
    for guild in default_guilds
        DBInterface.execute(db, "INSERT OR IGNORE INTO $(DB.GUILDS_TABLE) (id, name) VALUES ($(guild.id), '$(guild.name)')")
    end

    # List of channels
    reset ? DBInterface.execute(db, "DROP TABLE IF EXISTS $(DB.CHANNELS_TABLE);") : nothing
    DBInterface.execute(db, """
    CREATE TABLE IF NOT EXISTS $(DB.CHANNELS_TABLE) (
        id INTEGER PRIMARY KEY,
        name TEXT
        );""")

    # Insert all channels in default guild
    for guild in default_guilds
        SQL_VALUES = AbstractString[]
        # Iterate each guild text channel
        for channel in filter(c -> c.type == CT_GUILD_TEXT, fetchval(Discord.get_guild_channels(c, guild.id)))
            push!(SQL_VALUES, "($(channel.id),'$(channel.name)')")
        end
        DBInterface.execute(db, "INSERT OR IGNORE INTO $(DB.CHANNELS_TABLE) (id, name) VALUES $(join(SQL_VALUES, ","))")
    end

    # List of humans
    reset ? DBInterface.execute(db, "DROP TABLE IF EXISTS $(DB.HUMANS_TABLE);") : nothing
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS $(DB.HUMANS_TABLE) (
            id INTEGER PRIMARY KEY,
            username TEXT
    );""")

    # List of channels
    reset ? DBInterface.execute(db, "DROP TABLE IF EXISTS $(DB.HUMANS_TABLE);") : nothing
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS $(DB.HUMANS_TABLE) (
            id INTEGER PRIMARY KEY,
            username TEXT
    );""")

    # List of emojis and their image locations
    reset ? DBInterface.execute(db, "DROP TABLE IF EXISTS $(DB.EMOJIS_TABLE);") : nothing
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS $(DB.EMOJIS_TABLE) (
            emoji TEXT PRIMARY KEY,
            img TEXT
    );""")

    # List of emoji reactions by humans
    reset ? DBInterface.execute(db, "DROP TABLE IF EXISTS $(DB.REACTS_TABLE);") : nothing
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS $(DB.REACTS_TABLE) (
            timestamp TEXT,
            corp_ID INTEGER,
            stonk_ID TEXT,
            channel_ID INTEGER,
            message_ID INTEGER,
            FOREIGN KEY (corp_ID) REFERENCES $(DB.HUMANS_TABLE) (id),
            FOREIGN KEY (stonk_ID) REFERENCES $(DB.EMOJIS_TABLE) (emoji),
            PRIMARY KEY (timestamp, corp_ID, stonk_ID, channel_ID, message_ID)
    );""")

    #= STONK MARKET DBs =#

    # Static table for order types
    reset ? DBInterface.execute(db, "DROP TABLE IF EXISTS $(DB.ORDERS_TYPE_TABLE);") : nothing
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS $(DB.ORDERS_TYPE_TABLE) (
            name TEXT PRIMARY KEY
        )
    ;""")
    DBInterface.execute(db, "INSERT OR IGNORE INTO $(DB.ORDERS_TYPE_TABLE) (name) VALUES $(join(["('$order')" for order in instances(Order)],","))")

    # List of open orders
    reset ? DBInterface.execute(db, "DROP TABLE IF EXISTS $(DB.ORDERS_TABLE);") : nothing
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS $(DB.ORDERS_TABLE) (
            corp_ID INTEGER,
            stonk_ID TEXT,
            order_type TEXT,    -- call, put, issue, buyback
            count REAL,
            price REAL,
            expiration TEXT,    -- DateTime when order expires
            timestamp TEXT,     -- DateTime when order created
            FOREIGN KEY (corp_ID) REFERENCES $(DB.HUMANS_TABLE) (id),
            FOREIGN KEY (stonk_ID) REFERENCES $(DB.EMOJIS_TABLE) (emoji)
            FOREIGN KEY (order_type) REFERENCES $(DB.ORDERS_TYPE_TABLE) (name)
    );""")

    return db

end

#= GUILDS =#

function get_guilds(db::SQLite.DB)
    return table(DBInterface.execute(db, "SELECT * FROM $(DB.GUILDS_TABLE)"))
end

#= CHANNELS =#

function get_channels(db::SQLite.DB)
    return table(DBInterface.execute(db, "SELECT * FROM $(DB.CHANNELS_TABLE)"))
end

#= HUMANS =#

function load_humans(c::Discord.Client, db::SQLite.DB)

    for guild in DB.get_guilds(db)

        # Get guild member IDs
        # TODO: update this to allow for >1000 if this ever takes off
        members = fetchval(Discord.list_guild_members(c, guild.id; limit=1000))

        # Filter out bots
        humans = filter(m -> ismissing(m.user.bot) || (!ismissing(m.user.bot) && !m.user.bot), members)

        # Compile into a SQL statement
        SQL_STMT_VALUES = join([ "($(h.user.id),'$(h.user.username)')" for h in humans ], ",")

        # Store in SQLite Database
        DBInterface.execute(db, "REPLACE INTO $(DB.HUMANS_TABLE) (id,username) VALUES $SQL_STMT_VALUES")

    end

end

#= EMOJIS =#

function emoji_img_url(e::Discord.Emoji)::AbstractString
    return "$(DB.DISCORD_IMG_URL)$(e.id).$(e.animated ? "gif" : "png")"
end
function emoji_img_url(e::AbstractString)::AbstractString
    img_code = lowercase(join(string.(UInt.([ Char(xi) for xi in e ]), base=16),"-"))
    return "$(DB.TWEMOJI_IMG_URL)$img_code.png"
end

function load_emojis(c::Discord.Client, db::SQLite.DB)

    # Create table
    emoji_standard_filename = download(DB.TWEMOJI_STANDARD_URL)

    emoji_dict = Dict{AbstractString,AbstractString}()

    emojis = readdlm(emoji_standard_filename,';', AbstractString, comments=true, comment_char='#')

    codepoints = [ split(codepoint[1]," "; keepempty=false)
        for codepoint in filter(e -> e[2] == "fully-qualified",
            [ strip.((emojis[i, 1], emojis[i, 2]))
                for i = 1:size(emojis, 1) ]) ]

    # Get emoji characters and links to images
    SQL_STMT_VALUES = AbstractString[]
    for emoji_code in codepoints
        emoji = Utils.emoji_string(String(reduce(*, Char.(parse.(Int, emoji_code, base=16)))))
        emoji_img_url = DB.emoji_img_url(emoji)
       append!(SQL_STMT_VALUES, ["('$emoji','$emoji_img_url')"])

    end

    DBInterface.execute(db, "REPLACE INTO $(DB.EMOJIS_TABLE) (emoji, img) VALUES $(join(SQL_STMT_VALUES, ","))")

    for guild in DB.get_guilds(db)

        SQL_STMT_VALUES = AbstractString[]

        # Get Guild emojis
        guild_emojis = fetchval(list_guild_emojis(c, guild.id))

        for e in guild_emojis
            emoji = Utils.emoji_string(e)
            emoji_img_url = DB.emoji_img_url(e)
            append!(SQL_STMT_VALUES, ["('$emoji','$emoji_img_url')"])
        end

        # Store in SQLite Database
        DBInterface.execute(db, "REPLACE INTO $(DB.EMOJIS_TABLE) (emoji, img) VALUES $(join(SQL_STMT_VALUES, ","))")

    end

end

function check_discord_emoji(db::SQLite.DB, e::Discord.Emoji)
    # If emoji is a proper discord emoji
    if Utils.is_discord_emoji(e)
        # If emoji is not in the EMOJIS table
        if length(table(DBInterface.execute(db, "SELECT * FROM $(DB.EMOJIS_TABLE) WHERE emoji = '$(Utils.emoji_string(e))'"))) == 0
            # Add emoji to EMOJIS table
            DBInterface.execute(db, "INSERT OR IGNORE INTO $(DB.EMOJIS_TABLE) (emoji, img) VALUES ('$(Utils.emoji_string(e))','$(emoji_img_url(e))')")
        end
    end
end

function get_emojis(db::SQLite.DB, emojis::Vector{T})::IndexedTable where {T <: AbstractString}
    return table(DBInterface.execute(db, "SELECT * FROM $(DB.EMOJIS_TABLE) WHERE emoji IN ('$(join(emojis,"','"))') "))
end
function get_emoji(db::SQLite.DB, emoji::T)::IndexedTable where {T <: AbstractString}
    return table(DBInterface.execute(db, "SELECT * FROM $(DB.EMOJIS_TABLE) WHERE emoji = '$emoji'"))
end

function get_emojis(db::SQLite.DB, emojis::Vector{Discord.Emoji})::IndexedTable
    return get_emojis(db, Utils.emoji_string.(emojis))
end
function get_emoji(db::SQLite.DB, emoji::Discord.Emoji)::IndexedTable
    try
        return get_emoji(db, Utils.emoji_string(emoji))
    catch e
        check_discord_emoji(db, emoji)
        return get_emoji(db, Utils.emoji_string(emoji))
    end
end

function get_emojis_all(db::SQLite.DB)::IndexedTable
    return table(DBInterface.execute(db, "SELECT * FROM $(DB.EMOJIS_TABLE)"))
end

#= REACTS =#

"""
    Get latest message reactions for each channel
"""
function get_latest_reacts(db::SQLite.DB)
    return table(DBInterface.execute(db, "SELECT DISTINCT max(timestamp), channel_ID, message_ID FROM $(DB.REACTS_TABLE) GROUP BY channel_ID"))
end

function load_reacts(c::Discord.Client, db::SQLite.DB, epoch::DateTime)

    function get_SQL_values(c::Discord.Client, channel_id::Discord.Snowflake, epoch::DateTime)::Vector{AbstractString}

        # Initialize SQL statement values
        SQL_VALUES = AbstractString[]

        # Get first batch of channel messages
        # NOTE: *last* message in list is *oldest* message in channel (until sorted later)
        channel_msgs = fetchval(Discord.get_channel_messages(c, channel_id; limit=100))

        if !isnothing(channel_msgs)

            while length(channel_msgs) > 0

                for msg in channel_msgs
                    if msg.timestamp < epoch
                        return SQL_VALUES
                    else
                        if !ismissing(msg.reactions)
                            for r in msg.reactions
                                users = Discord.fetchval(Discord.get_reactions(c, channel_id, msg.id, replace(Utils.emoji_string(r.emoji), r"<|>" => "")))
                                if users !== nothing
                                    for u in users
                                        push!(SQL_VALUES, "('$(msg.timestamp)', $(u.id), '$(Utils.emoji_string(r.emoji))',$(channel_id),$(msg.id))")
                                    end
                                end
                            end
                        end
                    end
                end

                channel_msgs = fetchval(Discord.get_channel_messages(c, channel_id; before=channel_msgs[end].id, limit=100))

            end

        end

        return SQL_VALUES
    end

    for channel in DB.get_channels(db)

        SQL_VALUES = get_SQL_values(c, Discord.Snowflake(channel.id), epoch)
        @debug "Number of reactions for channel : $(channel.name) : $(!isnothing(SQL_VALUES) ? length(SQL_VALUES) : "N/A")"

        if !isempty(SQL_VALUES)
            DBInterface.execute(db, "INSERT OR IGNORE INTO $(DB.REACTS_TABLE) (timestamp, corp_ID, stonk_ID, channel_ID, message_ID) VALUES $(join(SQL_VALUES, ","))")
        end


    end

end

end
