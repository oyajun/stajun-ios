import Foundation

// MARK: - Emoji Category

enum EmojiCategory: String, CaseIterable, Identifiable {
    case smileys
    case animals
    case food
    case activities
    case travel
    case objects
    case symbols

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smileys: return "Smileys & People"
        case .animals: return "Animals & Nature"
        case .food: return "Food & Drink"
        case .activities: return "Activity"
        case .travel: return "Travel & Places"
        case .objects: return "Objects"
        case .symbols: return "Symbols"
        }
    }

    var symbol: String {
        switch self {
        case .smileys: return "😀"
        case .animals: return "🐻"
        case .food: return "🍔"
        case .activities: return "⚽️"
        case .travel: return "🚗"
        case .objects: return "💡"
        case .symbols: return "🔣"
        }
    }

    var systemImage: String {
        switch self {
        case .smileys: return "face.smiling"
        case .animals: return "pawprint.fill"
        case .food: return "fork.knife"
        case .activities: return "figure.run"
        case .travel: return "car.fill"
        case .objects: return "lightbulb.fill"
        case .symbols: return "number"
        }
    }
}

// MARK: - Emoji Item

struct EmojiItem: Identifiable, Hashable {
    var id: String { emoji }
    let emoji: String
    let category: EmojiCategory
    let keywords: String
}

// MARK: - Emoji Catalog

enum EmojiCatalog {

    // MARK: - Emojis by Category

    static let smileys: [String] = [
        "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "🫠", "😉", "😊", "😇",
        "🥰", "😍", "🤩", "😘", "😗", "😚", "😙", "🥲", "😋", "😛", "😜", "🤪", "😝", "🤑",
        "🤗", "🤭", "🫢", "🫣", "🤫", "🤔", "🫡", "🤐", "🤨", "😐", "😑", "😶", "🫥", "😏",
        "😒", "🙄", "😬", "🤥", "🫨", "😌", "😔", "😪", "🤤", "😴", "😷", "🤒", "🤕", "🤢",
        "🤮", "🤧", "🥵", "🥶", "🥴", "😵", "😵‍💫", "🤯", "🤠", "🥳", "🥸", "😎", "🤓", "🧐",
        "😕", "🫤", "😟", "🙁", "☹️", "😮", "😯", "😲", "😳", "🥺", "🥹", "😦", "😧", "😨",
        "😰", "😥", "😢", "😭", "😱", "😖", "😣", "😞", "😓", "😩", "😫", "🥱", "😤", "😡",
        "😠", "🤬", "😈", "👿", "💀", "☠️", "💩", "🤡", "👹", "👺", "👻", "👽", "👾", "🤖",
        "😺", "😸", "😹", "😻", "😼", "😽", "🙀", "😿", "😾", "🙈", "🙉", "🙊", "💋", "❤️‍🔥",
        "❤️‍🩹", "💬", "👁️‍🗨️", "🗨️", "🗯️", "💭", "👋", "🤚", "🖐️", "✋", "🖖", "🫱", "🫲", "🫸",
        "🫷", "👌", "🤌", "🤏", "✌️", "🤞", "🫰", "🤟", "🤘", "🤙", "👈", "👉", "👆", "🖕",
        "👇", "☝️", "🫵", "👍", "👎", "✊", "👊", "🤛", "🤜", "👏", "🙌", "🫶", "👐", "🤲",
        "🤝", "🙏", "✍️", "💅", "🤳", "💪", "🦾", "🦿", "🦵", "🦶", "👂", "🦻", "👃", "🫀",
        "🫁", "🧠", "🦷", "👀", "👁️", "👅", "👄", "🫦", "👶", "🧒", "👦", "👧", "🧑", "👱",
        "👨", "🧔", "👨‍🦰", "👨‍🦱", "👨‍🦳", "👨‍🦲", "👩", "👱‍♀️", "👩‍🦰", "👩‍🦱", "👩‍🦳", "👩‍🦲", "🧓", "👴",
        "👵", "🙍", "🙎", "🙅", "🙆", "💁", "🙋", "🧏", "🙇", "🤦", "🤷", "🧑‍⚕️", "🧑‍🎓", "🧑‍🏫",
        "🧑‍⚖️", "🧑‍🌾", "🧑‍🍳", "🧑‍🔧", "🧑‍🏭", "🧑‍💼", "🧑‍🔬", "🧑‍💻", "🧑‍🎤", "🧑‍🎨", "🧑‍✈️", "🧑‍🚀", "🧑‍🚒", "👮",
        "🕵️", "💂", "🥷", "👷", "🤴", "👸", "👳", "👲", "🧕", "🤵", "👰", "🤰", "🫃", "🫄",
        "🤱", "👼", "🎅", "🤶", "🧑‍🎄", "🦸", "🦹", "🧙", "🧚", "🧛", "🧜", "🧝", "🧞", "🧟",
        "🧌", "💆", "💇", "🚶", "🧍", "🧎", "🏃", "💃", "🕺", "🕴️", "👯", "🧖", "👭", "👫",
        "👬", "💏", "💑", "👪", "👥", "👤"
    ]

