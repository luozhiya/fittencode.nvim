--[[

这些字符码都是基本多语言平面（BMP）中的字符，BMP包含了Unicode标准中前65536个字符（即U+0000到U+FFFF）
在UTF-16和UTF-32编码中，对于基本多语言平面（BMP）中的字符（即码点从U+0000到U+FFFF的字符），它们的表示方式是相同的。
对于超出BMP的字符（即码点大于U+FFFF的字符），UTF-16使用代理对（surrogate pair）来表示这些字符，而UTF-32使用单个32位的码点来表示。

使用示例
print(CodePoints.EURO_SIGN)       -- 输出 8364 (0x20AC)
print(CodePoints.COPYRIGHT_SIGN)  -- 输出 169 (0x00A9)

]]

local CodePoints = {
    -- 基础符号
    EXCLAMATION_MARK          = 0x0021, -- !
    QUOTATION_MARK            = 0x0022, -- "
    NUMBER_SIGN               = 0x0023, -- #
    DOLLAR_SIGN               = 0x0024, -- $
    PERCENT_SIGN              = 0x0025, -- %
    AMPERSAND                 = 0x0026, -- &
    APOSTROPHE                = 0x0027, -- '
    LEFT_PARENTHESIS          = 0x0028, -- (
    RIGHT_PARENTHESIS         = 0x0029, -- )
    ASTERISK                  = 0x002A, -- *
    PLUS_SIGN                 = 0x002B, -- +
    COMMA                     = 0x002C, -- ,
    HYPHEN_MINUS              = 0x002D, -- -
    FULL_STOP                 = 0x002E, -- .
    SOLIDUS                   = 0x002F, -- /
    COLON                     = 0x003A, -- :
    SEMICOLON                 = 0x003B, -- ;
    QUESTION_MARK             = 0x003F, -- ?
    LOW_LINE                  = 0x005F, -- _
    LEFT_SQUARE_BRACKET       = 0x005B, -- [
    RIGHT_SQUARE_BRACKET      = 0x005D, -- ]
    LEFT_CURLY_BRACKET        = 0x007B, -- {
    RIGHT_CURLY_BRACKET       = 0x007D, -- }
    VERTICAL_LINE             = 0x007C, -- |
    TILDE                     = 0x007E, -- ~
    BACKSLASH                 = 0x005C, -- \
    CARET                     = 0x005E, -- ^
    GRAVE_ACCENT              = 0x0060, -- `
    AT_SYMBOL                 = 0x0040, -- @
    SPACE                     = 0x0020, -- 空格
    NEW_LINE                  = 0x000A, -- 换行
    EQUALS                    = 0x003D, -- =
    LEFT_ANGLE_BRACKET        = 0x003C, -- <
    RIGHT_ANGLE_BRACKET       = 0x003E, -- >
    SLASH                     = 0x002F, -- /
    PIPE                      = 0x007C, -- |

    -- 数字
    DIGIT_ZERO                = 0x0030, -- 0
    DIGIT_ONE                 = 0x0031, -- 1
    DIGIT_TWO                 = 0x0032, -- 2
    DIGIT_THREE               = 0x0033, -- 3
    DIGIT_FOUR                = 0x0034, -- 4
    DIGIT_FIVE                = 0x0035, -- 5
    DIGIT_SIX                 = 0x0036, -- 6
    DIGIT_SEVEN               = 0x0037, -- 7
    DIGIT_EIGHT               = 0x0038, -- 8
    DIGIT_NINE                = 0x0039, -- 9

    -- 货币符号
    EURO_SIGN                 = 0x20AC, -- €
    POUND_SIGN                = 0x00A3, -- £
    YEN_SIGN                  = 0x00A5, -- ¥
    WON_SIGN                  = 0x20A9, -- ₩
    RUPEE_SIGN                = 0x20A8, -- ₨

    -- 数学符号
    MULTIPLICATION_SIGN       = 0x00D7, -- ×
    DIVISION_SIGN             = 0x00F7, -- ÷
    INFINITY                  = 0x221E, -- ∞
    NOT_EQUAL_TO              = 0x2260, -- ≠
    LESS_THAN_OR_EQUAL_TO     = 0x2264, -- ≤
    GREATER_THAN_OR_EQUAL_TO  = 0x2265, -- ≥
    PLUS_MINUS_SIGN           = 0x00B1, -- ±
    MINUS_SIGN                = 0x2212, -- −
    DIVISION_SLASH            = 0x2215, -- ÷
    FRACTION_SLASH            = 0x2044, -- ⁄

    -- 箭头
    LEFT_ARROW                = 0x2190, -- ←
    UP_ARROW                  = 0x2191, -- ↑
    RIGHT_ARROW               = 0x2192, -- →
    DOWN_ARROW                = 0x2193, -- ↓

    -- 特殊符号
    COPYRIGHT_SIGN            = 0x00A9, -- ©
    REGISTERED_SIGN           = 0x00AE, -- ®
    TRADE_MARK_SIGN           = 0x2122, -- ™
    DEGREE_SIGN               = 0x00B0, -- °
    MICRO_SIGN                = 0x00B5, -- μ
    PILCROW_SIGN              = 0x00B6, -- ¶
    MIDLINE_DOT               = 0x00B7, -- ·
    SECTION_SIGN              = 0x00A7, -- §
    NOT_SIGN                  = 0x00AC, -- ¬
    INVERTED_EXCLAMATION_MARK = 0x00A1, -- ¡
    INVERTED_QUESTION_MARK    = 0x00BF, -- ¿

    -- 标点
    NO_BREAK_SPACE            = 0x00A0, --  
    EN_DASH                   = 0x2013, -- –
    LEFT_QUOTE                = 0x201C, -- “
    RIGHT_QUOTE               = 0x201D, -- ”
    HORIZONTAL_ELLIPSIS       = 0x2026, -- …
    CURLY_DASH                = 0x2015, -- ―
    CURLY_QUOTE               = 0x2018, -- ‘
    CURLY_DOUBLE_QUOTE        = 0x201C, -- “
    CURLY_QUOTE_RIGHT         = 0x2019, -- ’
    CURLY_DOUBLE_QUOTE_RIGHT  = 0x201D, -- ”
    GUILLEMET_LEFT            = 0x00AB, -- «
    GUILLEMET_RIGHT           = 0x00BB, -- »
    QUOTE_SINGLE_LEFT         = 0x2018, -- ‘
    QUOTE_SINGLE_RIGHT        = 0x2019, -- ’
    QUOTE_DOUBLE_LEFT         = 0x201C, -- “
    QUOTE_DOUBLE_RIGHT        = 0x201D, -- ”

    -- 字母 a-z 大小写
    A                         = 0x0041, -- A
    B                         = 0x0042, -- B
    C                         = 0x0043, -- C
    D                         = 0x0044, -- D
    E                         = 0x0045, -- E
    F                         = 0x0046, -- F
    G                         = 0x0047, -- G
    H                         = 0x0048, -- H
    I                         = 0x0049, -- I
    J                         = 0x004A, -- J
    K                         = 0x004B, -- K
    L                         = 0x004C, -- L
    M                         = 0x004D, -- M
    N                         = 0x004E, -- N
    O                         = 0x004F, -- O
    P                         = 0x0050, -- P
    Q                         = 0x0051, -- Q
    R                         = 0x0052, -- R
    S                         = 0x0053, -- S
    T                         = 0x0054, -- T
    U                         = 0x0055, -- U
    V                         = 0x0056, -- V
    W                         = 0x0057, -- W
    X                         = 0x0058, -- X
    Y                         = 0x0059, -- Y
    Z                         = 0x005A, -- Z
    a                         = 0x0061, -- a
    b                         = 0x0062, -- b
    c                         = 0x0063, -- c
    d                         = 0x0064, -- d
    e                         = 0x0065, -- e
    f                         = 0x0066, -- f
    g                         = 0x0067, -- g
    h                         = 0x0068, -- h
    i                         = 0x0069, -- i
    j                         = 0x006A, -- j
    k                         = 0x006B, -- k
    l                         = 0x006C, -- l
    m                         = 0x006D, -- m
    n                         = 0x006E, -- n
    o                         = 0x006F, -- o
    p                         = 0x0070, -- p
    q                         = 0x0071, -- q
    r                         = 0x0072, -- r
    s                         = 0x0073, -- s
    t                         = 0x0074, -- t
    u                         = 0x0075, -- u
    v                         = 0x0076, -- v
    w                         = 0x0077, -- w
    x                         = 0x0078, -- x
    y                         = 0x0079, -- y
    z                         = 0x007A, -- z
}

return CodePoints
