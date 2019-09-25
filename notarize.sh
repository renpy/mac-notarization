#!/bin/bash

set -e

ROOT=$(dirname "$0")

. "$ROOT/config.txt"

if [ -e "$ROOT/config.local.txt" ]; then
    . "$ROOT/config.local.txt"
fi

if [ -z "$APPLEID" ]; then
    echo "Please edit config.txt to add information about your own accounts."
    exit 1
fi

project="$1"
command="$2"
app=$(find $project -name \*.app || true)

case "$command" in
    unpack_app)
        if [ -e "$project" ]; then
            echo "$project already exists, please remove it."
            exit 1
        fi

        if [ ! -e "$project.zip" ]; then
            echo "$project.zip doesn't exist."
            exit 1
        fi

        mkdir "$project"
        unzip -d "$project" "$project.zip"

        echo "Next, run $0 $project sign_app"
        ;;

    sign_app)
        cat >entitlements.plist <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
EOT

        codesign --entitlements=entitlements.plist --options=runtime --timestamp --verbose -s "$IDENTITY" -f --deep --no-strict "$app"

        echo "Next, run $0 $project notarize_app"

        ;;

    notarize_app)

        zip -r "$project-app.zip" "$app"

        xcrun altool $ALTOOL_EXTRA -u "$APPLEID" -p "$PASSWORD"  \
            --notarize-app --primary-bundle-id "$BUNDLE" -f "$project-app.zip"

        echo "Wait for notarization to finish, then run $0 $project staple_app"

        ;;

    staple_app)

        xcrun stapler staple "$app"

        echo "Next, run $0 $project pack_dmg"

        ;;


    pack_dmg)

        hdiutil create -fs 'HFS+' -format UDBZ -ov -volname "$project" -srcfolder "$project" "$project.dmg"

        echo "Next, run $0 $project sign_dmg"

        ;;

    sign_dmg)
        codesign --timestamp --verbose -s "$IDENTITY" -f  "$project.dmg"

        echo "Next, run $0 $project notarize_dmg"

        ;;

    notarize_dmg)

        xcrun altool $ALTOOL_EXTRA -u "$APPLEID" -p "$PASSWORD"  \
            --notarize-app --primary-bundle-id "$BUNDLE.dmg" -f "$project.dmg"

        echo "Wait for notarization to finish, then run $0 $project staple_dmg"

        ;;

    staple_dmg)

        xcrun stapler staple "$project.dmg"

        echo "All done. You can give $project.dmg to anyone who wants it."

        ;;

    status)

        xcrun altool $ALTOOL_EXTRA -u "$APPLEID" -p "$PASSWORD"  \
            --notarization-history 0

        ;;

    step1)

        "$0" "$project" unpack_app
        "$0" "$project" sign_app
        "$0" "$project" notarize_app

        echo "or run $0 $project step2"

        ;;

    step2)

        "$0" "$project" staple_app
        "$0" "$project" pack_dmg
        "$0" "$project" sign_dmg
        "$0" "$project" notarize_dmg

        echo "or run $0 $project step3"

        ;;

    step3)

        "$0" "$project" staple_dmg

        ;;

    shiro)

        echo "There are no easter eggs in this project."

        ;;

    *)
        cat <<EOT
usage: $0 <project> <command>

Possible commands are:

    step1
        unpack_app
        sign_app
        notarize_app

    step2
        staple_app
        pack_dmg
        sign_dmg
        notarize_dmg

    step3
        staple_dmg

    status

EOT
        ;;
esac