    static let animals: [String] = [
        "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐽",
        "🐸", "🐵", "🐒", "🐔", "🐧", "🐦", "🐤", "🐣", "🐥", "🦆", "🦅", "🦉", "🦇", "🐺",
        "🐗", "🐴", "🦄", "🐝", "🪱", "🐛", "🦋", "🐌", "🐞", "🐜", "🪰", "🪲", "🪳", "🦟",
        "🦗", "🕷️", "🕸️", "🦂", "🐢", "🐍", "🦎", "🦖", "🦕", "🐙", "🦑", "🦐", "🦞", "🦀",
        "🪼", "🐡", "🐠", "🐟", "🐬", "🐳", "🐋", "🦈", "🦭", "🐊", "🐅", "🐆", "🦓", "🦍",
        "🦧", "🦣", "🐘", "🦛", "🦏", "🐪", "🐫", "🦒", "🦘", "🦬", "🐃", "🐂", "🐄", "🐎",
        "🐖", "🐏", "🐑", "🦙", "🐐", "🦌", "🐕", "🐩", "🦮", "🐕‍🦺", "🐈", "🐈‍⬛", "🪶", "🐓",
        "🦃", "🦤", "🦚", "🦜", "🦢", "🦩", "🕊️", "🐇", "🦝", "🦨", "🦡", "🦫", "🦦", "🦥",
        "🐁", "🐀", "🐿️", "🦔", "🐾", "🐉", "🐲", "🌵", "🎄", "🌲", "🌳", "🌴", "🪵", "🌱",
        "🌿", "☘️", "🍀", "🎍", "🪴", "🎋", "🍃", "🍂", "🍁", "🪺", "🪹", "🍄", "🪨", "🌾",
        "💐", "🌷", "🌹", "🥀", "🪻", "🌺", "🌸", "🪷", "🌼", "🌻", "🌞", "🌝", "🌛", "🌜",
        "🌚", "🌕", "🌖", "🌗", "🌘", "🌑", "🌒", "🌓", "🌔", "🌙", "🌎", "🌍", "🌏", "🪐",
        "💫", "⭐️", "🌟", "✨", "⚡️", "☄️", "💥", "🔥", "🌪️", "🌈", "☀️", "🌤️", "⛅️", "🌥️",
        "☁️", "🌦️", "🌧️", "⛈️", "🌩️", "🌨️", "❄️", "☃️", "⛄️", "🌬️", "💨", "💧", "💦", "🫧",
        "☔️", "☂️", "🌊", "🌫️"
    ]

    static let food: [String] = [
        "🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍈", "🍒", "🍑", "🥭",
        "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥬", "🥒", "🌶️", "🫑", "🌽", "🥕", "🫒",
        "🧄", "🧅", "🥔", "🍠", "🫚", "🫛", "🥐", "🥯", "🍞", "🥖", "🥨", "🧀", "🥚", "🍳",
        "🧈", "🥞", "🧇", "🥓", "🥩", "🍗", "🍖", "🦴", "🌭", "🍔", "🍟", "🍕", "🫓", "🥪",
        "🥙", "🧆", "🌮", "🌯", "🫔", "🥗", "🥘", "🫕", "🥫", "🫙", "🍝", "🍜", "🍲", "🍛",
        "🍣", "🍱", "🥟", "🦪", "🍤", "🍙", "🍚", "🍘", "🍥", "🥠", "🥮", "🍢", "🍡", "🍧",
        "🍨", "🍦", "🥧", "🧁", "🍰", "🎂", "🍮", "🍭", "🍬", "🍫", "🍿", "🍩", "🍪", "🌰",
        "🥜", "🍯", "🥛", "🍼", "🫖", "☕️", "🍵", "🧃", "🥤", "🧋", "🍶", "🍺", "🍻", "🥂",
        "🍷", "🥃", "🍸", "🍹", "🧉", "🍾", "🧊", "🥄", "🍴", "🍽️", "🥣", "🥡", "🥢", "🧂"
    ]

    static let activities: [String] = [
        "⚽️", "🏀", "🏈", "⚾️", "🥎", "🎾", "🏐", "🏉", "🥏", "🎱", "🪀", "🏓", "🏸", "🏒",
        "🏑", "🥍", "🏏", "🪃", "🥅", "⛳️", "🪁", "🏹", "🎣", "🤿", "🥊", "🥋", "🎽", "🛹",
        "🛼", "🛷", "⛸️", "🥌", "🎿", "⛷️", "🏂", "🪂", "🏋️", "🤼", "🤸", "⛹️", "🤺", "🤾",
        "🏌️", "🏇", "🧘", "🏄", "🏊", "🤽", "🚣", "🧗", "🚵", "🚴", "🏆", "🥇", "🥈", "🥉",
        "🏅", "🎖️", "🏵️", "🎗️", "🎫", "🎟️", "🎪", "🤹", "🎭", "🩰", "🎨", "🎬", "🎤", "🎧",
        "🎼", "🎹", "🥁", "🪘", "🎷", "🎺", "🪗", "🎸", "🪕", "🎻", "🪈", "🎲", "♟️", "🎯",
        "🎳", "🎮", "🎰", "🧩"
    ]

    static let travel: [String] = [
        "🚗", "🚕", "🚙", "🚌", "🚎", "🏎️", "🚓", "🚑", "🚒", "🚐", "🛻", "🚚", "🚛", "🚜",
        "🦯", "🦽", "🦼", "🛴", "🚲", "🛵", "🏍️", "🛺", "🚨", "🚔", "🚍", "🚘", "🚖", "🚡",
        "🚠", "🚟", "🚃", "🚋", "🚞", "🚝", "🚄", "🚅", "🚈", "🚂", "🚆", "🚇", "🚊", "🚉",
        "✈️", "🛫", "🛬", "🛩️", "💺", "🛰️", "🚀", "🛸", "🚁", "🛶", "⛵️", "🚤", "🛥️", "🛳️",
        "⛴️", "🚢", "⚓️", "🛟", "🪝", "⛽️", "🚧", "🚦", "🚥", "🚏", "🗺️", "🗿", "🗽", "🗼",
        "🏰", "🏯", "🏟️", "🎡", "🎢", "🎠", "⛲️", "⛱️", "🏖️", "🏝️", "🏜️", "🌋", "⛰️", "🏔️",
        "🗻", "🏕️", "⛺️", "🛖", "🏠", "🏡", "🏘️", "🏚️", "🏗️", "🏭", "🏢", "🏬", "🏣", "🏤",
        "🏥", "🏦", "🏨", "🏪", "🏫", "💒", "🏛️", "⛪️", "🕌", "🛕", "🕍", "⛩️", "🕋"
    ]

