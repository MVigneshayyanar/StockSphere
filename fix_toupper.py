import os
import re
import sys
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

def to_title_case(text, abbreviations):
    """Convert ALL CAPS text to Title Case, preserving abbreviations."""
    words = text.split(' ')
    result = []
    for word in words:
        if word.upper() in abbreviations:
            result.append(word)  # Keep abbreviation as-is
        elif word.isupper() and len(word) > 1:
            result.append(word[0].upper() + word[1:].lower())
        else:
            result.append(word)
    return ' '.join(result)

ABBREVIATIONS = {
    'CGST', 'SGST', 'IGST', 'GSTIN', 'GST', 'PDF', 'UPI', 'QR', 'OTP',
    'SMS', 'URL', 'API', 'HSN', 'PIN', 'PAN', 'IFSC', 'EMI', 'COD',
    'GPS', 'USB', 'NFC', 'LED', 'BLE', 'ID', 'USD', 'INR', 'EUR', 'GBP',
    'FAQ', 'MRP', 'VAT', 'TIN', 'CIN', 'SAC', 'TDS', 'TCS', 'FSSAI',
    'MAX', 'ML',
    # 3-letter ISO currency codes
    'AED', 'AFN', 'ALL', 'AMD', 'ANG', 'AOA', 'ARS', 'AUD', 'AWG', 'AZN',
    'BAM', 'BBD', 'BDT', 'BGN', 'BHD', 'BIF', 'BMD', 'BND', 'BOB', 'BRL',
    'BSD', 'BTN', 'BWP', 'BYN', 'BZD', 'CAD', 'CDF', 'CHF', 'CLP', 'CNY',
    'COP', 'CRC', 'CUP', 'CVE', 'CZK', 'DJF', 'DKK', 'DOP', 'DZD', 'EGP',
    'ERN', 'ETB', 'FJD', 'FKP', 'GEL', 'GHS', 'GIP', 'GMD', 'GNF', 'GTQ',
    'GYD', 'HKD', 'HNL', 'HRK', 'HTG', 'HUF', 'IDR', 'ILS', 'IQD', 'IRR',
    'ISK', 'JMD', 'JOD', 'JPY', 'KES', 'KGS', 'KHR', 'KMF', 'KPW', 'KRW',
    'KWD', 'KYD', 'KZT', 'LAK', 'LBP', 'LKR', 'LRD', 'LSL', 'LYD', 'MAD',
    'MDL', 'MGA', 'MKD', 'MMK', 'MNT', 'MOP', 'MRU', 'MUR', 'MVR', 'MWK',
    'MXN', 'MYR', 'MZN', 'NAD', 'NGN', 'NIO', 'NOK', 'NPR', 'NZD', 'OMR',
    'PAB', 'PEN', 'PGK', 'PHP', 'PKR', 'PLN', 'PYG', 'QAR', 'RON', 'RSD',
    'RUB', 'RWF', 'SAR', 'SBD', 'SCR', 'SDG', 'SEK', 'SGD', 'SHP', 'SLL',
    'SOS', 'SRD', 'SSP', 'STN', 'SYP', 'SZL', 'THB', 'TJS', 'TMT', 'TND',
    'TOP', 'TRY', 'TTD', 'TWD', 'TZS', 'UAH', 'UGX', 'UYU', 'UZS', 'VES',
    'VND', 'VUV', 'WST', 'XAF', 'XCD', 'XOF', 'XPF', 'YER', 'ZAR', 'ZMW', 'ZWL',
}

# Patterns that indicate backend/data context - skip these lines
DATA_CONTEXT_PATTERNS = [
    '.collection(', '.doc(', '.where(', "data['", 'data["',
    'DateFormat(', "replaceAll(", '.orderBy(',
    "import '", 'import "',
    "key:", "'key'", '"key"',
    # Don't touch map literal keys that look like data
    "'storeId'", "'updatedAt'", "'createdAt'", "'timestamp'",
]

total_changes = 0
changed_files = []

# ============================================================
# PART 1: Fix .toUpperCase() calls in UI-visible code
# ============================================================
# These are the patterns we want to change:
# .toUpperCase() → remove it (since the base text is already Title Case)
# But skip: name[0].toUpperCase() (just capitalizing first letter - OK)
# And skip: backend/data processing lines

SKIP_TOUPPER_PATTERNS = [
    '[0].toUpperCase()',   # first-letter capitalization - OK
    'excel_import_service',  # backend
    'services/',  # backend services
]

def should_skip_toupper(filepath, line):
    for pat in SKIP_TOUPPER_PATTERNS:
        if pat in filepath or pat in line:
            return True
    return False

def fix_toupper_calls(filepath, lines):
    """Remove .toUpperCase() from UI text display calls."""
    changes = 0
    new_lines = []
    for i, line in enumerate(lines):
        if 'toUpperCase()' in line and not should_skip_toupper(filepath, line):
            new_line = line.replace('.toUpperCase()', '')
            if new_line != line:
                changes += 1
                print(f"  [toUpperCase] {filepath}:{i+1}")
                print(f"    OLD: {line.rstrip()[:150]}")
                print(f"    NEW: {new_line.rstrip()[:150]}")
            new_lines.append(new_line)
        else:
            new_lines.append(line)
    return new_lines, changes

