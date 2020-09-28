module DB

using ..Utils
using DelimitedFiles
using SQLite, Discord, JuliaDB

export get_emojis

const DB_PATH = joinpath(@__DIR__,"..","data","hfss.sqlite")

const TWEMOJI_STANDARD_URL = "https://unicode.org/Public/emoji/13.0/emoji-test.txt"
const TWEMOJI_IMG_URL = "https://raw.githubusercontent.com/twitter/twemoji/master/assets/72x72/"
const DISCORD_IMG_URL = "https://cdn.discordapp.com/emojis/"

const CORPS_TABLE  = "CORPS"
const EMOJIS_TABLE = "EMOJIS"
const PRICES_TABLE = "PRICES"
const EPOCHS_TABLE = "EPOCHS"
const REACTS_TABLE = "REACTS"

const ORDERS_TYPE_TABLE = "OrderType"
const ORDERS_TABLE = "ORDERS" # List of open Stonk Market orders
const FILLED_TABLE = "FILLED" # List of filled Stonk Market orders


function create()::SQLite.DB

    # Connect to database
    db = SQLite.DB(DB.DB_PATH)

    # List of users
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS $(DB.CORPS_TABLE) (
            id INTEGER PRIMARY KEY
    )""")

    # List of emojis and image location
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS $(DB.EMOJIS_TABLE) (
            emoji TEXT PRIMARY KEY,
            img TEXT
    )""")

    # List of emoji reactions by user
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS $(DB.REACTS_TABLE) (
            timestamp TEXT,
            corp_ID INTEGER,
            stonk_ID TEXT,
            FOREIGN KEY (corp_ID) REFERENCES $(DB.CORPS_TABLE) (id),
            FOREIGN KEY (stonk_ID) REFERENCES $(DB.EMOJIS_TABLE) (emoji)
    )""")

    # List of initial message IDs per channel
    # These messages represent the start of "history" for stonk prices
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS $(DB.EPOCHS_TABLE) (
            channel_ID INTEGER PRIMARY KEY,
            message_ID INTEGER
    )""")

    #= STONK MARKET DBs =#

    # Static table for order types
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS $(DB.ORDERS_TYPE_TABLE) (
            name TEXT PRIMARY KEY
        )
    """)
    DBInterface.execute(db, "INSERT OR IGNORE INTO $(DB.ORDERS_TYPE_TABLE) (name) VALUES ('call'), ('put'), ('issue'), ('buyback')")

    # List of open orders
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS $(DB.ORDERS_TABLE) (
            corp_ID INTEGER,
            stonk_ID TEXT,
            order_type TEXT,         -- call, put, issue, buyback
            count REAL,
            price REAL,
            expiration TEXT,    -- DateTime when order expires
            timestamp TEXT,     -- DateTime when order created
            FOREIGN KEY (corp_ID) REFERENCES $(DB.CORPS_TABLE) (id),
            FOREIGN KEY (stonk_ID) REFERENCES $(DB.EMOJIS_TABLE) (emoji)
            FOREIGN KEY (order_type) REFERENCES $(DB.ORDERS_TYPE_TABLE) (name)
    )""")

    return db

end

function load_emojis(db::SQLite.DB, emojis_guild::Vector{Discord.Emoji})

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
        emoji = Utils.clean_emoji_string(String(reduce(*, Char.(parse.(Int, emoji_code, base=16)))))
        img_code = lowercase(join(string.(UInt.([ Char(xi) for xi in emoji ]), base=16),"-"))
        emoji_img_url = "$(DB.TWEMOJI_IMG_URL)$img_code.png"
       append!(SQL_STMT_VALUES, ["('$emoji','$emoji_img_url')"])

    end
    for e in emojis_guild
        emoji = Utils.clean_emoji_string(e)
        emoji_img_url = "$(DB.DISCORD_IMG_URL)$(e.id).$(e.animated ? "gif" : "png")"
        append!(SQL_STMT_VALUES, ["('$emoji','$emoji_img_url')"])
    end
    DBInterface.execute(db, "INSERT OR IGNORE INTO $(DB.EMOJIS_TABLE) (emoji, img) VALUES $(join(SQL_STMT_VALUES, ","))")

end

function get_emojis(db::SQLite.DB, emojis::Vector{T})::IndexedTable where {T <: AbstractString}
    return table(DBInterface.execute(db, "SELECT * FROM $(DB.EMOJIS_TABLE) WHERE emoji IN ('$(join(emojis,"','"))') "))
end
function get_emojis(db::SQLite.DB, emoji::T)::IndexedTable where {T <: AbstractString}
    return get_emojis(db, Vector{T}([emoji]))
end

function get_all_emojis(db::SQLite.DB)::IndexedTable
    return table(DBInterface.execute(db, "SELECT * FROM $(DB.EMOJIS_TABLE)"))
end

#TODO: FIX THIS
"""
    Upon an admin command, set the epoch of a particular channel for determining stonk prices to that specific message
"""
function set_channel_epoch(c::Client, e::Discord.Message)

    try
        (e.channel_id, e.id)

        epoch_db = JuliaDB.load(HFSS.EPOCHS_DB)


        JuliaDB.save(epoch_db, HFSS.EPOCHS_DB)

    catch e
        @warn e.msg
    end



end

#TODO: have this reference the "epochs" database
function load_history(c::Discord.Client, db::SQLite.DB, channel_ID=Discord.Snowflake(149686433618067457), message_ID=Discord.Snowflake(754759564234063997))

    channel = fetchval(Discord.get_channel(c, channel_ID))

    SQL_VALUES = AbstractString[]

    for i = 1:2
        channel_msgs = fetchval(Discord.get_channel_messages(c, channel_ID; before=channel.last_message_id, limit=100))
        msg_0_ID = channel_msgs[end].id
        for msg in channel_msgs
            if !ismissing(msg.reactions)
                for r in msg.reactions
                    users = Discord.fetchval(Discord.get_reactions(c, channel_ID, msg.id, replace(Utils.clean_emoji_string(r.emoji), r"<|>" => "")))
                    if users !== nothing
                        for u in users
                            append!(SQL_VALUES, ["('$(msg.timestamp)', $(u.id), '$(Utils.clean_emoji_string(r.emoji))')"])
                        end
                    end
                end
            end
        end
    end

    DBInterface.execute(db, "INSERT OR IGNORE INTO $(DB.REACTS_TABLE) (timestamp, corp_ID, stonk_ID) VALUES $(join(SQL_VALUES, ","))")
end

end