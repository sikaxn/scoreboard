# Remote Display QR pairing

On the owner iPhone or iPad, open **Settings > Remote Display & Control**,
enable pairing, then choose **Scan to Pair** in Displays. Scan the QR code on
the remote device's pairing screen. Apple TV, Mac, iPhone, and iPad can show
the QR code; scanning is available on iPhone and iPad. Manual four-digit
pairing remains available on all operator devices.

The QR contains a version, display ID, and the current four-digit code. It
does not contain a pairing secret or network endpoint. The owner must find
the display in its nearby displays list before pairing. Missing displays,
invalid QR codes, denied/restricted camera access, and camera failures show
an error. Scanning uses the existing pairing and takeover-confirmation flow;
the receiver still validates its current code and rotates it normally.

## Verify on physical devices

1. Pair an iPhone/iPad with a discovered Remote Display by scanning its QR.
   Confirm the scoreboard connects and updates. Confirm manual pairing works.
2. Scan a pairing QR whose display is absent from the owner's list. Verify
   the discovery error appears and no pairing starts. Restore discovery and
   use **Scan Again** to pair.
3. Scan an unrelated QR, an old code, a connected display, and a display used
   by another operator. Verify invalid/unavailable codes fail and takeover
   still requires confirmation when offered by the receiver.
4. Deny camera access, cancel, and pair manually. Reopen the scanner, use
   **Open Settings**, grant access, and return. Background/dismiss the scanner
   and confirm the camera stops; reopen it and confirm scanning resumes.
5. Check the QR and numeric code in portrait/landscape, narrow windows, and
   on Apple TV. Confirm the QR scans at the displayed size and the pairing
   screen's controls remain reachable before and after pairing, including
   Disconnect, Return to Live, and Forget Paired Devices. Repeat in
   Simplified Chinese.

For App Review notes: “On an iPhone or iPad, open Settings > Remote Display
& Control, enable pairing, and select Scan to Pair in Displays. The camera
scans the QR code shown by another device in Remote Display / Control Mode.
Both devices must be discoverable to each other. Manual pairing is also
available. Camera images are not saved or transmitted.”
