import re

# This assumes dictation is always running in the background,
# special commands are spoken to start/end dictation which are excluded

# Global, track when dictation is active.
is_active = False

# -----------------------------------------------------------------------------
# Constants

# -----------------------------------------------------------------------------
# Replace Multiple Words

TEXT_REPLACE_REGEX = (
    ("\\b" "data type" "\\b", "data-type"),
    ("\\b" "copy on write" "\\b", "copy-on-write"),
    ("\\b" "key word" "\\b", "keyword"),
)
TEXT_REPLACE_REGEX = tuple(
    (re.compile(match), replacement)
    for (match, replacement) in TEXT_REPLACE_REGEX
)

# Commands to use.
START_COMMAND = ("start", "now")
FINISH_COMMAND = ("stop", "now")
DELETE_WORD_COMMAND = ("delete", "word")

# VOSK-API doesn't use capitals anywhere so they have to be explicit added in. the
WORD_REPLACE = {
    "i": "I",
    "api": "API",
    "linux": "Linux",

    # It's also possible to ignore words entirely.
    "um": "",
}

# Regular expressions allow partial words to be replaced.
WORD_REPLACE_REGEX = (
    ("^i'(.*)", "I'\\1"),
)
WORD_REPLACE_REGEX = tuple(
    (re.compile(match), replacement)
    for (match, replacement) in WORD_REPLACE_REGEX
)

CLOSING_PUNCTUATION = {
    "period": ".",
    "comma": ",",
    "karma": ",",
    "question mark": "?",
    "colon": ":",
    "semi colon": ";",
    "close quote": '"',
}

OPENING_PUNCTUATION = {
    "open quote": '"',
}

# -----------------------------------------------------------------------------
# Utility Functions

def match_words_at_index(haystack_words, haystack_index, needle_words):
    """
    Check needle_words is in haystack_words at haystack_index.
    """
    return (
        (needle_words[0] == haystack_words[haystack_index]) and
        (haystack_index + len(needle_words) <= len(haystack_words)) and
        (needle_words[1:] == haystack_words[haystack_index + 1 : haystack_index + len(needle_words)])
    )


# -----------------------------------------------------------------------------
# Main Processing Function

def nerd_dictation_process(text):
    global is_active

    text = parse(text)

    words_input = tuple(text.split(" "))
    words = []

    i = 0

    # First check if there is text prior to having begun/ended dictation.
    # The part should always be ignored.
    if is_active:
        while i < len(words_input):
            if match_words_at_index(words_input, i, START_COMMAND):
                i += len(START_COMMAND)
                break
            i += 1
        if i == len(words_input):
            i = 0
        # Else keep the advance of 'i', since it skips text before dictation started.

    while i < len(words_input):
        word = words_input[i]
        if is_active:
            if match_words_at_index(words_input, i, FINISH_COMMAND):
                is_active = False
                i += len(FINISH_COMMAND)
                continue
        else:
            if match_words_at_index(words_input, i, START_COMMAND):
                is_active = True
                i += len(START_COMMAND)
                continue

        if is_active:
            words.append(word)
        i += 1

    return " ".join(words)

def parse(text):

    for match, replacement in TEXT_REPLACE_REGEX:
        text = match.sub(replacement, text)

    for match, replacement in CLOSING_PUNCTUATION.items():
        text = text.replace(" " + match, replacement)

    for match, replacement in OPENING_PUNCTUATION.items():
        text = text.replace(match + " ", replacement)

    words = text.split(" ")

    for i, w in enumerate(words):
        w_init = w
        w_test = WORD_REPLACE.get(w)
        if w_test is not None:
            w = w_test
        if w_init == w:
            for match, replacement in WORD_REPLACE_REGEX:
                w_test = match.sub(replacement, w)
                if w_test != w:
                    w = w_test
                    break

        words[i] = w

    # Strip any words that were replaced with empty strings.
    words[:] = [w for w in words if w]

    return " ".join(words)