    static let objects: [String] = [
        "⌚️", "📱", "📲", "💻", "⌨️", "🖥️", "🖨️", "🖱️", "🖲️", "🕹️", "💽", "💾", "💿", "📀",
        "📼", "📷", "📸", "📹", "🎥", "📽️", "🎞️", "📞", "☎️", "📟", "📠", "📺", "📻", "🎙️",
        "🎚️", "🎛️", "⏱️", "⏲️", "⏰", "🕰️", "⌛️", "⏳", "📡", "🔋", "🪫", "🔌", "💡", "🔦",
        "🕯️", "🪔", "🧯", "🛢️", "💸", "💵", "💴", "💶", "💷", "🪙", "💰", "💳", "💎", "⚖️",
        "🪜", "🧰", "🪛", "🔧", "🔨", "⚒️", "🛠️", "⛏️", "🪚", "🔩", "⚙️", "🪤", "🧱", "⛓️",
        "🧲", "🔫", "💣", "🧨", "🪓", "🔪", "🗡️", "⚔️", "🛡️", "🚬", "⚰️", "🪦", "⚱️", "🏺",
        "🔮", "📿", "🧿", "🪬", "💈", "⚗️", "🔭", "🔬", "🕳️", "🩹", "🩺", "💊", "💉", "🩸",
        "🧬", "🦠", "🧫", "🧪", "🌡️", "🧹", "🪠", "🧺", "🧻", "🚽", "🚰", "🚿", "🛁", "🛀",
        "🧼", "🪥", "🪒", "🧽", "🪣", "🧴", "🛎️", "🔑", "🗝️", "🚪", "🪑", "🛋️", "🛏️", "🛌",
        "🧸", "🪆", "🖼️", "🪞", "🪟", "🛍️", "🛒", "🎁", "🎈", "🎏", "🎀", "🪄", "🪅", "🎊",
        "🎉", "🎎", "🏮", "🎐", "🧧", "✉️", "📩", "📨", "📧", "💌", "📥", "📤", "📦", "🏷️",
        "🪧", "📪", "📫", "📬", "📭", "📮", "📯", "📜", "📃", "📄", "📑", "🧾", "📊", "📈",
        "📉", "🗒️", "🗓️", "📅", "📆", "📇", "🗃️", "🗳️", "🗄️", "📋", "📁", "📂", "🗂️", "🗞️",
        "📰", "📓", "📔", "📒", "📕", "📗", "📘", "📙", "📚", "📖", "🔖", "🧷", "🔗", "📎",
        "🖇️", "📐", "📏", "🧮", "📌", "📍", "✂️", "🖊️", "🖋️", "✒️", "🖌️", "🖍️", "📝", "✏️",
        "🔍", "🔎", "🔏", "🔐", "🔒", "🔓"
    ]

    static let symbols: [String] = [
        "❤️", "🩷", "🧡", "💛", "💚", "💙", "🩵", "💜", "🤎", "🖤", "🩶", "🤍", "💔", "❣️",
        "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "☮️", "✝️", "☪️", "🕉️", "☸️", "✡️",
        "🔯", "🕎", "☯️", "☦️", "🛐", "⛎", "♈️", "♉️", "♊️", "♋️", "♌️", "♍️", "♎️", "♏️",
        "♐️", "♑️", "♒️", "♓️", "🆔", "⚛️", "🉑", "☢️", "☣️", "📴", "📳", "🈶", "🈚️", "🈸",
        "🈺", "🈷️", "✴️", "🆚", "💮", "🉐", "㊙️", "㊗️", "🈴", "🈵", "🈹", "🈲", "🅰️", "🅱️",
        "🆎", "🆑", "🅾️", "🆘", "❌", "⭕️", "🛑", "⛔️", "📛", "🚫", "💯", "💢", "♨️", "🚷",
        "🚯", "🚳", "🚱", "🔞", "📵", "🚭", "❗️", "❕", "❓", "❔", "‼️", "⁉️", "🔅", "🔆",
        "〽️", "⚠️", "🚸", "🔱", "⚜️", "🔰", "♻️", "✅", "🈯️", "💹", "❇️", "✳️", "❎", "🌐",
        "💠", "Ⓜ️", "🌀", "💤", "🏧", "🚾", "♿️", "🅿️", "🈳", "🈂️", "🛂", "🛃", "🛄", "🛅",
        "🚹", "🚺", "🚼", "⚧️", "🚻", "🚮", "🎦", "📶", "🈁", "🔣", "ℹ️", "🔤", "🔡", "🔠",
        "🆖", "🆗", "🆙", "🆒", "🆕", "🆓", "0️⃣", "1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣",
        "8️⃣", "9️⃣", "🔟", "🔢", "#️⃣", "*️⃣", "⏏️", "▶️", "⏸️", "⏯️", "⏹️", "⏺️", "⏭️", "⏮️",
        "⏩", "⏪", "⏫", "⏬", "◀️", "🔼", "🔽", "➡️", "⬅️", "⬆️", "⬇️", "↗️", "↘️", "↙️",
        "↖️", "↕️", "↔️", "↪️", "↩️", "⤴️", "⤵️", "🔀", "🔁", "🔂", "🔄", "🔃", "🎵", "🎶",
        "➕", "➖", "➗", "✖️", "🟰", "♾️", "💲", "💱", "™️", "©️", "®️", "〰️", "➰", "➿",
        "🔚", "🔙", "🔛", "🔝", "🔜", "☑️", "🔘", "🔴", "🟠", "🟡", "🟢", "🔵", "🟣", "🟤",
        "⚫️", "⚪️", "🟥", "🟧", "🟨", "🟩", "🟦", "🟪", "🟫", "⬛️", "⬜️", "◼️", "◻️", "◾️",
        "◽️", "▪️", "▫️", "🔶", "🔷", "🔸", "🔹", "🔺", "🔻", "🔳", "🔲"
    ]

    // MARK: - Multilingual Keywords Map (Japanese, Korean, English synonyms)