# ============================================================
# PART 2: Fix remaining static ALL CAPS strings
# ============================================================
ALL_CAPS_PATTERN = re.compile(r"""(['"])((?:[A-Z][A-Z &/]{1,}[A-Z]))\1""")

def should_skip_caps_line(line):
    """Skip lines that are backend/data context."""
    for pat in DATA_CONTEXT_PATTERNS:
        if pat in line:
            return True
    return False

def fix_static_caps(filepath, lines):
    """Convert remaining static ALL CAPS strings to Title Case."""
    changes = 0
    new_lines = []
    for i, line in enumerate(lines):
        if should_skip_caps_line(line):
            new_lines.append(line)
            continue

        new_line = line
        for m in ALL_CAPS_PATTERN.finditer(line):
            quote = m.group(1)
            text = m.group(2)
            # Check if ALL words are uppercase (excluding & and /)
            words = text.replace('&', ' ').replace('/', ' ').split()
            if not all(w.isupper() and len(w) >= 2 for w in words if w.strip()):
                continue
            # Skip abbreviations (single-word)
            if text in ABBREVIATIONS:
                continue

            # Convert to Title Case
            converted = to_title_case(text, ABBREVIATIONS)
            if converted != text:
                old_str = f"{quote}{text}{quote}"
                new_str = f"{quote}{converted}{quote}"
                new_line = new_line.replace(old_str, new_str, 1)

        if new_line != line:
            changes += 1
            print(f"  [CAPS] {filepath}:{i+1}")
            print(f"    OLD: {line.rstrip()[:150]}")
            print(f"    NEW: {new_line.rstrip()[:150]}")
        new_lines.append(new_line)
    return new_lines, changes

# ============================================================
# PART 3: Fix the StaffManagement permission display names map
# ============================================================
def fix_permission_names(filepath, lines):
    """Convert ALL CAPS values in the permission display names map."""
    changes = 0
    new_lines = []
    in_display_names = False
    for i, line in enumerate(lines):
        if "const displayNames = {" in line or "displayNames = {" in line:
            in_display_names = True
        if in_display_names and "};" in line:
            in_display_names = False

        if in_display_names:
            # Match: 'key': 'ALL CAPS VALUE',
            m = re.search(r"""(:\s*['"])([A-Z][A-Z &/]+[A-Z])(['"])""", line)
            if m:
                text = m.group(2)
                converted = to_title_case(text, ABBREVIATIONS)
                if converted != text:
                    new_line = line.replace(f"{m.group(1)}{text}{m.group(3)}", f"{m.group(1)}{converted}{m.group(3)}")
                    if new_line != line:
                        changes += 1
                        print(f"  [PermMap] {filepath}:{i+1}")
                        print(f"    OLD: {line.rstrip()}")
                        print(f"    NEW: {new_line.rstrip()}")
                        new_lines.append(new_line)
                        continue
        new_lines.append(line)
    return new_lines, changes

# ============================================================
# PART 4: Fix 'EXPIRED' static text in Profile.dart
# ============================================================
def fix_expired_text(filepath, lines):
    """Fix specific patterns like 'EXPIRED'."""
    changes = 0
    new_lines = []
    for i, line in enumerate(lines):
        new_line = line
        if "'EXPIRED'" in line:
            new_line = new_line.replace("'EXPIRED'", "'Expired'")
        if new_line != line:
            changes += 1
            print(f"  [Static] {filepath}:{i+1}")
            print(f"    OLD: {line.rstrip()[:150]}")
            print(f"    NEW: {new_line.rstrip()[:150]}")
        new_lines.append(new_line)
    return new_lines, changes

# ============================================================
# Main processing
# ============================================================
print("=" * 60)
print("Fix ALL CAPS -> Title Case (Phase 2: toUpperCase + remaining)")
print("=" * 60)

for root, _, files in os.walk('lib'):
    for fn in sorted(files):
        if not fn.endswith('.dart'):
            continue
        filepath = os.path.join(root, fn)

        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()

        original = lines[:]
        file_changes = 0

        # Apply fixes
        lines, c = fix_toupper_calls(filepath, lines)
        file_changes += c

        lines, c = fix_static_caps(filepath, lines)
        file_changes += c

        if 'StaffManagement' in filepath:
            lines, c = fix_permission_names(filepath, lines)
            file_changes += c

        if 'Profile' in filepath:
            lines, c = fix_expired_text(filepath, lines)
            file_changes += c

        if file_changes > 0:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.writelines(lines)
            total_changes += file_changes
            changed_files.append((filepath, file_changes))
            print(f"  OK {filepath}: {file_changes} changes\n")

print("=" * 60)
print(f"Total: {total_changes} changes across {len(changed_files)} files")
for fp, c in changed_files:
    print(f"  {fp}: {c}")
print("=" * 60)

