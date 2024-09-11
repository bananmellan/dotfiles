function set_random_symbol
    random $argv[1] && random > /dev/null
    set -l EMOJIS 🦍 🫎 💣 🩸 🚀 🛸 🎲 🧅 🍿 🧙 🍄 🦋 🐛 🥀 🌼 🌻 🌵 💀 💩 🧠 👃 💪 👴 🐨 🐯 🐷 🐪 🦇 🦔 🐧 🦆 🦢 🦉 🦤 🐲 🐙 🪲 🐞 🦟 🪰 🪱 🦠 🍀 🌳 🍊 🍉 🍇 🍅 🥔 🥒 🥬 🥦 🌚 🌝 🌞 🪐 ⭐ 🪬 🗿
    set -U EMOJI (random choice $EMOJIS)
    set -U EMOJI_DATE $argv[1]
end
