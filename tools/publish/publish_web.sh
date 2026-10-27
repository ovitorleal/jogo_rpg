#!/usr/bin/env bash
# Exporta, valida e (opcionalmente) publica o build Web no GitHub Pages (branch gh-pages).
#
# Uso:
#   tools/publish/publish_web.sh            # testa, exporta e valida em exports/web (não publica)
#   tools/publish/publish_web.sh --deploy   # depois de validar, publica o mesmo build no branch gh-pages
#
# Variável GODOT: caminho do executável do Godot 4.7.2 (padrão: o desta máquina).
# Só publica a partir de um commit limpo do main, para o site corresponder exatamente ao código versionado.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT:-/c/Users/ovito/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe}"
OUT="$ROOT/exports/web"
DEPLOY=0
[[ "${1:-}" == "--deploy" ]] && DEPLOY=1

cd "$ROOT"
fail() { echo "ERRO: $*" >&2; exit 1; }

if [[ $DEPLOY -eq 1 ]]; then
	[[ -z "$(git status --porcelain)" ]] || fail "há alterações não commitadas; publique a partir de um commit limpo"
	[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || fail "publique a partir do branch main"
fi

echo "== 1/4 Testes"
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://tests/run_tests.gd > /tmp/publish_tests.log 2>&1 || {
	tail -20 /tmp/publish_tests.log; fail "os testes falharam"; }
grep -E "^Resultado:" /tmp/publish_tests.log

echo "== 2/4 Exportação"
rm -rf "$OUT"
mkdir -p "$OUT"
# Sem .gdignore o editor importa a pasta de saída e o build anterior entra no pacote.
touch "$ROOT/exports/.gdignore"
"$GODOT" --headless --path . --export-release "Web" exports/web/index.html > /tmp/publish_export.log 2>&1 || {
	tail -20 /tmp/publish_export.log; fail "a exportação falhou"; }
"$GODOT" --headless --path . --script res://tools/publish/write_engine_licenses.gd -- "$OUT/ENGINE_LICENSES.txt" > /dev/null 2>&1 \
	|| fail "não foi possível gerar ENGINE_LICENSES.txt"

echo "== 3/4 Verificação dos arquivos"
for file in index.html index.js index.wasm index.pck index.audio.worklet.js index.audio.position.worklet.js ENGINE_LICENSES.txt; do
	[[ -s "$OUT/$file" ]] || fail "arquivo ausente ou vazio: $file"
done
grep -q "index.js" "$OUT/index.html" || fail "index.html não carrega index.js"
if ls "$OUT"/*.import > /dev/null 2>&1; then fail "arquivos .import na saída"; fi
if grep -a -q "res://exports/" "$OUT/index.pck"; then fail "o pacote contém arquivos de exports/"; fi
if grep -a -q "res://tests/" "$OUT/index.pck"; then fail "o pacote contém testes"; fi
VERSION="$(grep -E '^config/version=' project.godot | cut -d'"' -f2)"
COMMIT="$(git rev-parse --short HEAD)"
cp THIRD_PARTY_NOTICES.md "$OUT/THIRD_PARTY_NOTICES.md"
cp LICENSE "$OUT/LICENSE.txt"
printf '%s (%s) %s\n' "$VERSION" "$COMMIT" "$(date -u +%Y-%m-%dT%H:%MZ)" > "$OUT/version.txt"
touch "$OUT/.nojekyll"
du -sh "$OUT"
ls -la "$OUT"
echo "Build $VERSION ($COMMIT) validado em exports/web."

if [[ $DEPLOY -eq 0 ]]; then
	echo "Sem --deploy: nada foi publicado."
	exit 0
fi

echo "== 4/4 Publicação no branch gh-pages"
SITE="$(mktemp -d)"
trap 'git worktree remove --force "$SITE" > /dev/null 2>&1 || true' EXIT
if git ls-remote --exit-code --heads origin gh-pages > /dev/null 2>&1; then
	git fetch -q origin gh-pages
	git worktree add -q "$SITE" origin/gh-pages
	git -C "$SITE" checkout -q -B gh-pages
else
	git worktree add -q --detach "$SITE"
	git -C "$SITE" checkout -q --orphan gh-pages
fi
git -C "$SITE" rm -rq --ignore-unmatch . > /dev/null 2>&1 || true
find "$SITE" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r "$OUT"/. "$SITE"/
git -C "$SITE" add -A
git -C "$SITE" commit -q -m "Publicar build Web $VERSION ($COMMIT)"
git -C "$SITE" push -q origin gh-pages
echo "Publicado: build $VERSION ($COMMIT) no branch gh-pages."
