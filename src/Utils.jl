module Utils

using Discord, Dates

const EMOJI_REGEX = r"<a?:(?:\w+):(?:\d+)>"

function clean_emoji_string(e::AbstractString)::AbstractString
    # If this is not a custom Discord emoji
    if match(Utils.EMOJI_REGEX, e) === nothing
        # Remove variation selectors
        return filter(ei -> Base.Unicode.category_code(Char(ei)) != Base.Unicode.UTF8PROC_CATEGORY_MN, e)
    else
        return e
    end
end
clean_emoji_string(e::Discord.Emoji)::AbstractString = clean_emoji_string(Discord.string(e))


end