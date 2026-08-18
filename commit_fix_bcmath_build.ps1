git add server/Dockerfile

git commit -m "Fix Render build: install bcmath PHP extension" -m "The financial-hardening commit added ext-bcmath to composer.json's
require (LedgerService now uses bcadd/bccomp for exact decimal money
math instead of float). composer.json's require just DECLARES the
extension is needed - it doesn't install it. The Dockerfile's
docker-php-ext-install line only ever installed pdo/pdo_pgsql/pgsql/zip,
so Render's build correctly failed fast with 'ext-bcmath ... is
missing from your system' instead of silently deploying broken code.

Fix: added bcmath to the same docker-php-ext-install line. It's a
core PHP extension (unlike pdo_pgsql/zip, it needs no extra apt
package/lib), so this is a one-word change."

git push origin new-design
