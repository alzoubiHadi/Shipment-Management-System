git add app/assets/images/fms_logo.png `
        app/android/app/src/main/res/mipmap-mdpi/ic_launcher.png `
        app/android/app/src/main/res/mipmap-hdpi/ic_launcher.png `
        app/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png `
        app/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png `
        app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png `
        app/ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png

git commit -m "Update app logo and launcher icon to new FMS branding" -m "Replaced fms_logo.png (used on the splash/welcome screen) and regenerated every Android mipmap density and iOS AppIcon.appiconset size from the new FMS logo image (navy rounded-square badge with truck, road, gold pin, and FMS wordmark). iOS icons are flattened onto the logo's own navy background since Apple doesn't allow transparency in app icons; the in-app logo and Android launcher icons keep the original transparency."

git push origin new-design
