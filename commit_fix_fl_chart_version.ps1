git add app/pubspec.yaml

git commit -m "Fix build: pin fl_chart to an actual published version" -m "fl_chart was added as ^0.68.0, a version number that doesn't correspond to any real release on pub.dev (I guessed it without checking) -- that broke dependency resolution during 'flutter build apk', surfacing as the generic 'compileFlutterBuildRelease ... non-zero exit value 1' Gradle error with no further detail. Pinned to ^1.2.0, the actual current major release confirmed on pub.dev. Reviewed the fl_chart 0.67-1.2 changelog for breaking changes against the BarChart API used in ReportsHomePage.dart (BarChartData/BarChartGroupData/BarChartRodData/FlTitlesData/AxisTitles/SideTitles) -- none of the listed breaking changes affect the properties actually used there, so no other code changes should be needed."

git push origin new-design
