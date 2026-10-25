function set_random_symbol
    begin; random $argv[1] && random; end > /dev/null
    set -l EMOJIS 🦍 🫎 💣 🩸 🚀 🛸 🎲 🧅 🍿 🧙 🍄 🦋 🐛 🥀 🌼 🌻 🌵 💀 💩 🧠 👃 💪 👴 🐨 🐯 🐷 🐪 🦇 🦔 🐧 🦆 🦢 🦉 🦤 🐲 🐙 🪲 🐞 🦟 🪰 🪱 🦠 🍀 🌳 🍊 🍉 🍇 🍅 🥔 🥒 🥬 🥦 🌚 🌝 🌞 🪐 🪬 🗿 ⭐ 🐢
    set -U EMOJI (random choice $EMOJIS)
    set -U EMOJI_DATE $argv[1]
end
