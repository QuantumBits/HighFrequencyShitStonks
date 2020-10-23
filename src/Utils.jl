module Utils

using Discord, Dates, Plots, Images

const EMOJI_REGEX = r"<a?:(?:\w+):(?:\d+)>"

function emoji_string(e::AbstractString)::AbstractString
    # If this is not a custom Discord emoji
    if match(Utils.EMOJI_REGEX, e) === nothing
        # Remove variation selectors
        return filter(ei -> Base.Unicode.category_code(Char(ei)) != Base.Unicode.UTF8PROC_CATEGORY_MN, e)
    else
        return e
    end
end
emoji_string(e::Discord.Emoji)::AbstractString = emoji_string(Discord.string(e))

is_discord_emoji(e::Union{AbstractString,Discord.Emoji})::Bool = !isnothing(match(EMOJI_REGEX, emoji_string(e)))

function put_image_on_plot(p::Plots.Plot, img::Matrix, X::Float64, Y::Float64, MX::Float64, MY::Float64)

    (NX, NY) = size(img)

    return plot!(p,
        MX .* (1:NX)./NX .+ X .- (MX/2),
        MY .* (1:NY)./NY .+ Y .- (MY/2),
        img[end:-1:1, :], ratio=1, yflip=false)

end

end