    private static let keywordDict: [String: String] = [
        // Smileys & People
        "😀": "笑顔 わらう にっこり 笑い happy smile grin joy 미소 웃음",
        "😃": "笑顔 笑う にっこり happy smile joy big grin 웃음",
        "😄": "笑顔 笑い 目 嬉しい happy smile joy 웃음 기쁨",
        "😁": "笑顔 歯 にやり happy grin teeth 미소",
        "😆": "笑顔 大笑い 爆笑 laughing joy haha 웃음 폭소",
        "😅": "冷や汗 苦笑い 汗 sweat smile nervous 땀 웃음",
        "🤣": "爆笑 転がる rofl laughing floor roll 폭소 구름",
        "😂": "嬉し泣き 涙 笑い joy tears laughing 눈물 웃음",
        "🙂": "笑顔 にっこり 微笑み slight smile 미소",
        "🙃": "逆さま 皮肉 さかさま upside down sarcastic 거꾸로",
        "😉": "ウインク ウィンク wink playful 윙크",
        "😊": "照れ笑い 嬉しい ほほえみ blush smile warm 미소 부끄",
        "😇": "天使 善人 純粋 angel halo innocent 천사",
        "🥰": "大好き 愛情 ハート 恋 love hearts adore 사랑 하트",
        "😍": "目がハート 恋 惚れる love heart eyes crushed 하트눈 사랑",
        "🤩": "スター 目が星 感動 star struck excited 별눈",
        "😘": "キス 投げキッス 愛 kiss blow love 키스 사랑",
        "😋": "美味しい ぺろり yum delicious tongue 맛있다 낼름",
        "😛": "舌出し てへぺろ tongue playful 혀 장난",
        "😜": "ウインク 舌 tongue wink silly 윙크 혀",
        "🤪": "狂気 クレイジー 変顔 crazy wild wacky 미친 장난",
        "😝": "ぎゅっ 舌出し squint tongue 맛없음 장난",
        "🤑": "お金 リッチ money rich dollar 돈 부자",
        "🤗": "ハグ 抱っこ 感謝 hug open hands warm 포옹 감사",
        "🤫": "しー 静かに 秘密 shh quiet secret 쉿 비밀 조용",
        "🤔": "考え中 疑問 悩み think pondering hmm 생각 고민",
        "🫡": "敬礼 了解 salute respect yes sir 경례 알겠습니다",
        "🤐": "口チャック 秘密 zipper secret quiet 입닫음 비밀",
        "🤨": "疑い 眉 eyebrow raised suspicious 의심",
        "😐": "無表情 真顔 neutral straight face 무표정",
        "😑": "呆れ 無表情 expressionless bored 한심 무표정",
        "😶": "無言 口なし silent blank face 말없음",
        "😏": "ドヤ顔 にやり smirk sly flirty 썩소 능글",
        "😒": "不満 睨み unamused unimpressed 째림 불만",
        "🙄": "呆れ 目を回す rolling eyes whatever 눈굴림 한심",
        "😬": "苦笑い 引きつり grimace awkward 당황",
        "🤥": "嘘 ピノキオ lying pinocchio nose 거짓말 피노키오",
        "😌": "安心 ほっとした relieved peaceful calm 안심 편안",
        "😔": "落ち込み 悲しい pensive sad down 우울 슬픔",
        "😪": "眠い 鼻提灯 sleepy snot bubble 졸림",
        "🤤": "よだれ 美味しそう drool delicious 침흘림",
        "😴": "睡眠 おやすみ 寝る sleep zzz snoring 잠 자기",
        "😷": "マスク 風邪 予防 mask sick cold illness 마스크 감기",
        "🤒": "熱 体温計 病気 fever thermometer sick 열 아픔",
        "🤕": "包帯 怪我 head bandage hurt 다침 붕대",
        "🤢": "吐き気 気持ち悪い nauseated sick gross 메스꺼움 구역질",
        "🤮": "嘔吐 ゲロ vomit throwing up 토 구토",
        "🤧": "くしゃみ 花粉症 sneeze allergy tissue 재채기 감기",
        "🥵": "暑い 猛暑 汗 hot heat red sweating 덥다 더위",
        "🥶": "寒い 氷 凍る cold freezing blue 추위 얼음",
        "🥴": "酔っ払い 朦朧 woozy drunk dizzy 취함 어지러움",
        "😵": "めまい 気絶 dizzy knocked out 기절 어지러움",
        "🤯": "頭爆発 衝撃 mind blown exploding head 충격 멘붕",
        "🤠": "カウボーイ 帽子 cowboy hat western 카우보이",
        "🥳": "パーティー お祝い 乾杯 party celebration celebrate 파티 축하",
        "😎": "サングラス かっこいい クール cool sunglasses awesome 선글라스 멋짐",
        "🤓": "オタク メガネ 勉強 ガリ勉 nerd geek glasses smart 안경 공부 오타쿠",
        "🧐": "観察 虫眼鏡 monocle inspect curious 돋보기 관찰",
        "😕": "困惑 混乱 confused puzzled 혼란 당황",
        "😟": "心配 不安 worried anxious 걱정 불안",
        "🥺": "ぴえん お願い 潤んだ目 please puppy eyes pleading 간청 애원",
        "😭": "号泣 泣く 涙 大泣き crying loud tears sob 울음 오열 눈물",
        "😱": "叫び 恐怖 ショック scream horror shock 비명 공포 경악",
        "😤": "フン 怒り 鼻息 triumphant proud huff 흥 승리",
        "😡": "激怒 怒る red rage angry mad 분노 화남",
        "😠": "怒り 不機嫌 angry annoyed mad 화남 불쾌",
        "🤬": "暴言 悪口 激怒 cursing censored swear 욕 분노",
        "😈": "悪魔 いたずら devil purple smile 악마 장난",
        "💀": "ドクロ 骸骨 死 skull dead skeleton 해골 죽음",
        "💩": "うんち うんこ 便 poop poo crap 똥",
        "🤡": "ピエロ クラウン clown circus 광대",
        "👻": "おばけ 幽霊 ゴースト ghost spooky halloween 유령 귀신",
        "👽": "宇宙人 エイリアン alien ufo 외계인",
        "🤖": "ロボット 機械 robot bot machine 로봇",
        "😺": "猫 笑顔 ねこ cat smile grinning 고양이 미소",
        "😸": "猫 笑顔 ねこ cat grin smile happy 고양이 웃음",
        "😹": "猫 嬉し泣き ねこ cat joy tears laughter 고양이 눈물",
        "😻": "猫 ハート ねこ cat love heart eyes 고양이 하트 사랑",
        "😼": "猫 ドヤ顔 ねこ cat smirk sly 고양이 썩소",
        "😽": "猫 キス ねこ cat kiss love 고양이 키스",
        "🙀": "猫 驚き ねこ cat shocked scream 고양이 놀람",
        "😿": "猫 泣く ねこ cat crying sad tears 고양이 울음",
        "😾": "猫 怒る ねこ cat angry pouting 고양이 화남",
        "🙈": "見ざる 恥ずかしい monkey see no evil see-no-evil 원숭이 안보기",
        "🙉": "聞かざる 耳塞ぐ monkey hear no evil 원숭이 안듣기",
        "🙊": "言わざる 口塞ぐ monkey speak no evil 원숭이 말안하기",
        "❤️": "ハート 赤 愛 好き red heart love like redheart 빨간하트 사랑",
        "🩷": "ハート ピンク 恋 pink heart love 핑크하트 사랑",
        "🧡": "ハート オレンジ orange heart 오렌지하트",
        "💛": "ハート 黄色 友達 yellow heart friendship 옐로하트",
        "💚": "ハート 緑 自然 green heart green nature 그린하트",
        "💙": "ハート 青 信頼 blue heart trust 파란하트",
        "🩵": "ハート 水色 light blue heart 하늘색하트",
        "💜": "ハート 紫 魅力 purple heart purple 보라하트",
        "🖤": "ハート 黒 闇 black heart black 검은하트",
        "🤍": "ハート 白 純粋 white heart white 하얀하트",
        "💔": "失恋 傷心 ブロークン broken heart heartbreak 실연 하트깨짐",
        "🔥": "炎 火 燃える 熱い fire flame hot lit hype 불 화염 열정",
        "💪": "力 筋肉 筋トレ 頑張る muscle strong bicep workout flex 힘 근육 운동 파이팅",
        "👍": "いいね グッド 賛成 thumbs up good like approve 최고 좋아요",
        "👎": "だめ 低評価 thumbs down bad dislike 싫어요",
        "👏": "拍手 称賛 おめでとう clap applause praise 박수 축하",
        "🙌": "万歳 バンザイ 歓喜 celebrate hands raised yay 만세 환호",
        "🫶": "ハート 手 指ハート heart hands love 손하트 사랑",
        "🙏": "お願い 祈り 感謝 いただきます pray please thank you 기도 부탁 감사",
        "🤝": "握手 契約 合意 handshake deal agree 악수 계약",
        "✌️": "ピース チョキ 勝利 peace victory sign 승리 브이",
        "✨": "キラキラ 輝き sparkles shine glow 반짝임 빛",
        "🌟": "星 スター 光る glowing star sparkle shining 별 스타",
        "⭐️": "星 スター star favorite 별",
        "💯": "100点 満点 パーフェクト hundred points perfect 점수 백점",
        "🧠": "脳 思考 知性 頭脳 brain smart mind think 뇌 지능 생각",

        // Animals & Nature
        "🐶": "犬 子犬 いぬ ワンちゃん dog puppy dogface 개 강아지",
        "🐕": "犬 いぬ dog shiba 개 멍멍이",
        "🐩": "プードル 犬 poodle dog 푸들 강아지",
        "🐱": "猫 子猫 ねこ ニャンコ cat kitty catface 고양이 야옹이",
        "🐈": "猫 ねこ cat pet 고양이",
        "🐈‍⬛": "黒猫 くろねこ black cat 검은고양이",
        "🦁": "ライオン 百獣の王 lion king safari 사자",
        "🐯": "トラ 虎 tiger face 호랑이",
        "🐻": "クマ 熊 bear teddy 곰",
        "🐼": "パンダ 笹 panda bear 판다",
        "🐨": "コアラ koala australia 코알라",
        "🦊": "キツネ 狐 fox animal 여우",
        "🐰": "ウサギ 兎 うさぎ rabbit bunny 토끼",
        "🐹": "ハムスター hamster pet 햄스터",
        "🐭": "ネズミ 鼠 mouse rat 쥐",
        "🐷": "ブタ 豚 ぶた pig pigface 돼지",
        "🐸": "カエル 蛙 frog toad 개구리",
        "🐵": "サル 猿 monkey monkeyface 원숭이",
        "🐧": "ペンギン 南極 penguin bird 펭귄",
        "🐦": "鳥 小鳥 とり bird fly 새",
        "🐤": "ひよこ 雛 chick baby bird 병아리",
        "🦅": "ワシ 鷲 eagle bird 독수리",
        "🦉": "フクロウ 梟 owl night bird 올빼미 부엉이",
        "🐺": "オオカミ 狼 wolf howl 늑대",
        "🐗": "イノシシ 猪 boar wild boar 멧돼지",
        "🐴": "ウマ 馬 horse racehorse 말",
        "🦄": "ユニコーン 伝説 unicorn fantasy 유니콘",
        "🐝": "ハチ 蜂 honeybee bee 꿀벌 벌",
        "🦋": "蝶 チョウ butterfly insect 나비",
        "🐢": "カメ 亀 turtle tortoise 거북이",
        "🐍": "ヘビ 蛇 snake reptile 뱀",
        "🐬": "イルカ 海 dolphin ocean marine 돌고래",
        "🐳": "クジラ 鯨 whale ocean spouting 고래",
        "🦈": "サメ 鮫 shark ocean marine 상어",
        "🐙": "タコ 蛸 octopus ocean 문어",
        "🦀": "カニ 蟹 crab seafood 게",
        "🌱": "芽 植物 新芽 若葉 seedling sprout plant green 새싹 식물",
        "🌲": "木 常緑樹 森林 tree pine evergreen 나무 숲",
        "🌳": "木 落葉樹 自然 tree nature deciduous 큰나무",
        "🌴": "ヤシの木 南国 palm tree beach island 야자수",
        "🍀": "四つ葉 クローバー 幸運 four leaf clover lucky 행운 클로버",
        "🌸": "桜 サクラ 花 cherry blossom sakura flower 벚꽃 꽃",
        "🌹": "バラ 薔薇 花 rose flower red 장미 꽃",
        "🌻": "ひまわり 向日葵 sunflower flower 여름 해바라기",
        "🌷": "チューリップ 花 tulip flower 튤립 꽃",
        "💐": "花束 ブーケ bouquet flowers gift 꽃다발",
        "🍁": "紅葉 カエデ 秋 maple leaf autumn fall 단풍잎 가을",
        "🍂": "落ち葉 枯れ葉 秋 fallen leaf autumn 낙엽 가을",
        "🍄": "キノコ 茸 mushroom toadstool 버섯",
        "☀️": "晴れ 太陽 サン sun sunny bright 태양 맑음",
        "🌙": "月 三日月 夜 moon crescent night 달 초승달 밤",
        "⚡️": "雷 電撃 稲妻 電気 lightning bolt electric thunder 번개 전기",
        "❄️": "雪 氷 冬 snowflake snow winter cold 눈 겨울 얼음",
        "🌊": "波 海 津波 ocean wave water surf 바다 파도",
        "🌈": "虹 レインボー rainbow colorful sky 무지개",

        // Food & Drink
        "🍏": "青リンゴ リンゴ green apple fruit 사과 청사과",
        "🍎": "リンゴ 赤 apple red fruit 사과",
        "🍊": "みかん オレンジ tangerine orange citrus 귤 오렌지",
        "🍋": "レモン lemon citrus sour 레몬",
        "🍌": "バナナ banana fruit 바나나",
        "🍉": "スイカ watermelon summer fruit 수박",
        "🍇": "ぶどう 葡萄 grapes fruit wine 포도",
        "🍓": "いちご 苺 strawberry fruit berry 딸기",
        "🍑": "桃 ピーチ peach fruit 복숭아",
        "🍍": "パイナップル pineapple tropical fruit 파인애플",
        "🥑": "アボカド avocado vegetable 아보카도",
        "🍅": "トマト tomato vegetable 토마토",
        "🍔": "ハンバーガー バーガー hamburger burger fastfood 햄버거",
        "🍟": "フライドポテト ポテト french fries fastfood 감자튀김",
        "🍕": "ピザ pizza slice cheese 피자",
        "🌭": "ホットドッグ hot dog sausage 핫도그",
        "🥪": "サンドイッチ sandwich lunch 샌드위치",
        "🌮": "タコス メキシコ taco mexican 타코",
        "🍜": "ラーメン 麺 noodle ramen ramen bowl 라면 국수",
        "🍲": "鍋 スープ pot stew soup 찌개 전골",
        "🍛": "カレー ライス curry rice 카레",
        "🍣": "寿司 スシ sushi japanese food 초밥 스시",
        "🍱": "弁当 bento box lunch 도시락",
        "🥟": "餃子 dumpling gyoza 만두 교자",
        "🍤": "エビフライ 天ぷら fried shrimp tempura 새우튀김",
        "🍙": "おにぎり おむすび rice ball onigiri 주먹밥 삼각김밥",
        "🍚": "ご飯 米 rice cooked bowl 밥 쌀",
        "🍘": "せんべい 煎餅 rice cracker 센베이 쌀과자",
        "🍢": "おでん oden skewer 오뎅",
        "🍡": "団子 だんご dango sweet 당고 경단",
        "🍧": "かき氷 shaved ice summer 빙수",
        "🍨": "アイス クリーム ice cream dessert 아이스크림",
        "🍦": "ソフトクリーム soft serve ice cream 소프트콘",
        "🍰": "ケーキ ショートケーキ shortcake dessert cake 케이크",
        "🎂": "バースデーケーキ 誕生祝 birthday cake party 생일케이크",
        "🍮": "プリン カスタード pudding custard 푸딩",
        "🍭": "キャンディ 飴 lollipop candy 막대사탕",
        "🍫": "チョコレート チョコ chocolate bar sweet 초콜릿",
        "🍿": "ポップコーン 映画 popcorn movie snack 팝콘",
        "🍩": "ドーナツ doughnut donut sweet 도넛",
        "🍪": "クッキー cookie biscuit biscuit 쿠키",
        "☕️": "コーヒー カフェ 珈琲 coffee hot tea cafe 커피 카페",
        "🍵": "お茶 緑茶 日本茶 green tea match 녹차 찻잔",
        "🧋": "タピオカ バブルティー bubble tea boba milk tea 버블티 타피오카",
        "🍺": "ビール お酒 乾杯 beer mug alcohol drink 맥주 술",
        "🍻": "乾杯 ビール cheers beer clinking clink 건배 맥주",
        "🍷": "ワイン 赤ワイン wine glass alcohol 와인 포도주",
        "🍶": "日本酒 徳利 sake japanese alcohol 사케 전통주",

        // Activity
        "⚽️": "サッカー フットボール soccer ball football sports 축구",
        "🏀": "バスケ バスケットボール basketball sports 농구",
        "🏈": "アメフト アメリカンフットボール american football 미식축구",
        "⚾️": "野球 ベースボール baseball sports 야구",
        "🎾": "テニス ラケット tennis ball sports 테니스",
        "🏐": "バレー バレーボール volleyball sports 배구",
        "🏓": "卓球 ピンポン table tennis ping pong 탁구",
        "🏸": "バドミントン badminton sports 배드민턴",
        "🥊": "ボクシング グローブ boxing glove punch 복싱 권투",
        "🥋": "空手 柔道 胴着 martial arts karate judo 유도 태권도",
        "🛹": "スケボー スケートボード skateboard skate 스케이트보드",
        "🎿": "スキー 冬 雪 ski skiing snow winter 스키",
        "🏂": "スノボ スノーボード snowboard winter snow 스노보드",
        "🏋️": "重量挙げ 筋トレ ジム weightlifting gym workout 역도 헬스",
        "🚴": "自転車 サイクリング cycling bike bicycle 자전거 라이딩",
        "🏆": "トロフィー 優勝 1位 勝利 trophy winner victory champion 트로피 우승",
        "🥇": "金メダル 1位 gold medal 1st place champion 금메달 일등",
        "🥈": "銀メダル 2位 silver medal 2nd place 은메달",
        "🥉": "銅メダル 3位 bronze medal 3rd place 동메달",
        "🎯": "ダーツ 的 的中 命中 direct hit bullseye dart 다트 명중 타겟",
        "🎮": "ゲーム コントローラー switch ps5 gaming video game controller 게임기 패드",
        "🎲": "サイコロ ダイス dice game gambling 주사위",
        "🎨": "絵画 パレット アート 芸術 artist palette art painting 팔레트 미술",
        "🎬": "映画 カチンコ clapper board movie cinema 영화 클랩보드",
        "🎤": "マイク カラオケ 歌 microphone karaoke singing 마이크 노래방",
        "🎧": "ヘッドホン 音楽 headphone headphones music 헤드폰 음악",
        "🎸": "ギター 楽器 ロック guitar instrument rock 기타 악기",
        "🎹": "ピアノ 鍵盤 楽器 piano keyboard music 피아노 건반",

        // Travel & Places
        "🚗": "車 自動車 ドライブ car automobile vehicle drive 자동차 운전 차",
        "🚕": "タクシー taxi cab 택시",
        "🚙": "SUV 車 自動車 suv vehicle 자동차",
        "🚌": "バス bus public transit 버스",
        "🏎️": "レーシングカー レース racing car f1 race 레이싱카",
        "🚓": "パトカー 警察 police car cop 경찰차",
        "🚑": "救急車 病院 ambulance emergency 구급차",
        "🚒": "消防車 fire engine truck 소방차",
        "🚚": "トラック 配達 truck delivery 트럭 배달",
        "🚲": "自転車 チャリ bicycle bike 자전거",
        "🏍️": "バイク 単車 motorcycle motorbike 오토바이",
        "🚨": "パトランプ 緊急 警告 siren emergency police light 사이렌 비상",
        "🚄": "新幹線 特急 bullet train shinkansen high speed 신칸센 고속열차",
        "🚅": "新幹線 電車 bullet train express 신칸센 기차",
        "🚆": "電車 列車 鉄道 train railway 기차 열차",
        "🚇": "地下鉄 メトロ metro subway underground 지하철",
        "🚉": "駅 ステーション train station station 기차역 역",
        "✈️": "飛行機 空港 旅 airplane plane airport travel 비행기 공항 여행",
        "🚀": "ロケット 宇宙 発射 rocket space launch 로켓 우주",
        "⛵️": "ヨット 帆船 sailboat boat sea 요트 돛단배",
        "🚢": "船 客船 航海 ship boat cruise 배 여객선",
        "⛽️": "ガソリンスタンド 給油 fuel pump gas station 주유소 휘발유",
        "🗼": "東京タワー タワー tokyo tower tower 도쿄타워 타워",
        "🏯": "日本の城 城 japanese castle landmark 성",
        "🏰": "城 キャッスル european castle landmark 성 캐슬",
        "🗻": "富士山 山 fuji mount fuji mountain 후지산",
        "🏠": "家 マイホーム 住宅 house home building 집 주택",
        "🏢": "オフィス ビル 会社 office building company 빌딩 회사",
        "🏣": "郵便局 post office 우체국",
        "🏥": "病院 hospital clinic 병원",
        "🏦": "銀行 bank money 은행",
        "🏪": "コンビニ convenience store 24h 편의점",
        "🏫": "学校 教室 校舎 school building classroom 학교",
        "⛩️": "神社 鳥居 shinto shrine torii 신사 도리이",

        // Objects
        "📱": "スマホ 携帯 iPhone mobile phone smartphone 스마트폰 핸드폰",
        "💻": "パソコン ノートPC Mac laptop computer macbook 노트북 컴퓨터",
        "🖥️": "パソコン デスクトップ desktop computer monitor 데스크탑 모니터",
        "⌨️": "キーボード keyboard typing 키보드",
        "⌚️": "時計 腕時計 アップルウォッチ watch apple watch smartwatch 시계 손목시계",
        "📷": "カメラ 写真 camera photo 디카 카메라",
        "📸": "カメラ フラッシュ camera flash photo 사진 플래시",
        "💡": "電球 ひらめき アイデア light bulb idea creative inspiration 전구 아이디어",
        "🔦": "懐中電灯 ライト flashlight torch 손전등",
        "📖": "本 読書 開いた本 open book reading study 책 독서",
        "📚": "本 勉強 参考書 読書 books study library education reading 책 공부 서적",
        "📝": "メモ ノート 勉強 記録 memo pencil write note test 메모 공책 시험",
        "✏️": "鉛筆 ペン 勉強 pencil write draw 연필 필기",
        "✒️": "万年筆 ペン fountain pen pen 만년필 펜",
        "🖊️": "ボールペン ペン pen ballpoint 볼펜",
        "📌": "画鋲 ピン pushpin pin 핀 압정",
        "📎": "クリップ ペーパークリップ paperclip clip 클립",
        "📏": "定規 ものさし ruler scale 자 줄자",
        "📐": "三角定規 triangle ruler 삼각자",
        "✂️": "ハサミ 鋏 scissors cut 가위",
        "🔍": "虫眼鏡 検索 調べる search magnifying glass find magnifier 돋보기 검색 찾기",
        "🔎": "虫眼鏡 検索 magnifying glass search 돋보기",
        "🔒": "鍵 ロック 施錠 locked security secure 자물쇠 잠금",
        "🔓": "解錠 オープン unlock unlocked 열림 해제",
        "🔑": "鍵 キー key password 열쇠 비밀번호",
        "⏰": "目覚まし時計 アラーム alarm clock time 알람시계 알람",
        "⏱️": "ストップウォッチ 計測 stopwatch timer 스톱워치 측정",
        "⏳": "砂時計 タイマー hourglass timer sand 모래시계",
        "💰": "お金 札束 ドル 財産 money bag dollar rich gold 돈자루 돈",
        "💴": "円 日本円 お金 yen banknote money japan 엔화 돈",
        "💵": "ドル アメリカ お金 dollar money currency 달러 돈",
        "💳": "クレジットカード カード credit card payment 신용카드 카드",
        "💎": "ダイヤモンド 宝石 ジュエリー gem stone diamond jewel 다이아몬드 보석",
        "🎁": "プレゼント 贈り物 ギフト gift wrapped present birthday 선물 기프트",
        "🎉": "クラッカー お祝い パーティー party popper celebrate congrats 폭죽 파티 축하",
        "✉️": "手紙 メール 封筒 envelope letter mail email 편지 우편 봉투",
        "📦": "段ボール 荷物 宅配 package box delivery 택배 상자",
        "🧪": "試験管 実験 科学 test tube science lab chemistry 시험관 과학 실험",
        "🔬": "顕微鏡 科学 研究 microscope science research 현미경 연구",

        // Symbols
        "❤️‍🔥": "情熱 燃えるハート heart on fire passion passionate 타오르는하트 열정",
        "❤️‍🩹": "回復 回復中ハート mending heart healing 완쾌 치유",
        "❓": "はてな クエスチョン 疑問 question mark why 질문 물음표",
        "❗️": "びっくり エクスクラメーション 感嘆 exclamation mark alert 느낌표 경고",
        "‼️": "びっくり ダブル 感嘆 double exclamation 느낌표두개",
        "⁉️": "はてな びっくり question exclamation 혼란",
        "⚠️": "注意 警告 危険 warning caution hazard 위험 경고 주의",
        "✅": "チェック 完了 OK check mark done approved success 체크 완료 확인",
        "❌": "バツ ダメ 不可 cross mark no cancel error 엑스 취소 불가",
        "⭕️": "まる 正解 丸 circle mark correct ok 동그라미 정답",
        "🛑": "一時停止 ストップ stop sign octagonal 멈춤 정지",
        "🚫": "禁止 立ち入り禁止 prohibited forbidden no entry 금지",
        "🎵": "音符 音楽 メロディ musical note music tune 음표 음악",
        "🎶": "音符 音楽 歌 notes music melody 음표들 노래",
        "💤": "zzz 睡眠 眠い sleeping zzz snore 졸림 수면",
        "🔰": "初心者 若葉マーク beginner mark japanese symbol 초보운전 새싹",
        "♻️": "リサイクル エコ recycle recycling eco 재활용 에코",
        "0️⃣": "0 数字 ゼロ zero number keycap 숫자 영",
        "1️⃣": "1 数字 一 one number keycap 숫자 일",
        "2️⃣": "2 数字 二 two number keycap 숫자 이",
        "3️⃣": "3 数字 三 three number keycap 숫자 삼",
        "4️⃣": "4 数字 四 four number keycap 숫자 사",
        "5️⃣": "5 数字 五 five number keycap 숫자 오",
        "6️⃣": "6 数字 六 six number keycap 숫자 육",
        "7️⃣": "7 数字 七 seven number keycap 숫자 칠",
        "8️⃣": "8 数字 八 eight number keycap 숫자 팔",
        "9️⃣": "9 数字 九 nine number keycap 숫자 구",
        "🔟": "10 数字 十 ten number keycap 숫자 십"
        ]

