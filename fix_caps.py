"""
Convert ALL CAPS UI text -> Title Case in Flutter .dart files.
ONLY targets strings on lines that contain UI widgets (Text, pw.Text, etc.).
Leaves backend code (currency codes, Firestore, date formats, map keys) untouched.
"""
import os, re

LIB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'lib')

# Abbreviations that must stay ALL CAPS
KEEP_UPPER = {
    'CGST', 'SGST', 'IGST', 'GSTIN', 'GST', 'PDF', 'UPI', 'QR',
    'OTP', 'SMS', 'URL', 'API', 'HSN', 'PIN', 'PAN', 'IFSC',
    'EMI', 'COD', 'GPS', 'USB', 'NFC', 'LED', 'BLE', 'ID',
    'USD', 'INR', 'EUR', 'GBP', 'FAQ', 'FAQs', 'MRP', 'VAT',
    'TIN', 'CIN', 'SAC', 'TDS', 'TCS', 'FSSAI',
}

def title_word(w):
    if w in KEEP_UPPER:
        return w
    if not w:
        return w
    return w[0].upper() + w[1:].lower()

def title_case(text):
    return ' '.join(title_word(w) for w in text.split(' '))

ALL_CAPS_RE = re.compile(r"""(['"])([A-Z][A-Z ]{1,}[A-Z])\1""")

def is_ui_line(line):
    """True only if the line contains a Flutter UI widget / display helper."""
    s = line.strip()
    if s.startswith('//'):
        return False
    ui_hits = [
        'Text(', 'pw.Text(', 'TranslatedText(',
        '_buildStat(', '_buildSectionLabel(', '_buildDialogField(',
        '_buildField(', '_buildHeaderTag(', '_pdfCell(',
        'Tab(', 'SnackBar(', 'SnackBarAction(',
    ]
    return any(sig in line for sig in ui_hits)

def has_data_context(line):
    """True if the line also contains backend / data patterns we must skip."""
    blockers = [
        '.collection(', '.doc(', '.where(', '.orderBy(',
        "data['", 'data["', "storeData['", 'storeData["',
        '.replaceAll(', 'DateFormat(',
        "'code':", '"code":', "'symbol':", '"symbol":',
        "'flag':", "'name':", '"name":',
        'isGreaterThanOrEqualTo:', 'isLessThan:',
    ]
    return any(b in line for b in blockers)

def process_line(line):
    if not is_ui_line(line):
        return line
    if has_data_context(line):
        return line

    def replacer(m):
        q, txt = m.group(1), m.group(2)
        if txt.strip() in KEEP_UPPER:
            return m.group(0)
        words = txt.split(' ')
        if not all(w.isupper() for w in words if w):
            return m.group(0)
        return q + title_case(txt) + q

    return ALL_CAPS_RE.sub(replacer, line)

def process_file(fpath):
    with open(fpath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    new_lines = [process_line(l) for l in lines]
    if new_lines != lines:
        with open(fpath, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        return True
    return False

def main():
    changed = []
    for root, _, files in os.walk(LIB_DIR):
        for fn in sorted(files):
            if fn.endswith('.dart'):
                fp = os.path.join(root, fn)
                if process_file(fp):
                    changed.append(os.path.relpath(fp, LIB_DIR))
                    print(f'  ok  {changed[-1]}')
    print(f'\nDone — {len(changed)} files modified.')

if __name__ == '__main__':
    main()

