# frozen_string_literal: true

# The smstools gem otherwise reports a third "ascii" encoding for messages that happen to be
# pure ASCII. We only care about the two encodings that actually change the segment size —
# GSM-7 and Unicode (UCS-2) — so we turn the ascii bucket off and let ASCII fall under GSM,
# of which it's a subset. Segment counts are identical either way; this just keeps the reported
# encoding to the two values our pricing cares about.
SmsTools.use_ascii_encoding = false