    // MARK: - All Categorized Items

    static let allCategories: [EmojiCategory] = EmojiCategory.allCases

    static func emojis(for category: EmojiCategory) -> [String] {
        switch category {
        case .smileys: return smileys
        case .animals: return animals
        case .food: return food
        case .activities: return activities
        case .travel: return travel
        case .objects: return objects
        case .symbols: return symbols
        }
    }

    /// Pre-indexed list of all EmojiItems with keywords
    static let allItems: [EmojiItem] = {
        var items: [EmojiItem] = []
        var seen = Set<String>()
        for category in EmojiCategory.allCases {
            for emoji in emojis(for: category) {
                if !seen.contains(emoji) {
                    seen.insert(emoji)
                    let unicodeNames = emoji.unicodeScalars.compactMap { $0.properties.name?.lowercased() }.joined(separator: " ")
                    let extraKeywords = keywordDict[emoji] ?? ""
                    let combined = "\(emoji) \(unicodeNames) \(extraKeywords) \(category.title.lowercased())"
                    items.append(EmojiItem(emoji: emoji, category: category, keywords: combined))
                }
            }
        }
        return items
    }()

    // MARK: - Search

    /// Multi-language search supporting Japanese (kanji, hiragana, katakana), Korean, English, and direct emoji input
    static func search(query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }

