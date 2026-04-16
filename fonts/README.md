# SF Pro Font Installation

## Instructions

To use SF Pro fonts in this app, you need to download the font files and place them in this directory.

### Steps:

1. **Download SF Pro fonts** from Apple:
   - Visit: https://developer.apple.com/fonts/
   - Download "SF Pro" font family
   - Or search for "SF Pro fonts download" online

2. **Extract and copy these files to this `fonts/` directory:**
   - `SF-Pro-Display-Regular.ttf`
   - `SF-Pro-Display-Medium.ttf`
   - `SF-Pro-Display-Semibold.ttf`
   - `SF-Pro-Display-Bold.ttf`

3. **File structure should look like:**
   ```
   fonts/
     ├── SF-Pro-Display-Regular.ttf
     ├── SF-Pro-Display-Medium.ttf
     ├── SF-Pro-Display-Semibold.ttf
     ├── SF-Pro-Display-Bold.ttf
     └── README.md (this file)
   ```

4. **Run these commands:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## Alternative: Use System Font

If you don't want to download SF Pro fonts, you can use the system default by removing the `fontFamily` line from `main.dart`:

```dart
// In lib/main.dart, remove this line:
fontFamily: 'SF Pro',
```

## Font Weights Used in App:

- **Regular (400)**: Default text
- **Medium (500)**: Slightly emphasized text
- **Semibold (600)**: Important headings
- **Bold (700)**: Primary headings and emphasis

## Already Configured

The app is already configured to use SF Pro fonts:
- ✅ `pubspec.yaml` - Font assets configured
- ✅ `main.dart` - Theme fontFamily set to 'SF Pro'
- ⚠️ Font files need to be added to this directory

## Note

SF Pro is Apple's system font. Make sure you comply with Apple's font license terms when using it in your app.

