
# Prototype bulk package builder


sh build_pkg.sh latest-release
sh sync_pkg.sh down

cd Sources/pkgbeta-tzinit-org/incoming/
# Move where you want
# Tidy up Sources/pkg*/
sh index.sh 17.3
sh sync_pkg.sh