        var results: [String] = []
        var seen = Set<String>()

        // If query is an exact single emoji, prioritize it
        if let exact = allItems.first(where: { $0.emoji == trimmed }) {
            results.append(exact.emoji)
            seen.insert(exact.emoji)
            let others = allItems.filter { $0.emoji != trimmed && matches(item: $0, query: trimmed) }.map(\.emoji)
            for e in others {
                if !seen.contains(e) {
                    seen.insert(e)
                    results.append(e)
                }
            }
            return results
        }

        // Search through indexed items
        let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return [] }

        let scored = allItems.compactMap { item -> (String, Int)? in
            var score = 0
            for token in tokens {
                if item.emoji == token {
                    score += 100
                } else if item.keywords.localizedCaseInsensitiveContains(token) {
                    score += 10
                } else {
                    // Normalize Katakana to Hiragana and vice-versa for Japanese searches
                    if let hira = token.applyingTransform(.hiraganaToKatakana, reverse: true),
                       item.keywords.localizedCaseInsensitiveContains(hira) {
                        score += 8
                    } else if let kata = token.applyingTransform(.hiraganaToKatakana, reverse: false),
                              item.keywords.localizedCaseInsensitiveContains(kata) {
                        score += 8
                    } else {
                        return nil // All tokens must match
                    }
                }
            }
            return (item.emoji, score)
        }
        .sorted { $0.1 > $1.1 }

        for (emoji, _) in scored {
            if !seen.contains(emoji) {
                seen.insert(emoji)
                results.append(emoji)
            }
        }

        return results
    }

    private static func matches(item: EmojiItem, query: String) -> Bool {
        if item.emoji == query { return true }
        if item.keywords.localizedCaseInsensitiveContains(query) { return true }
        if let hira = query.applyingTransform(.hiraganaToKatakana, reverse: true),
           item.keywords.localizedCaseInsensitiveContains(hira) {
            return true
        }
        if let kata = query.applyingTransform(.hiraganaToKatakana, reverse: false),
           item.keywords.localizedCaseInsensitiveContains(kata) {
            return true
        }
        return false
    }
}
